// Tests unitaires du coeur StudioVoix (framework juce::UnitTest).
// Lancement : studiovoix_cli test

#include "TestSignals.h"

#include "core/AudioIO.h"
#include "core/plugins/ChainStages.h"
#include "core/Log.h"
#include "core/Loudness.h"
#include "core/analysis/KeyDetector.h"
#include "core/analysis/PitchDetector.h"
#include "core/analysis/StructureDetector.h"
#include "core/analysis/TempoDetector.h"
#include "core/analysis/VoiceActivity.h"
#include "core/assistant/CommandParser.h"
#include "core/ai/AiClient.h"
#include "core/ai/AiFeatures.h"
#include "core/analysis/BeatLibrary.h"
#include "core/analysis/ContentClassifier.h"
#include "core/dsp/MasterChain.h"
#include "core/dsp/PitchCorrector.h"
#include "core/dsp/ProblemAnalyzer.h"
#include "core/dsp/Denoiser.h"
#include "core/dsp/Leveler.h"
#include "core/dsp/TrackRepair.h"
#include "core/plugins/InternalPlugins.h"
#include "core/plugins/PluginChain.h"
#include "core/dsp/PitchShifter.h"
#include "core/dsp/Processors.h"
#include "core/dsp/TimingCorrector.h"
#include "core/dsp/VocalChain.h"
#include "core/gen/BackingGenerator.h"
#include "core/gen/TakeComper.h"
#include "core/project/Project.h"
#include "core/project/Renderer.h"
#include "core/update/Updater.h"

#include <juce_cryptography/juce_cryptography.h>

#include <cstring>
#include <set>

namespace sv::test
{
namespace
{
    constexpr double kSr = 48000.0;

    MusicalKey aMinor()
    {
        MusicalKey k;
        k.root = 9;
        k.minor = true;
        return k;
    }

    MusicalKey cMajor()
    {
        MusicalKey k;
        k.root = 0;
        k.minor = false;
        return k;
    }

    float bandRmsDb (const Mono& x, double sr, double lo, double hi, size_t a, size_t b)
    {
        Mono y (x.begin() + static_cast<long> (a), x.begin() + static_cast<long> (std::min (b, x.size())));
        if (lo > 0.0)
            dsp::highPass (y, sr, lo, 4);
        if (hi > 0.0)
            dsp::lowPass (y, sr, hi, 4);
        return gainToDb (audio::rms (y.data(), y.size()));
    }
}

class LoudnessTests final : public juce::UnitTest
{
public:
    LoudnessTests() : juce::UnitTest ("Sonie LUFS / crete vraie", "studiovoix") {}

    void runTest() override
    {
        beginTest ("EBU 3341 : sinus 1 kHz -23 dBFS stereo = -23 LUFS");
        {
            const auto s = sine (1000.0, 20.0, kSr, dbToGain (-23.0f));
            const auto st = audio::monoToStereo (s);
            const double l = loudness::integratedLufs (st, kSr);
            logMessage ("mesure : " + juce::String (l, 3) + " LUFS");
            expectWithinAbsoluteError (l, -23.0, 0.1);
        }
        beginTest ("Crete vraie d'un sinus 0,5");
        {
            const auto st = audio::monoToStereo (sine (997.0, 1.0, kSr, 0.5f));
            expectWithinAbsoluteError (loudness::truePeakDb (st), -6.02, 0.15);
        }
        beginTest ("Silence = -120");
        {
            expectEquals (loudness::integratedLufs (makeStereo (48000), kSr), -120.0);
        }
    }
};

class ResampleTests final : public juce::UnitTest
{
public:
    ResampleTests() : juce::UnitTest ("Reechantillonnage", "studiovoix") {}

    void runTest() override
    {
        beginTest ("44,1 kHz -> 48 kHz conserve frequence et niveau");
        const auto s = sine (1000.0, 2.0, 44100.0, 0.5f);
        const auto r = audio::resample (s, 44100.0, 48000.0);
        expectWithinAbsoluteError (static_cast<double> (r.size()), 96000.0, 2.0);
        const float rmsIn = audio::rms (s.data() + 4410, 44100);
        const float rmsOut = audio::rms (r.data() + 4800, 48000);
        expectWithinAbsoluteError (gainToDb (rmsOut) - gainToDb (rmsIn), 0.0f, 0.1f);
        int crossings = 0;
        for (size_t i = 4801; i < 52800; ++i)
            crossings += (r[i - 1] < 0.0f && r[i] >= 0.0f) ? 1 : 0;
        expectWithinAbsoluteError (crossings, 1000, 2);
    }
};

class PitchTests final : public juce::UnitTest
{
public:
    PitchTests() : juce::UnitTest ("Hauteur YIN / PSOLA / autotune", "studiovoix") {}

    void runTest() override
    {
        beginTest ("YIN sur sinus 220 Hz");
        {
            const auto s = sine (220.0, 1.0, kSr, 0.3f);
            expectWithinAbsoluteError (medianF0 (s, kSr), 220.0f, 1.0f);
        }
        beginTest ("YIN sur voix de synthese (La 2 = 220 Hz)");
        {
            VoicePhrase p;
            p.notes = { { 57.0f, 1.0, 0.0f } };
            const auto v = synthVoice ({ p }, kSr, 0.2, 0.0f);
            expectWithinAbsoluteError (medianF0 (v, kSr, 0.3, 1.1), 220.0f, 2.5f);
        }
        beginTest ("PSOLA : +2 demi-tons");
        {
            VoicePhrase p;
            p.notes = { { 55.0f, 1.2, 0.0f } };   // Sol 2 = 196 Hz
            const auto v = synthVoice ({ p }, kSr, 0.2, 0.0f);
            const auto track = analysis::detectPitch (v, kSr);
            const auto up = dsp::psolaShiftSemitones (v, kSr, track, 2.0f);
            const float expected = 196.0f * std::pow (2.0f, 2.0f / 12.0f);
            const float measured = medianF0 (up, kSr, 0.35, 1.2);
            logMessage ("PSOLA : attendu " + juce::String (expected, 1) + " Hz, mesure " + juce::String (measured, 1) + " Hz");
            expectWithinAbsoluteError (measured, expected, 3.0f);
            expect (std::abs (static_cast<double> (up.size()) - static_cast<double> (v.size())) < 1.0, "durée conservée"_u8);
        }
        beginTest ("PSOLA : -12 demi-tons (octave en dessous, harmonie basse et nappe)");
        {
            VoicePhrase p;
            p.notes = { { 57.0f, 1.2, 0.0f } };   // La 2 = 220 Hz
            const auto v = synthVoice ({ p }, kSr, 0.2, 0.0f);
            const auto track = analysis::detectPitch (v, kSr);
            const auto down = dsp::psolaShiftSemitones (v, kSr, track, -12.0f);
            const float measured = medianF0 (down, kSr, 0.35, 1.2);
            logMessage ("PSOLA -12 : attendu 110 Hz, mesure " + juce::String (measured, 1) + " Hz");
            expectWithinAbsoluteError (measured, 110.0f, 4.0f);
        }
        beginTest ("Autotune : voix desaccordee de +35 cents ramenee sur la gamme");
        {
            const auto key = aMinor();
            auto phrases = defaultPhrases (key, 100.0, 35.0f);
            const auto v = synthVoice (phrases, kSr, 0.5, 0.0f);
            dsp::PitchCorrectionParams pc;
            pc.key = key;
            pc.amount = 1.0f;
            pc.retuneMs = 5.0f;
            const auto res = dsp::correctPitch (v, kSr, pc);
            const auto after = analysis::detectPitch (res.audio, kSr);
            double devBefore = 0.0, devAfter = 0.0;
            int nb = 0, na = 0;
            const auto before = res.track;
            for (const auto& f : before.frames)
                if (f.voiced)
                {
                    const float m = analysis::hzToMidi (f.f0);
                    devBefore += std::abs (m - dsp::nearestScaleMidi (m, key, false)) * 100.0;
                    ++nb;
                }
            for (const auto& f : after.frames)
                if (f.voiced)
                {
                    const float m = analysis::hzToMidi (f.f0);
                    devAfter += std::abs (m - dsp::nearestScaleMidi (m, key, false)) * 100.0;
                    ++na;
                }
            devBefore /= std::max (1, nb);
            devAfter /= std::max (1, na);
            logMessage ("écart moyen à la gamme : avant "_u8 + juce::String (devBefore, 1) + " cents, après "_u8 + juce::String (devAfter, 1) + " cents");
            expect (devBefore > 25.0, "la voix de test doit être désaccordée"_u8);
            expect (devAfter < 10.0, "la correction doit ramener la voix à moins de 10 cents"_u8);
        }
        beginTest ("Degres diatoniques");
        {
            const auto key = aMinor();
            expectEquals (dsp::diatonicShift (72.0f, key, 2), 76.0f);   // Do -> Mi
            expectEquals (dsp::diatonicShift (69.0f, key, 4), 76.0f);   // La -> Mi
            expectEquals (dsp::diatonicShift (69.0f, key, -7), 57.0f);  // octave en dessous
            expectEquals (dsp::nearestScaleMidi (70.0f, key, false), 69.0f);   // Sib -> La (Si plus loin? 71) : 69 et 71 à égalité, 69 retenu
        }
    }
};

class AnalysisTests final : public juce::UnitTest
{
public:
    AnalysisTests() : juce::UnitTest ("Analyse instru et voix", "studiovoix") {}

    void runTest() override
    {
        beginTest ("Tonalite : instru en La mineur");
        {
            const auto instru = synthInstru (140.0, aMinor(), 16, kSr, false);
            const auto k = analysis::detectKey (audio::toMono (instru), kSr);
            logMessage ("détecté : "_u8 + k.key.toFrench());
            expectEquals (k.key.root, 9);
            expect (k.key.minor, "mode mineur attendu");
        }
        beginTest ("Tonalite : instru en Do majeur");
        {
            const auto instru = synthInstru (100.0, cMajor(), 16, kSr, false);
            const auto k = analysis::detectKey (audio::toMono (instru), kSr);
            logMessage ("détecté : "_u8 + k.key.toFrench());
            expectEquals (k.key.root, 0);
            expect (! k.key.minor, "mode majeur attendu");
        }
        beginTest ("Tempo 140 BPM");
        {
            const auto instru = synthInstru (140.0, aMinor(), 16, kSr, false);
            const auto t = analysis::detectTempo (audio::toMono (instru), kSr);
            expectWithinAbsoluteError (t.bpm, 140.0, 0.1);   // au centième : pas de dérive de grille
            const double beat = 60.0 / 140.0;
            const double phase = std::fmod (t.firstBeatSec, beat * 4.0);
            expect (phase < 0.03 || beat * 4.0 - phase < 0.03, "premier temps fort proche de 0 (mesure) : " + juce::String (t.firstBeatSec, 3));
        }
        beginTest ("Tonalite : signal sans harmonie -> confiance basse (correction chromatique)");
        {
            juce::Random rnd (11);
            Mono noise (static_cast<size_t> (10 * kSr));
            for (auto& v : noise)
                v = (rnd.nextFloat() * 2.0f - 1.0f) * 0.2f;
            const auto k = analysis::detectKey (noise, kSr);
            expect (k.key.confidence < 0.2f, "confiance "_u8 + juce::String (k.key.confidence, 2));
        }
        beginTest ("Tonalite : Do majeur avec 6 s de silence au debut");
        {
            const auto instru = synthInstru (100.0, cMajor(), 16, kSr, false);
            Mono mono (static_cast<size_t> (6 * kSr), 0.0f);
            const auto body = audio::toMono (instru);
            mono.insert (mono.end(), body.begin(), body.end());
            const auto k = analysis::detectKey (mono, kSr);
            logMessage ("détecté : "_u8 + k.key.toFrench());
            expect (k.key.root == 0 && ! k.key.minor, "Do majeur attendu, détecté "_u8 + k.key.toFrench());
        }
        beginTest ("Tempo 95 BPM");
        {
            const auto instru = synthInstru (95.0, cMajor(), 12, kSr, false);
            const auto t = analysis::detectTempo (audio::toMono (instru), kSr);
            expectWithinAbsoluteError (t.bpm, 95.0, 1.5);
        }
        beginTest ("Structure : refrains detectes");
        {
            TempoInfo tempo;
            tempo.bpm = 120.0;
            tempo.firstBeatSec = 0.0;
            const auto instru = synthInstru (120.0, aMinor(), 32, kSr, true);
            const auto secs = analysis::detectStructure (audio::toMono (instru), kSr, tempo);
            int choruses = 0;
            for (const auto& s : secs)
                choruses += s.kind == "refrain" ? 1 : 0;
            logMessage (juce::String ((int) secs.size()) + " sections, " + juce::String (choruses) + " refrains");
            expect (secs.size() >= 3, "au moins 3 sections");
            expect (choruses >= 2, "au moins 2 refrains");
            expect (choruses < static_cast<int> (secs.size()), "les couplets ne sont pas tous des refrains");
        }
        beginTest ("Activite vocale : 4 phrases");
        {
            const auto v = synthVoice (defaultPhrases (aMinor(), 100.0), kSr);
            const auto va = analysis::analyzeVoice (v, kSr);
            expectEquals (static_cast<int> (va.phrases.size()), 4);
            if (! va.phrases.empty())
                expect (va.phrases[0].syllableOnsets.size() >= 3, "attaques de syllabes détectées : "_u8
                                                                   + juce::String ((int) va.phrases[0].syllableOnsets.size()));
        }
    }
};

class ProcessorTests final : public juce::UnitTest
{
public:
    ProcessorTests() : juce::UnitTest ("Effets voix", "studiovoix") {}

