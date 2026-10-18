#include "TrackRepair.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/VoiceActivity.h"
#include "Denoiser.h"
#include "MasterChain.h"

#include <cmath>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Reparation";

    Mono channel (const Stereo& a, int c) { return Mono (a.getReadPointer (c), a.getReadPointer (c) + a.getNumSamples()); }
    void setChannel (Stereo& a, int c, const Mono& m)
    {
        for (int i = 0; i < a.getNumSamples() && i < static_cast<int> (m.size()); ++i)
            a.setSample (c, i, m[static_cast<size_t> (i)]);
    }
}

juce::String RepairReport::summary() const
{
    juce::StringArray l;
    if (clippedRepaired > 0)
        l.add ("écrêtage réparé ("_u8 + juce::String (clippedRepaired) + " échantillons)"_u8);
    if (noiseReducedDb > 0.5f)
        l.add ("bruit -" + juce::String (noiseReducedDb, 1) + " dB dans les silences");
    for (const auto& su : leveler.surges)
        l.add ("montée brusque rabaissée "_u8 + su.describe());
    if (leveler.applied)
        l.add ("niveau régularisé : étendue "_u8 + juce::String (leveler.rangeBeforeDb, 1) + " -> " + juce::String (leveler.rangeAfterDb, 1) + " dB (+"
               + juce::String (leveler.maxBoostDb, 1) + " / -" + juce::String (leveler.maxCutDb, 1) + " dB)");
    if (resonance.applied && resonance.maxReductionDb > 0.5f)
        l.add ("résonances rabaissées : "_u8 + juce::String (resonance.meanReductionDb, 1) + " dB en moyenne, " + juce::String (resonance.maxReductionDb, 1) + " dB max");
    if (compGrDb > 0.1f)
        l.add ("compression " + juce::String (compGrDb, 1) + " dB");
    l.add ("niveau " + juce::String (outputGainDb >= 0.0f ? "+" : "") + juce::String (outputGainDb, 1) + " dB"
           + (limiterGrDb > 0.1f ? ", limiteur -" + juce::String (limiterGrDb, 1) + " dB" : juce::String()));
    return l.joinIntoString ("\n");
}

float compressStereo (Stereo& audio, double sr, const CompressorSettings& c)
{
    const int n = audio.getNumSamples();
    if (c.ratio <= 1.0f || n == 0 || audio.getNumChannels() < 1)
        return 0.0f;
    const float T = c.thresholdDb, R = c.ratio, W = std::max (0.0f, c.kneeDb);
    const float att = static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, c.attackMs) * 0.001)));
    const float rel = static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, c.releaseMs) * 0.001)));
    const float makeup = dbToGain (c.makeupDb);
    const int rmsLen = std::max (1, static_cast<int> (sr * 0.01));
    const int chans = audio.getNumChannels();
    const Stereo dry (audio);
    double sq = 0.0, grSum = 0.0;
    long grCount = 0;
    float smooth = 0.0f;
    for (int i = 0; i < n; ++i)
    {
        float det = 0.0f;
        for (int ch = 0; ch < chans; ++ch)
            det = std::max (det, std::abs (dry.getSample (ch, i)));
        float levelDb;
        if (c.rmsDetector)
        {
            sq += static_cast<double> (det) * det;
            if (i >= rmsLen)
            {
                float old = 0.0f;
                for (int ch = 0; ch < chans; ++ch)
                    old = std::max (old, std::abs (dry.getSample (ch, i - rmsLen)));
                sq -= static_cast<double> (old) * old;
            }
            levelDb = gainToDb (static_cast<float> (std::sqrt (std::max (0.0, sq) / rmsLen)));
        }
        else
            levelDb = gainToDb (det);
        float outDb;
        const float over = levelDb - T;
        if (2.0f * over < -W)
            outDb = levelDb;
        else if (2.0f * std::abs (over) <= W && W > 0.0f)
            outDb = levelDb + (1.0f / R - 1.0f) * std::pow (over + W * 0.5f, 2.0f) / (2.0f * W);
        else
            outDb = T + over / R;
        const float target = std::max (0.0f, levelDb - outDb);
        smooth = target > smooth ? att * smooth + (1.0f - att) * target : rel * smooth + (1.0f - rel) * target;
        const float g = dbToGain (-smooth) * makeup;
        for (int ch = 0; ch < chans; ++ch)
            audio.setSample (ch, i, audio.getSample (ch, i) * g);
        if (levelDb > T - 20.0f)
        {
            grSum += smooth;
            ++grCount;
        }
    }
    if (c.mix < 0.999f)
        for (int ch = 0; ch < chans; ++ch)
            for (int i = 0; i < n; ++i)
                audio.setSample (ch, i, dry.getSample (ch, i) * (1.0f - c.mix) + audio.getSample (ch, i) * c.mix);
    return grCount > 0 ? static_cast<float> (grSum / grCount) : 0.0f;
}

RepairReport repairStereo (Stereo& audio, double sr, const style::VocalParams& p)
{
    log::ScopedTimer timer (kMod, "réparation stéréo"_u8);
    RepairReport rep;
    const int n = audio.getNumSamples();
    if (n == 0 || audio.getNumChannels() < 1)
        return rep;
    const int chans = audio.getNumChannels();

    // 1) Dé-écrêtage, coupe-bas, débruitage : par canal (filtres linéaires ou profil commun).
    const Mono monoIn = audio::toMono (audio);
    const auto va = analysis::analyzeVoice (monoIn, sr);
    for (int c = 0; c < chans; ++c)
    {
        auto m = channel (audio, c);
        if (p.clean.enabled && p.clean.declip)
            rep.clippedRepaired += declip (m);
        highPass (m, sr, std::max (20.0f, p.clean.hpfHz), 4);
        if (p.clean.enabled && p.clean.denoiseDb > 0.0f)
            rep.noiseReducedDb = std::max (rep.noiseReducedDb, spectralDenoise (m, sr, va, p.clean.denoiseDb).reductionDb());
        setChannel (audio, c, m);
    }

    // 2) Niveleur lié : passages trop bas remontés, trop forts baissés, image inchangée.
    if (p.leveler.enabled)
        rep.leveler = autoLevelStereo (audio, sr, p.leveler);

    // 3) EQ corrective par canal (linéaire), puis résonances liées.
    for (int c = 0; c < chans; ++c)
    {
        auto m = channel (audio, c);
        applyEq (m, sr, p.eq);
        setChannel (audio, c, m);
    }
    if (p.resonance.enabled)
        rep.resonance = suppressResonancesStereo (audio, sr, p.resonance);

    // 4) Compression liée, niveau cible, limiteur.
    rep.compGrDb = compressStereo (audio, sr, p.comp);
    if (p.comp2.ratio > 1.0f)
        rep.compGrDb += compressStereo (audio, sr, p.comp2);
    const float g = gainForActiveRms (audio::toMono (audio), sr, p.outputDb);
    rep.outputGainDb = gainToDb (g);
    audio.applyGain (g);
    rep.limiterGrDb = limitStereo (audio, sr, -1.0f);
    size_t fixed = 0;
    for (int c = 0; c < chans; ++c)
        fixed += audio::sanitize (audio.getWritePointer (c), static_cast<size_t> (n));
    if (fixed > 0)
        SV_LOG_WARN (kMod, juce::String (static_cast<juce::int64> (fixed)) + " échantillons non finis corrigés"_u8);
    SV_LOG_INFO (kMod, rep.summary().replace ("\n", " | "));
    return rep;
}
} // namespace sv::dsp
