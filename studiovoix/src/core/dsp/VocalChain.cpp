#include "VocalChain.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "PitchCorrector.h"
#include "TimingCorrector.h"

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "VocalChain";
}

juce::String describeParams (const style::VocalParams& p)
{
    juce::StringArray s;
    s.add ("autotune " + (p.pitch.enabled ? juce::String (p.pitch.amount, 2) + "/" + juce::String (juce::roundToInt (p.pitch.retuneMs)) + "ms" : juce::String ("off")));
    s.add ("HPF " + juce::String (juce::roundToInt (p.eq.lowCutHz)) + "Hz");
    s.add ("présence "_u8 + juce::String (p.eq.presenceDb, 1) + "dB@" + juce::String (juce::roundToInt (p.eq.presenceHz)));
    s.add ("air " + juce::String (p.eq.airDb, 1) + "dB");
    s.add ("comp " + juce::String (p.comp.ratio, 1) + ":1@" + juce::String (juce::roundToInt (p.comp.thresholdDb)) + "dB");
    s.add ("de-ess " + juce::String (p.deEss.amount, 2));
    s.add ("sat " + juce::String (p.sat.driveDb, 1) + "dB/" + juce::String (p.sat.mix, 2));
    s.add ("réverb "_u8 + juce::String (p.reverb.send, 2));
    s.add ("délai "_u8 + juce::String (p.delay.send, 2) + (p.delay.throwsOnly ? " (fins de phrases)" : ""));
    s.add ("sortie " + juce::String (p.outputDb, 1) + "dB, pan " + juce::String (p.pan, 2) + ", largeur " + juce::String (p.width, 2));
    return s.joinIntoString (", ");
}

