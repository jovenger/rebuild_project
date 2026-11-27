#include "TrackRepair.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/VoiceActivity.h"
#include "Denoiser.h"
#include "MasterChain.h"

#include <algorithm>
#include <cmath>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Reparation";

    using audio::channel;
    using audio::setChannel;
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
    rep.compGrDb = compressLinked (audio, sr, p.comp);
    if (p.comp2.ratio > 1.0f)
        rep.compGrDb += compressLinked (audio, sr, p.comp2);
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
namespace
{
    // Échantillons en plateau au sommet : mêmes conditions que declip (Denoiser.cpp), sans rien modifier.
    int plateauSamples (const float* x, int n, float threshold)
    {
        int count = 0;
        for (int i = 0; i < n;)
        {
            if (std::abs (x[i]) < threshold)
            {
                ++i;
                continue;
            }
            int j = i;
            float lo = std::abs (x[i]), hi = lo;
            while (j < n && std::abs (x[j]) >= threshold && (x[j] > 0.0f) == (x[i] > 0.0f))
            {
                lo = std::min (lo, std::abs (x[j]));
                hi = std::max (hi, std::abs (x[j]));
                ++j;
            }
            const int len = j - i;
            if (hi - lo <= 0.005f * threshold && len >= 2 && i >= 2 && j + 1 < n && len < 4096)
                count += len;
            i = j;
        }
        return count;
    }
}

MixBaseReport fixMixBase (Stereo& audio, double sampleRate, float ceilingDb, double minClippedShare)
{
    log::ScopedTimer timer (kMod, "réglage de base d'un mix"_u8);
    MixBaseReport rep;
    const int n = audio.getNumSamples(), chans = audio.getNumChannels();
    if (n <= 0 || chans <= 0 || sampleRate <= 0.0)
        return rep;
    const float peak = audio.getMagnitude (0, n);
    rep.peakBeforeDb = rep.peakAfterDb = gainToDb (peak);
    if (peak < 1.0e-5f)
    {
        SV_LOG_INFO (kMod, "Réglage de base : son muet, rien à faire"_u8);
        return rep;
    }
    // 1. Écrêtage : plateaux à moins de 1,5 % du sommet.
    const float threshold = 0.985f * peak;
    for (int c = 0; c < chans; ++c)
        rep.clippedSamples += plateauSamples (audio.getReadPointer (c), n, threshold);
    rep.clippedShare = static_cast<double> (rep.clippedSamples) / (static_cast<double> (n) * chans);
    if (rep.clippedShare >= minClippedShare)
    {
        for (int c = 0; c < chans; ++c)
        {
            Mono m (audio.getReadPointer (c), audio.getReadPointer (c) + n);   // un canal à la fois (mémoire)
            rep.clippedRepaired += declip (m, threshold);
            std::copy (m.begin(), m.end(), audio.getWritePointer (c));
        }
        rep.changed = rep.clippedRepaired > 0;
    }
    // 2. Marge : gain constant, le même sur tous les canaux (image et équilibre inchangés).
    const float ceiling = dbToGain (ceilingDb), peakNow = audio.getMagnitude (0, n);
    if (peakNow > ceiling)
    {
        const float g = ceiling / peakNow;
        audio.applyGain (g);
        rep.gainDb = gainToDb (g);
        rep.changed = true;
    }
    rep.peakAfterDb = gainToDb (audio.getMagnitude (0, n));
    SV_LOG_INFO (kMod, "Réglage de base : "_u8 + juce::String (rep.clippedSamples) + " échantillons en plateau ("_u8
                       + juce::String (100.0 * rep.clippedShare, 3) + " %, seuil " + juce::String (100.0 * minClippedShare, 3) + " %) -> "
                       + juce::String (rep.clippedRepaired) + " reconstruits ; gain "_u8 + juce::String (rep.gainDb, 2) + " dB ; crête "_u8
                       + juce::String (rep.peakBeforeDb, 1) + " -> " + juce::String (rep.peakAfterDb, 1) + " dBFS"
                       + (rep.changed ? juce::String() : juce::String (" ; son inchangé"_u8)));
    return rep;
}

} // namespace sv::dsp