    void runTest() override
    {
        beginTest ("Compresseur : reduit l'ecart fort / faible");
        {
            Mono x = sine (440.0, 1.0, kSr, dbToGain (-30.0f));
            const auto loud = sine (440.0, 1.0, kSr, dbToGain (-6.0f));
            x.insert (x.end(), loud.begin(), loud.end());
            const float before = gainToDb (audio::rms (x.data() + 48000, 48000)) - gainToDb (audio::rms (x.data(), 48000));
            dsp::CompressorSettings c;
            c.thresholdDb = -24.0f;
            c.ratio = 4.0f;
            const float gr = dsp::compress (x, kSr, c);
            const float after = gainToDb (audio::rms (x.data() + 60000, 30000)) - gainToDb (audio::rms (x.data() + 10000, 30000));
            logMessage ("écart avant "_u8 + juce::String (before, 1) + " dB, après "_u8 + juce::String (after, 1) + " dB, réduction "_u8 + juce::String (gr, 1) + " dB");
            expect (after < before - 10.0f, "compression effective");
        }
        beginTest ("Compresseur RMS : reduction stable (pas de derive), attaque sans surplus");
        {
            // Sinus à -10 dBFS RMS, seuil -20, ratio 2, sans genou : réduction théorique 5 dB.
            const float amp = dbToGain (-10.0f) * std::sqrt (2.0f);
            Mono x (static_cast<size_t> (kSr * 0.5), 0.0f);
            const auto tone = sine (220.0, 3.0, kSr, amp);
            x.insert (x.end(), tone.begin(), tone.end());
            dsp::CompressorSettings c;
            c.thresholdDb = -20.0f;
            c.ratio = 2.0f;
            c.kneeDb = 0.0f;
            c.attackMs = 10.0f;
            c.releaseMs = 100.0f;
            c.rmsDetector = true;
            dsp::compress (x, kSr, c);
            const float early = gainToDb (audio::rms (x.data() + static_cast<size_t> (0.6 * kSr), static_cast<size_t> (0.1 * kSr)));
            const float late = gainToDb (audio::rms (x.data() + static_cast<size_t> (3.0 * kSr), static_cast<size_t> (0.4 * kSr)));
            logMessage ("niveau après compression : début "_u8 + juce::String (early, 2) + " dB, fin " + juce::String (late, 2) + " dB (attendu -15)");
            expectWithinAbsoluteError (late, -15.0f, 0.7f);
            expect (std::abs (early - late) < 1.5f, "pas de dérive ni de surplus à l'attaque"_u8);
        }
        beginTest ("De-esser : attenue le 's' sans toucher la voyelle");
        {
            VoicePhrase p;
            p.notes = { { 57.0f, 0.6, 0.0f } };
            p.sibilantAtEnd = true;
            const auto v = synthVoice ({ p }, kSr, 0.2, 0.0f);
            Mono y = v;
            dsp::DeEsserSettings d;
            d.amount = 0.8f;
            dsp::deEss (y, kSr, d);
            const size_t vowelA = static_cast<size_t> (0.3 * kSr), vowelB = static_cast<size_t> (0.7 * kSr);
            const size_t sA = static_cast<size_t> (0.8 * kSr), sB = static_cast<size_t> (0.92 * kSr);
            const float vowelDelta = bandRmsDb (y, kSr, 0, 3000, vowelA, vowelB) - bandRmsDb (v, kSr, 0, 3000, vowelA, vowelB);
            const float sDelta = bandRmsDb (y, kSr, 5000, 0, sA, sB) - bandRmsDb (v, kSr, 5000, 0, sA, sB);
            logMessage ("voyelle " + juce::String (vowelDelta, 2) + " dB, sifflante " + juce::String (sDelta, 2) + " dB");
            expect (std::abs (vowelDelta) < 1.0f, "voyelle préservée"_u8);
            expect (sDelta < -3.0f, "sifflante réduite d'au moins 3 dB"_u8);
        }
        beginTest ("De-esser : rien de compte dans le silence");
        {
            Mono silence (static_cast<size_t> (kSr * 2), 0.0f);
            dsp::DeEsserSettings d;
            expectWithinAbsoluteError (dsp::deEss (silence, kSr, d), 0.0f, 1.0e-6f);
        }
        beginTest ("Chaine vocale : prise quasi silencieuse non amplifiee");
        {
            juce::Random rnd (3);
            Mono hiss (static_cast<size_t> (kSr * 3));
            for (auto& s : hiss)
                s = (rnd.nextFloat() * 2.0f - 1.0f) * 1.0e-4f;   // environ -85 dBFS
            dsp::AnalysisContext ctx;
            const auto res = dsp::processVocal (hiss, kSr, style::makeParams (style::Style::Trap, style::Role::Lead, {}), ctx);
            expect (res.report.nearSilent && res.report.phrases == 0, "prise quasi silencieuse détectée"_u8);
            const float pk = audio::peak (res.audio.getReadPointer (0), static_cast<size_t> (res.audio.getNumSamples()));
            expect (gainToDb (pk) < -50.0f, "pas amplifiée : crête "_u8 + juce::String (gainToDb (pk), 1) + " dBFS");
        }
        beginTest ("Saturation : pas de NaN, niveau conserve");
        {
            Mono x = sine (220.0, 1.0, kSr, 0.4f);
            const float before = audio::rms (x.data(), x.size());
            dsp::SaturationSettings s { 9.0f, 1.0f, 0.2f };
            dsp::saturate (x, kSr, s);
            expect (! audio::hasNonFinite (x.data(), x.size()));
            expectWithinAbsoluteError (gainToDb (audio::rms (x.data() + 4800, x.size() - 9600)) - gainToDb (before), 0.0f, 1.0f);
        }
        beginTest ("Reverberation : niveau de retour calibre");
        {
            const auto x = synthVoice (defaultPhrases (aMinor(), 100.0), kSr);
            dsp::ReverbSettings r;
            r.send = 1.0f;
            const auto wet = dsp::reverbReturn (x, kSr, r);
            const float inDb = gainToDb (audio::rms (x.data(), x.size()));
            const float wetDb = gainToDb (wet.getRMSLevel (0, 0, wet.getNumSamples()));
            logMessage ("retour réverb (send 1) : "_u8 + juce::String (wetDb - inDb, 1) + " dB par rapport à l'entrée"_u8);
            expect (wetDb - inDb > -15.0f && wetDb - inDb < 3.0f, "niveau de retour plausible");
        }
        beginTest ("Delai : premiere repetition au bon temps");
        {
            Mono x (static_cast<size_t> (kSr * 2), 0.0f);
            x[1000] = 1.0f;
            dsp::DelaySettings d;
            d.send = 1.0f;
            d.noteBeats = 1.0f;
            d.feedback = 0.0f;
            d.hpfHz = 20.0f;
            d.lpfHz = 20000.0f;
            const auto out = dsp::delayReturn (x, kSr, 120.0, d);
            int peakIdx = 0;
            float pk = 0.0f;
            for (int i = 0; i < out.getNumSamples(); ++i)
                if (std::abs (out.getSample (0, i)) > pk)
                {
                    pk = std::abs (out.getSample (0, i));
                    peakIdx = i;
                }
            expectWithinAbsoluteError (peakIdx, 1000 + 24000, 2);
        }
        beginTest ("Nettoyage : respiration attenuee, voix intacte");
        {
            auto phrases = defaultPhrases (aMinor(), 100.0);
            const auto v = synthVoice (phrases, kSr);
            Mono y = v;
            const auto va = analysis::analyzeVoice (y, kSr);
            const auto track = analysis::detectPitch (y, kSr);
            dsp::CleanSettings cs;
            cs.hpfHz = 80.0f;
            const auto rep = dsp::clean (y, kSr, cs, track, va);
            logMessage ("respirations traitées : "_u8 + juce::String (rep.breathsTreated) + ", plosives : " + juce::String (rep.plosivesTreated));
            expect (! audio::hasNonFinite (y.data(), y.size()));
            const float dv = gainToDb (audio::rms (y.data(), y.size())) - gainToDb (audio::rms (v.data(), v.size()));
            expect (std::abs (dv) < 1.5f, "niveau global conservé ("_u8 + juce::String (dv, 2) + " dB)");
        }
        beginTest ("Recalage rythmique : attaque decalee de 30 ms ramenee sur la grille");
        {
            TempoInfo tempo;
            tempo.bpm = 120.0;   // grille de doubles croches = 125 ms
            tempo.firstBeatSec = 0.0;
            Mono x (static_cast<size_t> (kSr * 3), 0.0f);
            const double onset = 1.0 + 0.030;   // 30 ms après le temps
            const auto burst = sine (300.0, 0.3, kSr, 0.5f);
            for (size_t i = 0; i < burst.size(); ++i)
                x[static_cast<size_t> (onset * kSr) + i] = burst[i] * std::min (1.0f, static_cast<float> (i) / 100.0f);
            const auto va = analysis::analyzeVoice (x, kSr);
            dsp::TimingParams tp;
            tp.strength = 1.0f;
            const auto res = dsp::correctTiming (x, kSr, tempo, va, tp);
            const auto va2 = analysis::analyzeVoice (res.audio, kSr);
            expect (! va2.phrases.empty(), "phrase présente"_u8);
            if (! va2.phrases.empty())
            {
                logMessage ("attaque après recalage : "_u8 + juce::String (va2.phrases[0].startSec, 3) + " s");
                expectWithinAbsoluteError (va2.phrases[0].startSec, 1.0, 0.015);
            }
        }
    }
};

class MasterTests final : public juce::UnitTest
{
public:
    MasterTests() : juce::UnitTest ("Mastering", "studiovoix") {}

    void runTest() override
    {
        const auto instru = synthInstru (140.0, aMinor(), 8, kSr, false);
        for (auto target : { dsp::LoudnessTarget::Spotify, dsp::LoudnessTarget::AppleMusic, dsp::LoudnessTarget::Fort })
        {
            const auto info = dsp::targetInfo (target);
            beginTest ("Cible " + info.name);
            dsp::MasterSettings ms;
            ms.target = target;
            dsp::MasterReport rep;
            const auto out = dsp::master (instru, kSr, ms, rep);
            logMessage (juce::String (rep.outputLufs, 2) + " LUFS, " + juce::String (rep.truePeakDb, 2) + " dBTP");
            expectWithinAbsoluteError (rep.outputLufs, static_cast<double> (info.lufs), 0.5);
            expect (rep.truePeakDb <= info.ceilingDbTp + 0.15, "crête vraie sous le plafond"_u8);
            expect (! audio::hasNonFinite (out.getReadPointer (0), static_cast<size_t> (out.getNumSamples())));
        }
        beginTest ("Mastering : mix quasi silencieux non amplifie");
        {
            juce::Random rnd (7);
            Stereo hiss (2, static_cast<int> (kSr * 4));
            for (int c = 0; c < 2; ++c)
                for (int i = 0; i < hiss.getNumSamples(); ++i)
                    hiss.setSample (c, i, (rnd.nextFloat() * 2.0f - 1.0f) * 1.0e-4f);   // environ -85 dBFS
            dsp::MasterSettings ms;
            dsp::MasterReport rep;
            dsp::master (hiss, kSr, ms, rep);
            expect (rep.outputLufs < -60.0, "souffle amplifié : "_u8 + juce::String (rep.outputLufs, 1) + " LUFS");
        }
        beginTest ("Mastering : marge MP3 (-2 dBTP) sur la cible Fort");
        {
            dsp::MasterSettings ms;
            ms.target = dsp::LoudnessTarget::Fort;
            ms.extraHeadroomDb = 1.0f;
            dsp::MasterReport rep;
            dsp::master (instru, kSr, ms, rep);
            expect (rep.truePeakDb <= -2.0 + 0.05, "crête vraie "_u8 + juce::String (rep.truePeakDb, 2) + " dBTP");
        }
        beginTest ("Limiteur : aucun echantillon au-dessus du plafond");
        {
            Stereo loud = audio::monoToStereo (sine (100.0, 1.0, kSr, 1.5f));
            dsp::limitStereo (loud, kSr, -1.0f);
            const float pk = std::max (loud.getMagnitude (0, 0, loud.getNumSamples()), loud.getMagnitude (1, 0, loud.getNumSamples()));
            expect (pk <= dbToGain (-1.0f) + 1.0e-5f, "crête "_u8 + juce::String (gainToDb (pk), 3) + " dBFS");
        }
    }
};

class AssistantTests final : public juce::UnitTest
{
public:
    AssistantTests() : juce::UnitTest ("Assistant texte", "studiovoix") {}

    void runTest() override
    {
        style::Macros m;
        beginTest ("normalisation des accents");
        logMessage ("normalise : [" + assistant::normalise ("Plus de réverb, d'énergie"_u8) + "]");
        expectEquals (assistant::normalise ("Plus de réverb"_u8), juce::String ("plus de reverb"));
        beginTest ("plus de reverb");
        expect (assistant::apply (juce::String (juce::CharPointer_UTF8 ("plus de réverb")), m).macros.reverbTrim > 0.5f);
        beginTest ("voix plus sombre");
        expect (assistant::apply ("voix plus sombre", m).macros.presence < 0.5f);
        beginTest ("beaucoup moins d'autotune");
        expectWithinAbsoluteError (assistant::apply ("beaucoup moins d'autotune", m).macros.autotune, 0.2f, 0.001f);
        beginTest ("trop de delai");
        expect (assistant::apply (juce::String (juce::CharPointer_UTF8 ("il y a trop de délai")), m).macros.delayTrim < 0.5f);
        beginTest ("un peu plus d'energie");
        expectWithinAbsoluteError (assistant::apply (juce::String (juce::CharPointer_UTF8 ("un peu plus d'énergie")), m).macros.energy, 0.57f, 0.001f);
        beginTest ("phrase incomprise");
        expect (! assistant::apply ("bonjour", m).understood);
        beginTest ("plus naturel = moins d'autotune");
        expect (assistant::apply ("plus naturel", m).macros.autotune < 0.5f);
        beginTest ("negations, valeurs absolues, phrases mixtes, majuscules accentuees");
        expectWithinAbsoluteError (assistant::apply ("pas de reverb", m).macros.reverbTrim, 0.0f, 1.0e-6f);
        expectWithinAbsoluteError (assistant::apply ("je ne veux plus d'autotune", m).macros.autotune, 0.0f, 1.0e-6f);
        expectWithinAbsoluteError (assistant::apply ("coupe le délai"_u8, m).macros.delayTrim, 0.0f, 1.0e-6f);
        expectWithinAbsoluteError (assistant::apply ("reverb à 30 %"_u8, m).macros.reverbTrim, 0.3f, 1.0e-4f);
        expectWithinAbsoluteError (assistant::apply ("autotune à 0,8"_u8, m).macros.autotune, 0.8f, 1.0e-4f);
        expect (assistant::apply ("trop peu de reverb", m).macros.reverbTrim > 0.5f, "trop peu = plus");
        expect (assistant::apply ("pas trop de reverb", m).macros.reverbTrim < 0.5f, "pas trop = moins");
        {
            const auto r = assistant::apply ("plus de reverb et moins d'autotune", m);
            expect (r.macros.reverbTrim > 0.5f && r.macros.autotune < 0.5f, "phrase mixte : " + r.changes.joinIntoString ("; "));
        }
        expect (assistant::apply ("PLUS DE RÉVERB"_u8, m).macros.reverbTrim > 0.5f, "majuscules accentuées"_u8);
        expect (assistant::apply ("Écho plus fort"_u8, m).macros.delayTrim > 0.5f, "Écho = délai"_u8);
    }
};

class GeneratorTests final : public juce::UnitTest
{
public:
    GeneratorTests() : juce::UnitTest ("Generation backs / harmonies / ad-libs", "studiovoix") {}

