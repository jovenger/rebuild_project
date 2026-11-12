// StudioVoix Web : façade C (extern "C") du moteur pour WebAssembly (Emscripten).
// Le navigateur (JavaScript) fournit les échantillons (Float32 à la fréquence de l'AudioContext), le moteur C++ existant
// fait l'analyse de l'instru, la chaîne vocale du style ajustée à la mesure de la prise, et le mix voix / instru.
// Aucun fichier, aucun thread : tout passe par des tampons en mémoire WebAssembly.

#include "core/AudioIO.h"
#include "core/Log.h"
#include "core/Loudness.h"
#include "core/analysis/KeyDetector.h"
#include "core/analysis/StructureDetector.h"
#include "core/analysis/TempoDetector.h"
#include "core/dsp/MasterChain.h"
#include "core/dsp/ProblemAnalyzer.h"
#include "core/dsp/VocalChain.h"
#include "core/mix/AutoMixer.h"
#include "core/style/StyleProfiles.h"
#include "tests/TestSignals.h"

#include <emscripten/emscripten.h>

#include <ctime>
#include <cwchar>
#include <string>
#include <vector>

// La libc d'Emscripten 3.1 n'a pas wcsftime (utilisé par juce::Time::formatted pour l'horodatage des journaux) :
// version simple via strftime, suffisante pour des formats ASCII.
extern "C" size_t wcsftime (wchar_t* out, size_t maxOut, const wchar_t* format, const struct tm* t)
{
    std::string fmt;
    for (const wchar_t* p = format; p != nullptr && *p != 0; ++p)
        fmt.push_back (*p < 128 ? static_cast<char> (*p) : '?');
    std::vector<char> buf (maxOut + 1, 0);
    const size_t n = std::strftime (buf.data(), buf.size(), fmt.c_str(), t);
    if (n == 0 || n >= maxOut)
        return 0;
    for (size_t i = 0; i < n; ++i)
        out[i] = static_cast<wchar_t> (static_cast<unsigned char> (buf[i]));
    out[n] = 0;
    return n;
}

namespace
{
    constexpr const char* kMod = "Web";

    // Contexte musical du morceau (rempli par l'analyse de l'instru, modifiable depuis la page).
    sv::dsp::AnalysisContext context;
    bool contextReady = false;

    // Dernier résultat stéréo (voix traitée ou mix) : la page lit les deux canaux par pointeur.
    sv::Stereo lastOut;
    std::string lastJson;   // dernier rapport JSON (tampon stable tant qu'un autre appel n'a pas lieu)

    const char* reply (const juce::var& v)
    {
        lastJson = juce::JSON::toString (v, true).toStdString();
        return lastJson.c_str();
    }

    juce::var errorJson (const juce::String& message)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("ok", false);
        o->setProperty ("error", message);
        SV_LOG_ERROR (kMod, message);
        return juce::var (o);
    }

    sv::Stereo stereoFrom (const float* left, const float* right, int frames)
    {
        sv::Stereo s (2, frames);
        s.copyFrom (0, 0, left, frames);
        s.copyFrom (1, 0, right != nullptr ? right : left, frames);
        return s;
    }

    void ensureLog()
    {
        static bool done = false;
        if (! done)
        {
            // Pas de fichier dans le navigateur : les journaux partent sur la console (stderr -> console.error / log).
            sv::log::init (juce::File(), sv::log::Level::Info, true);
            done = true;
            SV_LOG_INFO (kMod, "Moteur StudioVoix Web démarré (JUCE "_u8 + juce::String (JUCE_MAJOR_VERSION) + "." + juce::String (JUCE_MINOR_VERSION) + ")");
        }
    }
}

