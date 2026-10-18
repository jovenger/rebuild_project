#include "ProblemAnalyzer.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/ContentClassifier.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/SpectrumAnalyzer.h"
#include "../analysis/VoiceActivity.h"
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

    p.fixes.clear();
    if (! vocal && p.instrumentKind.isNotEmpty())
        p.fixes.add (p.instrumentKind == "basse" ? juce::String ("basse : coupe-bas 35 Hz, compression 3:1 lente, pas de porte"_u8)
                     : p.instrumentKind == "batterie" ? juce::String ("batterie : coupe-bas 40 Hz, compression 2:1 qui laisse passer les attaques, pas de porte"_u8)
                     : p.instrumentKind == "harmonique" ? juce::String ("instrument harmonique : coupe-bas 60 Hz, compression 3:1 (5 ms / 50 ms)"_u8)
                                                          : juce::String ("instrument : coupe-bas 30 Hz, nivellement doux"_u8));
    p.fixes.add ("niveau remis à -14 dB (gain "_u8 + db1 (-14.0f - p.activeLevelDb) + ")");
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

juce::String describeProblems (const TrackProblems& p)
{
    juce::String s;
    s << "Défauts constatés : "_u8 << (p.found.isEmpty() ? juce::String ("aucun notable") : p.found.joinIntoString (" ; ")) << "\n"
      << "Corrections : " << (p.fixes.isEmpty() ? juce::String ("aucune") : p.fixes.joinIntoString (" ; "));
    return s;
}
} // namespace sv::dsp