    void runTest() override
    {
        const auto key = aMinor();
        const auto voice = synthVoice (defaultPhrases (key, 100.0), kSr);
        gen::LeadAnalysis la;
        la.prepared = voice;
        la.track = analysis::detectPitch (voice, kSr);
        la.va = analysis::analyzeVoice (voice, kSr);
        la.key = key;
        la.tempo.bpm = 100.0;

        beginTest ("Options par defaut du style trap");
        {
            gen::GenerationOptions o = gen::GenerationOptions::fromDefaults (style::generationDefaults (style::Style::Trap));
            o.ambiance = true;
            const auto tracks = gen::generate (la, kSr, o);
            int doubles = 0, harmonies = 0, backs = 0, adlibs = 0, amb = 0;
            for (const auto& t : tracks)
            {
                expect (! audio::hasNonFinite (t.audio.data(), t.audio.size()), "pas de NaN : " + t.name);
                expectEquals (static_cast<int> (t.audio.size()), static_cast<int> (voice.size()));
                doubles += t.role == style::Role::Double;
                harmonies += t.role == style::Role::Harmony;
                backs += t.role == style::Role::KeywordBack;
                adlibs += t.role == style::Role::AdLib;
                amb += t.role == style::Role::Ambiance;
            }
            expectEquals (doubles, 2);
            expectEquals (harmonies, 1);
            expectEquals (backs, 1);
            expectEquals (adlibs, 1);
            expectEquals (amb, 1);
        }
        beginTest ("Profils : tous les styles (dont rock et latino), ids stables, chaine sans NaN");
        {
            for (int i = 0; i < static_cast<int> (style::Style::Count); ++i)
            {
                const auto st = static_cast<style::Style> (i);
                expect (style::styleFromId (style::styleId (st)) == st, "aller-retour id : " + style::styleId (st));
                expect (style::styleName (st).isNotEmpty());
                for (int r = 0; r < static_cast<int> (style::Role::Count); ++r)
                {
                    const auto p = style::makeParams (st, static_cast<style::Role> (r), {});
                    expect (std::isfinite (p.outputDb) && std::isfinite (p.comp.ratio) && p.comp.ratio >= 1.0f
                                && std::isfinite (p.reverb.send) && std::isfinite (p.delay.noteBeats) && p.delay.noteBeats > 0.0f,
                            "reglages finis : " + style::styleId (st) + " / " + style::roleId (static_cast<style::Role> (r)));
                }
            }
            expect (style::makeParams (style::Style::Rock, style::Role::Lead, {}).pitch.amount
                    < style::makeParams (style::Style::Latino, style::Role::Lead, {}).pitch.amount,
                    "rock : moins d'autotune que latino");
            {
                // Chaque style a son propre pré-réglage complet, décrit lisiblement dans l'onglet Voix IA.
                juce::StringArray chains;
                for (int i = 0; i < static_cast<int> (style::Style::Count); ++i)
                {
                    const auto st = static_cast<style::Style> (i);
                    const auto d = dsp::describeChain (style::makeParams (st, style::Role::Lead, {}));
                    for (const char* effect : { "Autotune : ", "EQ : ", "Compresseur : ", "De-esser : ", "Saturation : ", "Réverb : ", "Délai : " })
                        expect (d.contains (juce::String (juce::CharPointer_UTF8 (effect))), "effet décrit : "_u8 + effect + " / " + style::styleId (st));
                    // UTF-8 lu comme ASCII/Latin-1 (« Ã© ») laisse toujours un caractère U+0080..U+00BF.
                    bool mojibake = false;
                    for (auto c = d.getCharPointer(); ! c.isEmpty(); ++c)
                        mojibake = mojibake || (*c >= 0x80 && *c <= 0xBF);
                    expect (! mojibake, "accents corrects : " + style::styleId (st));
                    chains.addIfNotAlreadyThere (d);
                }
                expectEquals (chains.size(), static_cast<int> (style::Style::Count), "un pré-réglage distinct par style"_u8);
                expect (dsp::describeChain (style::makeParams (style::Style::Trap, style::Role::Lead, {})).contains ("Autotune : effet marqué"_u8),
                        "trap : autotune marqué"_u8);
                // Rap parlé : nettoyage transparent (40-80 ms, 70-90 %) — lent, donc naturel, mais pas « léger ».
                const auto rapP = style::makeParams (style::Style::Rap, style::Role::Lead, {}).pitch;
                expect (rapP.enabled && rapP.retuneMs >= 40.0f && rapP.amount >= 0.6f && rapP.amount <= 0.9f, "rap : nettoyage transparent"_u8);
            }
            dsp::AnalysisContext ctx;
            ctx.key = key;
            ctx.tempo.bpm = 100.0;
            expect (style::makeParams (style::Style::BoomBap, style::Role::Lead, {}).pitch.retuneMs >= 90.0f, "boom bap : autotune le plus lent (voyelles longues seulement)");
            expect (style::makeParams (style::Style::Acoustique, style::Role::Lead, {}).pitch.amount
                    < style::makeParams (style::Style::RapMelodique, style::Role::Lead, {}).pitch.amount,
                    "acoustique : moins d'autotune que rap melodique");
            expect (style::styleFromId ("rap_melodique") == style::Style::RapMelodique && style::styleFromId ("inconnu") == style::Style::Rap,
                    "ids des nouveaux styles");
            {
                std::vector<int> seen (static_cast<size_t> (style::Style::Count), 0);
                for (const auto& g : style::styleGroups())
                    for (const auto st : g.styles)
                        ++seen[static_cast<size_t> (st)];
                for (int i = 0; i < static_cast<int> (style::Style::Count); ++i)
                    expectEquals (seen[static_cast<size_t> (i)], 1, "style dans une seule famille : " + style::styleId (static_cast<style::Style> (i)));
            }
            expect (style::makeParams (style::Style::RapHardcore, style::Role::Lead, {}).comp.ratio
                    > style::makeParams (style::Style::RapConscient, style::Role::Lead, {}).comp.ratio,
                    "hardcore : plus compresse que conscient");
            for (int i = 0; i < static_cast<int> (style::Style::Count); ++i)
            {
                const auto st = static_cast<style::Style> (i);
                const auto res = dsp::processVocal (voice, kSr, style::makeParams (st, style::Role::Lead, {}), ctx);
                const auto* l = res.audio.getReadPointer (0);
                expect (! audio::hasNonFinite (l, static_cast<size_t> (res.audio.getNumSamples())), "pas de NaN : " + style::styleId (st));
                const float pk = audio::peak (l, static_cast<size_t> (res.audio.getNumSamples()));
                expect (pk > 0.01f && pk < 1.5f, "niveau plausible " + style::styleId (st) + " : " + juce::String (pk, 3));
            }
        }
        beginTest ("Harmonie : tierce au-dessus dans la gamme");
        {
            VoicePhrase p;
            p.notes = { { 57.0f, 1.2, 0.0f } };   // La 2
            const auto v = synthVoice ({ p }, kSr, 0.2, 0.0f);
            gen::LeadAnalysis l2 = la;
            l2.prepared = v;
            l2.track = analysis::detectPitch (v, kSr);
            l2.va = analysis::analyzeVoice (v, kSr);
            const auto h = gen::makeHarmony (l2, kSr, 0);
            const float f = medianF0 (h.audio, kSr, 0.4, 1.2);
            logMessage ("harmonie : " + juce::String (f, 1) + " Hz (attendu Do, MIDI 60 = 261,6 Hz)");
            expectWithinAbsoluteError (f, 261.63f, 261.63f * 0.03f);
        }
        beginTest ("Backs mots cles : uniquement en fin de phrase");
        {
            const auto t = gen::makeKeywordBacks (la, kSr, 2);
            for (const auto& ph : la.va.phrases)
            {
                const size_t a = static_cast<size_t> (ph.startSec * kSr);
                const size_t mid = static_cast<size_t> ((ph.startSec + ph.duration() * 0.25) * kSr);
                const float startRms = audio::rms (t.audio.data() + a, mid - a);
                const size_t e = static_cast<size_t> (ph.endSec * kSr);
                const size_t s = static_cast<size_t> ((ph.endSec - 0.2) * kSr);
                const float endRms = audio::rms (t.audio.data() + s, e - s);
                expect (endRms > 0.01f, "contenu en fin de phrase");
                expect (startRms < endRms * 0.1f, "pas de contenu au début de phrase"_u8);
            }
        }
        beginTest ("Ad-libs sans banque : places dans les silences");
        {
            gen::GenerationOptions o;
            o.adLibDensity = 1.0f;
            juce::Random rng (3);
            int placed = 0;
            const auto t = gen::makeAdLibs (la, kSr, o, rng, placed);
            expect (placed >= 2, "ad-libs placés : "_u8 + juce::String (placed));
            for (const auto& ph : la.va.phrases)
            {
                const size_t a = static_cast<size_t> ((ph.startSec + 0.05) * kSr);
                const size_t b = static_cast<size_t> ((ph.endSec - 0.05) * kSr);
                expect (audio::rms (t.audio.data() + a, b - a) < 1.0e-4f, "pas d'ad-lib pendant une phrase");
            }
        }
    }
};

class CompTests final : public juce::UnitTest
{
public:
    CompTests() : juce::UnitTest ("Assemblage des prises", "studiovoix") {}

    void runTest() override
    {
        const auto key = aMinor();
        TempoInfo tempo;
        tempo.bpm = 100.0;
        const auto phrases = defaultPhrases (key, 100.0);
        const Mono good = synthVoice (phrases, kSr, 0.5, 15.0f, 1);
        Mono bad = synthVoice (phrases, kSr, 0.5, 15.0f, 2);
        // Prise 2 : saturation numérique violente sur la phrase 2.
        const auto va = analysis::analyzeVoice (good, kSr);
        expect (va.phrases.size() == 4, "4 phrases");
        if (va.phrases.size() < 4)
            return;
        for (size_t i = static_cast<size_t> (va.phrases[1].startSec * kSr); i < static_cast<size_t> (va.phrases[1].endSec * kSr); ++i)
            bad[i] = juce::jlimit (-1.0f, 1.0f, bad[i] * 40.0f);

        std::vector<gen::TakeInput> takes (2);
        takes[0] = { &good, 0, 0, static_cast<long> (good.size()), 1 };
        takes[1] = { &bad, 0, 0, static_cast<long> (bad.size()), 2 };

        beginTest ("Meilleure prise : la phrase saturee vient de la prise propre");
        {
            const auto res = gen::compBest (takes, kSr, key, tempo, style::Style::PopUrbaine);
            bool phrase2FromGood = false;
            const long mid = static_cast<long> (0.5 * (va.phrases[1].startSec + va.phrases[1].endSec) * kSr);
            for (const auto& s : res.segments)
                if (mid >= s.start && mid < s.end)
                    phrase2FromGood = s.takeIndex == 0;
            logMessage (res.summary);
            expect (phrase2FromGood, "phrase 2 prise dans la prise 1");
            expect (audio::peak (res.audio.data(), res.audio.size()) < 0.99f, "pas d'écrêtage dans l'assemblage"_u8);
        }
        beginTest ("Meilleure prise : zone couverte par deux prises partielles -> pas de silence");
        {
            Mono tone (static_cast<size_t> (10 * kSr), 0.0f);
            for (size_t i = static_cast<size_t> (3 * kSr); i < static_cast<size_t> (8 * kSr); ++i)
                tone[i] = 0.3f * static_cast<float> (std::sin (2.0 * juce::MathConstants<double>::pi * 220.0 * static_cast<double> (i) / kSr));
            std::vector<gen::TakeInput> t3 = { { &tone, 0, 0, static_cast<long> (6 * kSr), 1 },
                                               { &tone, 0, static_cast<long> (4 * kSr), static_cast<long> (10 * kSr), 2 } };
            const auto res = gen::compBest (t3, kSr, key, tempo, style::Style::PopUrbaine);
            const long i0 = static_cast<long> (5 * kSr) - res.startSample;
            const float lvl = i0 >= 0 && i0 + static_cast<long> (kSr) <= static_cast<long> (res.audio.size())
                                  ? audio::rms (res.audio.data() + i0, static_cast<size_t> (kSr)) : 0.0f;
            expect (lvl > 0.1f, "niveau entre 5 et 6 s : "_u8 + juce::String (lvl, 3));
        }
        beginTest ("Derniere prise : punch-in remplace la zone");
        {
            Mono punch (good.size(), 0.0f);
            for (size_t i = 48000; i < 96000; ++i)
                punch[i] = 0.25f;
            std::vector<gen::TakeInput> t2 = { takes[0], { &punch, 0, 48000, 96000, 3 } };
            const auto res = gen::compLatest (t2, kSr);
            expectWithinAbsoluteError (res.audio[70000], 0.25f, 1.0e-4f);
            expectWithinAbsoluteError (res.audio[20000], good[20000], 1.0e-6f);
        }
    }
};

class ProjectTests final : public juce::UnitTest
{
public:
    ProjectTests() : juce::UnitTest ("Projet / sauvegarde / rendu", "studiovoix") {}

