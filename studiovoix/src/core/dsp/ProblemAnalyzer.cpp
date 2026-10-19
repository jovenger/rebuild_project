#include "ProblemAnalyzer.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/ContentClassifier.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/SpectrumAnalyzer.h"
#include "../analysis/VoiceActivity.h"
#include "Leveler.h"
#include "PitchCorrector.h"
#include "Processors.h"

#include <cmath>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Correction";

    float bandMeanDb (const analysis::BandSpectrum& s, float lo, float hi)
    {
        double sum = 0.0;
        int n = 0;
        for (size_t i = 0; i < s.centersHz.size(); ++i)
            if (s.centersHz[i] >= lo && s.centersHz[i] <= hi)
            {
                sum += s.levelsDb[i];
                ++n;
            }
        return n > 0 ? static_cast<float> (sum / n) : -120.0f;
    }

    juce::String db1 (float v) { return (v >= 0.0f ? "+" : "") + juce::String (v, 1) + " dB"; }
}

TrackProblems analyzeTrackProblems (const Mono& x, double sr, const MusicalKey& key, bool vocal)
{
    log::ScopedTimer timer (kMod, "analyse des défauts"_u8);
    TrackProblems p;
    p.vocal = vocal;
    if (x.empty() || sr <= 0.0)
        return p;
    if (vocal)
    {
        // Voix à plusieurs (chœurs), piano, musique : une correction de justesse « monophonique » ferait des vagues.
        const auto content = analysis::classifyContent (audio::monoToStereo (x), sr);
        p.polyphonic = ! content.voice;
        if (p.polyphonic)
            p.found.add ("son polyphonique ou musical ("_u8 + content.reason + ") : pas de correction de justesse"_u8);
    }

    // Niveau, crête, composante continue, saturation.
    double sum = 0.0;
    float peak = 0.0f;
    int clipped = 0;
    for (const float v : x)
    {
        sum += v;
        peak = std::max (peak, std::abs (v));
        if (std::abs (v) >= 0.985f)
            ++clipped;
    }
    p.dcOffset = static_cast<float> (sum / static_cast<double> (x.size()));
    p.peakDb = gainToDb (peak);
    p.clippedSamples = clipped;
    p.activeLevelDb = activeLevelDb (x, sr);

    // Bruit de fond.
    const auto va = analysis::analyzeVoice (x, sr);
    p.noiseFloorDb = va.noiseFloorDb;

    // Régularité du niveau d'un passage à l'autre, et résonances (bandes qui dépassent leur voisinage).
    // Seuil d'activité : au-dessus du bruit de fond, mais jamais à moins de 20 dB sous le niveau actif (un son continu,
    // sans silence, a un « bruit de fond » mesuré au niveau du son lui-même).
    const float gate = std::max (-60.0f, std::min (va.noiseFloorDb + 12.0f, p.activeLevelDb - 20.0f));
    p.levelRangeDb = shortTermRangeDb (x, sr, 400.0f, gate);
    p.surges = levelSurges (x, sr, 9.0f, 400.0f, gate);
    p.resonanceDb = resonanceExcessDb (x, sr);

    // Densité de transitoires : montées d'au moins 8 dB d'une trame (10 ms) à la suivante.
    {
        int onsets = 0;
        for (size_t i = 1; i < va.envDb.size(); ++i)
            if (va.envDb[i] - va.envDb[i - 1] >= 8.0f && va.envDb[i] > va.noiseFloorDb + 12.0f)
                ++onsets;
        const double dur = static_cast<double> (va.envDb.size()) * va.frameSec;
        p.onsetsPerSec = dur > 0.0 ? static_cast<float> (onsets / dur) : 0.0f;
    }

    // Équilibre spectral : boue (200-400 Hz), dureté (2,5-5 kHz), sifflantes (5-9 kHz) par rapport au médium.
    const auto spec = analysis::averageSpectrum (x, sr);
    if (spec.valid())
    {
        const float mid = bandMeanDb (spec, 500.0f, 2000.0f);
        const float low = bandMeanDb (spec, 200.0f, 400.0f);
        const float high = bandMeanDb (spec, 2500.0f, 5000.0f);
        const float sib = bandMeanDb (spec, 5000.0f, 9000.0f);
        const float presence = bandMeanDb (spec, 1000.0f, 4000.0f);
        // Courbe attendue d'une voix propre : bas-médium ~ médium, 2,5-5 kHz ~ médium - 3 dB.
        p.mudExcessDb = std::max (0.0f, low - mid - (vocal ? 0.0f : 3.0f));
        p.harshExcessDb = std::max (0.0f, high - (mid - 3.0f));
        p.sibilanceDb = sib - presence;
        // Centre de gravité spectral (pondéré par l'énergie).
        double wsum = 0.0, esum = 0.0;
        for (size_t i = 0; i < spec.centersHz.size(); ++i)
        {
            const double e = std::pow (10.0, spec.levelsDb[i] / 10.0);
            wsum += e * spec.centersHz[i];
            esum += e;
        }
        p.centroidHz = esum > 0.0 ? static_cast<float> (wsum / esum) : 0.0f;
    }

    if (! vocal)
    {
        // Instrument : type reconnu d'après les graves, le centre spectral et les transitoires.
        float lowRatio = 0.0f;
        {
            const float a = static_cast<float> (std::exp (-2.0 * juce::MathConstants<double>::pi * 150.0 / sr));
            float lp = 0.0f;
            double eLow = 0.0, eAll = 0.0;
            for (const float v : x)
            {
                lp = a * lp + (1.0f - a) * v;
                eLow += static_cast<double> (lp) * lp;
                eAll += static_cast<double> (v) * v;
            }
            lowRatio = eAll > 1e-12 ? static_cast<float> (eLow / eAll) : 0.0f;
        }
        if (lowRatio >= 0.6f && p.centroidHz < 400.0f)
            p.instrumentKind = "basse";
        else if (p.onsetsPerSec >= 3.0f && p.voicedFraction < 0.3f)
            p.instrumentKind = "batterie";
        else if (p.centroidHz >= 300.0f)
            p.instrumentKind = "harmonique";
        else
            p.instrumentKind = "autre";
        p.found.add ("instrument reconnu : "_u8 + (p.instrumentKind == "basse" ? juce::String ("basse / 808") : p.instrumentKind == "batterie" ? juce::String ("batterie / percussions")
                                                   : p.instrumentKind == "harmonique" ? juce::String ("clavier / guitare / synthé"_u8) : juce::String ("autre"))
                     + " (centre " + juce::String (juce::roundToInt (p.centroidHz)) + " Hz, " + juce::String (p.onsetsPerSec, 1) + " attaques/s, graves "
                     + juce::String (juce::roundToInt (lowRatio * 100.0f)) + " %)");
    }

    // Justesse : écart moyen à la note de la gamme la plus proche (voix seulement).
    if (vocal)
    {
        const auto track = analysis::detectPitch (x, sr);
        double dev = 0.0;
        int voiced = 0, active = 0;
        for (size_t i = 0; i < track.frames.size(); ++i)
        {
            const double t = static_cast<double> (i) * track.hopSec;
            if (! va.isActiveAt (t))
                continue;
            ++active;
            const auto& f = track.frames[i];
            if (! f.voiced || f.f0 <= 0.0f || f.confidence < 0.5f)
                continue;
            const float midi = 69.0f + 12.0f * std::log2 (f.f0 / 440.0f);
            dev += std::abs (midi - nearestScaleMidi (midi, key, false)) * 100.0;
            ++voiced;
        }
        p.pitchDeviationCents = voiced > 0 ? static_cast<float> (dev / voiced) : 0.0f;
        p.voicedFraction = active > 0 ? static_cast<float> (voiced) / static_cast<float> (active) : 0.0f;
    }

    // Constats lisibles.
    if (p.clippedSamples > static_cast<int> (sr * 0.002))
        p.found.add ("saturation (" + juce::String (p.clippedSamples) + " échantillons écrêtés)"_u8);
    if (std::abs (p.dcOffset) > 0.01f)
        p.found.add ("composante continue " + juce::String (p.dcOffset, 3));
    if (p.activeLevelDb < -30.0f)
        p.found.add ("niveau trop bas (" + juce::String (p.activeLevelDb, 1) + " dBFS)");
    else if (p.activeLevelDb > -10.0f)
        p.found.add ("niveau trop fort (" + juce::String (p.activeLevelDb, 1) + " dBFS)");
    if (p.noiseFloorDb > -45.0f)
        p.found.add ("bruit de fond élevé ("_u8 + juce::String (juce::roundToInt (p.noiseFloorDb)) + " dBFS)");
    for (const auto& su : p.surges)
        p.found.add ("monte en flèche "_u8 + su.describe());
    if (p.levelRangeDb >= 6.0f)
        p.found.add ("niveau irrégulier d'un passage à l'autre ("_u8 + juce::String (juce::roundToInt (p.levelRangeDb)) + " dB d'écart)"_u8);
    if (p.resonanceDb >= 4.0f)
        p.found.add ("résonances / dureté par moments ("_u8 + db1 (p.resonanceDb) + " au-dessus du voisinage)"_u8);
    if (p.mudExcessDb >= 2.0f)
        p.found.add ("boue dans le bas-médium ("_u8 + db1 (p.mudExcessDb) + ")");
    if (p.harshExcessDb >= 2.0f)
        p.found.add ("dureté 2,5-5 kHz ("_u8 + db1 (p.harshExcessDb) + ")");
    if (p.sibilanceDb >= 0.0f)
        p.found.add ("sifflantes marquées ("_u8 + db1 (p.sibilanceDb) + ")");
    if (vocal && p.pitchDeviationCents >= 18.0f && p.voicedFraction > 0.2f)
        p.found.add ("justesse approximative (écart moyen "_u8 + juce::String (juce::roundToInt (p.pitchDeviationCents)) + " cents)");
    SV_LOG_INFO (kMod, "Défauts : "_u8 + (p.found.isEmpty() ? juce::String ("aucun notable") : p.found.joinIntoString (" ; ")));
    return p;
}

