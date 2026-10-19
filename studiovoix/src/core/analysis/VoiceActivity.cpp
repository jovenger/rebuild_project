#include "VoiceActivity.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <algorithm>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "VoiceActivity";

    float percentile (std::vector<float> v, float p)
    {
        if (v.empty())
            return -120.0f;
        const auto idx = static_cast<size_t> (juce::jlimit (0.0f, 1.0f, p) * static_cast<float> (v.size() - 1));
        std::nth_element (v.begin(), v.begin() + static_cast<long> (idx), v.end());
        return v[idx];
    }
}

bool VoiceActivity::isActiveAt (double timeSec) const
{
    const auto i = static_cast<long> (timeSec / frameSec);
    return i >= 0 && i < static_cast<long> (active.size()) && active[static_cast<size_t> (i)] != 0;
}

VoiceActivity analyzeVoice (const Mono& signal, double sampleRate, const VoiceActivityParams& params)
{
    log::ScopedTimer timer (kMod, "analyse d'activité vocale"_u8);
    VoiceActivity va;
    va.frameSec = 0.01;
    if (signal.empty() || sampleRate <= 0.0)
        return va;

    const int frameLen = std::max (1, static_cast<int> (std::round (sampleRate * va.frameSec)));
    const int numFrames = static_cast<int> ((signal.size() + static_cast<size_t> (frameLen) - 1) / static_cast<size_t> (frameLen));
    va.envDb.resize (static_cast<size_t> (numFrames));
    va.active.assign (static_cast<size_t> (numFrames), 0);

    std::vector<float> nonSilent;
    for (int f = 0; f < numFrames; ++f)
    {
        const size_t start = static_cast<size_t> (f) * static_cast<size_t> (frameLen);
        const size_t len = std::min (static_cast<size_t> (frameLen), signal.size() - start);
        const float db = gainToDb (audio::rms (signal.data() + start, len));
        va.envDb[static_cast<size_t> (f)] = db;
        if (db > -100.0f)
            nonSilent.push_back (db);
    }

    if (nonSilent.empty())
    {
        SV_LOG_WARN (kMod, "voix silencieuse : aucune phrase détectée"_u8);
        return va;
    }

    va.noiseFloorDb = percentile (nonSilent, 0.10f);
    const float loud = percentile (nonSilent, 0.95f);
    va.thresholdDb = std::max ({ va.noiseFloorDb + params.marginAboveNoiseDb, loud - 40.0f, -60.0f });
    if (va.thresholdDb > loud - 6.0f)   // signal très comprimé ou bruit fort : seuil prudent
        va.thresholdDb = loud - 6.0f;

    for (int f = 0; f < numFrames; ++f)
        va.active[static_cast<size_t> (f)] = va.envDb[static_cast<size_t> (f)] > va.thresholdDb ? 1 : 0;

    // Maintien de 50 ms puis fusion des trous courts.
    const int hang = 5;
    for (int f = numFrames - 1; f >= 0; --f)
        if (va.active[static_cast<size_t> (f)])
            for (int k = 1; k <= hang && f + k < numFrames; ++k)
                va.active[static_cast<size_t> (f + k)] = 1;

    const int minGap = static_cast<int> (params.minGapSec / va.frameSec);
    const int minPhrase = static_cast<int> (params.minPhraseSec / va.frameSec);
    struct Run { int a, b; };
    std::vector<Run> runs;
    for (int f = 0; f < numFrames;)
    {
        if (! va.active[static_cast<size_t> (f)])
        {
            ++f;
            continue;
        }
        int g = f;
        while (g < numFrames && va.active[static_cast<size_t> (g)])
            ++g;
        if (! runs.empty() && f - runs.back().b < minGap)
            runs.back().b = g;
        else
            runs.push_back ({ f, g });
        f = g;
    }

    std::fill (va.active.begin(), va.active.end(), 0);
    for (const auto& r : runs)
    {
        if (r.b - r.a < minPhrase)
            continue;
        for (int f = r.a; f < r.b; ++f)
            va.active[static_cast<size_t> (f)] = 1;

        Phrase p;
        p.startSec = r.a * va.frameSec;
        p.endSec = r.b * va.frameSec;
        double energy = 0.0;
        for (int f = r.a; f < r.b; ++f)
            energy += std::pow (10.0, va.envDb[static_cast<size_t> (f)] / 10.0);
        p.levelDb = static_cast<float> (10.0 * std::log10 (std::max (1.0e-12, energy / (r.b - r.a))));

        // Attaques de syllabes : remontée d'au moins minOnsetRiseDb sur 30 ms.
        p.syllableOnsets.push_back (p.startSec);
        const int minSpacing = std::max (1, static_cast<int> (params.minSyllableSpacingSec / va.frameSec));
        int lastOnset = r.a;
        for (int f = r.a + 3; f < r.b; ++f)
        {
            const float rise = va.envDb[static_cast<size_t> (f)] - va.envDb[static_cast<size_t> (f - 3)];
            const bool localPeakAhead = f + 1 >= r.b || va.envDb[static_cast<size_t> (f + 1)] <= va.envDb[static_cast<size_t> (f)] + 0.5f;
            if (rise >= params.minOnsetRiseDb && localPeakAhead && f - lastOnset >= minSpacing)
            {
                // L'attaque commence au point bas des 30 ms précédentes.
                int lowIdx = f - 3;
                for (int k = f - 3; k < f; ++k)
                    if (va.envDb[static_cast<size_t> (k)] < va.envDb[static_cast<size_t> (lowIdx)])
                        lowIdx = k;
                if (lowIdx - lastOnset >= minSpacing)
                {
                    p.syllableOnsets.push_back (lowIdx * va.frameSec);
                    lastOnset = lowIdx;
                }
            }
        }
        va.phrases.push_back (std::move (p));
    }

    SV_LOG_INFO (kMod, juce::String ((int) va.phrases.size()) + " phrases, bruit de fond " + juce::String (va.noiseFloorDb, 1)
                       + " dB, seuil " + juce::String (va.thresholdDb, 1) + " dB");
    return va;
}
} // namespace sv::analysis
