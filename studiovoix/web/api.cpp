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
#include "core/dsp/BleedRemover.h"
#include "core/dsp/MasterChain.h"
#include "core/dsp/Processors.h"
#include "core/dsp/ProblemAnalyzer.h"
#include "core/dsp/VocalChain.h"
#include "core/mix/AutoMixer.h"
#include "core/style/StyleProfiles.h"
#include "tests/TestSignals.h"

#include <emscripten/emscripten.h>

#include <algorithm>
#include <cmath>
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

    // Équilibre multipiste (sv_balance_*) : instru + pistes voix posées sur la grille du morceau.
    struct BalanceTrack
    {
        int key = 0;
        sv::style::Role role = sv::style::Role::Lead;
        float volumeDb = 0.0f;   // fader de l'utilisateur
        sv::Stereo audio;        // longueur = celle du morceau
    };
    struct BalanceState
    {
        bool open = false;
        double sampleRate = 44100.0;
        sv::style::Style style = sv::style::Style::Rap;
        sv::Stereo instru;
        std::vector<BalanceTrack> tracks;
    } balance;

    /** Place visée d'un rôle par rapport à la voix principale (LU). Même table que sv::render::roleOffsetLu
        (Renderer.cpp, logiciel PC), non compilé dans la version web : à garder identique. */
    float webRoleOffsetLu (sv::style::Role role)
    {
        using sv::style::Role;
        switch (role)
        {
            case Role::Double:      return -9.0f;
            case Role::KeywordBack: return -7.0f;
            case Role::ManualBack:  return -7.0f;   // back enregistré : comme les backs (logiciel PC : 0, géré par le style)
            case Role::Harmony:     return -9.0f;
            case Role::AdLib:       return -9.0f;
            case Role::Ambiance:    return -14.0f;
            case Role::Instrument:  return -4.0f;
            default:                return 0.0f;
        }
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

} // extern "C"