style::VocalParams correctionParams (TrackProblems& p, bool vocal)
{
    // Point de départ neutre : aucun effet de style.
    style::VocalParams v = style::makeParams (style::Style::Acoustique, vocal ? style::Role::Lead : style::Role::Instrument, {});
    v.sat = {};
    v.reverb.send = 0.0f;
    v.delay.send = 0.0f;
    v.timing.strength = 0.0f;
    v.pitch.enabled = false;
    v.eq = {};
    v.eq.lowCutHz = vocal ? 80.0f : 30.0f;
    v.comp = { -22.0f, 2.0f, 10.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };   // nivellement doux
    v.comp2.ratio = 1.0f;
    if (! vocal)
    {
        // Réglages de départ par type d'instrument (pratiques courantes : coupe-bas sous la note la plus grave,
        // compression qui laisse passer les attaques, aucune bosse ajoutée : seulement des corrections mesurées).
        if (p.instrumentKind == "basse")
        {
            v.eq.lowCutHz = 35.0f;
            v.comp = { -20.0f, 3.0f, 8.0f, 10.0f, 100.0f, 0.0f, 1.0f, true };
        }
        else if (p.instrumentKind == "batterie")
        {
            v.eq.lowCutHz = 40.0f;
            v.comp = { -18.0f, 2.0f, 8.0f, 25.0f, 80.0f, 0.0f, 1.0f, false };   // attaque lente : les coups restent nets
        }
        else if (p.instrumentKind == "harmonique")
        {
            v.eq.lowCutHz = 60.0f;
            v.comp = { -20.0f, 3.0f, 8.0f, 5.0f, 50.0f, 0.0f, 1.0f, false };    // piano / guitare : 3:1, 5 ms, 50 ms
        }
    }
    v.deEss.amount = 0.0f;
    v.clean.enabled = true;
    v.clean.dePlosive = vocal;
    v.clean.breathReductionDb = vocal ? 6.0f : 0.0f;
    v.clean.gateRangeDb = p.noiseFloorDb > -45.0f ? 18.0f : (p.noiseFloorDb > -60.0f ? 10.0f : 4.0f);
    v.clean.denoiseDb = p.noiseFloorDb > -45.0f ? 20.0f : (p.noiseFloorDb > -60.0f ? 14.0f : 8.0f);
    if (p.instrumentKind == "basse" || p.instrumentKind == "batterie")
    {
        v.clean.gateRangeDb = 0.0f;                                // pas de porte : les tenues et les queues restent
        v.clean.denoiseDb = std::min (v.clean.denoiseDb, 6.0f);   // débruitage léger : la texture reste
    }
    v.clean.declip = true;
    v.outputDb = -14.0f;
    v.inputTargetDb = -20.0f;

    // Niveleur : fader suivi dès que le niveau bouge d'un passage à l'autre ; la batterie garde sa dynamique.
    const bool drums = p.instrumentKind == "batterie";
    v.leveler.enabled = p.levelRangeDb >= (drums ? 10.0f : 4.0f) || ! p.surges.empty();
    float worstSurge = 0.0f;
    for (const auto& su : p.surges)
        worstSurge = std::max (worstSurge, su.overDb);
    v.leveler.surgeCutDb = juce::jlimit (6.0f, 18.0f, worstSurge + 2.0f);
    v.leveler.targetDb = -20.0f;
    v.leveler.maxBoostDb = vocal ? 8.0f : (drums ? 2.0f : 5.0f);
    v.leveler.maxCutDb = vocal ? 6.0f : (drums ? 3.0f : 5.0f);
    v.leveler.attackMs = drums ? 600.0f : 250.0f;
    v.leveler.releaseMs = drums ? 2500.0f : 1200.0f;
    // Résonances : rabaissées seulement si elles sont mesurées ; graves protégés plus haut sur un instrument.
    v.resonance.enabled = p.resonanceDb >= 3.0f;
    v.resonance.thresholdDb = 3.0f;
    v.resonance.maxReductionDb = juce::jlimit (3.0f, 9.0f, 1.5f + p.resonanceDb);
    v.resonance.protectBelowHz = vocal ? 600.0f : 300.0f;

    p.fixes.clear();
    if (! vocal && p.instrumentKind.isNotEmpty())
        p.fixes.add (p.instrumentKind == "basse" ? juce::String ("basse : coupe-bas 35 Hz, compression 3:1 lente, pas de porte"_u8)
                     : p.instrumentKind == "batterie" ? juce::String ("batterie : coupe-bas 40 Hz, compression 2:1 qui laisse passer les attaques, pas de porte"_u8)
                     : p.instrumentKind == "harmonique" ? juce::String ("instrument harmonique : coupe-bas 60 Hz, compression 3:1 (5 ms / 50 ms)"_u8)
                                                          : juce::String ("instrument : coupe-bas 30 Hz, nivellement doux"_u8));
    p.fixes.add ("niveau remis à -14 dB (gain "_u8 + db1 (-14.0f - p.activeLevelDb) + ")");
    if (! p.surges.empty())
        p.fixes.add ("montées brusques rabaissées (jusqu'à -"_u8 + juce::String (juce::roundToInt (v.leveler.surgeCutDb)) + " dB)");
    if (v.leveler.enabled)
        p.fixes.add ("niveau régularisé d'un passage à l'autre (fader suivi, +"_u8 + juce::String (juce::roundToInt (v.leveler.maxBoostDb)) + " / -"
                     + juce::String (juce::roundToInt (v.leveler.maxCutDb)) + " dB max)");
    if (v.resonance.enabled)
        p.fixes.add ("résonances rabaissées quand elles dépassent (max -"_u8 + juce::String (juce::roundToInt (v.resonance.maxReductionDb)) + " dB)");
    if (p.clippedSamples > 0)
        p.fixes.add ("passages saturés reconstruits (dé-écrêtage)"_u8);
    if (std::abs (p.dcOffset) > 0.01f)
        p.fixes.add ("composante continue retirée (coupe-bas)"_u8);
    p.fixes.add ("débruitage spectral jusqu'à -"_u8 + juce::String (juce::roundToInt (v.clean.denoiseDb)) + " dB (souffle, ronflement, bruit de pièce)"_u8
                 + (p.noiseFloorDb > -60.0f ? " + silences atténués de "_u8 + juce::String (juce::roundToInt (v.clean.gateRangeDb)) + " dB" : juce::String()));
    if (p.mudExcessDb >= 1.0f)
    {
        v.eq.mudHz = 300.0f;
        v.eq.mudDb = -std::min (6.0f, p.mudExcessDb);
        v.eq.mudQ = 1.0f;
        p.fixes.add ("bas-médium corrigé "_u8 + db1 (v.eq.mudDb) + " à 300 Hz"_u8);
    }
    if (p.harshExcessDb >= 1.0f)
    {
        v.eq.presenceHz = 3500.0f;
        v.eq.presenceDb = -std::min (5.0f, p.harshExcessDb);
        v.eq.presenceQ = 1.2f;
        p.fixes.add ("dureté corrigée "_u8 + db1 (v.eq.presenceDb) + " à 3,5 kHz"_u8);
    }
    if (vocal && p.sibilanceDb >= -3.0f)
    {
        v.deEss = { 6500.0f, juce::jlimit (0.3f, 0.9f, 0.5f + p.sibilanceDb * 0.1f), 10.0f, -8.0f };
        p.fixes.add ("de-esser " + juce::String (juce::roundToInt (v.deEss.amount * 100.0f)) + " %");
    }
    if (vocal && ! p.polyphonic && p.pitchDeviationCents >= 12.0f && p.voicedFraction > 0.2f)
    {
        // Justesse douce vers la gamme : corrige l'écart sans effet robot.
        const float amount = juce::jlimit (0.3f, 0.8f, p.pitchDeviationCents / 40.0f);
        v.pitch = { true, amount, 60.0f, 0.8f };
        p.fixes.add ("justesse ramenée vers la gamme ("_u8 + juce::String (juce::roundToInt (amount * 100.0f)) + " %, naturel)");
    }
    SV_LOG_INFO (kMod, "Corrections : "_u8 + p.fixes.joinIntoString (" ; "));
    return v;
}