    void runTest() override
    {
        const auto root = juce::File::getSpecialLocation (juce::File::tempDirectory).getChildFile ("studiovoix_tests_" + juce::String (juce::Time::currentTimeMillis()));
        juce::String err;

        beginTest ("Recalage de latence");
        expectEquals (project::compensatedTakeStart (48000, 256, 512, 0), 47232L);
        expectEquals (project::compensatedTakeStart (100, 256, 512, 0), -668L);

        beginTest ("Creation, sauvegarde et rechargement");
        const auto folder = project::createProjectFolder (root, "Test projet", err);
        expect (folder.isDirectory(), err);
        project::Project p;
        p.folder = folder;
        p.name = "Test";
        p.style = style::Style::Trap;
        p.key = aMinor();
        p.tempo.bpm = 140.0;
        p.lyrics = juce::String (juce::CharPointer_UTF8 ("Première ligne\nDeuxième ligne"));
        auto& instru = p.addTrack (style::Role::Instru, "Instru");
        instru.sourceFile = "instru.wav";
        auto& lead = p.addTrack (style::Role::Lead, "Voix");
        lead.macros.autotune = 0.8f;
        project::Take tk;
        tk.id = p.nextTakeId++;
        tk.file = "prise1.wav";
        tk.startSample = 0;
        tk.regionStart = 0;
        tk.regionEnd = 48000 * 8;
        tk.fadeIn = 480;
        tk.fadeOut = 960;
        lead.takes.push_back (tk);
        lead.stages["comp"].bypass = true;
        lead.stages["eq"].state = plugins::defaultInternalState (*plugins::findInternal ("interne:eq"));
        const int leadId = lead.id;   // la référence 'lead' devient invalide quand d'autres pistes sont ajoutées
        p.armedTrackId = leadId;
        expect (p.save (err), err);
        expect (p.saveVersion ("test", err), err);
        expect (p.saveAutosave (err), err);

        project::Project q;
        expect (project::Project::load (folder, q, err), err);
        expectEquals (q.tracks.size(), p.tracks.size());
        expect (q.style == style::Style::Trap);
        expectEquals (q.lyrics, p.lyrics);
        expectWithinAbsoluteError (q.findTrack (leadId)->macros.autotune, 0.8f, 1.0e-4f);
        expectEquals (q.findTrack (leadId)->takes.size(), static_cast<size_t> (1));
        expect (q.findTrack (leadId)->takes[0].fadeIn == 480 && q.findTrack (leadId)->takes[0].fadeOut == 960, "fondus du bloc enregistrés"_u8);
        expect (q.findTrack (leadId)->stages.size() == 2 && q.findTrack (leadId)->stages.at ("comp").bypass
                    && q.findTrack (leadId)->stages.at ("eq").state == lead.stages.at ("eq").state, "chaîne réglée à la main enregistrée"_u8);
        expectEquals (static_cast<int> (q.listVersions().size()), 1);
        expectEquals (q.armedTrackId, leadId);

        beginTest ("Chaine visible : etapes <-> reglages (aller-retour, contournement, reglage manuel, sauvegarde)");
        {
            const auto base = style::makeParams (style::Style::Rap, style::Role::Lead, {}, true);
            int active = 0;
            for (const auto& st : plugins::chainStages())
            {
                const juce::String stName (juce::CharPointer_UTF8 (st.name));
                expect (plugins::findInternal (st.pluginId) != nullptr, "effet intégré de l'étape "_u8 + stName);
                auto q = base;
                plugins::applyStageState (st, plugins::stageState (st, base), q);
                expect (plugins::stageSummary (st, q) == plugins::stageSummary (st, base) && plugins::stageActive (st, q) == plugins::stageActive (st, base),
                        "aller-retour état -> réglages sans changement : "_u8 + stName + " (" + plugins::stageSummary (st, base) + " -> " + plugins::stageSummary (st, q) + ")");
                plugins::bypassStage (st, q);
                expect (! plugins::stageActive (st, q), "contournement : "_u8 + stName + " éteint"_u8);
                active += plugins::stageActive (st, base) ? 1 : 0;
            }
            expect (active >= 6, "le style Rap allume au moins 6 étapes ("_u8 + juce::String (active) + ")");
            const auto instr = style::makeParams (style::Style::Trap, style::Role::Instrument, {});
            expect (! plugins::stageActive (*plugins::findStage ("tune"), instr) && ! plugins::stageActive (*plugins::findStage ("deess"), instr)
                        && ! plugins::stageActive (*plugins::findStage ("delay"), instr),
                    "instrument : cases autotune, de-esser et délai éteintes par le style"_u8);

            // Réglage manuel + contournement appliqués par-dessus le style.
            std::map<juce::String, plugins::StageOverride> ov;
            ov["comp"].bypass = true;
            const auto* eq = plugins::findStage ("eq");
            ov["eq"].state = plugins::withInternalParam (*plugins::findInternal (eq->pluginId), plugins::stageState (*eq, base), "presDb", 6.0f);
            auto pr = base;
            const auto line = plugins::applyStageOverrides (ov, pr);
            expect (pr.comp.ratio <= 1.0f && std::abs (pr.eq.presenceDb - 6.0f) < 1e-4f && std::abs (pr.eq.lowCutHz - base.eq.lowCutHz) < 1e-4f,
                    "compresseur contourné, présence +6 dB, reste de l'EQ du style : " + line);
            expect (line.contains ("Compresseur") && line.contains ("EQ") && ! line.containsChar (0xC3), "ligne lisible : " + line);
            expect (dsp::describeChain (pr) != dsp::describeChain (base), "le rapport reflète la chaîne réglée à la main"_u8);

            // Sauvegarde / lecture.
            const auto v = ov["eq"].toVar();
            const auto back = plugins::StageOverride::fromVar (v);
            expect (! back.bypass && back.state == ov["eq"].state, "StageOverride aller-retour JSON");
            expect (plugins::findInternal ("interne:tune") != nullptr && ! plugins::findInternal ("interne:tune")->insertable
                        && plugins::findInternal ("interne:comp")->insertable, "autotune : étape seulement, compresseur insérable"_u8);
        }

        beginTest ("Edition des blocs : couper, rogner, fondus, supprimer ; fondus appliques a l'assemblage");
        {
            project::Track tr;
            tr.name = "Voix";
            project::Take a;
            a.id = 1;
            a.file = "a.wav";
            a.startSample = 1000;
            a.regionStart = 1000;
            a.regionEnd = 49000;
            a.fadeIn = 500;
            a.fadeOut = 700;
            tr.takes.push_back (a);
            int nextId = 2;
            expect (! project::splitTake (tr, 1, 1000, nextId) && ! project::splitTake (tr, 1, 49000, nextId) && ! project::splitTake (tr, 9, 2000, nextId),
                    "couper : refusé aux bords ou sur une prise inconnue"_u8);
            expect (project::splitTake (tr, 1, 25000, nextId) && tr.takes.size() == 2, "couper au milieu : deux blocs");
            expect (tr.takes[0].id == 1 && tr.takes[0].regionStart == 1000 && tr.takes[0].regionEnd == 25000 && tr.takes[0].fadeIn == 500 && tr.takes[0].fadeOut == 0,
                    "bloc gauche : garde l'id et le fondu d'entrée"_u8);
            expect (tr.takes[1].id == 2 && nextId == 3 && tr.takes[1].regionStart == 25000 && tr.takes[1].regionEnd == 49000 && tr.takes[1].startSample == 1000
                        && tr.takes[1].file == "a.wav" && tr.takes[1].fadeIn == 0 && tr.takes[1].fadeOut == 700,
                    "bloc droit : nouvelle prise, même fichier, garde le fondu de sortie"_u8);
            expect (project::trimTake (tr, 2, 30000, 80000, 48000, 2400) && tr.takes[1].regionStart == 30000 && tr.takes[1].regionEnd == 49000,
                    "rogner : borné au fichier (1000 + 48000)"_u8);
            expect (! project::trimTake (tr, 2, 30000, 30100, 48000, 2400), "rogner : zone trop courte refusée"_u8);
            expect (project::trimTake (tr, 1, 0, 25000, 48000, 2400) && tr.takes[0].regionStart == 1000, "rogner : jamais avant le début du fichier"_u8);
            expect (project::setTakeFades (tr, 2, 100000, 100000) && tr.takes[1].fadeIn == 19000 && tr.takes[1].fadeOut == 0, "fondus bornés à la zone"_u8);
            expect (project::setTakeFades (tr, 2, 480, 480) && tr.takes[1].fadeIn == 480 && tr.takes[1].fadeOut == 480);
            expect (project::removeTake (tr, 1) && tr.takes.size() == 1 && tr.takes[0].id == 2 && ! project::removeTake (tr, 1), "supprimer un bloc");

            // Fondus appliqués par l'assemblage des prises (courbe en cosinus : 0 au bord, 0,5 au milieu, 1 à la fin).
            Mono one (48000, 1.0f);
            gen::TakeInput in;
            in.audio = &one;
            in.startSample = 0;
            in.regionStart = 0;
            in.regionEnd = 48000;
            in.id = 1;
            in.fadeIn = 4800;
            in.fadeOut = 9600;
            const auto res = gen::compLatest ({ in }, kSr);
            expect (res.audio.size() == 48000 && res.startSample == 0);
            expect (std::abs (res.audio[0]) < 1e-6f && std::abs (res.audio[2400] - 0.5f) < 1e-3f && std::abs (res.audio[4800] - 1.0f) < 1e-6f,
                    "fondu d'entrée : "_u8 + juce::String (res.audio[0], 3) + " / " + juce::String (res.audio[2400], 3) + " / " + juce::String (res.audio[4800], 3));
            expect (std::abs (res.audio[47999]) < 1e-3f && std::abs (res.audio[48000 - 4800] - 0.5f) < 1e-3f && std::abs (res.audio[48000 - 9600] - 1.0f) < 1e-6f,
                    "fondu de sortie : "_u8 + juce::String (res.audio[47999], 3) + " / " + juce::String (res.audio[48000 - 4800], 3));
            float maxStep = 0.0f;
            for (size_t i = 1; i < res.audio.size(); ++i)
                maxStep = std::max (maxStep, std::abs (res.audio[i] - res.audio[i - 1]));
            expect (maxStep < 0.001f, "fondus sans clic (saut max "_u8 + juce::String (maxStep, 5) + ")");
        }

        beginTest ("Pistes ajoutees a la main : instrument, piste armee");
        {
            juce::var v;
            juce::JSON::parse (R"({"format":"studiovoix-project","version":1,"name":"armes","armedTrack":2,"tracks":[
                {"id":1,"name":"Voix","role":"lead"},
                {"id":2,"name":"Instru","role":"instru","sourceFile":"instru.wav"},
                {"id":3,"name":"Guitare","role":"instrument"},
                {"id":4,"name":"Double","role":"double","generatedFrom":1,"sourceFile":"d.wav"}]})", v);
            project::Project ap;
            juce::String loadErr;
            expect (project::Project::fromVar (v, ap, loadErr), loadErr);
            expectEquals (ap.armedTrackId, -1);   // l'instru importée ne reçoit pas de prise
            expect (ap.findTrack (3) != nullptr && ap.findTrack (3)->role == style::Role::Instrument && ap.findTrack (3)->isRecordable()
                        && ! ap.findTrack (3)->isVoice(), "instrument : enregistrable, pas une voix pour le mix auto");
            expect (! ap.findTrack (4)->isRecordable(), "piste générée non enregistrable");
            ap.armedTrackId = 3;
            expect (ap.removeTrack (3) && ap.armedTrackId == -1, "piste armée supprimée : désarmée");

            const auto inst = style::makeParams (style::Style::Trap, style::Role::Instrument, {});
            expect (! inst.pitch.enabled && inst.deEss.amount <= 0.0f && inst.delay.send <= 0.0f, "instrument : ni autotune, ni de-esser, ni délai");
            expect (style::makeParams (style::Style::Trap, style::Role::Harmony, {}, true).pitch.enabled
                        && ! style::makeParams (style::Style::Trap, style::Role::Harmony, {}).pitch.enabled,
                    "harmonie chantée au micro : autotune du style ; générée : déjà corrigée");
            expect (style::roleFromId ("instrument") == style::Role::Instrument);
            for (const auto r : style::userTrackRoles())
                expect (! style::userTrackLabel (r).containsChar (0xC3) && style::userTrackBaseName (r).isNotEmpty(),
                        "libellé de type : " + style::roleId (r));
        }