VocalResult processVocal (const Mono& raw, double sampleRate, const style::VocalParams& params,
                          const AnalysisContext& context, const ProgressFn& progress)
{
    log::ScopedTimer timer (kMod, "chaîne vocale complète"_u8);
    // Dénormaux à zéro : les filtres IIR qui décroissent dans les silences ralentissent fortement le x86.
    const juce::ScopedNoDenormals noDenormals;
    VocalResult result;
    auto step = [&] (float p)
    {
        if (progress && ! progress (p))
        {
            result.cancelled = true;
            return false;
        }
        return true;
    };

    if (raw.empty())
    {
        SV_LOG_WARN (kMod, "voix vide : rien à traiter"_u8);
        result.audio = makeStereo (0);
        return result;
    }

    SV_LOG_INFO (kMod, "Réglages : "_u8 + describeParams (params));

    // 0) Traîne pour la réverbération et le délai.
    Mono x = raw;
    x.resize (raw.size() + static_cast<size_t> (kTailSec * sampleRate), 0.0f);
    if (const auto fixed = audio::sanitize (x.data(), x.size()); fixed > 0)
        SV_LOG_WARN (kMod, juce::String ((int) fixed) + " échantillons non finis corrigés en entrée"_u8);

    // 1) Normalisation d'entrée. Une prise quasi silencieuse (souvent la mauvaise entrée micro) n'est pas
    //    amplifiée : +60 dB de souffle traité comme une voix n'aide personne.
    const float rawLevelDb = activeLevelDb (x, sampleRate);
    result.report.nearSilent = rawLevelDb < -65.0f;
    float inGain = gainForActiveRms (x, sampleRate, params.inputTargetDb);
    if (result.report.nearSilent)
    {
        inGain = std::min (1.0f, inGain);
        SV_LOG_WARN (kMod, "Prise quasi silencieuse ("_u8 + juce::String (rawLevelDb, 1)
                           + " dBFS) : pas d'amplification, aucune phrase retenue (vérifie l'entrée micro)"_u8);
    }
    for (auto& v : x)
        v *= inGain;
    result.report.inputGainDb = gainToDb (inGain);
    if (! step (0.05f)) return result;

    // 2) Analyse.
    result.va = analysis::analyzeVoice (x, sampleRate);
    result.track = analysis::detectPitch (x, sampleRate);
    if (result.report.nearSilent)
        result.va.phrases.clear();   // pas de backs ni d'ad-libs générés à partir du bruit
    result.report.phrases = static_cast<int> (result.va.phrases.size());
    if (! step (0.20f)) return result;

    // 3) Nettoyage.
    result.report.clean = clean (x, sampleRate, params.clean, result.track, result.va);
    if (! step (0.30f)) return result;

    // 4) Recalage rythmique.
    if (params.timing.strength > 0.001f)
    {
        auto t = correctTiming (x, sampleRate, context.tempo, result.va, params.timing);
        x = std::move (t.audio);
        result.report.syllablesRetimed = t.segmentsMoved;
        if (t.segmentsMoved > 0)
        {
            result.va = analysis::analyzeVoice (x, sampleRate);
            result.track = analysis::detectPitch (x, sampleRate);
        }
    }
    if (! step (0.40f)) return result;

    // 5) Justesse.
    if (params.pitch.enabled && params.pitch.amount > 0.01f)
    {
        PitchCorrectionParams pc;
        pc.key = context.key;
        // Tonalité incertaine (instru sans harmonie claire, pas encore d'instru) : notes chromatiques,
        // sinon une note juste peut être tirée d'un demi-ton vers une gamme fausse.
        pc.chromatic = context.key.confidence < 0.2f;
        if (pc.chromatic)
            SV_LOG_WARN (kMod, "Tonalité incertaine (confiance "_u8 + juce::String (context.key.confidence, 2)
                               + ") : justesse corrigée vers la note la plus proche, sans gamme"_u8);
        pc.amount = params.pitch.amount;
        pc.retuneMs = params.pitch.retuneMs;
        pc.humanize = params.pitch.humanize;
        auto corrected = correctPitch (x, sampleRate, pc, &result.track);
        x = std::move (corrected.audio);
        result.report.meanCorrectionCents = corrected.meanAbsCorrectionCents;
        result.track = analysis::detectPitch (x, sampleRate);
    }
    result.prepared = x;
    result.prepared.resize (raw.size());   // même durée que la prise (sans la traîne)
    if (! step (0.60f)) return result;

    // 6) Égalisation (+ correction d'après la référence).
    {
        log::ScopedTimer t (kMod, "égalisation"_u8);
        applyEq (x, sampleRate, params.eq);
        if (params.referenceEq && context.reference.valid())
        {
            const auto mine = analysis::averageSpectrum (x, sampleRate);
            const auto curve = analysis::matchCurve (mine, context.reference, 4.0f, 150.0f, 14000.0f, params.referenceStrength);
            if (! curve.empty())
                applyCurveEq (x, sampleRate, mine.centersHz, curve);
        }
    }
    if (! step (0.65f)) return result;

    // 7) Compression, de-esser, saturation.
    {
        log::ScopedTimer t (kMod, "compression");
        result.report.compGrDb = compress (x, sampleRate, params.comp);
        if (params.comp2.ratio > 1.0f)
            result.report.compGrDb += compress (x, sampleRate, params.comp2);
    }
    {
        log::ScopedTimer t (kMod, "de-esser");
        result.report.deEssGrDb = deEss (x, sampleRate, params.deEss);
    }
    {
        log::ScopedTimer t (kMod, "saturation");
        saturate (x, sampleRate, params.sat);
    }
    if (! step (0.75f)) return result;

    // 8) Niveau de sortie.
    float outGain = gainForActiveRms (x, sampleRate, params.outputDb);
    if (result.report.nearSilent)
        outGain = std::min (1.0f, outGain);
    for (auto& v : x)
        v *= outGain;

    // 9) Image stéréo + effets.
    result.audio = placeStereo (x, sampleRate, params.pan, params.width, params.dryGain);
    if (! step (0.80f)) return result;

    {
        log::ScopedTimer t (kMod, "réverbération"_u8);
        const auto rev = reverbReturn (x, sampleRate, params.reverb);
        for (int c = 0; c < 2; ++c)
            result.audio.addFrom (c, 0, rev, c, 0, result.audio.getNumSamples());
    }
    if (! step (0.90f)) return result;

    {
        log::ScopedTimer t (kMod, "délai"_u8);
        std::vector<float> env;
        if (params.delay.throwsOnly)
            env = phraseEndThrowEnvelope (x.size(), sampleRate, result.va);
        const auto del = delayReturn (x, sampleRate, context.tempo.bpm, params.delay, env);
        for (int c = 0; c < 2; ++c)
            result.audio.addFrom (c, 0, del, c, 0, result.audio.getNumSamples());
    }

    for (int c = 0; c < 2; ++c)
        audio::sanitize (result.audio.getWritePointer (c), static_cast<size_t> (result.audio.getNumSamples()));

    step (1.0f);
    SV_LOG_INFO (kMod, "Voix traitée : gain d'entrée "_u8 + juce::String (result.report.inputGainDb, 1) + " dB, "
                       + juce::String (result.report.phrases) + " phrases, justesse " + juce::String (result.report.meanCorrectionCents, 1)
                       + " cents, compression " + juce::String (result.report.compGrDb, 1) + " dB, de-esser "
                       + juce::String (result.report.deEssGrDb, 1) + " dB, crête "_u8
                       + juce::String (gainToDb (std::max (result.audio.getMagnitude (0, 0, result.audio.getNumSamples()),
                                                           result.audio.getMagnitude (1, 0, result.audio.getNumSamples()))), 1) + " dBFS");
    return result;
}
} // namespace sv::dsp
