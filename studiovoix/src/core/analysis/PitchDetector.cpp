#include "PitchDetector.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <algorithm>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Pitch";
    constexpr double kAnalysisSr = 16000.0;
}

int PitchTrack::frameAt (double timeSec) const
{
    if (frames.empty())
        return -1;
    const int idx = static_cast<int> (std::lround (timeSec / hopSec));
    return juce::jlimit (0, static_cast<int> (frames.size()) - 1, idx);
}

float PitchTrack::f0At (double timeSec) const
{
    if (frames.empty())
        return 0.0f;
    const double pos = timeSec / hopSec;
    const int i0 = static_cast<int> (std::floor (pos));
    const int i1 = i0 + 1;
    const int n = static_cast<int> (frames.size());
    if (i0 < 0 || i0 >= n)
        return 0.0f;
    const auto& a = frames[static_cast<size_t> (i0)];
    if (i1 >= n || ! a.voiced)
        return a.voiced ? a.f0 : 0.0f;
    const auto& b = frames[static_cast<size_t> (i1)];
    if (! b.voiced)
        return a.f0;
    const float frac = static_cast<float> (pos - i0);
    // interpolation en échelle logarithmique
    return std::exp (std::log (a.f0) * (1.0f - frac) + std::log (b.f0) * frac);
}

bool PitchTrack::voicedAt (double timeSec) const
{
    const int i = frameAt (timeSec);
    return i >= 0 && frames[static_cast<size_t> (i)].voiced;
}

