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

juce::String describeChain (const style::VocalParams& p)
{
    auto num = [] (float v)   // 1 décimale, sans « .0 » inutile
    {
        const auto t = juce::String (v, 1);
        return t.endsWith (".0") ? t.dropLastCharacters (2) : t;
    };
    auto db = [num] (float v) { return (v > 0.0f ? "+" : "") + num (v) + " dB"; };
    auto hz = [num] (float f) { return f >= 1000.0f ? num (f / 1000.0f) + " kHz" : juce::String (juce::roundToInt (f)) + " Hz"; };
    auto pct = [] (float v) { return juce::String (juce::roundToInt (v * 100.0f)) + " %"; };
    auto note = [] (float beats) -> juce::String
    {
        if (std::abs (beats - 0.25f) < 0.01f) return "1/16";
        if (std::abs (beats - 0.5f) < 0.01f)  return "1/8 (croche)";
        if (std::abs (beats - 0.75f) < 0.01f) return "1/8 pointée"_u8;
        if (std::abs (beats - 1.0f) < 0.01f)  return "1/4 (noire)";
        if (std::abs (beats - 1.5f) < 0.01f)  return "1/4 pointée"_u8;
        if (std::abs (beats - 2.0f) < 0.01f)  return "1/2 (blanche)";
        return juce::String (beats, 2) + " temps";
    };
    juce::StringArray l;

    if (! p.pitch.enabled || p.pitch.amount < 0.01f)
        l.add ("Autotune : désactivé"_u8);
    else
        l.add ("Autotune : "_u8 + (p.pitch.amount >= 0.85f && p.pitch.retuneMs <= 15.0f ? "effet marqué"_u8
                                   : p.pitch.amount >= 0.5f ? juce::String ("moyen") : juce::String ("léger, naturel"_u8))
               + " (" + pct (p.pitch.amount) + ", vitesse " + juce::String (juce::roundToInt (p.pitch.retuneMs)) + " ms)");

    if (p.clean.enabled)
        l.add ("Nettoyage : coupe-bas "_u8 + hz (p.clean.hpfHz) + ", débruitage -"_u8 + juce::String (juce::roundToInt (p.clean.denoiseDb))
               + " dB, silences -" + juce::String (juce::roundToInt (p.clean.gateRangeDb))
               + " dB, respirations -" + juce::String (juce::roundToInt (p.clean.breathReductionDb)) + " dB" + (p.clean.dePlosive ? ", plosives (p, b)" : "")
               + (p.clean.declip ? ", dé-écrêtage"_u8 : ""));
    else
        l.add ("Nettoyage : désactivé"_u8);

    if (p.timing.strength > 0.001f)
        l.add ("Recalage rythmique : "_u8 + pct (p.timing.strength));

    juce::StringArray eq;
    eq.add ("coupe-bas " + hz (p.eq.lowCutHz));
    if (std::abs (p.eq.lowShelfDb) >= 0.1f) eq.add ("graves " + db (p.eq.lowShelfDb) + " sous " + hz (p.eq.lowShelfHz));
    if (std::abs (p.eq.mudDb) >= 0.1f)      eq.add ("bas-médium "_u8 + db (p.eq.mudDb) + " à "_u8 + hz (p.eq.mudHz));
    if (std::abs (p.eq.presenceDb) >= 0.1f) eq.add ("présence "_u8 + db (p.eq.presenceDb) + " à "_u8 + hz (p.eq.presenceHz));
    if (std::abs (p.eq.airDb) >= 0.1f)      eq.add ("air " + db (p.eq.airDb) + " au-dessus de "_u8 + hz (p.eq.airHz));
    if (p.eq.highCutHz > 0.0f)              eq.add ("coupe-haut " + hz (p.eq.highCutHz));
    l.add ("EQ : " + eq.joinIntoString (", "));

    auto comp = [&] (const dsp::CompressorSettings& c)
    {
        return num (c.ratio) + ":1 au seuil "_u8 + juce::String (juce::roundToInt (c.thresholdDb)) + " dB, attaque "
               + juce::String (juce::roundToInt (c.attackMs)) + " ms, relâche "_u8 + juce::String (juce::roundToInt (c.releaseMs)) + " ms"
               + (c.mix < 0.99f ? ", parallèle "_u8 + pct (c.mix) : juce::String()) + (c.rmsDetector ? ", détection RMS"_u8 : juce::String());
    };
    l.add ("Compresseur : " + (p.comp.ratio > 1.01f ? comp (p.comp) : juce::String ("désactivé"_u8)));
    if (p.comp2.ratio > 1.01f)
        l.add ("Compresseur 2 (nivellement) : " + comp (p.comp2));

    l.add ("De-esser : " + (p.deEss.amount > 0.01f ? hz (p.deEss.freqHz) + ", force " + pct (p.deEss.amount) + ", max -"
                                + juce::String (juce::roundToInt (p.deEss.maxReductionDb)) + " dB"
                                                   : juce::String ("désactivé"_u8)));
    l.add ("Saturation : " + (p.sat.mix > 0.01f ? db (p.sat.driveDb) + " de chauffe, mélange "_u8 + pct (p.sat.mix) : juce::String ("aucune")));
    l.add ("Réverb : "_u8 + (p.reverb.send > 0.005f ? pct (p.reverb.send) + ", taille " + pct (p.reverb.roomSize) + ", pré-délai "_u8
                                + juce::String (juce::roundToInt (p.reverb.preDelayMs)) + " ms"
                                                     : juce::String ("aucune")));
    l.add ("Délai : "_u8 + (p.delay.send > 0.005f ? pct (p.delay.send) + ", " + note (p.delay.noteBeats) + ", répétitions "_u8 + pct (p.delay.feedback)
                               + (p.delay.pingPong ? ", ping-pong" : "") + (p.delay.throwsOnly ? ", seulement en fin de phrase" : "")
                                                  : juce::String ("aucun")));
    l.add ("Sortie : " + db (p.outputDb) + (std::abs (p.pan) > 0.01f ? ", panoramique " + juce::String (juce::roundToInt (p.pan * 100.0f)) : juce::String())
           + (p.width > 0.01f ? ", largeur " + pct (p.width) : juce::String()) + (p.dryGain < 0.99f ? ", voix directe "_u8 + pct (p.dryGain) : juce::String()));
    return l.joinIntoString ("\n");
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

    // 7) Compresseur rapide (crêtes), de-esser, compresseur doux (nivellement), saturation — ordre courant en studio.
    {
        log::ScopedTimer t (kMod, "compression");
        result.report.compGrDb = compress (x, sampleRate, params.comp);
    }
    {
        log::ScopedTimer t (kMod, "de-esser");
        result.report.deEssGrDb = deEss (x, sampleRate, params.deEss);
    }
    if (params.comp2.ratio > 1.0f)
    {
        log::ScopedTimer t (kMod, "compression de nivellement");
        result.report.compGrDb += compress (x, sampleRate, params.comp2);
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