juce::StringArray fitStyleToMeasurement (style::VocalParams& v, const TrackProblems& p, double bpm)
{
    juce::StringArray n;
    const float dyn = p.levelRangeDb;   // étendue du niveau court terme (P90 - P10) : la dynamique de la prise

    // Compresseur principal : le ratio du style est un maximum, atteint pour une prise très dynamique (14 dB et plus) ;
    // une prise déjà régulière (4 dB) ne reçoit qu'un contrôle léger. Le seuil suit : plus haut si régulière, plus bas
    // si la dynamique est grande. Attaque et relâchement (le caractère du style) ne bougent pas.
    if (v.comp.ratio > 1.0f)
    {
        const float styleRatio = v.comp.ratio;
        const float t = juce::jlimit (0.0f, 1.0f, (dyn - 4.0f) / 10.0f);
        v.comp.ratio = juce::jlimit (1.5f, std::max (1.5f, styleRatio), 1.5f + (styleRatio - 1.5f) * t);
        v.comp.thresholdDb = juce::jlimit (-30.0f, -10.0f, v.comp.thresholdDb + (10.0f - dyn) * 0.4f);
        n.add ("compresseur "_u8 + juce::String (v.comp.ratio, 1) + ":1, seuil " + juce::String (juce::roundToInt (v.comp.thresholdDb)) + " dB (dynamique mesurée "_u8
               + juce::String (juce::roundToInt (dyn)) + " dB)");
    }
    if (v.comp2.ratio > 1.0f && dyn < 5.0f)
    {
        v.comp2.ratio = 1.0f;
        n.add ("second compresseur retiré (prise déjà régulière)"_u8);
    }

    // Niveleur : amplitude de correction selon la dynamique ; montées en flèche mesurées → baisse autorisée adaptée.
    if (v.leveler.enabled)
    {
        const float range = dyn > 12.0f ? 6.0f : dyn < 6.0f ? 2.0f : 4.0f;
        v.leveler.maxBoostDb = range;
        v.leveler.maxCutDb = range;
        float worstSurge = 0.0f;
        for (const auto& su : p.surges)
            worstSurge = std::max (worstSurge, su.overDb);
        if (worstSurge > 0.0f)
            v.leveler.surgeCutDb = juce::jlimit (6.0f, 18.0f, worstSurge + 2.0f);
        n.add ("niveleur ±"_u8 + juce::String (juce::roundToInt (range)) + " dB" + (p.surges.empty() ? juce::String() : ", "_u8 + juce::String (static_cast<int> (p.surges.size())) + " montée(s) rabaissée(s)"_u8));
    }

    // Résonances : rabaissées à la mesure (le style n'en met que 3 dB par défaut).
    if (p.resonanceDb >= 3.0f)
    {
        v.resonance.enabled = true;
        v.resonance.maxReductionDb = juce::jlimit (3.0f, 6.0f, 1.5f + p.resonanceDb);
        n.add ("résonances mesurées +"_u8 + juce::String (p.resonanceDb, 1) + " dB : rabaissées jusqu'à -"_u8 + juce::String (juce::roundToInt (v.resonance.maxReductionDb)) + " dB"_u8);
    }

    // EQ : la couleur du style reste, corrigée de ce que la prise a en trop ou en moins (boue 200-400 Hz, dureté 2,5-5 kHz).
    if (p.mudExcessDb >= 1.0f)
    {
        v.eq.mudDb = std::min (v.eq.mudDb, -std::min (6.0f, p.mudExcessDb));
        n.add ("bas-médium "_u8 + db1 (v.eq.mudDb) + " (boue mesurée +"_u8 + juce::String (p.mudExcessDb, 1) + " dB)");
    }
    else if (p.mudExcessDb <= -2.0f && v.eq.mudDb < 0.0f)
    {
        v.eq.mudDb = std::min (0.0f, v.eq.mudDb + 1.5f);
        n.add ("bas-médium moins creusé ("_u8 + db1 (v.eq.mudDb) + ", voix fine)"_u8);
    }
    if (p.harshExcessDb >= 1.0f)
    {
        v.eq.presenceDb = std::max (-4.0f, v.eq.presenceDb - std::min (5.0f, p.harshExcessDb));
        n.add ("présence "_u8 + db1 (v.eq.presenceDb) + " (dureté mesurée +"_u8 + juce::String (p.harshExcessDb, 1) + " dB)");
    }
    else if (p.harshExcessDb <= -2.0f)
    {
        v.eq.presenceDb += 1.5f;
        n.add ("présence "_u8 + db1 (v.eq.presenceDb) + " (voix sourde)"_u8);
    }

    // Saturation : une prise dure ou déjà écrêtée sature mal → dosée plus bas.
    if (v.sat.mix > 0.0f && (p.harshExcessDb >= 2.0f || p.clippedSamples > 0))
    {
        v.sat.driveDb = std::max (0.0f, v.sat.driveDb - 3.0f);
        v.sat.mix *= 0.6f;
        n.add ("saturation réduite ("_u8 + db1 (v.sat.driveDb) + ", " + juce::String (juce::roundToInt (v.sat.mix * 100.0f)) + " %) : "
               + (p.clippedSamples > 0 ? "prise écrêtée à la source"_u8 : "prise dure"_u8));
    }

    // De-esser : dosé sur les sifflantes mesurées (5-9 kHz par rapport à 1-4 kHz).
    if (p.vocal && v.deEss.amount > 0.0f)
    {
        const float before = v.deEss.amount;
        v.deEss.amount = p.sibilanceDb < -8.0f ? juce::jlimit (0.1f, 0.9f, before * 0.5f)
                                               : juce::jlimit (0.2f, 0.9f, before + p.sibilanceDb * 0.06f);
        if (std::abs (v.deEss.amount - before) >= 0.05f)
            n.add ("de-esser "_u8 + juce::String (juce::roundToInt (v.deEss.amount * 100.0f)) + " % (sifflantes mesurées "_u8 + db1 (p.sibilanceDb) + ")");
    }

    // Nettoyage : débruitage et porte dosés sur le bruit de fond mesuré.
    if (v.clean.enabled)
    {
        v.clean.denoiseDb = p.noiseFloorDb > -45.0f ? 20.0f : (p.noiseFloorDb > -60.0f ? 14.0f : 8.0f);
        v.clean.gateRangeDb = p.noiseFloorDb > -45.0f ? 18.0f : (p.noiseFloorDb > -60.0f ? 10.0f : 4.0f);
        n.add ("débruitage -"_u8 + juce::String (juce::roundToInt (v.clean.denoiseDb)) + " dB (bruit de fond mesuré "_u8 + juce::String (juce::roundToInt (p.noiseFloorDb)) + " dBFS)");
    }

    // Réverb : pré-délai calé sur le tempo (une triple croche, 15-60 ms), envoi réduit si la prise est bruyante (la réverb étale le bruit).
    if (v.reverb.send > 0.0f && bpm > 40.0)
    {
        v.reverb.preDelayMs = juce::jlimit (15.0f, 60.0f, static_cast<float> (60000.0 / bpm / 8.0));
        juce::String line = "réverb pré-délai "_u8 + juce::String (juce::roundToInt (v.reverb.preDelayMs)) + " ms (tempo " + juce::String (juce::roundToInt (bpm)) + ")";
        if (p.noiseFloorDb > -45.0f)
        {
            v.reverb.send *= 0.8f;
            line << ", envoi réduit (prise bruyante)"_u8;
        }
        n.add (line);
    }
    SV_LOG_INFO (kMod, "Réglages du style ajustés à la mesure : "_u8 + n.joinIntoString (" ; "));
    return n;
}

juce::String describeProblems (const TrackProblems& p)
{
    juce::String s;
    s << "Défauts constatés : "_u8 << (p.found.isEmpty() ? juce::String ("aucun notable") : p.found.joinIntoString (" ; ")) << "\n"
      << "Corrections : " << (p.fixes.isEmpty() ? juce::String ("aucune") : p.fixes.joinIntoString (" ; "));
    return s;
}
} // namespace sv::dsp