PitchTrack detectPitch (const Mono& signal, double sampleRate, const PitchParams& params)
{
    log::ScopedTimer timer (kMod, "détection de hauteur ("_u8 + juce::String (signal.size() / sampleRate, 1) + " s)");

    PitchTrack track;
    track.hopSec = params.hopSec;
    if (signal.empty() || sampleRate <= 0.0)
        return track;

    const Mono x = audio::resample (signal, sampleRate, kAnalysisSr);
    const int n = static_cast<int> (x.size());
    const int W = static_cast<int> (std::round (params.windowSec * kAnalysisSr));
    const int tauMax = static_cast<int> (std::ceil (kAnalysisSr / params.minHz));
    const int tauMin = std::max (2, static_cast<int> (std::floor (kAnalysisSr / params.maxHz)));
    const int hop = std::max (1, static_cast<int> (std::round (params.hopSec * kAnalysisSr)));
    const int numFrames = n / hop + 1;
    const float silenceGain = dbToGain (params.silenceDb);

    track.frames.resize (static_cast<size_t> (numFrames));
    std::vector<float> frame (static_cast<size_t> (W + tauMax + 2), 0.0f);
    std::vector<double> d (static_cast<size_t> (tauMax + 2), 0.0);
    std::vector<double> dn (static_cast<size_t> (tauMax + 2), 1.0);

    for (int f = 0; f < numFrames; ++f)
    {
        const int centre = f * hop;
        const int start = centre - (W + tauMax) / 2;
        for (int i = 0; i < W + tauMax + 1; ++i)
        {
            const int idx = start + i;
            frame[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[static_cast<size_t> (idx)] : 0.0f;
        }

        auto& pf = track.frames[static_cast<size_t> (f)];
        const float r = audio::rms (frame.data() + tauMax / 2, static_cast<size_t> (W));
        pf.rmsDb = gainToDb (r);
        if (r < silenceGain)
            continue;

        // Fonction de différence.
        // 4 accumulateurs indépendants : la boucle n'attend plus la latence de chaque addition.
        for (int tau = 1; tau <= tauMax; ++tau)
        {
            double acc0 = 0.0, acc1 = 0.0, acc2 = 0.0, acc3 = 0.0;
            const float* a = frame.data();
            const float* b = frame.data() + tau;
            int j = 0;
            for (; j + 3 < W; j += 4)
            {
                const double d0 = static_cast<double> (a[j]) - b[j];
                const double d1 = static_cast<double> (a[j + 1]) - b[j + 1];
                const double d2 = static_cast<double> (a[j + 2]) - b[j + 2];
                const double d3 = static_cast<double> (a[j + 3]) - b[j + 3];
                acc0 += d0 * d0;
                acc1 += d1 * d1;
                acc2 += d2 * d2;
                acc3 += d3 * d3;
            }
            for (; j < W; ++j)
            {
                const double diff = static_cast<double> (a[j]) - b[j];
                acc0 += diff * diff;
            }
            d[static_cast<size_t> (tau)] = (acc0 + acc1) + (acc2 + acc3);
        }

        // Différence normalisée cumulée.
        double running = 0.0;
        dn[0] = 1.0;
        for (int tau = 1; tau <= tauMax; ++tau)
        {
            running += d[static_cast<size_t> (tau)];
            dn[static_cast<size_t> (tau)] = running > 0.0 ? d[static_cast<size_t> (tau)] * tau / running : 1.0;
        }

        int best = -1;
        for (int tau = tauMin; tau < tauMax; ++tau)
        {
            if (dn[static_cast<size_t> (tau)] < params.threshold)
            {
                while (tau + 1 < tauMax && dn[static_cast<size_t> (tau + 1)] < dn[static_cast<size_t> (tau)])
                    ++tau;
                best = tau;
                break;
            }
        }
        if (best < 0)
        {
            double minV = 1.0e9;
            for (int tau = tauMin; tau < tauMax; ++tau)
                if (dn[static_cast<size_t> (tau)] < minV)
                {
                    minV = dn[static_cast<size_t> (tau)];
                    best = tau;
                }
        }
        if (best <= 0)
            continue;

        const double dBest = dn[static_cast<size_t> (best)];
        pf.confidence = static_cast<float> (juce::jlimit (0.0, 1.0, 1.0 - dBest));
        if (dBest > params.voicedMax)
            continue;

        // Interpolation parabolique.
        double tauRefined = best;
        if (best > 1 && best < tauMax - 1)
        {
            const double s0 = dn[static_cast<size_t> (best - 1)];
            const double s1 = dn[static_cast<size_t> (best)];
            const double s2 = dn[static_cast<size_t> (best + 1)];
            const double denom = s0 - 2.0 * s1 + s2;
            if (std::abs (denom) > 1.0e-12)
                tauRefined = best + 0.5 * (s0 - s2) / denom;
        }

        const double f0 = kAnalysisSr / tauRefined;
        if (f0 >= params.minHz && f0 <= params.maxHz)
        {
            pf.f0 = static_cast<float> (f0);
            pf.voiced = true;
        }
    }

    // Post-traitement : suppression des îlots voisés trop courts (< 3 trames)
    // et correction des sauts d'octave isolés par médiane locale.
    const int nf = static_cast<int> (track.frames.size());
    for (int i = 0; i < nf;)
    {
        if (! track.frames[static_cast<size_t> (i)].voiced)
        {
            ++i;
            continue;
        }
        int j = i;
        while (j < nf && track.frames[static_cast<size_t> (j)].voiced)
            ++j;
        if (j - i < 3)
            for (int k = i; k < j; ++k)
                track.frames[static_cast<size_t> (k)].voiced = false;
        i = j;
    }

    std::vector<float> fixedF0 (static_cast<size_t> (nf), 0.0f);
    for (int i = 0; i < nf; ++i)
    {
        const auto& fr = track.frames[static_cast<size_t> (i)];
        fixedF0[static_cast<size_t> (i)] = fr.f0;
        if (! fr.voiced)
            continue;
        std::vector<float> neigh;
        for (int k = i - 3; k <= i + 3; ++k)
            if (k >= 0 && k < nf && track.frames[static_cast<size_t> (k)].voiced)
                neigh.push_back (track.frames[static_cast<size_t> (k)].f0);
        if (neigh.size() < 3)
            continue;
        std::nth_element (neigh.begin(), neigh.begin() + static_cast<long> (neigh.size() / 2), neigh.end());
        const float med = neigh[neigh.size() / 2];
        const float ratio = fr.f0 / med;
        if (ratio > 1.8f && ratio < 2.2f)
            fixedF0[static_cast<size_t> (i)] = fr.f0 * 0.5f;
        else if (ratio > 0.45f && ratio < 0.55f)
            fixedF0[static_cast<size_t> (i)] = fr.f0 * 2.0f;
    }
    int voicedCount = 0;
    for (int i = 0; i < nf; ++i)
    {
        auto& fr = track.frames[static_cast<size_t> (i)];
        if (fr.voiced)
        {
            fr.f0 = fixedF0[static_cast<size_t> (i)];
            ++voicedCount;
        }
        else
        {
            fr.f0 = 0.0f;
        }
    }

    SV_LOG_DEBUG (kMod, juce::String (nf) + " trames, " + juce::String (voicedCount) + " voisées"_u8);
    return track;
}
} // namespace sv::analysis