namespace
{
    // ------------------------------------------------------------------------------------------------------------
    // Effets d'une piste, lisibles et réglables depuis la page (tableau des effets). Un objet par effet :
    // { on, valeurs… }. fxToVar : réglages → JSON ; applyFx : surcharges de la page → réglages (valeurs bornées :
    // entrée externe). « on » à faux neutralise l'effet ; « on » à vrai sur un effet que le style laisse éteint lui
    // donne une valeur de départ audible.
    juce::var fxObj (bool on, std::initializer_list<std::pair<const char*, double>> fields)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("on", on);
        for (const auto& f : fields)
            o->setProperty (f.first, f.second);
        return juce::var (o);
    }

    juce::var fxToVar (const sv::style::VocalParams& p)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("clean", fxObj (p.clean.enabled, { { "denoiseDb", p.clean.denoiseDb }, { "gateRangeDb", p.clean.gateRangeDb },
                                                          { "breathReductionDb", p.clean.breathReductionDb }, { "hpfHz", p.clean.hpfHz } }));
        o->setProperty ("leveler", fxObj (p.leveler.enabled, { { "maxBoostDb", p.leveler.maxBoostDb }, { "maxCutDb", p.leveler.maxCutDb } }));
        o->setProperty ("timing", fxObj (p.timing.strength > 0.001f, { { "strength", p.timing.strength } }));
        o->setProperty ("pitch", fxObj (p.pitch.enabled, { { "amount", p.pitch.amount }, { "retuneMs", p.pitch.retuneMs }, { "humanize", p.pitch.humanize } }));
        const bool eqOn = std::abs (p.eq.lowShelfDb) > 0.05f || std::abs (p.eq.mudDb) > 0.05f || std::abs (p.eq.presenceDb) > 0.05f
                          || std::abs (p.eq.airDb) > 0.05f || p.eq.lowCutHz > 25.0f || p.eq.highCutHz > 0.0f;
        o->setProperty ("eq", fxObj (eqOn, { { "lowCutHz", p.eq.lowCutHz }, { "lowShelfDb", p.eq.lowShelfDb }, { "mudDb", p.eq.mudDb },
                                            { "presenceDb", p.eq.presenceDb }, { "airDb", p.eq.airDb } }));
        o->setProperty ("resonance", fxObj (p.resonance.enabled, { { "maxReductionDb", p.resonance.maxReductionDb } }));
        o->setProperty ("comp", fxObj (p.comp.ratio > 1.001f, { { "thresholdDb", p.comp.thresholdDb }, { "ratio", p.comp.ratio },
                                                               { "attackMs", p.comp.attackMs }, { "releaseMs", p.comp.releaseMs }, { "mix", p.comp.mix } }));
        o->setProperty ("comp2", fxObj (p.comp2.ratio > 1.001f, { { "thresholdDb", p.comp2.thresholdDb }, { "ratio", p.comp2.ratio } }));
        o->setProperty ("deEss", fxObj (p.deEss.amount > 0.001f, { { "amount", p.deEss.amount }, { "freqHz", p.deEss.freqHz } }));
        o->setProperty ("sat", fxObj (p.sat.mix > 0.001f, { { "mix", p.sat.mix }, { "driveDb", p.sat.driveDb } }));
        o->setProperty ("reverb", fxObj (p.reverb.send > 0.001f, { { "send", p.reverb.send }, { "roomSize", p.reverb.roomSize },
                                                                  { "damping", p.reverb.damping }, { "preDelayMs", p.reverb.preDelayMs } }));
        o->setProperty ("delay", fxObj (p.delay.send > 0.001f, { { "send", p.delay.send }, { "feedback", p.delay.feedback }, { "noteBeats", p.delay.noteBeats } }));
        o->setProperty ("stereo", fxObj (true, { { "pan", p.pan }, { "width", p.width } }));
        return juce::var (o);
    }

    void applyFx (sv::style::VocalParams& p, const juce::var& fx)
    {
        if (! fx.isObject())
            return;
        auto num = [] (const juce::var& o, const char* k, float& dst, float lo, float hi)
        {
            if (! o.isObject() || ! o.hasProperty (k))
                return;
            const double v = static_cast<double> (o[k]);
            if (std::isfinite (v))
                dst = juce::jlimit (lo, hi, static_cast<float> (v));
        };
        // -1 = pas dit, 0 = éteint, 1 = allumé
        auto on = [] (const juce::var& o) { return o.isObject() && o.hasProperty ("on") ? (static_cast<bool> (o["on"]) ? 1 : 0) : -1; };

        { const auto e = fx["clean"]; num (e, "denoiseDb", p.clean.denoiseDb, 0.0f, 24.0f); num (e, "gateRangeDb", p.clean.gateRangeDb, 0.0f, 24.0f);
          num (e, "breathReductionDb", p.clean.breathReductionDb, 0.0f, 18.0f); num (e, "hpfHz", p.clean.hpfHz, 20.0f, 250.0f);
          if (on (e) >= 0) p.clean.enabled = on (e) == 1; }
        { const auto e = fx["leveler"]; num (e, "maxBoostDb", p.leveler.maxBoostDb, 0.0f, 12.0f); num (e, "maxCutDb", p.leveler.maxCutDb, 0.0f, 12.0f);
          if (on (e) >= 0) p.leveler.enabled = on (e) == 1; }
        { const auto e = fx["timing"]; num (e, "strength", p.timing.strength, 0.0f, 1.0f);
          if (on (e) == 0) p.timing.strength = 0.0f; else if (on (e) == 1 && p.timing.strength < 0.001f) p.timing.strength = 0.5f; }
        { const auto e = fx["pitch"]; num (e, "amount", p.pitch.amount, 0.0f, 1.0f); num (e, "retuneMs", p.pitch.retuneMs, 0.0f, 400.0f);
          num (e, "humanize", p.pitch.humanize, 0.0f, 1.0f);
          if (on (e) >= 0) p.pitch.enabled = on (e) == 1; }
        { const auto e = fx["eq"]; num (e, "lowCutHz", p.eq.lowCutHz, 20.0f, 300.0f); num (e, "lowShelfDb", p.eq.lowShelfDb, -12.0f, 12.0f);
          num (e, "mudDb", p.eq.mudDb, -12.0f, 12.0f); num (e, "presenceDb", p.eq.presenceDb, -12.0f, 12.0f); num (e, "airDb", p.eq.airDb, -12.0f, 12.0f);
          if (on (e) == 0) { p.eq.lowCutHz = 20.0f; p.eq.lowShelfDb = p.eq.mudDb = p.eq.presenceDb = p.eq.airDb = 0.0f; p.eq.highCutHz = 0.0f; p.referenceEq = false; } }
        { const auto e = fx["resonance"]; num (e, "maxReductionDb", p.resonance.maxReductionDb, 0.0f, 12.0f);
          if (on (e) >= 0) p.resonance.enabled = on (e) == 1; }
        { const auto e = fx["comp"]; num (e, "thresholdDb", p.comp.thresholdDb, -50.0f, 0.0f); num (e, "ratio", p.comp.ratio, 1.0f, 20.0f);
          num (e, "attackMs", p.comp.attackMs, 0.1f, 200.0f); num (e, "releaseMs", p.comp.releaseMs, 10.0f, 1000.0f); num (e, "mix", p.comp.mix, 0.0f, 1.0f);
          if (on (e) == 0) p.comp.ratio = 1.0f; else if (on (e) == 1 && p.comp.ratio <= 1.001f) p.comp.ratio = 3.0f; }
        { const auto e = fx["comp2"]; num (e, "thresholdDb", p.comp2.thresholdDb, -50.0f, 0.0f); num (e, "ratio", p.comp2.ratio, 1.0f, 10.0f);
          if (on (e) == 0) p.comp2.ratio = 1.0f; else if (on (e) == 1 && p.comp2.ratio <= 1.001f) p.comp2.ratio = 2.0f; }
        { const auto e = fx["deEss"]; num (e, "amount", p.deEss.amount, 0.0f, 1.0f); num (e, "freqHz", p.deEss.freqHz, 3000.0f, 12000.0f);
          if (on (e) == 0) p.deEss.amount = 0.0f; else if (on (e) == 1 && p.deEss.amount <= 0.001f) p.deEss.amount = 0.5f; }
        { const auto e = fx["sat"]; num (e, "mix", p.sat.mix, 0.0f, 1.0f); num (e, "driveDb", p.sat.driveDb, 0.0f, 24.0f);
          if (on (e) == 0) p.sat.mix = 0.0f; else if (on (e) == 1 && p.sat.mix <= 0.001f) { p.sat.mix = 0.2f; p.sat.driveDb = juce::jmax (p.sat.driveDb, 6.0f); } }
        { const auto e = fx["reverb"]; num (e, "send", p.reverb.send, 0.0f, 1.0f); num (e, "roomSize", p.reverb.roomSize, 0.0f, 1.0f);
          num (e, "damping", p.reverb.damping, 0.0f, 1.0f); num (e, "preDelayMs", p.reverb.preDelayMs, 0.0f, 200.0f);
          if (on (e) == 0) p.reverb.send = 0.0f; else if (on (e) == 1 && p.reverb.send <= 0.001f) p.reverb.send = 0.2f; }
        { const auto e = fx["delay"]; num (e, "send", p.delay.send, 0.0f, 1.0f); num (e, "feedback", p.delay.feedback, 0.0f, 0.9f);
          num (e, "noteBeats", p.delay.noteBeats, 0.125f, 2.0f);
          if (on (e) == 0) p.delay.send = 0.0f; else if (on (e) == 1 && p.delay.send <= 0.001f) p.delay.send = 0.2f; }
        { const auto e = fx["stereo"]; num (e, "pan", p.pan, -1.0f, 1.0f); num (e, "width", p.width, 0.0f, 1.0f); }
    }
} // namespace

