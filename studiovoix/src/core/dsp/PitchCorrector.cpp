#include "PitchCorrector.h"

#include "PitchShifter.h"
#include "../Log.h"

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Autotune";
}

float nearestScaleMidi (float midi, const MusicalKey& key, bool chromatic)
{
    if (chromatic)
        return std::round (midi);
    float best = std::round (midi);
    float bestDist = 1.0e9f;
    const int base = static_cast<int> (std::floor (midi)) - 2;
    for (int m = base; m <= base + 5; ++m)
    {
        if (! key.contains (m))
            continue;
        const float d = std::abs (static_cast<float> (m) - midi);
        if (d < bestDist)
        {
            bestDist = d;
            best = static_cast<float> (m);
        }
    }
    return best;
}

int scaleDegreeOf (float midi, const MusicalKey& key, int& octaveBaseMidi)
{
    const int note = static_cast<int> (nearestScaleMidi (midi, key, false));
    const auto sc = key.scale();
    const int pc = ((note % 12) + 12) % 12;
    for (int d = 0; d < 7; ++d)
    {
        if (sc[static_cast<size_t> (d)] == pc)
        {
            // octaveBaseMidi = note MIDI de la tonique de l'octave du degré (peut être < note - 11)
            const int rootOffset = ((pc - key.root) % 12 + 12) % 12;
            octaveBaseMidi = note - rootOffset;
            return d;
        }
    }
    octaveBaseMidi = note;
    return 0;
}

float diatonicShift (float midi, const MusicalKey& key, int steps)
{
    int octaveBase = 0;
    const int degree = scaleDegreeOf (midi, key, octaveBase);
    const auto sc = key.scale();
    // Intervalles en demi-tons depuis la tonique, pour chaque degré.
    std::array<int, 7> offsets {};
    for (int d = 0; d < 7; ++d)
        offsets[static_cast<size_t> (d)] = ((sc[static_cast<size_t> (d)] - key.root) % 12 + 12) % 12;

    int target = degree + steps;
    int octave = 0;
    while (target >= 7) { target -= 7; ++octave; }
    while (target < 0)  { target += 7; --octave; }
    return static_cast<float> (octaveBase + offsets[static_cast<size_t> (target)] + 12 * octave);
}

PitchCorrectionResult correctPitch (const Mono& input, double sampleRate, const PitchCorrectionParams& params,
                                    const analysis::PitchTrack* precomputedTrack)
{
    log::ScopedTimer timer (kMod, "correction de justesse");
    PitchCorrectionResult res;
    res.track = precomputedTrack != nullptr ? *precomputedTrack : analysis::detectPitch (input, sampleRate);
    const auto& frames = res.track.frames;
    const size_t nf = frames.size();
    res.outputMidi.assign (nf, 0.0f);
    res.targetMidi.assign (nf, 0.0f);

    if (params.amount <= 0.001f || nf == 0)
    {
        res.audio = input;
        for (size_t i = 0; i < nf; ++i)
            if (frames[i].voiced)
                res.outputMidi[i] = res.targetMidi[i] = analysis::hzToMidi (frames[i].f0);
        SV_LOG_DEBUG (kMod, "correction désactivée (quantité 0)"_u8);
        return res;
    }

    const double hopMs = res.track.hopSec * 1000.0;
    const float alpha = params.retuneMs <= 0.5f ? 1.0f
                                                : static_cast<float> (1.0 - std::exp (-hopMs / params.retuneMs));
    const int lpHalf = std::max (1, static_cast<int> (75.0 / hopMs));

    std::vector<float> ratios (nf, 1.0f);
    double absCents = 0.0;
    int counted = 0;

    for (size_t i = 0; i < nf;)
    {
        if (! frames[i].voiced)
        {
            ++i;
            continue;
        }
        size_t j = i;
        while (j < nf && frames[j].voiced)
            ++j;

        // Segment voisé [i, j).
        std::vector<float> midi (j - i);
        for (size_t k = i; k < j; ++k)
            midi[k - i] = analysis::hzToMidi (frames[k].f0);

        std::vector<float> base (midi.size());
        for (size_t k = 0; k < midi.size(); ++k)
        {
            double s = 0.0;
            int c = 0;
            for (int o = -lpHalf; o <= lpHalf; ++o)
            {
                const long idx = static_cast<long> (k) + o;
                if (idx >= 0 && idx < static_cast<long> (midi.size()))
                {
                    s += midi[static_cast<size_t> (idx)];
                    ++c;
                }
            }
            const float lp = static_cast<float> (s / std::max (1, c));
            base[k] = midi[k] + (lp - midi[k]) * params.humanize;
        }

        float currentTarget = nearestScaleMidi (base[0], params.key, params.chromatic);
        float smoothedCorr = currentTarget - base[0];
        for (size_t k = 0; k < midi.size(); ++k)
        {
            const float candidate = nearestScaleMidi (base[k], params.key, params.chromatic);
            if (std::abs (candidate - currentTarget) > 0.01f && std::abs (base[k] - currentTarget) > 0.5f + params.hysteresisSemis)
                currentTarget = candidate;
            const float corr = currentTarget - base[k];
            smoothedCorr += (corr - smoothedCorr) * alpha;
            const float outMidi = midi[k] + params.amount * smoothedCorr;
            res.outputMidi[i + k] = outMidi;
            res.targetMidi[i + k] = currentTarget;
            ratios[i + k] = std::pow (2.0f, (outMidi - midi[k]) / 12.0f);
            absCents += std::abs (outMidi - midi[k]) * 100.0;
            ++counted;
        }
        i = j;
    }

    res.meanAbsCorrectionCents = counted > 0 ? static_cast<float> (absCents / counted) : 0.0f;
    res.audio = psolaShift (input, sampleRate, res.track, ratios);
    SV_LOG_INFO (kMod, "Gamme " + juce::String (params.chromatic ? "chromatique" : params.key.toFrench())
                       + ", quantité "_u8 + juce::String (params.amount, 2) + ", vitesse " + juce::String (juce::roundToInt (params.retuneMs))
                       + " ms, correction moyenne " + juce::String (res.meanAbsCorrectionCents, 1) + " cents");
    return res;
}
} // namespace sv::dsp