extern "C"
{
EMSCRIPTEN_KEEPALIVE const char* sv_version()
{
    ensureLog();
    return "StudioVoix Web 0.1 (build " SV_BUILD_NUMBER_STR ")";
}

/** Liste des styles, par famille : [{"family":"Rap","styles":[{"id":"trap","name":"Trap"},…]},…] */
EMSCRIPTEN_KEEPALIVE const char* sv_styles()
{
    ensureLog();
    juce::Array<juce::var> groups;
    for (const auto& g : sv::style::styleGroups())
    {
        juce::Array<juce::var> styles;
        for (const auto st : g.styles)
        {
            auto* o = new juce::DynamicObject();
            o->setProperty ("id", sv::style::styleId (st));
            o->setProperty ("name", sv::style::styleName (st));
            styles.add (juce::var (o));
        }
        auto* go = new juce::DynamicObject();
        go->setProperty ("family", juce::String (juce::CharPointer_UTF8 (g.name)));
        go->setProperty ("styles", styles);
        groups.add (juce::var (go));
    }
    return reply (juce::var (groups));
}

/** Analyse de l'instru (tonalité, tempo, structure). Canaux planaires ; right peut être nul (mono). */
EMSCRIPTEN_KEEPALIVE const char* sv_analyze_instru (const float* left, const float* right, int frames, double sampleRate)
{
    ensureLog();
    if (left == nullptr || frames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Instru vide"_u8));
    sv::log::ScopedTimer timer (kMod, "analyse de l'instru"_u8);
    const auto stereo = stereoFrom (left, right, frames);
    const auto mono = sv::audio::toMono (stereo);
    const auto key = sv::analysis::detectKey (mono, sampleRate);
    const auto tempo = sv::analysis::detectTempo (mono, sampleRate);
    const auto sections = sv::analysis::detectStructure (mono, sampleRate, tempo);
    context.key = key.key;
    context.tempo = tempo;
    contextReady = true;

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("key", key.key.toFrench());
    o->setProperty ("root", key.key.root);
    o->setProperty ("minor", key.key.minor);
    o->setProperty ("keyConfidence", key.key.confidence);
    o->setProperty ("bpm", tempo.bpm);
    o->setProperty ("firstBeatSec", tempo.firstBeatSec);
    o->setProperty ("tempoConfidence", tempo.confidence);
    o->setProperty ("seconds", frames / sampleRate);
    o->setProperty ("lufs", sv::loudness::integratedLufs (stereo, sampleRate));
    o->setProperty ("peakDb", sv::gainToDb (stereo.getMagnitude (0, frames)));
    juce::Array<juce::var> secs;
    for (const auto& s : sections)
    {
        auto* so = new juce::DynamicObject();
        so->setProperty ("start", s.startSec);
        so->setProperty ("end", s.endSec);
        so->setProperty ("label", s.label);
        so->setProperty ("kind", s.kind);
        secs.add (juce::var (so));
    }
    o->setProperty ("sections", secs);
    SV_LOG_INFO (kMod, "Instru : "_u8 + key.key.toFrench() + ", " + juce::String (tempo.bpm, 1) + " BPM, " + juce::String ((int) sections.size()) + " sections");
    return reply (juce::var (o));
}

/** Tonalité / tempo fixés depuis la page (si l'utilisateur les change à la main). */
EMSCRIPTEN_KEEPALIVE void sv_set_context (int root, int minor, double bpm, double firstBeatSec, int useScale)
{
    ensureLog();
    context.key.root = juce::jlimit (0, 11, root);
    context.key.minor = minor != 0;
    context.key.confidence = 1.0f;
    context.tempo.bpm = bpm > 20.0 ? bpm : context.tempo.bpm;
    context.tempo.firstBeatSec = firstBeatSec;
    context.useScale = useScale != 0;
    contextReady = true;
    SV_LOG_INFO (kMod, "Contexte fixé : "_u8 + context.key.toFrench() + ", " + juce::String (context.tempo.bpm, 1) + " BPM, gamme "
                       + (context.useScale ? "oui" : "non"));
}

/** Traite une prise mono par le style : mesure de la prise, réglages du style ajustés à la mesure, chaîne complète.
    Résultat stéréo lisible via sv_out_left / sv_out_right / sv_out_frames. JSON : rapport (réglages, mesures, notes). */
EMSCRIPTEN_KEEPALIVE const char* sv_process_voice (const float* mono, int frames, double sampleRate, const char* styleId,
                                                   int cleaning, int useScale)
{
    ensureLog();
    if (mono == nullptr || frames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Prise vide"_u8));
    sv::log::ScopedTimer timer (kMod, "traitement de la voix"_u8);
    const auto style = sv::style::styleFromId (juce::String (styleId != nullptr ? styleId : ""));
    auto params = sv::style::makeParams (style, sv::style::Role::Lead, {}, true);
    params.clean.enabled = cleaning != 0;
    context.useScale = useScale != 0;

    sv::Mono raw (mono, mono + frames);
    const auto problems = sv::dsp::analyzeTrackProblems (raw, sampleRate, context.key, true);
    const auto notes = sv::dsp::fitStyleToMeasurement (params, problems, context.tempo.bpm);
    auto result = sv::dsp::processVocal (raw, sampleRate, params, context, {});
    lastOut = std::move (result.audio);

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("style", sv::style::styleName (style));
    o->setProperty ("frames", lastOut.getNumSamples());
    o->setProperty ("chain", sv::dsp::describeChain (params));
    o->setProperty ("fitNotes", notes.joinIntoString (" ; "));
    o->setProperty ("found", problems.found.joinIntoString (" ; "));
    o->setProperty ("meanCorrectionCents", result.report.meanCorrectionCents);
    o->setProperty ("compGrDb", result.report.compGrDb);
    o->setProperty ("adaptedKey", result.report.scaleAdapted ? result.report.adaptedKey.toFrench() : juce::String());
    o->setProperty ("chromatic", result.report.chromaticUsed);
    o->setProperty ("nearSilent", result.report.nearSilent);
    o->setProperty ("lufs", sv::loudness::integratedLufs (lastOut, sampleRate));
    return reply (juce::var (o));
}

/** Mix : instru (brute, jamais modifiée sauf creux sous la voix si duckingDb > 0) + voix traitée placée à voiceStartSec.
    Équilibre voix / instru par la sonie (mix auto), limiteur de sécurité -1 dBTP. Résultat dans sv_out_*. */
EMSCRIPTEN_KEEPALIVE const char* sv_mix (const float* instruL, const float* instruR, int instruFrames,
                                         const float* voiceL, const float* voiceR, int voiceFrames,
                                         double voiceStartSec, double sampleRate, float duckingDb, float vocalOverInstruLu)
{
    ensureLog();
    if (instruL == nullptr || instruFrames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Instru vide"_u8));
    sv::log::ScopedTimer timer (kMod, "mix"_u8);
    const auto instru = stereoFrom (instruL, instruR, instruFrames);
    const int offset = juce::jmax (0, (int) std::llround (voiceStartSec * sampleRate));
    const int total = juce::jmax (instruFrames, voiceFrames > 0 ? offset + voiceFrames : 0);

    // Voix placée sur la grille du morceau (même longueur que le mix) pour le calcul de sonie et du creux.
    sv::Stereo voice (2, total);
    voice.clear();
    if (voiceL != nullptr && voiceFrames > 0)
    {
        voice.copyFrom (0, offset, voiceL, voiceFrames);
        voice.copyFrom (1, offset, voiceR != nullptr ? voiceR : voiceL, voiceFrames);
    }
    sv::Stereo instruFull (2, total);
    instruFull.clear();
    instruFull.copyFrom (0, 0, instru, 0, 0, instruFrames);
    instruFull.copyFrom (1, 0, instru, 1, 0, instruFrames);

    sv::mix::AutoMixSettings settings;
    settings.duckingDb = juce::jmax (0.0f, duckingDb);
    settings.vocalOverInstruLu = vocalOverInstruLu;
    const auto am = sv::mix::autoMix (instruFull, voice, voice, sampleRate, settings);
    const float vg = sv::dbToGain (am.vocalGainDb);

    lastOut = am.duckedInstru.getNumSamples() == total ? am.duckedInstru : instruFull;
    lastOut.addFrom (0, 0, voice, 0, 0, total, vg);
    lastOut.addFrom (1, 0, voice, 1, 0, total, vg);
    const float limiterGr = sv::dsp::limitStereo (lastOut, sampleRate, -1.0f);

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("frames", total);
    o->setProperty ("vocalGainDb", am.vocalGainDb);
    o->setProperty ("instruLufs", am.instruLufs);
    o->setProperty ("leadLufs", am.leadLufs);
    o->setProperty ("limiterGrDb", limiterGr);
    o->setProperty ("mixLufs", sv::loudness::integratedLufs (lastOut, sampleRate));
    SV_LOG_INFO (kMod, "Mix : gain voix "_u8 + juce::String (am.vocalGainDb, 1) + " dB, limiteur " + juce::String (limiterGr, 1) + " dB");
    return reply (juce::var (o));
}

/** Démo : instru synthétique (La mineur, 100 BPM, `bars` mesures) dans sv_out_*, pour essayer sans fichier. */
EMSCRIPTEN_KEEPALIVE const char* sv_demo_instru (double sampleRate, int bars)
{
    ensureLog();
    sv::MusicalKey key;
    key.root = 9;
    key.minor = true;
    lastOut = sv::test::synthInstru (100.0, key, juce::jlimit (8, 200, bars), sampleRate, true);
    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("frames", lastOut.getNumSamples());
    o->setProperty ("bpm", 100.0);
    return reply (juce::var (o));
}

/** Démo : voix synthétique (phrases en La mineur, légèrement fausse) calée sur l'instru de démo, mono dans le canal gauche. */
EMSCRIPTEN_KEEPALIVE const char* sv_demo_voice (double sampleRate, int bars)
{
    ensureLog();
    sv::MusicalKey key;
    key.root = 9;
    key.minor = true;
    auto phrases = sv::test::defaultPhrases (key, 100.0, 25.0f);
    const auto base = phrases;
    const int repeats = std::max (2, juce::jlimit (8, 200, bars) / 8);
    for (int i = 1; i < repeats; ++i)
        phrases.insert (phrases.end(), base.begin(), base.end());
    const auto voice = sv::test::synthVoice (phrases, sampleRate, 2.4);
    lastOut = sv::audio::monoToStereo (voice);
    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("frames", lastOut.getNumSamples());
    return reply (juce::var (o));
}

EMSCRIPTEN_KEEPALIVE const float* sv_out_left()  { return lastOut.getNumChannels() > 0 ? lastOut.getReadPointer (0) : nullptr; }
EMSCRIPTEN_KEEPALIVE const float* sv_out_right() { return lastOut.getNumChannels() > 1 ? lastOut.getReadPointer (1) : sv_out_left(); }
EMSCRIPTEN_KEEPALIVE int sv_out_frames() { return lastOut.getNumSamples(); }
EMSCRIPTEN_KEEPALIVE void sv_out_release() { lastOut.setSize (0, 0); }

EMSCRIPTEN_KEEPALIVE float* sv_alloc (int floats) { return static_cast<float*> (std::malloc (sizeof (float) * static_cast<size_t> (juce::jmax (1, floats)))); }
EMSCRIPTEN_KEEPALIVE void sv_free (float* p) { std::free (p); }
}
