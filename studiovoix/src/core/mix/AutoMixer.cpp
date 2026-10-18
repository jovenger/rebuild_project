#include "AutoMixer.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../Loudness.h"
#include "../dsp/Processors.h"

namespace sv::mix
{
namespace
{
    constexpr const char* kMod = "AutoMix";
}

AutoMixResult autoMix (const Stereo& instru, const Stereo& leadProcessed, const Stereo& allVocals,
                       double sampleRate, const AutoMixSettings& settings)
{
    log::ScopedTimer timer (kMod, "mix automatique");
    AutoMixResult r;
    r.duckedInstru.makeCopyOf (instru);
    if (! settings.enabled || instru.getNumSamples() == 0)
        return r;

    r.instruLufs = static_cast<float> (loudness::integratedLufs (instru, sampleRate));
    r.leadLufs = static_cast<float> (loudness::integratedLufs (leadProcessed, sampleRate));
    if (r.instruLufs > -70.0f && r.leadLufs > -70.0f)
        r.vocalGainDb = juce::jlimit (-18.0f, 18.0f, (r.instruLufs + settings.vocalOverInstruLu) - r.leadLufs);

    if (settings.duckingDb > 0.05f && allVocals.getNumSamples() > 0)
    {
        const int n = instru.getNumSamples();
        const Mono vox = audio::toMono (allVocals);
        // Enveloppe de la voix (attaque 10 ms, relâchement 250 ms).
        const float att = static_cast<float> (std::exp (-1.0 / (sampleRate * 0.010)));
        const float rel = static_cast<float> (std::exp (-1.0 / (sampleRate * 0.250)));
        std::vector<float> env (static_cast<size_t> (n), 0.0f);
        float e = 0.0f, maxE = 0.0f;
        const float vg = dbToGain (r.vocalGainDb);
        for (int i = 0; i < n; ++i)
        {
            const float a = i < static_cast<int> (vox.size()) ? std::abs (vox[static_cast<size_t> (i)]) * vg : 0.0f;
            e = a > e ? att * e + (1.0f - att) * a : rel * e + (1.0f - rel) * a;
            env[static_cast<size_t> (i)] = e;
            maxE = std::max (maxE, e);
        }
        const float maxDb = gainToDb (maxE);

        for (int c = 0; c < 2; ++c)
        {
            const float* src = instru.getReadPointer (c);
            float* dst = r.duckedInstru.getWritePointer (c);
            dsp::Biquad bp = dsp::Biquad::bandPass (sampleRate, 2500.0, 0.8);
            for (int i = 0; i < n; ++i)
            {
                const float k = juce::jlimit (0.0f, 1.0f, (gainToDb (env[static_cast<size_t> (i)]) - (maxDb - 30.0f)) / 20.0f);
                const float dip = dbToGain (-k * settings.duckingDb) - 1.0f;          // <= 0
                const float broad = dbToGain (-k * settings.duckingDb * 0.25f);
                const float band = bp.process (src[i]);
                dst[i] = (src[i] + dip * band) * broad;
            }
        }
    }

    SV_LOG_INFO (kMod, "Instru " + juce::String (r.instruLufs, 1) + " LUFS, voix " + juce::String (r.leadLufs, 1)
                       + " LUFS -> gain voix " + juce::String (r.vocalGainDb, 1) + " dB, creux instru "
                       + juce::String (settings.duckingDb, 1) + " dB");
    return r;
}
} // namespace sv::mix