extern "C"
{
/** Traite une prise mono par le style : mesure de la prise, réglages du style ajustés à la mesure, chaîne complète.
    Résultat stéréo lisible via sv_out_left / sv_out_right / sv_out_frames. JSON : rapport (réglages, mesures, notes). */
EMSCRIPTEN_KEEPALIVE const char* sv_process_voice (const float* mono, int frames, double sampleRate, const char* styleId,
                                                   const char* roleId, int cleaning, int useScale, double startSec,
                                                   const char* fxJson, int gentle)
{
    ensureLog();
    if (mono == nullptr || frames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Prise vide"_u8));
    sv::log::ScopedTimer timer (kMod, "traitement de la voix"_u8);
    const auto style = sv::style::styleFromId (juce::String (styleId != nullptr ? styleId : ""));
    auto role = sv::style::roleFromId (juce::String (roleId != nullptr ? roleId : "lead"));
    if (role == sv::style::Role::Instru)
        role = sv::style::Role::Lead;   // une piste voix n'est jamais traitée comme l'instru
    auto params = sv::style::makeParams (style, role, {}, true);
    SV_LOG_INFO (kMod, "Piste : style "_u8 + sv::style::styleName (style) + ", type " + sv::style::roleName (role));
    params.clean.enabled = cleaning != 0;
    context.useScale = useScale != 0;

    sv::Mono raw (mono, mono + frames);
    const auto problems = sv::dsp::analyzeTrackProblems (raw, sampleRate, context.key, true);
    const auto notes = sv::dsp::fitStyleToMeasurement (params, problems, context.tempo.bpm);
    // « Voix lissée » (gentle) : un interrupteur qui s'ajoute au style, pas un mode à part. Le style reste entier dans
    // ce qui fait son caractère (autotune, égaliseur, réverb, écho, image stéréo) ; tout ce qui peut rendre la voix
    // rêche quand le niveau monte est ramené dans un régime doux : dynamique (compresseurs, niveleur, résonances,
    // de-esser), nettoyage (débruitage, porte, respirations), saturation, vitesse de l'autotune, recalage rythmique.
    // Chaque effet se règle ensuite à la main dans le tableau des effets (fxJson, appliqué après).
    if (gentle != 0)
    {
        params.timing.strength = 0.0f;
        params.pitch.retuneMs = juce::jmax (params.pitch.retuneMs, 40.0f);
        params.sat.mix = juce::jmin (params.sat.mix, 0.15f);
        params.sat.driveDb = juce::jmin (params.sat.driveDb, 6.0f);
        params.comp.ratio = juce::jmin (params.comp.ratio, 3.0f);
        params.comp.attackMs = juce::jmax (params.comp.attackMs, 8.0f);
        params.comp.releaseMs = juce::jmax (params.comp.releaseMs, 120.0f);
        params.comp2.ratio = juce::jmin (params.comp2.ratio, 1.5f);
        params.leveler.maxBoostDb = juce::jmin (params.leveler.maxBoostDb, 4.0f);
        params.leveler.maxCutDb = juce::jmin (params.leveler.maxCutDb, 4.0f);
        params.resonance.maxReductionDb = juce::jmin (params.resonance.maxReductionDb, 4.0f);
        params.clean.denoiseDb = juce::jmin (params.clean.denoiseDb, 8.0f);
        params.clean.gateRangeDb = juce::jmin (params.clean.gateRangeDb, 8.0f);
        params.clean.breathReductionDb = juce::jmin (params.clean.breathReductionDb, 6.0f);
        params.deEss.amount = juce::jmin (params.deEss.amount, 0.5f);
        SV_LOG_INFO (kMod, "Voix lissée : effets du style gardés (autotune, égaliseur, réverb, écho) ; compression, niveleur, résonances, de-esser, nettoyage, saturation et recalage ramenés dans un régime doux"_u8);
    }
    // Tableau des effets : le pré-réglage (style + mesure, lissé ou non) est rendu tel quel, puis les réglages faits à
    // la main (fxJson, un objet par effet) s'appliquent par-dessus.
    const auto preset = fxToVar (params);
    if (fxJson != nullptr && fxJson[0] != 0)
    {
        juce::var fx;
        const auto parsed = juce::JSON::parse (juce::String (juce::CharPointer_UTF8 (fxJson)), fx);
        if (parsed.failed() || ! fx.isObject())
            SV_LOG_WARN (kMod, "Réglages d'effets illisibles, ignorés : "_u8 + parsed.getErrorMessage());
        else
        {
            applyFx (params, fx);
            SV_LOG_INFO (kMod, "Réglages d'effets faits à la main appliqués : "_u8 + juce::JSON::toString (fx, true));
        }
    }
    // Grille rythmique vue depuis le début de la prise (comme le logiciel PC : Renderer, takeCtx) : une prise posée à
    // startSec sur le morceau voit le premier temps fort startSec plus tôt.
    auto takeCtx = context;
    takeCtx.tempo.firstBeatSec -= juce::jmax (0.0, startSec);
    auto result = sv::dsp::processVocal (raw, sampleRate, params, takeCtx, {});
    lastOut = std::move (result.audio);

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("style", sv::style::styleName (style));
    o->setProperty ("role", sv::style::roleName (role));
    o->setProperty ("roleId", sv::style::roleId (role));
    o->setProperty ("frames", lastOut.getNumSamples());
    o->setProperty ("gentle", gentle != 0);
    o->setProperty ("chain", sv::dsp::describeChain (params));
    o->setProperty ("preset", preset);           // réglages du style ajustés à la prise, avant les réglages à la main
    o->setProperty ("fx", fxToVar (params));     // réglages réellement appliqués
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

/** Prise micro : retire l'instru captée par le micro (si elle y est) et calcule où placer la voix sur l'instru.
    recOffsetSec : temps de l'instru (s) au moment où rec[0] a été écrit (négatif si l'enregistrement a démarré avant
    l'instru, compte à rebours compris). Le décalage aller-retour (sortie + entrée) est mesuré sur la musique captée ;
    sans musique captée (casque), fallbackLatencySec (latences annoncées par le navigateur) est utilisé.
    Voix nettoyée dans sv_out_* (mono dans les deux canaux) ; JSON : startSec = place de rec[0] sur l'instru. */
EMSCRIPTEN_KEEPALIVE const char* sv_clean_take (const float* rec, int recFrames, const float* instruL, const float* instruR, int instruFrames,
                                                double sampleRate, double recOffsetSec, double fallbackLatencySec)
{
    ensureLog();
    if (rec == nullptr || recFrames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Prise vide"_u8));
    sv::log::ScopedTimer timer (kMod, "nettoyage de la prise"_u8);
    sv::Mono take (rec, rec + recFrames);
    sv::dsp::BleedReport rep;
    if (instruL != nullptr && instruFrames > 0)
    {
        const auto instru = sv::audio::toMono (stereoFrom (instruL, instruR, instruFrames));
        const long off = static_cast<long> (std::llround (recOffsetSec * sampleRate));
        sv::Mono ref (take.size(), 0.0f);
        for (size_t i = 0; i < ref.size(); ++i)
        {
            const long j = static_cast<long> (i) + off;
            if (j >= 0 && j < static_cast<long> (instru.size()))
                ref[i] = instru[static_cast<size_t> (j)];
        }
        rep = sv::dsp::removeBleed (take, ref, sampleRate, -0.02, 0.8);
    }
    const double latency = rep.detected ? rep.lagSec : std::max (0.0, fallbackLatencySec);
    const double startSec = recOffsetSec - latency;
    lastOut = sv::audio::monoToStereo (take);

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("frames", lastOut.getNumSamples());
    o->setProperty ("bleedDetected", rep.detected);
    o->setProperty ("latencyMs", latency * 1000.0);
    o->setProperty ("latencyMeasured", rep.detected);
    o->setProperty ("bleedBeforeDb", rep.bleedBeforeDb);
    o->setProperty ("bleedAfterDb", rep.bleedAfterDb);
    o->setProperty ("peakRatio", rep.peakRatio);
    o->setProperty ("startSec", startSec);
    o->setProperty ("describe", rep.describe());
    SV_LOG_INFO (kMod, "Prise : décalage "_u8 + juce::String (latency * 1000.0, 1) + " ms (" + (rep.detected ? "mesuré" : "annoncé par le navigateur")
                       + "), début sur l'instru " + juce::String (startSec, 3) + " s ; " + rep.describe());
    return reply (juce::var (o));
}

/** Équilibre multipiste, en trois temps : begin (instru), add (une fois par piste voix audible), end (calcul).
    Comme le logiciel PC (« orchestre ») : chaque piste hors voix principale est ramenée à sa place par rapport à la
    voix principale selon son type (back -7 LU, ambiance -14 LU…), puis toutes les voix ensemble par rapport à
    l'instru (sonie visée par le style). Le résultat donne un gain par piste (dB, fader compris) : la page l'applique
    à la lecture et à l'export. L'instru n'est jamais modifiée. */
EMSCRIPTEN_KEEPALIVE const char* sv_balance_begin (const float* instruL, const float* instruR, int instruFrames, double sampleRate,
                                                   const char* styleId)
{
    ensureLog();
    balance = {};
    if (sampleRate <= 0.0)
        return reply (errorJson ("Fréquence invalide"_u8));
    balance.open = true;
    balance.sampleRate = sampleRate;
    balance.style = sv::style::styleFromId (juce::String (styleId != nullptr ? styleId : ""));
    if (instruL != nullptr && instruFrames > 0)
        balance.instru = stereoFrom (instruL, instruR, instruFrames);
    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    return reply (juce::var (o));
}

EMSCRIPTEN_KEEPALIVE const char* sv_balance_add (int key, const float* left, const float* right, int frames, double startSec,
                                                 const char* roleId, float volumeDb)
{
    ensureLog();
    if (! balance.open)
        return reply (errorJson ("Équilibre non commencé (sv_balance_begin)"_u8));
    if (left == nullptr || frames <= 0)
        return reply (errorJson ("Piste vide"_u8));
    BalanceTrack t;
    t.key = key;
    t.role = sv::style::roleFromId (juce::String (roleId != nullptr ? roleId : "lead"));
    t.volumeDb = juce::jlimit (-60.0f, 12.0f, volumeDb);
    const int offset = juce::jmax (0, (int) std::llround (startSec * balance.sampleRate));
    t.audio.setSize (2, offset + frames);
    t.audio.clear();
    t.audio.copyFrom (0, offset, left, frames);
    t.audio.copyFrom (1, offset, right != nullptr ? right : left, frames);
    balance.tracks.push_back (std::move (t));
    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("count", (int) balance.tracks.size());
    return reply (juce::var (o));
}

} // extern "C" (le calcul commun n'est pas exporté)

namespace
{
    /** Équilibre commun à sv_balance_end (lecture) et sv_finalmix_end (mixage final) : place de chaque piste selon son
        type par rapport à la voix principale, puis gain de toutes les voix par rapport à l'instru. */
    struct BalanceCalc
    {
        int total = 0;
        std::vector<float> autoGain;
        float vocalGainDb = 0.0f;
        float instruLufs = -120.0f;
        double leadLufs = -120.0;
        int leadCount = 0;
        float vocalOverInstruLu = 0.0f;
        juce::Array<juce::var> items;
        juce::StringArray lines;
        sv::Stereo lead, all, instru;   // sur la grille du morceau ; all = voix avec fader + place
    };

    BalanceCalc runBalance (float vocalOverInstruLuOverride)
    {
        BalanceCalc bc;
        const double sr = balance.sampleRate;
        int total = balance.instru.getNumSamples();
        for (const auto& t : balance.tracks)
            total = juce::jmax (total, t.audio.getNumSamples());
        auto onGrid = [total] (const sv::Stereo& src)
        {
            sv::Stereo d (2, juce::jmax (1, total));
            d.clear();
            const int n = juce::jmin (total, src.getNumSamples());
            if (n > 0)
                for (int c = 0; c < 2; ++c)
                    d.copyFrom (c, 0, src, c, 0, n);
            return d;
        };

        // Sonie de chaque piste, mesurée seulement là où elle chante (porte BS.1770 : les silences ne comptent pas).
        std::vector<double> lufsOf (balance.tracks.size(), -120.0);
        for (size_t i = 0; i < balance.tracks.size(); ++i)
            lufsOf[i] = sv::loudness::integratedLufs (balance.tracks[i].audio, sr);

        // Voix principales entre elles : chacune est ramenée à la même sonie (la médiane des pistes « voix principale »),
        // qu'il y en ait 2 ou 40 — une piste enregistrée plus fort ou plus loin du micro ne sort plus du lot.
        // Une seule voix principale : rien ne change (gain 0).
        std::vector<float> autoGain (balance.tracks.size(), 0.0f);
        std::vector<double> leadVals;
        for (size_t i = 0; i < balance.tracks.size(); ++i)
            if (balance.tracks[i].role == sv::style::Role::Lead && lufsOf[i] > -90.0)
                leadVals.push_back (lufsOf[i] + balance.tracks[i].volumeDb);
        double leadEach = -120.0;   // sonie visée pour chaque piste de voix principale
        if (! leadVals.empty())
        {
            std::sort (leadVals.begin(), leadVals.end());
            const size_t m = leadVals.size() / 2;
            leadEach = leadVals.size() % 2 == 1 ? leadVals[m] : 0.5 * (leadVals[m - 1] + leadVals[m]);
        }
        // Limites de la mise à niveau : remonter une piste remonte aussi son souffle (+12 dB au plus, signalé au-delà) ;
        // baisser ne coûte rien (-24 dB).
        constexpr float kMatchUpDb = 12.0f, kMatchDownDb = -24.0f;
        int leadClamped = 0;
        if (leadVals.size() > 1)
            for (size_t i = 0; i < balance.tracks.size(); ++i)
            {
                const auto& t = balance.tracks[i];
                if (t.role != sv::style::Role::Lead || lufsOf[i] <= -90.0)
                    continue;
                const float want = static_cast<float> (leadEach - (lufsOf[i] + t.volumeDb));
                autoGain[i] = juce::jlimit (kMatchDownDb, kMatchUpDb, want);
                if (want > kMatchUpDb || want < kMatchDownDb)
                    ++leadClamped;
            }

        // Voix principale : somme des pistes « voix principale » mises au même niveau (au moins une ; sinon la première
        // piste sert de repère).
        sv::Stereo lead = onGrid ({});
        int leadCount = 0;
        for (size_t i = 0; i < balance.tracks.size(); ++i)
        {
            const auto& t = balance.tracks[i];
            if (t.role == sv::style::Role::Lead)
            {
                const auto g = onGrid (t.audio);
                for (int c = 0; c < 2; ++c)
                    lead.addFrom (c, 0, g, c, 0, total, sv::dbToGain (t.volumeDb + autoGain[i]));
                ++leadCount;
            }
        }
        if (leadCount == 0 && ! balance.tracks.empty())
            lead = onGrid (balance.tracks.front().audio);
        const double leadLufs = balance.tracks.empty() ? -120.0 : sv::loudness::integratedLufs (lead, sr);

        // 1) Orchestre : gain automatique par piste selon son type (les autres types se placent par rapport à la voix
        //    principale ; deux pistes du même type sortent donc au même niveau).
        juce::Array<juce::var> items;
        juce::StringArray lines;
        if (leadVals.size() > 1)
        {
            float lo = 0.0f, hi = 0.0f;
            for (size_t i = 0; i < balance.tracks.size(); ++i)
                if (balance.tracks[i].role == sv::style::Role::Lead)
                {
                    lo = juce::jmin (lo, autoGain[i]);
                    hi = juce::jmax (hi, autoGain[i]);
                }
            lines.add (juce::String ((int) leadVals.size()) + " voix principales mises au même niveau ("_u8 + juce::String (leadEach, 1)
                       + " LUFS chacune ; corrections de "_u8 + juce::String (lo, 1) + " à "_u8 + juce::String (hi, 1) + " dB"
                       + (leadClamped > 0 ? " ; "_u8 + juce::String (leadClamped) + " piste(s) trop loin, limitée(s) à +12 / -24 dB"_u8 : juce::String()) + ")");
        }
        for (size_t i = 0; i < balance.tracks.size(); ++i)
        {
            const auto& t = balance.tracks[i];
            const double lufs = lufsOf[i];
            const bool isLeadRef = t.role == sv::style::Role::Lead || (leadCount == 0 && i == 0);
            float offset = 0.0f;
            if (! isLeadRef && leadLufs > -90.0 && lufs > -90.0)
            {
                offset = webRoleOffsetLu (t.role);
                const float want = static_cast<float> (leadLufs + offset - (lufs + t.volumeDb));
                autoGain[i] = juce::jlimit (kMatchDownDb, kMatchUpDb, want);
                lines.add (sv::style::roleName (t.role) + " #" + juce::String (t.key) + " : " + juce::String (lufs - leadLufs, 1)
                           + " LU / voix principale, place " + juce::String (offset, 0) + " LU -> " + juce::String (autoGain[i], 1) + " dB"
                           + (want > kMatchUpDb || want < kMatchDownDb ? " (trop loin : limité)"_u8 : juce::String()));
            }
            auto* o = new juce::DynamicObject();
            o->setProperty ("key", t.key);
            o->setProperty ("role", sv::style::roleName (t.role));
            o->setProperty ("lufs", lufs);
            o->setProperty ("placeLu", offset);
            o->setProperty ("autoGainDb", autoGain[i]);
            items.add (juce::var (o));
        }
        if (! lines.isEmpty())
            SV_LOG_INFO (kMod, "Orchestre : "_u8 + lines.joinIntoString (" | "));

        // 2) Toutes les voix ensemble par rapport à l'instru (sonie visée par le style).
        float vocalGainDb = 0.0f;
        float instruLufs = -120.0f;
        if (balance.instru.getNumSamples() > 0 && ! balance.tracks.empty())
        {
            sv::Stereo all = onGrid ({});
            for (size_t i = 0; i < balance.tracks.size(); ++i)
            {
                const auto g = onGrid (balance.tracks[i].audio);
                for (int c = 0; c < 2; ++c)
                    all.addFrom (c, 0, g, c, 0, total, sv::dbToGain (balance.tracks[i].volumeDb + autoGain[i]));
            }
            sv::mix::AutoMixSettings s;
            s.duckingDb = 0.0f;   // instru jamais modifiée
            s.vocalOverInstruLu = std::isfinite (vocalOverInstruLuOverride) && vocalOverInstruLuOverride > -50.0f
                                      ? vocalOverInstruLuOverride : sv::style::masterTone (balance.style).vocalOverInstruLu;
            const auto am = sv::mix::autoMix (onGrid (balance.instru), lead, all, sr, s);
            vocalGainDb = am.vocalGainDb;
            instruLufs = am.instruLufs;
            SV_LOG_INFO (kMod, "Voix / instru : gain voix "_u8 + juce::String (vocalGainDb, 1) + " dB (visée "
                               + juce::String (s.vocalOverInstruLu, 1) + " LU)");
        }
        bc.total = total; bc.autoGain = autoGain; bc.vocalGainDb = vocalGainDb; bc.instruLufs = instruLufs;
        bc.leadLufs = leadLufs; bc.leadCount = leadCount; bc.items = items; bc.lines = lines; bc.lead = lead;
        bc.instru = onGrid (balance.instru);
        bc.all = onGrid ({});
        for (size_t i = 0; i < balance.tracks.size(); ++i)
        {
            const auto g = onGrid (balance.tracks[i].audio);
            for (int c = 0; c < 2; ++c)
                bc.all.addFrom (c, 0, g, c, 0, total, sv::dbToGain (balance.tracks[i].volumeDb + autoGain[i]));
        }
        return bc;
    }
} // namespace

extern "C"
{
EMSCRIPTEN_KEEPALIVE const char* sv_balance_end (float vocalOverInstruLuOverride)
{
    ensureLog();
    if (! balance.open)
        return reply (errorJson ("Équilibre non commencé (sv_balance_begin)"_u8));
    sv::log::ScopedTimer timer (kMod, "équilibre des pistes"_u8);
    auto bc = runBalance (vocalOverInstruLuOverride);
    for (size_t i = 0; i < balance.tracks.size(); ++i)
        bc.items.getReference ((int) i).getDynamicObject()->setProperty ("gainDb", balance.tracks[i].volumeDb + bc.autoGain[i] + bc.vocalGainDb);

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("tracks", bc.items);
    o->setProperty ("vocalGainDb", bc.vocalGainDb);
    o->setProperty ("instruLufs", bc.instruLufs);
    o->setProperty ("leadLufs", bc.leadLufs);
    o->setProperty ("leadCount", bc.leadCount);
    o->setProperty ("report", bc.lines.joinIntoString ("\n"));
    balance = {};
    return reply (juce::var (o));
}

/** Mixage final (« Mixer la chanson ») : à partir des pistes posées par sv_balance_begin / sv_balance_add.
    1) place de chaque piste selon son type (comme sv_balance_end) ; 2) bus voix : toutes les voix passent ensemble
    dans le compresseur « colle » (BusGlue, rattrapage = réduction moyenne, 0 à 4 dB) ; 3) voix / instru par la sonie,
    avec un creux de l'instru sous la voix (duckingDb, vers 2,5 kHz, seulement quand la voix chante) ; 4) mastering
    (compression de cohésion, couleur du style, limiteur, sonie de la plateforme visée). Chanson stéréo dans sv_out_*. */
EMSCRIPTEN_KEEPALIVE const char* sv_finalmix_end (const char* targetId, float duckingDb)
{
    ensureLog();
    if (! balance.open)
        return reply (errorJson ("Mixage non commencé (sv_balance_begin)"_u8));
    if (balance.instru.getNumSamples() == 0 && balance.tracks.empty())
        return reply (errorJson ("Rien à mixer : ni instru ni piste voix"_u8));
    sv::log::ScopedTimer timer (kMod, "mixage final"_u8);
    const double sr = balance.sampleRate;
    auto bc = runBalance (-99.0f);

    // 2) Bus voix : réduction mesurée sur une copie, puis passage réel avec le rattrapage.
    float busGr = 0.0f, makeup = 0.0f, busGrMax = 0.0f;
    if (! balance.tracks.empty())
    {
        sv::Stereo probe;
        probe.makeCopyOf (bc.all);
        sv::dsp::BusGlue g1;
        g1.prepare (sr);
        busGr = g1.process (probe);
        makeup = juce::jlimit (0.0f, 4.0f, busGr);
        sv::dsp::BusGlue g2;
        g2.prepare (sr);
        g2.setMakeupDb (makeup);
        g2.process (bc.all);
        busGrMax = g2.maxReductionDb();
        SV_LOG_INFO (kMod, "Bus voix : réduction moyenne "_u8 + juce::String (busGr, 1) + " dB, max "_u8 + juce::String (busGrMax, 1) + " dB");
    }

    // 3) Voix / instru + creux de l'instru sous la voix.
    sv::mix::AutoMixSettings ms;
    ms.duckingDb = juce::jlimit (0.0f, 6.0f, duckingDb);
    ms.vocalOverInstruLu = sv::style::masterTone (balance.style).vocalOverInstruLu;
    sv::Stereo mix (2, juce::jmax (1, bc.total));
    mix.clear();
    float vocalGainDb = 0.0f;
    if (balance.instru.getNumSamples() > 0 && ! balance.tracks.empty())
    {
        const auto am = sv::mix::autoMix (bc.instru, bc.lead, bc.all, sr, ms);
        vocalGainDb = am.vocalGainDb;
        const auto& ins = am.duckedInstru.getNumSamples() == bc.total ? am.duckedInstru : bc.instru;
        for (int c = 0; c < 2; ++c)
        {
            mix.copyFrom (c, 0, ins, c, 0, bc.total);
            mix.addFrom (c, 0, bc.all, c, 0, bc.total, sv::dbToGain (vocalGainDb));
        }
    }
    else
        for (int c = 0; c < 2; ++c)
        {
            mix.copyFrom (c, 0, bc.instru, c, 0, bc.total);
            mix.addFrom (c, 0, bc.all, c, 0, bc.total);
        }

    // 4) Mastering.
    sv::dsp::MasterSettings mset;
    mset.target = sv::dsp::targetFromId (juce::String (targetId != nullptr ? targetId : "spotify"));
    const auto tone = sv::style::masterTone (balance.style);
    mset.lowShelfDb = tone.lowShelfDb;
    mset.highShelfDb = tone.highShelfDb;
    sv::dsp::MasterReport mr;
    lastOut = sv::dsp::master (mix, sr, mset, mr);

    for (size_t i = 0; i < balance.tracks.size(); ++i)
        bc.items.getReference ((int) i).getDynamicObject()->setProperty ("gainDb", balance.tracks[i].volumeDb + bc.autoGain[i] + vocalGainDb);
    const auto ti = sv::dsp::targetInfo (mset.target);
    SV_LOG_INFO (kMod, "Mixage final : voix "_u8 + juce::String (vocalGainDb, 1) + " dB, bus voix -" + juce::String (busGr, 1)
                       + " dB (rattrapage +" + juce::String (makeup, 1) + "), creux instru " + juce::String (ms.duckingDb, 1)
                       + " dB, mastering " + ti.name + " : " + juce::String (mr.inputLufs, 1) + " -> " + juce::String (mr.outputLufs, 1)
                       + " LUFS, crête " + juce::String (mr.truePeakDb, 1) + " dBTP, limiteur " + juce::String (mr.limiterMaxGrDb, 1) + " dB");

    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("tracks", bc.items);
    o->setProperty ("vocalGainDb", vocalGainDb);
    o->setProperty ("busGrDb", busGr);
    o->setProperty ("busGrMaxDb", busGrMax);
    o->setProperty ("busMakeupDb", makeup);
    o->setProperty ("duckingDb", ms.duckingDb);
    o->setProperty ("instruLufs", bc.instruLufs);
    o->setProperty ("leadLufs", bc.leadLufs);
    o->setProperty ("target", ti.name);
    o->setProperty ("targetLufs", ti.lufs);
    o->setProperty ("inputLufs", mr.inputLufs);
    o->setProperty ("outputLufs", mr.outputLufs);
    o->setProperty ("truePeakDb", mr.truePeakDb);
    o->setProperty ("glueGrDb", mr.glueGrDb);
    o->setProperty ("limiterGrDb", mr.limiterMaxGrDb);
    o->setProperty ("lowShelfDb", tone.lowShelfDb);
    o->setProperty ("highShelfDb", tone.highShelfDb);
    o->setProperty ("style", sv::style::styleName (balance.style));
    o->setProperty ("report", bc.lines.joinIntoString ("\n"));
    o->setProperty ("frames", lastOut.getNumSamples());
    balance = {};
    return reply (juce::var (o));
}

/** Limiteur de sécurité (export) : copie de (left, right) limitée à ceilingDb dans sv_out_* ; JSON : réduction, sonie. */
EMSCRIPTEN_KEEPALIVE const char* sv_limit (const float* left, const float* right, int frames, double sampleRate, float ceilingDb)
{
    ensureLog();
    if (left == nullptr || frames <= 0 || sampleRate <= 0.0)
        return reply (errorJson ("Mix vide"_u8));
    lastOut = stereoFrom (left, right, frames);
    const float gr = sv::dsp::limitStereo (lastOut, sampleRate, ceilingDb);
    auto* o = new juce::DynamicObject();
    o->setProperty ("ok", true);
    o->setProperty ("limiterGrDb", gr);
    o->setProperty ("lufs", sv::loudness::integratedLufs (lastOut, sampleRate));
    SV_LOG_INFO (kMod, "Export : limiteur "_u8 + juce::String (gr, 1) + " dB");
    return reply (juce::var (o));
}

/** Types de piste voix proposés dans la page : [{"id":"lead","name":"Voix principale"},…] */
EMSCRIPTEN_KEEPALIVE const char* sv_roles()
{
    ensureLog();
    juce::Array<juce::var> list;
    for (const auto r : sv::style::userTrackRoles())
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("id", sv::style::roleId (r));
        o->setProperty ("name", sv::style::roleName (r));
        o->setProperty ("label", sv::style::userTrackLabel (r));
        o->setProperty ("placeLu", webRoleOffsetLu (r));
        list.add (juce::var (o));
    }
    return reply (juce::var (list));
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