        beginTest ("Projet modifie a la main : id en double, id texte, role absent");
        {
            juce::var v;
            juce::JSON::parse (R"({"format":"studiovoix-project","version":1,"name":"main","tracks":[
                {"id":1,"name":"Voix","role":"lead"},
                {"id":"2","name":"Instru","sourceFile":"instru.wav"},
                {"id":1,"name":"Back","role":"manual_back"}]})", v);
            project::Project fixedProj;
            juce::String loadErr;
            expect (project::Project::fromVar (v, fixedProj, loadErr), loadErr);
            expectEquals (static_cast<int> (fixedProj.tracks.size()), 3);
            std::set<int> ids;
            for (const auto& t : fixedProj.tracks)
                ids.insert (t.id);
            expectEquals (static_cast<int> (ids.size()), 3);
            const auto* inst = fixedProj.instruTrack();
            expect (inst != nullptr && inst->id == 2, "instru déduite, id texte accepté"_u8);
            expect (! fixedProj.loadWarnings.isEmpty(), "réparations signalées"_u8);
        }
        beginTest ("Fichier corrompu refuse proprement");
        {
            const auto bad = root.getChildFile ("corrompu");
            bad.createDirectory();
            bad.getChildFile ("projet.svx").replaceWithText ("{ pas du json");
            project::Project r;
            juce::String e2;
            expect (! project::Project::load (bad, r, e2));
            expect (e2.isNotEmpty());
        }

        beginTest ("Chaine complete : instru + voix -> remix, generation, mix, master, export");
        {
            const auto key = aMinor();
            const auto instruAudio = synthInstru (100.0, key, 8, kSr, false);
            const auto voice = synthVoice (defaultPhrases (key, 100.0), kSr);
            expect (audio::writeFile (p.audioDir().getChildFile ("instru.wav"), instruAudio, kSr, audio::FileFormat::Wav24, err), err);
            expect (audio::writeMonoWavFloat (p.audioDir().getChildFile ("prise1.wav"), voice, kSr, err), err);
            p.findTrack (leadId)->takes[0].regionEnd = static_cast<long> (voice.size());

            render::AudioCache cache;
            const auto ctx = render::makeContext (p, cache);
            render::RenderSet set;
            for (const auto& t : p.tracks)
            {
                auto r = render::renderTrack (p, t, cache, ctx);
                expect (r->ok(), r->error);
                set[t.id] = r;
            }
            auto leadRender = set[leadId];
            gen::GenerationOptions o = gen::GenerationOptions::fromDefaults (style::generationDefaults (p.style));
            const auto ids = render::generateBackingTracks (p, leadId, *leadRender, o, err);
            expect (! ids.empty(), "pistes générées"_u8);
            for (int id : ids)
            {
                auto r = render::renderTrack (p, *p.findTrack (id), cache, ctx);
                expect (r->ok(), r->error);
                set[id] = r;
            }
            render::ExportOptions eo;
            eo.outDir = p.exportDir();
            eo.baseName = "test_mix";
            eo.stems = true;
            const auto rep = render::exportProject (p, set, eo);
            expect (rep.ok, rep.error);
            expect (rep.mixFile.existsAsFile(), "fichier de mix écrit"_u8);
            expectEquals (rep.stemFiles.size(), static_cast<int> (p.tracks.size()));
            logMessage ("mix : " + juce::String (rep.master.outputLufs, 2) + " LUFS, " + juce::String (rep.master.truePeakDb, 2)
                        + " dBTP, gain voix auto " + juce::String (rep.vocalGainDb, 1) + " dB");
            expectWithinAbsoluteError (rep.master.outputLufs, -14.0, 0.6);
            // Second export du même nom : nouveau fichier, le premier est conservé.
            eo.stems = false;
            const auto rep2 = render::exportProject (p, set, eo);
            expect (rep2.ok, rep2.error);
            expect (rep2.mixFile != rep.mixFile && rep.mixFile.existsAsFile() && rep2.mixFile.existsAsFile(),
                    "second export : "_u8 + rep2.mixFile.getFileName());
            expectEquals (audio::safeFileName ("CON", "mix"), juce::String ("_CON"));
            expectEquals (audio::safeFileName ("nul.txt", "mix"), juce::String ("_nul.txt"));
            expectEquals (audio::safeFileName ("  ...  ", "mix"), juce::String ("mix"));
            expectEquals (audio::safeFileName ("Refrain : v2.", "mix"), juce::String ("Refrain  v2"));

            auto reread = audio::loadStereo (rep.mixFile, kSr);
            expect (reread.ok(), reread.error);
            expect (! audio::hasNonFinite (reread.buffer.getReadPointer (0), static_cast<size_t> (reread.buffer.getNumSamples())));
        }

        beginTest ("Piste brute (importee / glissee) : aucun effet, hors mix auto ; style par piste");
        {
            project::Project rawProj = p;
            rawProj.findTrack (leadId)->raw = true;
            render::AudioCache cache;
            const auto ctx = render::makeContext (rawProj, cache);
            auto lr = render::renderTrack (rawProj, *rawProj.findTrack (leadId), cache, ctx);
            expect (lr->ok(), lr->error);
            bool same = lr->processed.getNumSamples() == lr->raw.getNumSamples() && lr->raw.getNumSamples() > 0;
            for (int c = 0; same && c < 2; ++c)
                same = std::memcmp (lr->processed.getReadPointer (c), lr->raw.getReadPointer (c),
                                    sizeof (float) * static_cast<size_t> (lr->raw.getNumSamples())) == 0;
            expect (same, "brut : le son rendu est exactement le son importé");
            render::RenderSet rs;
            rs[leadId] = lr;
            rs[rawProj.instruTrack()->id] = render::renderTrack (rawProj, *rawProj.instruTrack(), cache, ctx);
            {
                // Brut = aucun effet sur le son, mais le niveau voix / instru est géré quand même (le niveau n'est pas un effet).
                const auto ms = render::computeAutoMix (rawProj, rs);
                expect (ms.autoMixApplied && std::abs (ms.autoMix.vocalGainDb) <= 18.0f, "voix brute : niveau voix / instru géré ("_u8 + juce::String (ms.autoMix.vocalGainDb, 1) + " dB)");
            }
            rawProj.findTrack (leadId)->raw = false;
            rawProj.findTrack (leadId)->styleId = "rock";
            expect (rawProj.trackStyle (*rawProj.findTrack (leadId)) == style::Style::Rock && rawProj.trackStyle (*rawProj.instruTrack()) == rawProj.style, "style propre à la piste");

            juce::var v = rawProj.toVar();
            project::Project back;
            juce::String loadErr;
            expect (project::Project::fromVar (v, back, loadErr), loadErr);
            expectEquals (back.findTrack (leadId)->styleId, juce::String ("rock"));
            expect (! back.findTrack (leadId)->raw);

            using style::Role;
            expect (style::guessRoleForFile ("C:/Musique/Instru drill 140.mp3", false, false) == Role::Instru);
            expect (style::guessRoleForFile ("voix lead.wav", true, false) == Role::Lead);
            expect (style::guessRoleForFile ("voix lead.wav", true, true) == Role::ManualBack);
            expect (style::guessRoleForFile ("guitare acoustique.flac", true, true) == Role::Instrument);
            expect (style::guessRoleForFile ("adlibs refrain.wav", true, true) == Role::AdLib);
            expect (style::guessRoleForFile ("morceau.mp3", false, false) == Role::Instru, "sans instru : un fichier inconnu devient l'instru");
            expect (style::guessRoleForFile ("morceau.mp3", true, false) == Role::Instrument);

            // Contenu reconnu : une voix seule déposée ne devient pas l'instru.
            const auto keySig = aMinor();
            const auto voiceGuess = analysis::classifyContent (audio::monoToStereo (synthVoice (defaultPhrases (keySig, 100.0), kSr)), kSr);
            expect (voiceGuess.voice, "voix seule reconnue : " + voiceGuess.reason);
            const auto instruGuess = analysis::classifyContent (synthInstru (100.0, keySig, 8, kSr, false), kSr);
            expect (! instruGuess.voice, "instru reconnue comme musique : " + instruGuess.reason);
            expect (style::guessRoleForImport ("enregistrement 3.wav", 1, false, false) == Role::Lead, "voix reconnue -> voix principale");
            expect (style::guessRoleForImport ("enregistrement 3.wav", 1, true, true) == Role::ManualBack, "voix reconnue, lead occupé -> back");
            expect (style::guessRoleForImport ("enregistrement 3.wav", 0, false, false) == Role::Instru, "musique reconnue, pas d'instru -> instru");
            expect (style::guessRoleForImport ("instru.wav", 1, false, false) == Role::Instru, "le nom explicite l'emporte");
        }

        beginTest ("Chaine de plugins : gain, latence compensee, etat, contournement");
        {
            // Faux plugin : gain -6 dB, latence déclarée de 100 échantillons, état = 1 octet (gain actif ou non).
            class GainProc final : public juce::AudioProcessor
            {
            public:
                GainProc() : juce::AudioProcessor (BusesProperties().withInput ("In", juce::AudioChannelSet::stereo()).withOutput ("Out", juce::AudioChannelSet::stereo())) {}
                using juce::AudioProcessor::processBlock;
                const juce::String getName() const override { return "GainTest"; }
                void prepareToPlay (double, int) override { setLatencySamples (100); delay.assign (2, std::vector<float> (100, 0.0f)); }
                void releaseResources() override {}
                void processBlock (juce::AudioBuffer<float>& b, juce::MidiBuffer&) override
                {
                    const float g = active ? 0.5f : 1.0f;
                    for (int c = 0; c < 2; ++c)
                        for (int i = 0; i < b.getNumSamples(); ++i)
                        {
                            const float in = b.getSample (c, i) * g;
                            b.setSample (c, i, delay[static_cast<size_t> (c)][0]);
                            delay[static_cast<size_t> (c)].erase (delay[static_cast<size_t> (c)].begin());
                            delay[static_cast<size_t> (c)].push_back (in);
                        }
                }
                double getTailLengthSeconds() const override { return 0.0; }
                bool acceptsMidi() const override { return false; }
                bool producesMidi() const override { return false; }
                juce::AudioProcessorEditor* createEditor() override { return nullptr; }
                bool hasEditor() const override { return false; }
                int getNumPrograms() override { return 1; }
                int getCurrentProgram() override { return 0; }
                void setCurrentProgram (int) override {}
                const juce::String getProgramName (int) override { return {}; }
                void changeProgramName (int, const juce::String&) override {}
                void getStateInformation (juce::MemoryBlock& d) override { const char v = active ? 1 : 0; d.append (&v, 1); }
                void setStateInformation (const void* d, int n) override { active = n > 0 && static_cast<const char*> (d)[0] == 1; }
                bool active = true;
                std::vector<std::vector<float>> delay;
            };
            plugins::setInstanceFactory ([] (const plugins::PluginSlot& s, double, int, juce::String& whyNot) -> std::unique_ptr<juce::AudioProcessor>
            {
                if (s.identifier != "test:gain") { whyNot = "inconnu"; return nullptr; }
                return std::make_unique<GainProc>();
            });
            Stereo sig (2, 4800);
            for (int i = 0; i < 4800; ++i)
                for (int c = 0; c < 2; ++c)
                    sig.setSample (c, i, 0.5f * std::sin (0.05f * static_cast<float> (i)));
            plugins::PluginSlot slot;
            slot.identifier = "test:gain";
            slot.name = "Gain";
            auto a = sig;
            auto notes = plugins::applyPluginChain (a, kSr, { slot });
            expect (notes.size() == 1 && notes[0].contains ("latence 100"), "latence signalée : " + notes.joinIntoString (" | "));
            float maxErr = 0.0f;
            for (int i = 0; i < 4800 - 100; ++i)
                maxErr = std::max (maxErr, std::abs (a.getSample (0, i) - 0.5f * sig.getSample (0, i)));
            expect (maxErr < 1.0e-5f, "gain -6 dB appliqué et latence compensée (erreur max " + juce::String (maxErr, 6) + ")");
            slot.state.setSize (1);
            static_cast<char*> (slot.state.getData())[0] = 0;   // état : gain inactif
            auto b = sig;
            plugins::applyPluginChain (b, kSr, { slot });
            expect (std::abs (b.getSample (0, 500) - sig.getSample (0, 500)) < 1.0e-5f, "état restauré (gain inactif)"_u8);
            slot.bypass = true;
            auto c = sig;
            notes = plugins::applyPluginChain (c, kSr, { slot });
            expect (notes[0].contains ("contourn") && std::memcmp (c.getReadPointer (0), sig.getReadPointer (0), sizeof (float) * 4800) == 0, "contournement");
            plugins::PluginSlot unknown;
            unknown.identifier = "test:absent";
            unknown.name = "Absent";
            notes = plugins::applyPluginChain (c, kSr, { unknown });
            expect (notes[0].contains ("non charg"), "plugin absent signalé, son intact"_u8);
            const auto back = plugins::PluginSlot::fromVar (slot.toVar());
            expect (back.identifier == slot.identifier && back.bypass && back.state.getSize() == 1, "slot sauvegardé / relu"_u8);
            plugins::setInstanceFactory (nullptr);
        }

        beginTest ("Effets integres (plugins internes)");
        {
            expect (plugins::internalPlugins().size() >= 9 && plugins::isInternal ("interne:eq") && ! plugins::isInternal ("VST3-x"), "liste des effets intégrés"_u8);
            for (const auto& d : plugins::internalPlugins())
            {
                expect (plugins::findInternal (d.identifier) == &d, juce::String ("identifiant retrouvé : "_u8) + d.identifier);
                const auto st = plugins::defaultInternalState (d);
                for (const auto& prm : d.params)
                    expect (std::abs (plugins::internalParam (d, st, prm.id) - prm.def) < 1e-5f, juce::String (d.identifier) + " / " + prm.id + " : valeur par défaut"_u8);
            }
            // Limiteur : +12 dB de gain d'entrée puis plafond -3 dBTP → crête <= -2.9 dB.
            Stereo loud (2, 48000);
            for (int i = 0; i < loud.getNumSamples(); ++i)
            {
                const float v = 0.5f * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
                loud.setSample (0, i, v);
                loud.setSample (1, i, v);
            }
            const auto* limDef = plugins::findInternal ("interne:limiter");
            plugins::PluginSlot lim;
            lim.identifier = "interne:limiter";
            lim.name = "Limiteur";
            lim.state = plugins::withInternalParam (*limDef, plugins::withInternalParam (*limDef, {}, "gain", 12.0f), "ceil", -3.0f);
            expect (std::abs (plugins::internalParam (*limDef, lim.state, "ceil") + 3.0f) < 1e-5f && std::abs (plugins::internalParam (*limDef, lim.state, "gain") - 12.0f) < 1e-5f, "réglages écrits / relus"_u8);
            auto notes = plugins::applyPluginChain (loud, kSr, { lim }, 120.0);
            expect (notes.size() == 1 && notes[0].startsWith ("Limiteur"), "note du limiteur : " + notes.joinIntoString (" | "));
            expect (gainToDb (loud.getMagnitude (0, loud.getNumSamples())) <= -2.9f, "plafond respecté : "_u8 + juce::String (gainToDb (loud.getMagnitude (0, loud.getNumSamples())), 2) + " dB");
            // Compresseur : signal à -6 dB, seuil -30, ratio 8 → réduction nette, note chiffrée.
            Stereo comp (2, 48000);
            for (int i = 0; i < comp.getNumSamples(); ++i)
            {
                const float v = 0.5f * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
                comp.setSample (0, i, v);
                comp.setSample (1, i, v);
            }
            const auto* compDef = plugins::findInternal ("interne:comp");
            plugins::PluginSlot cs;
            cs.identifier = "interne:comp";
            cs.name = "Compresseur";
            cs.state = plugins::withInternalParam (*compDef, plugins::withInternalParam (*compDef, {}, "thr", -30.0f), "ratio", 8.0f);
            const float before = gainToDb (comp.getRMSLevel (0, 24000, 24000));
            notes = plugins::applyPluginChain (comp, kSr, { cs }, 120.0);
            const float after = gainToDb (comp.getRMSLevel (0, 24000, 24000));
            expect (before - after > 6.0f, "compression effective : " + juce::String (before - after, 1) + " dB");
            expect (notes[0].contains ("dB"), "note du compresseur chiffrée"_u8);
            // Égaliseur : coupe-bas 400 Hz sur un 60 Hz → fortement atténué ; largeur 0 → mono.
            Stereo low (2, 48000);
            for (int i = 0; i < low.getNumSamples(); ++i)
            {
                low.setSample (0, i, 0.5f * std::sin (2.0f * juce::MathConstants<float>::pi * 60.0f * static_cast<float> (i) / static_cast<float> (kSr)));
                low.setSample (1, i, -low.getSample (0, i));
            }
            const auto* eqDef = plugins::findInternal ("interne:eq");
            plugins::PluginSlot eq;
            eq.identifier = "interne:eq";
            eq.name = "EQ";
            eq.state = plugins::withInternalParam (*eqDef, {}, "lowCut", 400.0f);
            plugins::PluginSlot width;
            width.identifier = "interne:width";
            width.name = "Largeur";
            width.state = plugins::withInternalParam (*plugins::findInternal ("interne:width"), {}, "width", 0.0f);
            auto widthOnly = low;
            plugins::applyPluginChain (widthOnly, kSr, { width }, 120.0);
            expect (widthOnly.getMagnitude (0, 0, widthOnly.getNumSamples()) < 1e-4f, "largeur 0 sur un signal purement latéral → silence"_u8);
            notes = plugins::applyPluginChain (low, kSr, { eq }, 120.0);
            expect (gainToDb (low.getRMSLevel (0, 24000, 24000)) < -30.0f, "coupe-bas 400 Hz sur 60 Hz : " + juce::String (gainToDb (low.getRMSLevel (0, 24000, 24000)), 1) + " dB");
            // Réverb / délai : la queue ajoute de l'énergie après une impulsion ; état inconnu → effet signalé.
            Stereo imp (2, 48000);
            imp.clear();
            imp.setSample (0, 100, 0.8f);
            imp.setSample (1, 100, 0.8f);
            plugins::PluginSlot rev;
            rev.identifier = "interne:reverb";
            rev.name = "Réverb"_u8;
            rev.state = plugins::defaultInternalState (*plugins::findInternal ("interne:reverb"));
            plugins::applyPluginChain (imp, kSr, { rev }, 120.0);
            expect (imp.getRMSLevel (0, 4800, 24000) > 1e-5f, "réverb : traîne présente"_u8);
            plugins::PluginSlot bad;
            bad.identifier = "interne:inexistant";
            bad.name = "X";
            notes = plugins::applyPluginChain (imp, kSr, { bad }, 120.0);
            expect (notes[0].contains ("inconnu"), "effet intégré inconnu signalé"_u8);
        }

        beginTest ("Niveleur : passages egalises, montees brusques rabaissees, stereo lie");
        {
            // 220 Hz, 3 passages : -30 dB, -14 dB, -22 dB (2 s chacun) → tous ramenés vers -20 dB.
            const size_t n = static_cast<size_t> (kSr) * 6;
            Mono x (n);
            auto secDb = [] (size_t i) { return i < 96000 ? -30.0f : (i < 192000 ? -14.0f : -22.0f); };
            for (size_t i = 0; i < n; ++i)
                x[i] = dbToGain (secDb (i)) * juce::MathConstants<float>::sqrt2 * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
            const float rangeBefore = dsp::shortTermRangeDb (x, kSr);
            expect (rangeBefore >= 12.0f, "étendue avant : "_u8 + juce::String (rangeBefore, 1) + " dB");
            dsp::LevelerSettings ls;
            ls.enabled = true;
            ls.targetDb = -20.0f;
            ls.maxBoostDb = 10.0f;
            ls.maxCutDb = 8.0f;
            const auto rep = dsp::autoLevel (x, kSr, ls);
            expect (rep.applied && rep.rangeAfterDb <= rangeBefore - 5.0f, "étendue après : "_u8 + juce::String (rep.rangeAfterDb, 1) + " dB (avant " + juce::String (rangeBefore, 1) + ")");
            auto rmsDb = [&] (size_t a, size_t b) { return gainToDb (audio::rms (x.data() + a, b - a)); };
            const float s1 = rmsDb (48000, 90000), s2 = rmsDb (144000, 186000), s3 = rmsDb (240000, 282000);
            expect (std::abs (s1 + 20.0f) < 2.5f && std::abs (s2 + 20.0f) < 2.5f && std::abs (s3 + 20.0f) < 2.5f,
                    "passages à "_u8 + juce::String (s1, 1) + " / " + juce::String (s2, 1) + " / " + juce::String (s3, 1) + " dB");

            // Montée brusque : -20 dB partout, +14 dB pendant 1 s à 3 s → détectée, horodatée, rabaissée.
            Mono y (static_cast<size_t> (kSr) * 6);
            for (size_t i = 0; i < y.size(); ++i)
                y[i] = dbToGain (i >= 144000 && i < 192000 ? -6.0f : -20.0f) * juce::MathConstants<float>::sqrt2
                       * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
            const auto surges = dsp::levelSurges (y, kSr);
            expect (surges.size() == 1 && std::abs (surges[0].startSec - 3.0) < 0.5 && surges[0].overDb >= 12.0f,
                    "montée brusque : "_u8 + juce::String (static_cast<int> (surges.size())) + " trouvée(s)"_u8
                        + (surges.empty() ? juce::String() : " " + surges[0].describe()));
            expect (! surges.empty() && surges[0].describe().contains ("0:03"), "horodatage lisible");
            dsp::LevelerSettings sl;
            sl.enabled = true;
            sl.targetDb = -20.0f;
            sl.maxBoostDb = 4.0f;
            sl.maxCutDb = 4.0f;
            sl.surgeCutDb = 12.0f;
            const auto rep2 = dsp::autoLevel (y, kSr, sl);
            const float surgeAfter = gainToDb (audio::rms (y.data() + 160000, 24000));
            expect (rep2.surges.size() == 1 && surgeAfter <= -15.0f, "montée rabaissée à "_u8 + juce::String (surgeAfter, 1) + " dB");

            // Stéréo lié : gauche = 2 × droite, le rapport est conservé.
            Stereo st (2, static_cast<int> (n));
            for (int i = 0; i < st.getNumSamples(); ++i)
            {
                const float v = dbToGain (secDb (static_cast<size_t> (i))) * std::sin (2.0f * juce::MathConstants<float>::pi * 330.0f * static_cast<float> (i) / static_cast<float> (kSr));
                st.setSample (0, i, v);
                st.setSample (1, i, 0.5f * v);
            }
            const auto rep3 = dsp::autoLevelStereo (st, kSr, ls);
            const float l = st.getRMSLevel (0, 144000, 40000), r = st.getRMSLevel (1, 144000, 40000);
            expect (rep3.applied && std::abs (l / std::max (1e-9f, r) - 2.0f) < 0.02f, "image stéréo conservée : rapport "_u8 + juce::String (l / std::max (1e-9f, r), 3));
        }

        beginTest ("Resonances : bande saillante rabaissee, voisinage intact");
        {
            // Bruit filtré (large) + sinus 3 kHz de 2 à 4 s, 15 dB au-dessus de la bande : rabaissé, le 500 Hz ne bouge pas.
            const size_t n = static_cast<size_t> (kSr) * 6;
            Mono x (n);
            juce::Random rng (3);
            float lp = 0.0f;
            const float a = std::exp (-2.0f * juce::MathConstants<float>::pi * 1500.0f / static_cast<float> (kSr));
            for (size_t i = 0; i < n; ++i)
            {
                lp = a * lp + (1.0f - a) * (rng.nextFloat() * 2.0f - 1.0f);
                x[i] = 0.6f * lp;
            }
            const float band3kBefore = bandRmsDb (x, kSr, 2700.0, 3300.0, 96000, 192000);
            for (size_t i = 96000; i < 192000; ++i)
                x[i] += dbToGain (band3kBefore + 15.0f) * juce::MathConstants<float>::sqrt2 * std::sin (2.0f * juce::MathConstants<float>::pi * 3000.0f * static_cast<float> (i) / static_cast<float> (kSr));
            const float peakBand = bandRmsDb (x, kSr, 2700.0, 3300.0, 96000, 192000);
            const float ref500 = bandRmsDb (x, kSr, 400.0, 600.0, 96000, 192000);
            const float excessBefore = dsp::resonanceExcessDb (x, kSr);
            dsp::ResonanceSettings rs;
            rs.enabled = true;
            rs.thresholdDb = 3.0f;
            rs.maxReductionDb = 9.0f;
            rs.protectBelowHz = 300.0f;
            const auto rep = dsp::suppressResonances (x, kSr, rs);
            const float peakAfter = bandRmsDb (x, kSr, 2700.0, 3300.0, 96000, 192000);
            const float after500 = bandRmsDb (x, kSr, 400.0, 600.0, 96000, 192000);
            expect (rep.applied && peakBand - peakAfter >= 3.0f, "3 kHz rabaissé de "_u8 + juce::String (peakBand - peakAfter, 1) + " dB");
            expect (std::abs (ref500 - after500) < 1.0f, "500 Hz intact (" + juce::String (ref500 - after500, 2) + " dB)");
            expect (dsp::resonanceExcessDb (x, kSr) < excessBefore, "mesure de résonance réduite : "_u8 + juce::String (excessBefore, 1) + " -> " + juce::String (dsp::resonanceExcessDb (x, kSr), 1));
            // Un signal harmonique stable (voix tenue) n'est pas une résonance : réduction faible.
            Mono held (static_cast<size_t> (kSr) * 4);
            for (size_t i = 0; i < held.size(); ++i)
            {
                const float t = static_cast<float> (i) / static_cast<float> (kSr);
                held[i] = 0.0f;
                for (int h = 1; h <= 12; ++h)
                    held[i] += 0.3f / static_cast<float> (h) * std::sin (2.0f * juce::MathConstants<float>::pi * 196.0f * h * t);
            }
            const auto repHeld = dsp::suppressResonances (held, kSr, rs);
            expect (repHeld.meanReductionDb < 1.5f, "harmoniques fixes : réduction moyenne "_u8 + juce::String (repHeld.meanReductionDb, 2) + " dB");
        }

        beginTest ("Analyse : montee brusque signalee, correction avec niveleur");
        {
            Mono y (static_cast<size_t> (kSr) * 8);
            for (size_t i = 0; i < y.size(); ++i)
                y[i] = dbToGain (i >= 240000 && i < 288000 ? -4.0f : -20.0f) * juce::MathConstants<float>::sqrt2
                       * std::sin (2.0f * juce::MathConstants<float>::pi * 110.0f * static_cast<float> (i) / static_cast<float> (kSr));
            auto pr = dsp::analyzeTrackProblems (y, kSr, aMinor(), false);
            expect (pr.surges.size() == 1 && pr.found.joinIntoString (" ").contains ("fl"), "montée en flèche constatée : "_u8 + pr.found.joinIntoString (" ; "));
            auto params = dsp::correctionParams (pr, false);
            expect (params.leveler.enabled && params.leveler.surgeCutDb >= 12.0f, "niveleur armé contre la montée ("_u8 + juce::String (params.leveler.surgeCutDb, 0) + " dB)");
            expect (pr.fixes.joinIntoString (" ").contains ("brusques"), "correction annoncée"_u8);
        }

        beginTest ("Reparation stereo d'une instru (niveau regulier, pas de NaN, crete limitee)");
        {
            const int n = static_cast<int> (kSr) * 8;
            Stereo instruSt (2, n);
            juce::Random rng (5);
            float lp = 0.0f;
            const float a = std::exp (-2.0f * juce::MathConstants<float>::pi * 800.0f / static_cast<float> (kSr));
            for (int i = 0; i < n; ++i)
            {
                lp = a * lp + (1.0f - a) * (rng.nextFloat() * 2.0f - 1.0f);
                const float t = static_cast<float> (i) / static_cast<float> (kSr);
                const float g = (i >= 192000 && i < 288000) ? dbToGain (12.0f) : 1.0f;   // 4 à 6 s : +12 dB
                const float v = 0.2f * g * (lp + 0.5f * std::sin (2.0f * juce::MathConstants<float>::pi * 55.0f * t));
                instruSt.setSample (0, i, v);
                instruSt.setSample (1, i, 0.7f * v);
            }
            const float rangeBefore = dsp::shortTermRangeDb (audio::toMono (instruSt), kSr);
            const float surgeBefore = gainToDb (instruSt.getRMSLevel (0, 216000, 48000)) - gainToDb (instruSt.getRMSLevel (0, 48000, 96000));
            auto probs = dsp::analyzeTrackProblems (audio::toMono (instruSt), kSr, aMinor(), false);
            expect (! probs.surges.empty(), "montée de l'instru constatée : "_u8 + probs.found.joinIntoString (" ; "));
            const auto params = dsp::correctionParams (probs, false);
            const auto rep = dsp::repairStereo (instruSt, kSr, params);
            const float rangeAfter = dsp::shortTermRangeDb (audio::toMono (instruSt), kSr);
            const float surgeAfter = gainToDb (instruSt.getRMSLevel (0, 216000, 48000)) - gainToDb (instruSt.getRMSLevel (0, 48000, 96000));
            expect (rangeAfter < rangeBefore && surgeBefore >= 10.0f && surgeAfter <= 5.0f,
                    "montée "_u8 + juce::String (surgeBefore, 1) + " -> " + juce::String (surgeAfter, 1) + " dB, étendue "_u8 + juce::String (rangeBefore, 1) + " -> " + juce::String (rangeAfter, 1) + " dB");
            float peak = 0.0f;
            bool finite = true;
            for (int c = 0; c < 2; ++c)
                for (int i = 0; i < n; ++i)
                {
                    const float v = instruSt.getSample (c, i);
                    finite = finite && std::isfinite (v);
                    peak = std::max (peak, std::abs (v));
                }
            expect (finite && gainToDb (peak) <= -0.9f, "crête "_u8 + juce::String (gainToDb (peak), 2) + " dB, fini");
            expect (rep.summary().isNotEmpty() && ! rep.summary().containsChar (0xC3), "résumé lisible : "_u8 + rep.summary().replace ("\n", " | "));
            const float l = instruSt.getRMSLevel (0, 48000, 48000), r = instruSt.getRMSLevel (1, 48000, 48000);
            expect (std::abs (l / std::max (1e-9f, r) - 1.0f / 0.7f) < 0.08f, "image stéréo conservée ("_u8 + juce::String (l / std::max (1e-9f, r), 2) + ")");
        }

        beginTest ("Curseurs de style : positions reelles, differentes par style");
        {
            const auto rapC = style::makeParams (style::Style::RapConscient, style::Role::Lead, {});
            const auto rnb = style::makeParams (style::Style::RnB, style::Role::Lead, {});
            const auto trap = style::makeParams (style::Style::Trap, style::Role::Lead, {});
            const auto posRapC = style::styleMacros (rapC), posRnb = style::styleMacros (rnb), posTrap = style::styleMacros (trap);
            expect (std::abs (posRapC.autotune - rapC.pitch.amount) < 1e-4f && posRapC.autotune < 0.8f && rapC.pitch.retuneMs >= 60.0f, "rap conscient : nettoyage transparent "_u8 + juce::String (posRapC.autotune, 2));
            expect (posTrap.autotune > posRapC.autotune + 0.2f, "trap : bien plus d'autotune que le rap conscient ("_u8 + juce::String (posTrap.autotune, 2) + ")");
            expect (posRnb.space > posRapC.space, "R&B : plus d'espace que le rap conscient ("_u8 + juce::String (posRnb.space, 2) + " vs " + juce::String (posRapC.space, 2) + ")");
            expect (posRapC.presence > 0.5f, "rap conscient : présence au-dessus du milieu ("_u8 + juce::String (posRapC.presence, 2) + ")");
            // Curseurs laissés aux positions du style = son du style inchangé.
            style::Macros same = posRapC;
            same.custom = true;
            const auto again = style::makeParams (style::Style::RapConscient, style::Role::Lead, same);
            expect (std::abs (again.pitch.amount - rapC.pitch.amount) < 1e-4f && std::abs (again.reverb.send - rapC.reverb.send) < 1e-4f
                        && std::abs (again.eq.presenceDb - rapC.eq.presenceDb) < 1e-3f && std::abs (again.comp.ratio - rapC.comp.ratio) < 1e-3f,
                    "positions du style = réglages du style"_u8);
            // Déplacements : autotune 0 = coupé ; autotune 1 = effet marqué ; espace 0 = sec ; présence + = plus brillant.
            style::Macros off = posRapC;
            off.custom = true;
            off.autotune = 0.0f;
            off.space = 0.0f;
            const auto dry = style::makeParams (style::Style::RapConscient, style::Role::Lead, off);
            expect (! dry.pitch.enabled && dry.reverb.send <= 1e-6f && dry.delay.send <= 1e-6f, "autotune 0 et espace 0"_u8);
            style::Macros hard = posRapC;
            hard.custom = true;
            hard.autotune = 1.0f;
            hard.presence = juce::jlimit (0.0f, 1.0f, posRapC.presence + 0.25f);
            const auto robot = style::makeParams (style::Style::RapConscient, style::Role::Lead, hard);
            expect (robot.pitch.enabled && robot.pitch.amount >= 0.99f && robot.pitch.retuneMs <= 2.5f && robot.eq.presenceDb > rapC.eq.presenceDb + 2.0f, "effet robot + présence"_u8);
            // Anciens projets : macros sans « custom » = positions du style.
            const auto legacy = style::Macros::fromVar (juce::JSON::parse ("{\"autotune\":0.5,\"presence\":0.5}"));
            expect (! legacy.custom && std::abs (style::resolveMacros (legacy, rapC).autotune - posRapC.autotune) < 1e-4f, "ancien projet : positions du style"_u8);
            const auto rt = style::Macros::fromVar (hard.toVar());
            expect (rt.custom && std::abs (rt.autotune - 1.0f) < 1e-4f, "custom sauvegardé / relu"_u8);
        }

        beginTest ("Correction par instrument : basse, batterie, harmonique");
        {
            const auto keySig = aMinor();
            Mono bass (static_cast<size_t> (kSr) * 4);
            for (size_t i = 0; i < bass.size(); ++i)
            {
                const float t = static_cast<float> (i) / static_cast<float> (kSr);
                const float env = 0.5f + 0.5f * std::sin (2.0f * juce::MathConstants<float>::pi * 0.5f * t);
                bass[i] = 0.4f * env * (std::sin (2.0f * juce::MathConstants<float>::pi * 55.0f * t) + 0.3f * std::sin (2.0f * juce::MathConstants<float>::pi * 110.0f * t));
            }
            auto pb = dsp::analyzeTrackProblems (bass, kSr, keySig, false);
            expect (pb.instrumentKind == "basse", "basse reconnue : " + pb.instrumentKind + " (centroïde "_u8 + juce::String (pb.centroidHz, 0) + " Hz)");
            auto bassParams = dsp::correctionParams (pb, false);
            expect (! bassParams.pitch.enabled && bassParams.clean.hpfHz <= 30.0f && bassParams.eq.lowCutHz < 50.0f && bassParams.comp.ratio >= 2.5f, "basse : pas d'autotune, coupe-bas sous 50 Hz, compression 3:1"_u8);
            expect (bassParams.clean.gateRangeDb <= 0.0f, "basse : pas de porte (tenue des notes)"_u8);

            Mono drums (static_cast<size_t> (kSr) * 4, 0.0f);
            juce::Random rng (11);
            const int hit = static_cast<int> (kSr) / 6;   // 6 coups par seconde
            for (size_t i = 0; i < drums.size(); ++i)
            {
                const int k = static_cast<int> (i) % hit;
                if (k < 2400)
                    drums[i] = 0.6f * (rng.nextFloat() * 2.0f - 1.0f) * std::exp (-static_cast<float> (k) / 400.0f);
            }
            auto pd = dsp::analyzeTrackProblems (drums, kSr, keySig, false);
            expect (pd.onsetsPerSec >= 3.0f, "transitoires comptés : " + juce::String (pd.onsetsPerSec, 1) + "/s");
            expect (pd.instrumentKind == "batterie", "batterie reconnue : " + pd.instrumentKind);
            auto drumParams = dsp::correctionParams (pd, false);
            expect (! drumParams.pitch.enabled && drumParams.comp.attackMs >= 15.0f, "batterie : attaque lente pour garder les transitoires"_u8);
            expect (drumParams.clean.denoiseDb <= 6.0f, "batterie : débruitage doux (pas de pompage)"_u8);

            Mono keys (static_cast<size_t> (kSr) * 4);
            for (size_t i = 0; i < keys.size(); ++i)
            {
                const float t = static_cast<float> (i) / static_cast<float> (kSr);
                keys[i] = 0.25f * (std::sin (2.0f * juce::MathConstants<float>::pi * 440.0f * t) + std::sin (2.0f * juce::MathConstants<float>::pi * 554.37f * t)
                                   + std::sin (2.0f * juce::MathConstants<float>::pi * 659.25f * t) + 0.3f * std::sin (2.0f * juce::MathConstants<float>::pi * 1318.5f * t));
            }
            auto pk = dsp::analyzeTrackProblems (keys, kSr, keySig, false);
            expect (pk.instrumentKind == "harmonique", "clavier reconnu : " + pk.instrumentKind);
            auto keyParams = dsp::correctionParams (pk, false);
            expect (! keyParams.pitch.enabled && keyParams.eq.lowCutHz >= 50.0f, "clavier : pas d'autotune, coupe-bas ~60 Hz"_u8);
            expect (dsp::describeProblems (pk).isNotEmpty() && ! dsp::describeProblems (pk).containsChar (0xC3), "rapport lisible par instrument"_u8);
        }

        beginTest ("Porte et debruitage : pas de trou sur une note voisee qui s'eteint");
        {
            // 0,5 s de bruit de fond, puis un 220 Hz riche en harmoniques qui descend de -20 à -46 dB sur 3 s, puis 0,5 s de bruit.
            const size_t n = static_cast<size_t> (kSr) * 4;
            Mono x (n, 0.0f);
            juce::Random rng (21);
            for (auto& v : x)
                v = dbToGain (-70.0f) * (rng.nextFloat() * 2.0f - 1.0f);
            for (size_t i = 24000; i < 168000; ++i)
            {
                const float t = static_cast<float> (i - 24000) / static_cast<float> (kSr);
                const float db = -20.0f - 26.0f * t / 3.0f;
                float v = 0.0f;
                for (int h = 1; h <= 8; ++h)
                    v += std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * h * static_cast<float> (i) / static_cast<float> (kSr)) / static_cast<float> (h);
                x[i] = dbToGain (db) * 0.6f * v;
            }
            const auto va = analysis::analyzeVoice (x, kSr);
            const auto track = analysis::detectPitch (x, kSr);
            auto tailDb = [&] (const Mono& y) { return gainToDb (audio::rms (y.data() + 144000, 20000)); };   // 2,5-2,9 s : queue vers -42 dB
            const float before = tailDb (x);
            dsp::CleanSettings cs;
            cs.hpfHz = 60.0f;
            cs.dePlosive = false;
            cs.breathReductionDb = 0.0f;
            cs.gateRangeDb = 12.0f;
            cs.denoiseDb = 15.0f;
            cs.declip = false;
            auto y = x;
            dsp::clean (y, kSr, cs, track, va);
            const float after = tailDb (y);
            expect (before - after < 3.0f, "queue de note voisée conservée : "_u8 + juce::String (before, 1) + " -> " + juce::String (after, 1) + " dB");
            const float noiseBefore = gainToDb (audio::rms (x.data() + 2000, 20000)), noiseAfter = gainToDb (audio::rms (y.data() + 2000, 20000));
            expect (noiseBefore - noiseAfter > 6.0f, "bruit avant la note réduit : "_u8 + juce::String (noiseBefore, 1) + " -> " + juce::String (noiseAfter, 1) + " dB");
        }

        beginTest ("Orchestre : chaque piste ramenee a sa place par rapport a la voix principale");
        {
            project::Project op;
            op.sampleRate = kSr;
            op.style = style::Style::Rap;
            auto& inst = op.addTrack (style::Role::Instru, "Instru");
            inst.sourceFile = "i.wav";
            auto& ld = op.addTrack (style::Role::Lead, "Voix");
            ld.raw = false;
            const int ldId = ld.id;
            auto& dbl = op.addTrack (style::Role::Double, "Doublage");
            dbl.raw = false;
            dbl.generatedFrom = ldId;
            const int dblId = dbl.id;
            auto& rawT = op.addTrack (style::Role::KeywordBack, "Back brut");
            rawT.raw = true;
            const int rawId = rawT.id;   // brute : jamais touchée
            auto tone = [&] (float db, float hz)
            {
                auto r = std::make_shared<render::TrackRender>();
                r->processed = Stereo (2, static_cast<int> (kSr) * 4);
                for (int i = 0; i < r->processed.getNumSamples(); ++i)
                {
                    const float v = dbToGain (db) * juce::MathConstants<float>::sqrt2 * std::sin (2.0f * juce::MathConstants<float>::pi * hz * static_cast<float> (i) / static_cast<float> (kSr));
                    r->processed.setSample (0, i, v);
                    r->processed.setSample (1, i, v);
                }
                r->raw = r->processed;
                return r;
            };
            render::RenderSet rs;
            rs[inst.id] = tone (-24.0f, 110.0f);
            rs[ldId] = tone (-16.0f, 440.0f);
            rs[dblId] = tone (-14.0f, 660.0f);    // doublage plus fort que la voix : doit redescendre vers -9 LU (borne -8 dB)
            rs[rawId] = tone (-14.0f, 880.0f);
            const auto ms = render::computeAutoMix (op, rs);
            const float g = ms.autoTrackGain (dblId);
            expect (g <= -7.9f && g >= -8.0f, "doublage ramené : gain "_u8 + juce::String (g, 1) + " dB (visé -9 LU, borné à -8 dB)"_u8);
            expect (ms.autoTrackGain (rawId) <= -6.0f && std::abs (ms.autoTrackGain (ldId)) < 1e-6f, "piste brute aussi ramenée à sa place (le niveau n'est pas un effet) ; voix principale intacte"_u8);
            expect (ms.balanceReport.contains ("Doublage") && ! ms.balanceReport.containsChar (0xC3), "rapport orchestre : " + ms.balanceReport);
            expect (ms.mixLufs > -100.0, "sonie du mixage mesurée : "_u8 + juce::String (ms.mixLufs, 1) + " LUFS");
            // Gains orchestre comparés sans bus voix (le bus compresserait autrement sans rattrapage mesuré).
            project::Project noBus = op;
            noBus.vocalBusEnabled = false;
            render::MixState none;
            const auto plain = render::mixdown (noBus, rs, none);
            expect (render::mixdown (noBus, rs, ms).getRMSLevel (0, 48000, 48000) < plain.getRMSLevel (0, 48000, 48000), "le gain orchestre est appliqué au mixage"_u8);
            const auto mixed = render::mixdown (op, rs, ms);   // avec bus voix
            expect (std::abs (render::roleOffsetLu (style::Role::AdLib) + 9.0f) < 1e-6f && std::abs (render::roleOffsetLu (style::Role::Lead)) < 1e-6f, "places par rôle"_u8);

            // Bus voix : la somme des voix est compressée ensemble ; le rattrapage compense la réduction moyenne.
            expect (ms.busGrDb > 0.5f && ms.busGrDb < 6.0f, "bus voix : colle mesurée "_u8 + juce::String (ms.busGrDb, 1) + " dB (attendu 0,5-6)");
            expect (std::abs (ms.busMakeupDb - juce::jlimit (0.0f, 4.0f, ms.busGrDb)) < 1e-6f, "rattrapage = réduction moyenne bornée"_u8);
            const auto withoutBus = render::mixdown (noBus, rs, ms);
            Stereo onlyInstru = makeStereo (withoutBus.getNumSamples());
            render::sumTracks (noBus, rs, ms, false, render::Pick::Others, onlyInstru);
            // L'instru ne passe pas par le bus : identique dans les deux mixages une fois les voix retirées.
            Stereo voicesBus = mixed, voicesPlain = withoutBus;
            for (int c = 0; c < 2; ++c)
            {
                voicesBus.addFrom (c, 0, onlyInstru, c, 0, onlyInstru.getNumSamples(), -1.0f);
                voicesPlain.addFrom (c, 0, onlyInstru, c, 0, onlyInstru.getNumSamples(), -1.0f);
            }
            const float rmsBus = voicesBus.getRMSLevel (0, 48000, 96000), rmsPlain = voicesPlain.getRMSLevel (0, 48000, 96000);
            expect (std::abs (gainToDb (rmsBus) - gainToDb (rmsPlain)) < 1.0f,
                    "bus voix : niveau des voix conservé à 1 dB près (bus "_u8 + juce::String (gainToDb (rmsBus), 1) + " dB, sans "_u8 + juce::String (gainToDb (rmsPlain), 1) + " dB)");
        }

        beginTest ("Bus voix : compresseur colle (reduction sur un ensemble fort, rien sur un ensemble faible, temps reel = rendu)");
        {
            auto tone = [] (float db, int n)
            {
                Stereo s (2, n);
                for (int i = 0; i < n; ++i)
                {
                    const float v = dbToGain (db) * juce::MathConstants<float>::sqrt2 * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
                    s.setSample (0, i, v);
                    s.setSample (1, i, v);
                }
                return s;
            };
            const int n = static_cast<int> (kSr) * 2;
            Stereo loud = tone (-12.0f, n), quiet = tone (-36.0f, n);
            dsp::BusGlue glue;
            glue.prepare (kSr);
            const float grLoud = glue.process (loud);
            glue.prepare (kSr);
            const float grQuiet = glue.process (quiet);
            // -12 dB RMS, seuil -20, 2:1 -> ~4 dB de réduction en régime établi.
            expect (grLoud > 2.5f && grLoud < 5.0f, "ensemble fort : "_u8 + juce::String (grLoud, 1) + " dB de réduction (attendu 2,5-5)");
            expect (grQuiet < 0.05f, "ensemble faible : aucune réduction ("_u8 + juce::String (grQuiet, 2) + " dB)");
            const float tail = loud.getRMSLevel (0, n - 4800, 4800);
            expect (std::abs (gainToDb (tail) + 16.0f) < 0.7f, "régime établi : -12 dB -> "_u8 + juce::String (gainToDb (tail), 1) + " dB (attendu -16)");
            // Blocs de carte son (512) = un seul bloc : même résultat échantillon par échantillon (état conservé).
            Stereo blocks = tone (-12.0f, n), whole = tone (-12.0f, n);
            glue.prepare (kSr);
            for (int off = 0; off < n; off += 512)
            {
                float* ch[2] = { blocks.getWritePointer (0) + off, blocks.getWritePointer (1) + off };
                glue.process (ch, 2, std::min (512, n - off));
            }
            glue.prepare (kSr);
            glue.process (whole);
            float maxDiff = 0.0f;
            for (int i = 0; i < n; ++i)
                maxDiff = std::max (maxDiff, std::abs (blocks.getSample (0, i) - whole.getSample (0, i)));
            expect (maxDiff < 1e-5f, "temps réel par blocs = rendu en un bloc (écart max "_u8 + juce::String (maxDiff, 7) + ")");
            // Même courbe statique que le compresseur de piste : compressLinked avec les mêmes réglages donne le même niveau final.
            Stereo ref = tone (-12.0f, n);
            dsp::compressLinked (ref, kSr, dsp::BusGlue::settings());
            expect (std::abs (gainToDb (ref.getRMSLevel (0, n - 4800, 4800)) - gainToDb (tail)) < 0.3f, "une seule courbe de compression dans le programme"_u8);
        }

        beginTest ("Autotune : gamme adaptee a la voix quand elle chante hors de la gamme du morceau");
        {
            // Voix en La mineur, projet déclaré en Mi majeur (4 notes sur 7 hors gamme) : l'autotune doit suivre la voix.
            const auto keySig = aMinor();
            auto voiceSig = synthVoice (defaultPhrases (keySig, 100.0, 20.0f), kSr);
            dsp::AnalysisContext ctx;
            ctx.key.root = 4;
            ctx.key.minor = false;
            ctx.key.confidence = 0.8f;
            ctx.tempo.bpm = 100.0;
            auto params = style::makeParams (style::Style::Trap, style::Role::Lead, {});
            params.timing.strength = 0.0f;
            const auto res = dsp::processVocal (voiceSig, kSr, params, ctx);
            expect (res.report.outOfScaleFraction >= 0.3f, "notes hors Mi majeur mesurées : "_u8 + juce::String (res.report.outOfScaleFraction, 2));
            expect (res.report.scaleAdapted && ! res.report.chromaticUsed, "gamme adaptée"_u8);
            const auto& k = res.report.adaptedKey;
            expect (k.contains (9) && k.contains (0) && k.contains (5) && ! k.contains (1) && ! k.contains (8), "gamme choisie = notes de La mineur / Do majeur : " + k.toFrench());
            // Même voix avec la bonne tonalité : rien à adapter.
            ctx.key = keySig;
            ctx.key.confidence = 0.8f;
            const auto ok = dsp::processVocal (voiceSig, kSr, params, ctx);
            expect (! ok.report.scaleAdapted && ok.report.outOfScaleFraction < 0.25f, "tonalité juste : pas d'adaptation ("_u8 + juce::String (ok.report.outOfScaleFraction, 2) + ")");
        }

        beginTest ("Debruitage spectral et de-ecretage");
        {
            const auto keySig = aMinor();
            auto clean = synthVoice (defaultPhrases (keySig, 100.0), kSr);
            auto noisy = clean;
            juce::Random rng (7);
            const float noiseAmp = dbToGain (-45.0f);
            for (auto& v : noisy)
                v += noiseAmp * (rng.nextFloat() * 2.0f - 1.0f);
            const auto va = analysis::analyzeVoice (noisy, kSr);
            const auto rep = dsp::spectralDenoise (noisy, kSr, va, 15.0f);
            logMessage ("bruit : " + juce::String (rep.noiseBeforeDb, 1) + " -> " + juce::String (rep.noiseAfterDb, 1) + " dBFS");
            expect (rep.reductionDb() >= 8.0f, "bruit réduit d'au moins 8 dB : "_u8 + juce::String (rep.reductionDb(), 1));
            // La voix est préservée : niveau actif à ±1,5 dB du signal propre.
            const float before = dsp::activeLevelDb (clean, kSr), after = dsp::activeLevelDb (noisy, kSr);
            expect (std::abs (after - before) < 1.5f, "voix préservée : "_u8 + juce::String (before, 1) + " -> " + juce::String (after, 1));

            Mono sine (static_cast<size_t> (kSr));
            for (size_t i = 0; i < sine.size(); ++i)
                sine[i] = 1.6f * std::sin (2.0f * juce::MathConstants<float>::pi * 220.0f * static_cast<float> (i) / static_cast<float> (kSr));
            auto clipped = sine;
            int flat = 0;
            for (auto& v : clipped)
                if (std::abs (v) > 0.99f) { v = v > 0.0f ? 0.99f : -0.99f; ++flat; }
            const int repaired = dsp::declip (clipped, 0.985f);
            expect (repaired > flat / 2, "échantillons reconstruits : "_u8 + juce::String (repaired) + " / " + juce::String (flat));
            float pk = 0.0f;
            for (const float v : clipped)
                pk = std::max (pk, std::abs (v));
            expect (pk > 1.2f, "crête reconstruite au-dessus du niveau écrêté : "_u8 + juce::String (pk, 2));
        }

        beginTest ("Correction automatique : defauts mesures et corriges");
        {
            const auto keySig = aMinor();
            auto voiceSig = synthVoice (defaultPhrases (keySig, 100.0, 35.0f), kSr);   // faux de 35 cents
            for (auto& v : voiceSig)
                v = v * 0.05f + 0.02f;   // trop bas (-26 dB) + composante continue
            auto problems = dsp::analyzeTrackProblems (voiceSig, kSr, keySig, true);
            expect (problems.activeLevelDb < -24.0f, "niveau bas mesuré : " + juce::String (problems.activeLevelDb, 1));
            expect (std::abs (problems.dcOffset - 0.02f) < 0.01f, "composante continue mesurée");
            expect (problems.pitchDeviationCents > 15.0f, "justesse approximative mesurée : " + juce::String (problems.pitchDeviationCents, 1));
            expect (! problems.found.isEmpty(), "défauts listés"_u8);
            const auto params = dsp::correctionParams (problems, true);
            expect (params.pitch.enabled && params.reverb.send <= 0.0f && params.delay.send <= 0.0f && params.sat.mix <= 0.0f,
                    "correction : justesse activée, aucun effet de style"_u8);
            expect (! problems.fixes.isEmpty() && ! dsp::describeProblems (problems).containsChar (0xC3), "rapport lisible");
            dsp::AnalysisContext ctx;
            ctx.key = keySig;
            ctx.tempo.bpm = 100.0;
            const auto res = dsp::processVocal (voiceSig, kSr, params, ctx);
            const auto lvl = dsp::activeLevelDb (audio::toMono (res.audio), kSr);
            expect (lvl > -20.0f && lvl < -8.0f, "niveau corrigé : " + juce::String (lvl, 1) + " dB");
            expect (res.report.meanCorrectionCents > 5.0f, "justesse corrigée : " + juce::String (res.report.meanCorrectionCents, 1) + " c");

            project::Project cp = p;
            cp.findTrack (leadId)->raw = false;
            cp.findTrack (leadId)->styleId = dsp::kCorrectionStyleId;
            expect (cp.findTrack (leadId)->isCorrection() && cp.trackStyle (*cp.findTrack (leadId)) == cp.style);
            project::Project back2;
            juce::String loadErr2;
            expect (project::Project::fromVar (cp.toVar(), back2, loadErr2) && back2.findTrack (leadId)->isCorrection() && back2.loadWarnings.isEmpty(),
                    "pseudo-style correction sauvegardé / rechargé sans avertissement");
        }

        beginTest ("Copie de refrain vers les sections semblables");
        {
            p.sections = { { 0.0, 2.0, "Refrain 1", "refrain", 1, -10.0f }, { 2.0, 4.0, "Couplet 1", "couplet", 0, -12.0f },
                           { 4.0, 6.0, "Refrain 2", "refrain", 1, -10.0f } };
            render::AudioCache cache;
            const int copies = render::copySectionToSimilar (p, leadId, 0, cache, err);
            expectEquals (copies, 1);
        }

        root.deleteRecursively();
    }
};

