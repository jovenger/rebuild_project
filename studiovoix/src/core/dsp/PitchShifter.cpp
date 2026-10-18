#include "PitchShifter.h"

#include "../Log.h"

#include <algorithm>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "PSOLA";

    float ratioAt (const analysis::PitchTrack& track, const std::vector<float>& ratios, double timeSec)
    {
        if (ratios.empty())
            return 1.0f;
        const double pos = timeSec / track.hopSec;
        const int i0 = static_cast<int> (std::floor (pos));
        const int n = static_cast<int> (ratios.size());
        if (i0 < 0)
            return ratios.front();
        if (i0 + 1 >= n)
            return ratios.back();
        const float f = static_cast<float> (pos - i0);
        return ratios[static_cast<size_t> (i0)] * (1.0f - f) + ratios[static_cast<size_t> (i0 + 1)] * f;
    }
}

Mono psolaShift (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                 const std::vector<float>& ratioPerFrame, const PsolaOptions& options)
{
    log::ScopedTimer timer (kMod, "transposition PSOLA (" + juce::String (input.size() / sampleRate, 1) + " s)");
    const int n = static_cast<int> (input.size());
    if (n == 0)
        return {};

    const double defaultPeriod = sampleRate / options.defaultUnvoicedHz;
    auto periodAt = [&] (double sample) -> double
    {
        const float f0 = track.f0At (sample / sampleRate);
        return f0 > 0.0f ? sampleRate / f0 : defaultPeriod;
    };

    // Signal lissé (1 ms) pour caler les marques sur les impulsions glottiques.
    const int smoothLen = std::max (1, static_cast<int> (sampleRate * 0.001));
    std::vector<float> smooth (static_cast<size_t> (n));
    {
        double acc = 0.0;
        for (int i = 0; i < n; ++i)
        {
            acc += input[static_cast<size_t> (i)];
            if (i >= smoothLen)
                acc -= input[static_cast<size_t> (i - smoothLen)];
            smooth[static_cast<size_t> (i)] = static_cast<float> (acc / smoothLen);
        }
    }

    // Marques d'analyse.
    std::vector<int> marks;
    std::vector<char> markVoiced;
    {
        double m = 0.0;
        while (m < n)
        {
            const int mi = static_cast<int> (m);
            const bool voiced = track.voicedAt (mi / sampleRate);
            int chosen = mi;
            const double p = periodAt (mi);
            if (voiced && ! marks.empty())
            {
                const int radius = std::max (1, static_cast<int> (p * 0.25));
                float best = -1.0e9f;
                for (int k = std::max (0, mi - radius); k <= std::min (n - 1, mi + radius); ++k)
                    if (smooth[static_cast<size_t> (k)] > best)
                    {
                        best = smooth[static_cast<size_t> (k)];
                        chosen = k;
                    }
                if (chosen <= marks.back())
                    chosen = marks.back() + 1;
            }
            marks.push_back (chosen);
            markVoiced.push_back (voiced ? 1 : 0);
            m = chosen + std::max (1.0, periodAt (chosen));
        }
    }

    std::vector<double> acc (static_cast<size_t> (n), 0.0);
    std::vector<double> wsum (static_cast<size_t> (n), 0.0);

    double ts = 0.0;
    size_t nearest = 0;
    while (ts < n)
    {
        const double tSec = ts / sampleRate;
        const bool voiced = track.voicedAt (tSec);
        const float ratio = voiced ? std::max (0.25f, std::min (4.0f, ratioAt (track, ratioPerFrame, tSec))) : 1.0f;
        const double pa = periodAt (ts);
        const double ps = pa / ratio;

        // Marque d'analyse la plus proche de ts.
        while (nearest + 1 < marks.size() && std::abs (marks[nearest + 1] - ts) <= std::abs (marks[nearest] - ts))
            ++nearest;
        while (nearest > 0 && std::abs (marks[nearest - 1] - ts) < std::abs (marks[nearest] - ts))
            --nearest;

        const int ta = marks[nearest];
        const double paMark = periodAt (ta);
        const int half = std::max (2, static_cast<int> (std::round (std::max (paMark, std::min (ps, 1.5 * paMark)))));
        const float gain = markVoiced[nearest] ? 1.0f : options.unvoicedGain;
        const int tsi = static_cast<int> (std::round (ts));

        for (int j = -half; j <= half; ++j)
        {
            const int src = ta + j;
            const int dst = tsi + j;
            if (src < 0 || src >= n || dst < 0 || dst >= n)
                continue;
            const double w = 0.5 + 0.5 * std::cos (juce::MathConstants<double>::pi * j / half);
            acc[static_cast<size_t> (dst)] += w * input[static_cast<size_t> (src)] * gain;
            wsum[static_cast<size_t> (dst)] += w;
        }

        ts += std::max (1.0, ps);
    }

    Mono out (static_cast<size_t> (n));
    for (int i = 0; i < n; ++i)
        out[static_cast<size_t> (i)] = static_cast<float> (acc[static_cast<size_t> (i)] / std::max (0.6, wsum[static_cast<size_t> (i)]));
    return out;
}

Mono psolaShiftSemitones (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                          float semitones, const PsolaOptions& options)
{
    const float r = std::pow (2.0f, semitones / 12.0f);
    std::vector<float> ratios (track.frames.size(), r);
    return psolaShift (input, sampleRate, track, ratios, options);
}
} // namespace sv::dsp
