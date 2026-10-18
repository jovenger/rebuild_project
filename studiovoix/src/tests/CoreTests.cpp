// Tests unitaires du coeur StudioVoix (framework juce::UnitTest).
// Lancement : studiovoix_cli test

#include "TestSignals.h"

#include "core/AudioIO.h"
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
#include "core/dsp/MasterChain.h"
#include "core/dsp/PitchCorrector.h"
#include "core/dsp/PitchShifter.h"
#include "core/dsp/Processors.h"
#include "core/dsp/TimingCorrector.h"
#include "core/dsp/VocalChain.h"
#include "core/gen/BackingGenerator.h"
#include "core/gen/TakeComper.h"
#include "core/project/Project.h"
#include "core/project/Renderer.h"

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
                expect (dsp::describeChain (style::makeParams (style::Style::Rap, style::Role::Lead, {})).contains ("Autotune : léger"_u8),
                        "rap : autotune léger"_u8);
            }
            dsp::AnalysisContext ctx;
            ctx.key = key;
            ctx.tempo.bpm = 100.0;
            expect (! style::makeParams (style::Style::BoomBap, style::Role::Lead, {}).pitch.enabled, "boom bap : pas d'autotune");
            expect (style::makeParams (style::Style::Acoustique, style::Role::Lead, {}).pitch.amount
                    < style::makeParams (style::Style::RapMelodique, style::Role::Lead, {}).pitch.amount,
                    "acoustique : moins d'autotune que rap melodique");
            expect (style::styleFromId ("rap_melodique") == style::Style::RapMelodique && style::styleFromId ("inconnu") == style::Style::Rap,
                    "ids des nouveaux styles");
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
        lead.takes.push_back (tk);
        const int leadId = lead.id;   // la référence 'lead' devient invalide quand d'autres pistes sont ajoutées
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
        expectEquals (static_cast<int> (q.listVersions().size()), 1);

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