class AiTests final : public juce::UnitTest
{
public:
    AiTests() : juce::UnitTest ("IA facultative (hors ligne)", "studiovoix") {}

    void runTest() override
    {
        beginTest ("Corps de requete Claude : modele, sortie JSON structuree, repli");
        {
            ai::ClaudeRequest rq;
            rq.system = "sys";
            rq.user = "bonjour";
            auto* schema = new juce::DynamicObject();
            schema->setProperty ("type", "object");
            rq.schema = juce::var (schema);
            juce::var v;
            expect (juce::JSON::parse (ai::buildClaudeBody (rq), v).wasOk());
            expectEquals (v.getProperty ("model", {}).toString(), juce::String ("claude-opus-5-5"));
            expectEquals (v.getProperty ("output_config", {}).getProperty ("format", {}).getProperty ("type", {}).toString(), juce::String ("json_schema"));
            expectEquals (v.getProperty ("output_config", {}).getProperty ("effort", {}).toString(), juce::String ("medium"));
            expectEquals (v.getProperty ("fallbacks", {}).toString(), juce::String ("default"));
            expect (v.getProperty ("thinking", juce::var()).isVoid(), "pas de paramètre thinking (toujours actif sur ce modèle)"_u8);
            expectEquals (v.getProperty ("messages", {})[0].getProperty ("content", {}).toString(), juce::String ("bonjour"));
        }
        beginTest ("Lecture des reponses : succes JSON, refus, erreur 401");
        {
            const auto ok = ai::parseClaudeResponse (200, R"({"model":"claude-opus-5-5","stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"a\":1}"}],"usage":{"input_tokens":10,"output_tokens":5}})", true);
            expect (ok.ok, ok.error);
            expectEquals (static_cast<int> (ok.json.getProperty ("a", 0)), 1);
            expectEquals (ok.outputTokens, 5);
            const auto refusal = ai::parseClaudeResponse (200, R"({"stop_reason":"refusal","content":[]})", false);
            expect (! refusal.ok && refusal.error.isNotEmpty());
            const auto unauth = ai::parseClaudeResponse (401, R"({"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}})", false);
            expect (! unauth.ok);
            expect (unauth.error.contains ("Clé API invalide"_u8), unauth.error);
            const auto cut = ai::parseClaudeResponse (200, R"({"stop_reason":"max_tokens","content":[{"type":"text","text":"{\"a\":"}]})", true);
            expect (! cut.ok && cut.error.contains ("tronquée"_u8), cut.error);
            juce::var v;
            juce::JSON::parse (R"({"detail":{"status":"invalid_api_key","message":"Invalid API key"}})", v);
            expectEquals (ai::musicErrorMessage (v), juce::String ("Invalid API key"));
            juce::JSON::parse (R"({"detail":[{"loc":["body","prompt"],"msg":"field required","type":"missing"}]})", v);
            expectEquals (ai::musicErrorMessage (v), juce::String ("field required"));
            juce::JSON::parse (R"({"detail":"quota exceeded"})", v);
            expectEquals (ai::musicErrorMessage (v), juce::String ("quota exceeded"));
        }
        beginTest ("Sans cle : l'assistant avance retombe sur l'assistant local");
        {
            project::Project p;
            auto& t = p.addTrack (style::Role::Lead, "Voix");
            ai::AiSettings s;   // désactivée
            const auto a = ai::adviseMacros (s, "plus de reverb", p, t.id, {});
            expect (a.ok && ! a.usedAi);
            expect (a.macros.reverbTrim > 0.5f);
            const auto w = ai::helpWrite (s, "un couplet", p);
            expect (! w.ok && w.error.isNotEmpty(), "l'écriture exige l'IA"_u8);
        }
        beginTest ("Diagnostic local et brief d'instru par style");
        {
            project::Project p;
            p.addTrack (style::Role::Lead, "Voix");
            const auto d = ai::diagnoseMixLocal (p, {}, 0.0f);
            expect (d.ok && d.text.contains ("instru"));
            // Accents intacts : un texte UTF-8 lu comme ASCII donnerait "Ã©" au lieu de "é".
            expect (d.text.contains ("Diagnostic (local) :\n•"_u8) && ! d.text.containsChar (0xC3), "accents du diagnostic : " + d.text.substring (0, 80));
            expect (! ai::describeHttpError (401, {}).containsChar (0xC3), "accents des erreurs HTTP");
            const auto b = ai::briefFromStyle (style::Style::Trap);
            expect (b.bpmMin >= 120.0 && b.bpmMax <= 160.0 && b.prompt.isNotEmpty());
        }
        beginTest ("Style sur mesure : aller-retour JSON");
        {
            ai::CustomStyle c;
            c.name = "Drill sombre";
            c.base = style::Style::Drill;
            c.macros.space = 0.8f;
            c.generation.harmonies = 2;
            const auto back = ai::CustomStyle::fromVar (c.toVar());
            expectEquals (back.name, c.name);
            expect (back.base == style::Style::Drill);
            expectWithinAbsoluteError (back.macros.space, 0.8f, 1.0e-4f);
            expectEquals (back.generation.harmonies, 2);
        }
        beginTest ("Bibliotheque de beats : analyse et classement");
        {
            const auto dir = juce::File::getSpecialLocation (juce::File::tempDirectory).getChildFile ("sv_beats_" + juce::String (juce::Time::currentTimeMillis()));
            dir.createDirectory();
            juce::String err;
            expect (audio::writeFile (dir.getChildFile ("trap140.wav"), synthInstru (140.0, aMinor(), 8, kSr, true), kSr, audio::FileFormat::Wav24, err), err);
            expect (audio::writeFile (dir.getChildFile ("rnb75.wav"), synthInstru (75.0, cMajor(), 6, kSr, false), kSr, audio::FileFormat::Wav24, err), err);
            analysis::BeatLibrary lib;
            expectEquals (lib.scan (dir), 2);
            expect (analysis::BeatLibrary::cacheFileFor (dir).existsAsFile(), "cache écrit"_u8);
            analysis::BeatCriteria trap;
            trap.bpmMin = 135;
            trap.bpmMax = 145;
            trap.energy = 0.8f;
            const auto ranked = lib.rank (trap);
            expect (! ranked.empty() && juce::File (ranked.front().second.path).getFileName() == "trap140.wav",
                    "la trap à 140 BPM doit arriver en tête"_u8);
            analysis::BeatLibrary again;
            expectEquals (again.scan (dir), 0);   // tout vient du cache
            dir.deleteRecursively();
        }
    }
};

