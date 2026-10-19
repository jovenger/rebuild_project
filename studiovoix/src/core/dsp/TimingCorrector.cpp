#include "TimingCorrector.h"

#include "../Log.h"

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Timing";
}

TimingResult correctTiming (const Mono& input, double sampleRate, const TempoInfo& tempo,
                            const analysis::VoiceActivity& va, const TimingParams& params)
{
    TimingResult res;
    if (params.strength <= 0.001f || input.empty() || tempo.bpm <= 0.0)
    {
        res.audio = input;
        return res;
    }
    log::ScopedTimer timer (kMod, "recalage rythmique");

    const double step = tempo.beatSec() / std::max (1, params.divisionsPerBeat);
    const double tol = params.toleranceMs * 0.001;

    // Segments [début, fin) avec leur décalage en échantillons.
    struct Seg { long a, b, shift; };
    std::vector<Seg> segs;
    const long n = static_cast<long> (input.size());
    long cursor = 0;
    double shiftSum = 0.0;

    for (const auto& p : va.phrases)
    {
        const auto& on = p.syllableOnsets;
        for (size_t k = 0; k < on.size(); ++k)
        {
            const long a = static_cast<long> (on[k] * sampleRate);
            const long b = k + 1 < on.size() ? static_cast<long> (on[k + 1] * sampleRate)
                                              : static_cast<long> (p.endSec * sampleRate);
            if (b <= a || a < cursor)
                continue;
            if (a > cursor)
                segs.push_back ({ cursor, a, 0 });

            const double grid = tempo.firstBeatSec + std::round ((on[k] - tempo.firstBeatSec) / step) * step;
            const double dev = grid - on[k];
            long shift = 0;
            if (std::abs (dev) <= tol)
            {
                shift = static_cast<long> (std::round (dev * params.strength * sampleRate));
                if (shift != 0)
                {
                    ++res.segmentsMoved;
                    shiftSum += std::abs (static_cast<double> (shift)) / sampleRate * 1000.0;
                }
            }
            segs.push_back ({ a, std::min (b, n), shift });
            cursor = std::min (b, n);
        }
    }
    if (cursor < n)
        segs.push_back ({ cursor, n, 0 });

    // Placement en sortie : chaque segment occupe [début décalé, min(fin décalée, début décalé du suivant)).
    // Ainsi un segment avancé coupe la fin du précédent au lieu de s'y superposer
    // (sinon la normalisation mélangerait du silence et atténuerait l'attaque).
    const long fade = static_cast<long> (sampleRate * 0.005);
    std::vector<double> acc (static_cast<size_t> (n), 0.0), wsum (static_cast<size_t> (n), 0.0);
    long prevOutEnd = 0;
    for (size_t k = 0; k < segs.size(); ++k)
    {
        const auto& s = segs[k];
        // Un segment ne commence jamais après la fin du précédent : l'éventuel trou est comblé par
        // l'audio qui précède son attaque (fin de la syllabe précédente), au lieu d'un silence.
        const long outStart = k > 0 ? std::min (s.a + s.shift, prevOutEnd) : s.a + s.shift;
        long outEnd = s.b + s.shift;
        if (k + 1 < segs.size())
            outEnd = std::min (outEnd, segs[k + 1].a + segs[k + 1].shift);
        if (outEnd <= outStart)
            continue;
        prevOutEnd = outEnd;
        for (long o = outStart - fade; o < outEnd + fade; ++o)
        {
            double w = 1.0;
            if (o < outStart + fade)
                w = static_cast<double> (o - (outStart - fade)) / (2.0 * fade);
            else if (o >= outEnd - fade)
                w = static_cast<double> ((outEnd + fade) - o) / (2.0 * fade);
            w = juce::jlimit (0.0, 1.0, w);
            const long src = o - s.shift;
            if (o < 0 || o >= n || src < 0 || src >= n)
                continue;
            acc[static_cast<size_t> (o)] += w * input[static_cast<size_t> (src)];
            wsum[static_cast<size_t> (o)] += w;
        }
    }

    res.audio.resize (input.size());
    for (long i = 0; i < n; ++i)
    {
        const double w = wsum[static_cast<size_t> (i)];
        res.audio[static_cast<size_t> (i)] = w > 0.05 ? static_cast<float> (acc[static_cast<size_t> (i)] / std::max (w, 1.0)) : 0.0f;
    }
    res.meanShiftMs = res.segmentsMoved > 0 ? static_cast<float> (shiftSum / res.segmentsMoved) : 0.0f;
    SV_LOG_INFO (kMod, juce::String (res.segmentsMoved) + " syllabes recalées (décalage moyen "_u8
                       + juce::String (res.meanShiftMs, 1) + " ms, force " + juce::String (params.strength, 2) + ")");
    return res;
}
} // namespace sv::dsp