class UpdateTests final : public juce::UnitTest
{
public:
    UpdateTests() : juce::UnitTest ("Mises a jour (hors ligne)", "studiovoix") {}

    static juce::String releaseJson (const juce::String& assetName, juce::int64 size, const juce::String& digest,
                                     const juce::String& url = "https://api.github.com/repos/jovenger/rebuild_project/releases/assets/42")
    {
        return "{\"tag_name\":\"studiovoix-build57\",\"name\":\"StudioVoix build 57\",\"draft\":false,\"body\":\"Nouveaux styles\\nDétails\","
               "\"assets\":[{\"name\":\"notes.txt\",\"url\":\"" + url + "\",\"size\":10},"
               "{\"name\":\"" + assetName + "\",\"url\":\"" + url + "\",\"browser_download_url\":\"https://github.com/x/y/releases/download/t/a.exe\","
               "\"size\":" + juce::String (size) + (digest.isNotEmpty() ? ",\"digest\":\"" + digest + "\"" : juce::String()) + "}]}";
    }

    void runTest() override
    {
        beginTest ("Numero de build et lecture de la release GitHub");
        {
            expectEquals (update::buildFromName ("StudioVoix-Setup-0.1.0-build57.exe"), 57);
            expectEquals (update::buildFromName ("studiovoix-build123"), 123);
            expectEquals (update::buildFromName ("StudioVoix-Setup-0.1.0.exe"), 0);
            expectEquals (update::buildFromName ("build-x build9"), 9);
            const juce::String sha (juce::String::repeatedString ("ab", 32));
            auto r = update::parseRelease (releaseJson ("StudioVoix-Setup-0.1.0-build57.exe", 5600000, "sha256:" + sha.toUpperCase()));
            expect (r.ok, r.error);
            expectEquals (r.build, 57);
            expectEquals (r.sha256, sha);
            expect (r.size == 5600000);
            expect (r.notes.startsWith ("Nouveaux styles"));
            r = update::parseRelease (releaseJson ("StudioVoix-Setup-0.1.0-build57.exe", 5600000, {}));
            expect (r.ok && r.sha256.isEmpty(), "sans empreinte : accepté, vérification par taille");
            expect (! update::parseRelease (releaseJson ("Autre.zip", 5600000, {})).ok, "pas d'installateur");
            expect (! update::parseRelease (releaseJson ("StudioVoix-Setup-0.1.0-build57.exe", 500, {})).ok, "taille absurde");
            expect (! update::parseRelease (releaseJson ("StudioVoix-Setup-0.1.0-build57.exe", 5600000, {}, "https://exemple.com/a.exe")).ok,
                    "adresse hors API GitHub refusée");
            expect (! update::parseRelease ("[1,2]").ok && ! update::parseRelease ("pas du json").ok, "réponse illisible");
            expect (! update::parseRelease ("{\"draft\":true,\"assets\":[]}").ok, "brouillon ignoré");
            expect (update::describeHttpError (404, false).contains ("jeton"), "404 sans jeton : explique le jeton");
            expect (! update::describeHttpError (401, true).containsChar (0xC3), "accents des messages");
            expect (update::installerArguments (juce::File ("C:/t/log.txt")).contains ("/RELANCER=1"), "relance demandée à l'installateur");
        }
        beginTest ("Verification de l'installateur telecharge");
        {
            const auto f = juce::File::getSpecialLocation (juce::File::tempDirectory).getChildFile ("sv_update_test.exe");
            juce::MemoryBlock data;
            data.append ("MZ", 2);
            for (int i = 0; i < 200000; ++i)
                data.append (&i, 1);
            expect (f.replaceWithData (data.getData(), data.getSize()));
            update::ReleaseInfo rel;
            rel.ok = true;
            rel.size = static_cast<juce::int64> (data.getSize());
            rel.sha256 = juce::SHA256 (data).toHexString().toLowerCase();
            juce::String err;
            expect (update::verifyInstaller (f, rel, err), err);
            auto wrongSha = rel;
            wrongSha.sha256 = juce::String::repeatedString ("0", 64);
            expect (! update::verifyInstaller (f, wrongSha, err) && err.contains ("SHA-256"), "empreinte différente refusée");
            auto wrongSize = rel;
            wrongSize.size += 1;
            expect (! update::verifyInstaller (f, wrongSize, err), "taille différente refusée");
            data[0] = 'X';
            expect (f.replaceWithData (data.getData(), data.getSize()));
            auto noSha = rel;
            noSha.sha256.clear();
            expect (! update::verifyInstaller (f, noSha, err), "fichier qui n'est pas un exécutable refusé");
            f.deleteFile();
        }
    }
};

// Instances statiques : enregistrement automatique auprès de juce::UnitTest.
static LoudnessTests loudnessTests;
static ResampleTests resampleTests;
static PitchTests pitchTests;
static AnalysisTests analysisTests;
static ProcessorTests processorTests;
static MasterTests masterTests;
static AssistantTests assistantTests;
static GeneratorTests generatorTests;
static CompTests compTests;
static ProjectTests projectTests;
static AiTests aiTests;
static UpdateTests updateTests;

int runAllTests()
{
    juce::UnitTestRunner runner;
    runner.setAssertOnFailure (false);
    runner.runTestsInCategory ("studiovoix");
    int failures = 0, passes = 0;
    for (int i = 0; i < runner.getNumResults(); ++i)
    {
        const auto* r = runner.getResult (i);
        failures += r->failures;
        passes += r->passes;
    }
    SV_LOG_INFO ("Tests", juce::String (passes) + " vérifications réussies, "_u8 + juce::String (failures) + " échecs"_u8);
    return failures == 0 ? 0 : 1;
}
} // namespace sv::test
