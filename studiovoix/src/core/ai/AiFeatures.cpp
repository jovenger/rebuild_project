#include "AiFeatures.h"

#include "../Log.h"
#include "../Loudness.h"
#include "../analysis/SpectrumAnalyzer.h"
#include "../assistant/CommandParser.h"

namespace sv::ai
{
namespace
{
    constexpr const char* kMod = "AIFeatures";

    // --- Construction de schémas JSON ---------------------------------------------------------
    juce::var prop (const char* type, const juce::String& description = {})
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("type", type);
        if (description.isNotEmpty())
            o->setProperty ("description", description);
        return juce::var (o);
    }

    juce::var object (std::initializer_list<std::pair<const char*, juce::var>> props)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("type", "object");
        auto* p = new juce::DynamicObject();
        juce::Array<juce::var> required;
        for (const auto& [name, schema] : props)
        {
            p->setProperty (name, schema);
            required.add (juce::String (name));
        }
        o->setProperty ("properties", juce::var (p));
        o->setProperty ("required", required);
        o->setProperty ("additionalProperties", false);
        return juce::var (o);
    }

    juce::var enumOf (const juce::StringArray& values, const juce::String& description)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("type", "string");
        juce::Array<juce::var> e;
        for (const auto& v : values)
            e.add (v);
        o->setProperty ("enum", e);
        o->setProperty ("description", description);
        return juce::var (o);
    }

    juce::var arrayOf (const juce::var& items)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("type", "array");
        o->setProperty ("items", items);
        return juce::var (o);
    }

    float num01 (const juce::var& v, const char* key, float def)
    {
        const auto x = v.getProperty (key, def);
        const float f = static_cast<float> (static_cast<double> (x));
        return std::isfinite (f) ? juce::jlimit (0.0f, 1.0f, f) : def;
    }

    juce::StringArray styleIds()
    {
        juce::StringArray ids;
        for (int i = 0; i < static_cast<int> (style::Style::Count); ++i)
            ids.add (style::styleId (static_cast<style::Style> (i)));
        return ids;
    }

    const juce::String kSystemEngineer =
        "Tu es l'ingénieur du son intégré au logiciel StudioVoix (enregistrement de voix sur instru : rap, trap, pop urbaine, "_u8
        "R&B, drill, afro, rock, latino). Le logiciel traite le son lui-même : tu choisis seulement des réglages. Les curseurs vont de 0 à 1, "_u8
        "0,5 = réglage de base du style. autotune : 0 = aucun, 0,5 = style, 1 = effet robot. presence : 0 = voix chaude/sombre, "_u8
        "1 = voix brillante et devant. space : quantité de réverb + délai (0 = sec). energy : compression + saturation. "_u8
        "level : volume de la piste (0,5 = normal, ±12 dB). reverbTrim / delayTrim : ajustement fin de la réverb ou du délai seuls "_u8
        "(0,5 = neutre). timingStrength : recalage rythmique des syllabes (0 = désactivé). Fais des changements mesurés "_u8
        "(en général ±0,05 à ±0,3) sauf demande explicite. Réponds en français, simplement, sans jargon inutile."_u8;
}

juce::String describeProjectForAi (const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb)
{
    juce::String s;
    s << "Style : " << style::styleName (p.style) << "\n"
      << "Tonalité : "_u8 << p.key.toFrench() << ", tempo " << juce::String (p.tempo.bpm, 1) << " BPM\n"
      << "Sections : ";
    for (const auto& sec : p.sections)
        s << sec.label << " (" << juce::String (sec.startSec, 0) << "-" << juce::String (sec.endSec, 0) << " s) ";
    s << "\nMix automatique : " << (p.autoMixEnabled ? "oui" : "non") << ", gain voix " << juce::String (vocalAutoGainDb, 1)
      << " dB, creux instru " << juce::String (p.duckingDb, 1) << " dB\nDestination : " << dsp::targetInfo (p.target).name << "\nPistes :\n";

    const auto bands = analysis::thirdOctaveCenters();
    for (const auto& t : p.tracks)
    {
        s << "- #" << t.id << " " << t.name << " [" << style::roleName (t.role) << "] volume " << juce::String (t.volumeDb, 1)
          << " dB, pan " << juce::String (t.pan, 2) << (t.mute ? ", muet" : "");
        if (t.isVocal())
            s << ", curseurs autotune " << juce::String (t.macros.autotune, 2) << " présence "_u8 << juce::String (t.macros.presence, 2)
              << " espace " << juce::String (t.macros.space, 2) << " énergie "_u8 << juce::String (t.macros.energy, 2)
              << " niveau " << juce::String (t.macros.level, 2);
        auto it = renders.find (t.id);
        if (it != renders.end() && it->second != nullptr && it->second->ok())
        {
            const auto& r = *it->second;
            const auto lufs = loudness::integratedLufs (r.processed, p.sampleRate);
            s << " | sonie " << juce::String (lufs, 1) << " LUFS";
            if (t.isVocal())
            {
                s << ", justesse corrigée en moyenne "_u8 << juce::String (juce::roundToInt (r.report.meanCorrectionCents)) << " cents, compression "
                  << juce::String (r.report.compGrDb, 1) << " dB, de-esser " << juce::String (r.report.deEssGrDb, 1) << " dB";
                // Spectre en 5 zones (graves, bas-médiums, médiums, présence, air).
                const auto spec = analysis::averageSpectrum (audio::toMono (r.processed), p.sampleRate);
                if (spec.valid())
                {
                    auto zone = [&] (float lo, float hi)
                    {
                        double e = 0.0;
                        int c = 0;
                        for (size_t i = 0; i < bands.size(); ++i)
                            if (bands[i] >= lo && bands[i] < hi)
                            {
                                e += std::pow (10.0, spec.levelsDb[i] / 10.0);
                                ++c;
                            }
                        return c > 0 ? 10.0 * std::log10 (e / c) : -120.0;
                    };
                    const double ref = zone (500, 2000);
                    s << ", spectre relatif aux médiums : graves "_u8 << juce::String (zone (60, 250) - ref, 1) << " dB, bas-médiums "_u8
                      << juce::String (zone (250, 500) - ref, 1) << " dB, présence "_u8 << juce::String (zone (2000, 6000) - ref, 1)
                      << " dB, air " << juce::String (zone (6000, 16000) - ref, 1) << " dB";
                }
            }
        }
        s << "\n";
    }
    return s;
}

// =============================================================================================
MacroAdvice adviseMacros (const AiSettings& s, const juce::String& request, const project::Project& p, int trackId,
                          const juce::String& projectSummary)
{
    MacroAdvice a;
    const auto* t = p.findTrack (trackId);
    if (t == nullptr)
    {
        a.error = "Piste introuvable";
        return a;
    }
    a.macros = t->macros;
    a.timingStrength = t->timingStrength;

    if (! s.textAvailable())
    {
        // Cerveau local.
        const auto local = assistant::apply (request, t->macros);
        a.ok = local.understood;
        a.macros = local.macros;
        a.explanation = local.understood ? "Assistant local : " + local.changes.joinIntoString (", ")
                                         : juce::String ("Demande non comprise par l'assistant local (active l'IA connectée pour les demandes libres)."_u8);
        return a;
    }

    ClaudeRequest rq;
    rq.apiKey = s.textKey;
    rq.model = s.model;
    rq.effort = "low";
    rq.maxTokens = 16000;   // réflexion + réponse ; seul l'utilisé est facturé
    rq.system = kSystemEngineer;
    rq.user = "Projet :\n" + projectSummary + "\nPiste concernée : #"_u8 + juce::String (trackId) + " " + t->name + "\nCurseurs actuels : autotune "
            + juce::String (t->macros.autotune, 2) + ", presence " + juce::String (t->macros.presence, 2) + ", space "
            + juce::String (t->macros.space, 2) + ", energy " + juce::String (t->macros.energy, 2) + ", level " + juce::String (t->macros.level, 2)
            + ", reverbTrim " + juce::String (t->macros.reverbTrim, 2) + ", delayTrim " + juce::String (t->macros.delayTrim, 2)
            + ", timingStrength " + juce::String (t->timingStrength, 2) + "\n\nDemande de l'artiste : " + request
            + "\n\nDonne les nouvelles valeurs de tous les curseurs et explique en une ou deux phrases.";
    rq.schema = object ({ { "autotune", prop ("number") }, { "presence", prop ("number") }, { "space", prop ("number") },
                          { "energy", prop ("number") }, { "level", prop ("number") }, { "reverbTrim", prop ("number") },
                          { "delayTrim", prop ("number") }, { "timingStrength", prop ("number") },
                          { "explanation", prop ("string", "Explication courte en français de ce qui change et pourquoi"_u8) } });
    const auto res = askClaude (rq);
    if (! res.ok)
    {
        // Repli automatique sur l'assistant local.
        const auto local = assistant::apply (request, t->macros);
        a.ok = local.understood;
        a.macros = local.macros;
        a.error = res.error;
        a.explanation = "IA indisponible (" + res.error + ")"
                      + (local.understood ? " — assistant local : "_u8 + local.changes.joinIntoString (", ") : juce::String());
        return a;
    }
    const auto& j = res.json;
    a.macros.autotune = num01 (j, "autotune", t->macros.autotune);
    a.macros.presence = num01 (j, "presence", t->macros.presence);
    a.macros.space = num01 (j, "space", t->macros.space);
    a.macros.energy = num01 (j, "energy", t->macros.energy);
    a.macros.level = num01 (j, "level", t->macros.level);
    a.macros.reverbTrim = num01 (j, "reverbTrim", t->macros.reverbTrim);
    a.macros.delayTrim = num01 (j, "delayTrim", t->macros.delayTrim);
    a.timingStrength = num01 (j, "timingStrength", t->timingStrength);
    a.explanation = j.getProperty ("explanation", {}).toString();
    a.ok = true;
    a.usedAi = true;
    return a;
}

// =============================================================================================
MixDiagnosis diagnoseMixLocal (const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb)
{
    MixDiagnosis d;
    juce::StringArray notes;
    const auto* instru = p.instruTrack();
    const int leadId = p.leadTrackId();
    auto get = [&] (int id) -> const render::TrackRender*
    {
        auto it = renders.find (id);
        return it != renders.end() && it->second != nullptr && it->second->ok() ? it->second.get() : nullptr;
    };
    const auto* li = instru != nullptr ? get (instru->id) : nullptr;
    const auto* ll = leadId >= 0 ? get (leadId) : nullptr;
    if (li == nullptr)
        notes.add ("Pas d'instru : importe-la pour un diagnostic complet."_u8);
    if (ll == nullptr)
        notes.add ("La voix principale n'est pas encore traitée."_u8);

    if (li != nullptr && ll != nullptr)
    {
        const double instruLufs = loudness::integratedLufs (li->processed, p.sampleRate);
        const double leadLufs = loudness::integratedLufs (ll->processed, p.sampleRate) + vocalAutoGainDb + p.findTrack (leadId)->volumeDb;
        const double diff = leadLufs - instruLufs;
        notes.add ("Voix principale " + juce::String (diff, 1) + " LU par rapport à l'instru"_u8
                   + (diff < -3.0 ? " : la voix risque d'être noyée (monte le volume ou active le mix auto)."_u8
                      : diff > 5.0 ? " : la voix est très en avant (baisse un peu le volume)."_u8 : " : équilibre correct."_u8));
        if (ll->report.meanCorrectionCents > 40.0f)
            notes.add ("Justesse corrigée de "_u8 + juce::String (juce::roundToInt (ll->report.meanCorrectionCents))
                       + " cents en moyenne : vérifie la tonalité détectée ou fais une nouvelle prise plus juste."_u8);
        if (ll->report.compGrDb > 12.0f)
            notes.add ("Compression forte (" + juce::String (ll->report.compGrDb, 1) + " dB) : baisse le curseur Énergie si la voix sonne écrasée."_u8);
        if (ll->report.clean.noiseFloorDb > -50.0f)
            notes.add ("Bruit de fond élevé ("_u8 + juce::String (ll->report.clean.noiseFloorDb, 1) + " dB) : enregistre dans un endroit plus calme ou rapproche-toi du micro."_u8);

        const auto spec = analysis::averageSpectrum (audio::toMono (ll->processed), p.sampleRate);
        if (spec.valid())
        {
            const auto bands = analysis::thirdOctaveCenters();
            auto zone = [&] (float lo, float hi)
            {
                double e = 0.0;
                int c = 0;
                for (size_t i = 0; i < bands.size(); ++i)
                    if (bands[i] >= lo && bands[i] < hi)
                    {
                        e += std::pow (10.0, spec.levelsDb[i] / 10.0);
                        ++c;
                    }
                return c > 0 ? 10.0 * std::log10 (e / c) : -120.0;
            };
            const double mid = zone (500, 2000);
            if (zone (250, 500) - mid > 4.0)
                notes.add ("Voix chargée en bas-médiums (son « boueux ») : monte un peu la Présence."_u8);
            if (zone (2000, 6000) - mid < -8.0)
                notes.add ("Voix peu présente (manque de 2 à 6 kHz) : monte la Présence pour qu'elle passe devant l'instru."_u8);
            if (zone (6000, 16000) - mid > 0.0)
                notes.add ("Voix très brillante : baisse la Présence si les « s » agressent."_u8);
        }
    }
    int generated = 0;
    for (const auto& t : p.tracks)
        generated += t.isGenerated() ? 1 : 0;
    if (ll != nullptr && generated == 0)
        notes.add ("Aucune piste générée : essaie « Générer backs / harmonies » pour épaissir la voix."_u8);
    if (p.lyrics.trim().isEmpty())
        notes.add ("Astuce : colle tes paroles dans l'onglet Paroles pour le prompteur."_u8);

    d.ok = true;
    d.text = "Diagnostic (local) :\n• "_u8 + notes.joinIntoString ("\n• "_u8);
    return d;
}

MixDiagnosis diagnoseMix (const AiSettings& s, const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb)
{
    auto local = diagnoseMixLocal (p, renders, vocalAutoGainDb);
    if (! s.textAvailable())
        return local;

    ClaudeRequest rq;
    rq.apiKey = s.textKey;
    rq.model = s.model;
    rq.effort = "medium";
    rq.maxTokens = 16000;   // réflexion + réponse ; seul l'utilisé est facturé
    rq.system = kSystemEngineer;
    rq.user = "Voici les mesures du mix (calculées par le logiciel) :\n"_u8 + describeProjectForAi (p, renders, vocalAutoGainDb)
            + "\nPremier diagnostic automatique :\n" + local.text
            + "\n\nFais un diagnostic d'ingénieur du son : ce qui va bien, ce qui pose problème, et 3 à 6 actions concrètes "_u8
              "à faire dans StudioVoix (curseurs, volumes, génération, nouvelle prise). Court et clair."_u8;
    rq.schema = object ({ { "summary", prop ("string", "Diagnostic général en 2-3 phrases"_u8) },
                          { "actions", arrayOf (object ({ { "track", prop ("string", "Piste concernée ou 'mix'"_u8) },
                                                          { "action", prop ("string", "Action concrète dans StudioVoix"_u8) } })) } });
    const auto res = askClaude (rq);
    if (! res.ok)
    {
        local.error = res.error;
        local.text = "IA indisponible (" + res.error + ")\n\n" + local.text;
        return local;
    }
    MixDiagnosis d;
    d.ok = true;
    d.usedAi = true;
    d.text << "Diagnostic (IA) :\n" << res.json.getProperty ("summary", {}).toString() << "\n";
    if (const auto* actions = res.json.getProperty ("actions", {}).getArray())
        for (const auto& a : *actions)
            d.text << "\n• ["_u8 << a.getProperty ("track", {}).toString() << "] " << a.getProperty ("action", {}).toString();
    return d;
}

// =============================================================================================
WritingResult helpWrite (const AiSettings& s, const juce::String& request, const project::Project& p)
{
    WritingResult w;
    if (! s.textAvailable())
    {
        w.error = "L'aide à l'écriture nécessite l'IA connectée (Paramètres > IA connectée)."_u8;
        return w;
    }
    ClaudeRequest rq;
    rq.apiKey = s.textKey;
    rq.model = s.model;
    rq.effort = "medium";
    rq.maxTokens = 16000;   // réflexion + réponse ; seul l'utilisé est facturé
    rq.system = "Tu aides un artiste à écrire ses textes (rap, trap, pop urbaine, R&B, drill, afro, rock, latino), en français sauf demande contraire. "_u8
                "Respecte son univers et son vocabulaire, propose des rimes riches et un flow qui tombe sur les temps. "
                "Une ligne = une mesure, sauf indication contraire. Pas de contenu haineux ni d'incitation à la violence réelle."_u8;
    rq.user = "Style : " + style::styleName (p.style) + ", " + juce::String (p.tempo.bpm, 0) + " BPM, " + juce::String (p.lyricsBarsPerLine)
            + " mesure(s) par ligne.\nParoles actuelles :\n" + (p.lyrics.trim().isNotEmpty() ? p.lyrics : juce::String ("(vide)"))
            + "\n\nDemande : " + request;
    rq.schema = object ({ { "lyrics", prop ("string", "Texte proposé, une ligne par phrase"_u8) },
                          { "notes", prop ("string", "Conseils courts : flow, placement, rimes") } });
    const auto res = askClaude (rq);
    if (! res.ok)
    {
        w.error = res.error;
        return w;
    }
    w.ok = true;
    w.lyrics = res.json.getProperty ("lyrics", {}).toString();
    w.notes = res.json.getProperty ("notes", {}).toString();
    return w;
}

// =============================================================================================
juce::var CustomStyle::toVar() const
{
    auto* o = new juce::DynamicObject();
    o->setProperty ("name", name);
    o->setProperty ("base", style::styleId (base));
    o->setProperty ("macros", macros.toVar());
    auto* g = new juce::DynamicObject();
    g->setProperty ("doubles", generation.doubles);
    g->setProperty ("harmonies", generation.harmonies);
    g->setProperty ("keywordBacks", generation.keywordBacks);
    g->setProperty ("adLibs", generation.adLibs);
    g->setProperty ("ambiance", generation.ambiance);
    o->setProperty ("generation", juce::var (g));
    o->setProperty ("explanation", explanation);
    return juce::var (o);
}

CustomStyle CustomStyle::fromVar (const juce::var& v)
{
    CustomStyle c;
    c.name = v.getProperty ("name", "Style perso").toString();
    c.base = style::styleFromId (v.getProperty ("base", "rap").toString());
    c.macros = style::Macros::fromVar (v.getProperty ("macros", {}));
    c.generation = style::generationDefaults (c.base);
    const auto g = v.getProperty ("generation", {});
    c.generation.doubles = juce::jlimit (0, 3, static_cast<int> (g.getProperty ("doubles", c.generation.doubles)));
    c.generation.harmonies = juce::jlimit (0, 3, static_cast<int> (g.getProperty ("harmonies", c.generation.harmonies)));
    c.generation.keywordBacks = static_cast<bool> (g.getProperty ("keywordBacks", c.generation.keywordBacks));
    c.generation.adLibs = static_cast<bool> (g.getProperty ("adLibs", c.generation.adLibs));
    c.generation.ambiance = static_cast<bool> (g.getProperty ("ambiance", c.generation.ambiance));
    c.explanation = v.getProperty ("explanation", {}).toString();
    c.ok = true;
    return c;
}

CustomStyle createCustomStyle (const AiSettings& s, const juce::String& description)
{
    CustomStyle c;
    if (! s.textAvailable())
    {
        c.error = "La création de style sur mesure nécessite l'IA connectée."_u8;
        return c;
    }
    ClaudeRequest rq;
    rq.apiKey = s.textKey;
    rq.model = s.model;
    rq.effort = "medium";
    rq.maxTokens = 16000;   // réflexion + réponse ; seul l'utilisé est facturé
    rq.system = kSystemEngineer;
    rq.user = "Crée un style de traitement vocal sur mesure à partir de cette description : \""_u8 + description
            + "\".\nChoisis le style de base le plus proche parmi : " + styleIds().joinIntoString (", ")
            + ", puis les curseurs (0 à 1) et les pistes à générer (doublages 0-3, harmonies 0-3, backs mots clés, ad-libs, ambiance)."_u8;
    const auto intProp = prop ("integer");
    rq.schema = object ({ { "name", prop ("string", "Nom court du style") },
                          { "base", enumOf (styleIds(), "Style de base") },
                          { "autotune", prop ("number") }, { "presence", prop ("number") }, { "space", prop ("number") },
                          { "energy", prop ("number") }, { "reverbTrim", prop ("number") }, { "delayTrim", prop ("number") },
                          { "doubles", intProp }, { "harmonies", intProp }, { "keywordBacks", prop ("boolean") },
                          { "adLibs", prop ("boolean") }, { "ambiance", prop ("boolean") },
                          { "explanation", prop ("string", "Une phrase qui décrit le rendu obtenu"_u8) } });
    const auto res = askClaude (rq);
    if (! res.ok)
    {
        c.error = res.error;
        return c;
    }
    const auto& j = res.json;
    c.name = j.getProperty ("name", "Style perso").toString().substring (0, 40);
    c.base = style::styleFromId (j.getProperty ("base", "rap").toString());
    c.macros.autotune = num01 (j, "autotune", 0.5f);
    c.macros.presence = num01 (j, "presence", 0.5f);
    c.macros.space = num01 (j, "space", 0.5f);
    c.macros.energy = num01 (j, "energy", 0.5f);
    c.macros.reverbTrim = num01 (j, "reverbTrim", 0.5f);
    c.macros.delayTrim = num01 (j, "delayTrim", 0.5f);
    c.generation = style::generationDefaults (c.base);
    c.generation.doubles = juce::jlimit (0, 3, static_cast<int> (j.getProperty ("doubles", c.generation.doubles)));
    c.generation.harmonies = juce::jlimit (0, 3, static_cast<int> (j.getProperty ("harmonies", c.generation.harmonies)));
    c.generation.keywordBacks = static_cast<bool> (j.getProperty ("keywordBacks", true));
    c.generation.adLibs = static_cast<bool> (j.getProperty ("adLibs", false));
    c.generation.ambiance = static_cast<bool> (j.getProperty ("ambiance", false));
    c.explanation = j.getProperty ("explanation", {}).toString();
    c.ok = true;
    return c;
}

// =============================================================================================
InstruBrief briefFromStyle (style::Style st)
{
    InstruBrief b;
    b.ok = true;
    switch (st)
    {
        case style::Style::Rap:        b.bpmMin = 85;  b.bpmMax = 100; b.energy = 0.6f; b.prompt = "Boom bap hip-hop instrumental, punchy drums, dusty samples, deep bass"; break;
        case style::Style::Trap:       b.bpmMin = 130; b.bpmMax = 150; b.energy = 0.8f; b.prompt = "Dark trap instrumental, 808 bass, fast hi-hat rolls, atmospheric pads"; break;
        case style::Style::PopUrbaine: b.bpmMin = 95;  b.bpmMax = 120; b.energy = 0.6f; b.minor = false; b.prompt = "Catchy urban pop instrumental, warm synths, modern drums, uplifting chords"; break;
        case style::Style::RnB:        b.bpmMin = 60;  b.bpmMax = 90;  b.energy = 0.35f; b.prompt = "Smooth R&B instrumental, soft keys, warm bass, laid-back groove"; break;
        case style::Style::Drill:      b.bpmMin = 138; b.bpmMax = 146; b.energy = 0.85f; b.prompt = "UK drill instrumental, sliding 808s, syncopated hi-hats, dark piano"; break;
        case style::Style::Rock:       b.bpmMin = 110; b.bpmMax = 140; b.energy = 0.8f; b.prompt = "Energetic rock instrumental, driving live drums, distorted electric guitars, bass guitar"; break;
        case style::Style::Latino:     b.bpmMin = 88;  b.bpmMax = 100; b.energy = 0.7f; b.prompt = "Reggaeton instrumental, dembow rhythm, deep bass, latin percussion, catchy synth lead"; break;
        case style::Style::Afro:
        case style::Style::Count:      b.bpmMin = 100; b.bpmMax = 116; b.energy = 0.65f; b.prompt = "Afrobeats instrumental, log drums, percussive groove, bright guitar and synths"; break;
    }
    b.explanation = "Critères par défaut du style "_u8 + style::styleName (st);
    return b;
}

InstruBrief briefFromLyrics (const AiSettings& s, const juce::String& lyrics, style::Style st)
{
    auto def = briefFromStyle (st);
    if (! s.textAvailable() || lyrics.trim().isEmpty())
        return def;

    ClaudeRequest rq;
    rq.apiKey = s.textKey;
    rq.model = s.model;
    rq.effort = "low";
    rq.maxTokens = 16000;   // réflexion + réponse ; seul l'utilisé est facturé
    rq.system = "Tu es directeur artistique. À partir de paroles, tu décris l'instrumental idéal pour un générateur musical "_u8
                "(description en anglais, sans voix, sans nom d'artiste réel) et des critères de recherche."_u8;
    rq.user = "Style visé : "_u8 + style::styleName (st) + "\nParoles :\n" + lyrics.substring (0, 6000);
    rq.schema = object ({ { "prompt", prop ("string", "Description de l'instru en anglais (instruments, ambiance, rythme), sans voix") },
                          { "bpmMin", prop ("number") }, { "bpmMax", prop ("number") },
                          { "energy", prop ("number", "0 calme à 1 très énergique"_u8) },
                          { "minor", prop ("boolean", "Tonalité mineure ?"_u8) },
                          { "lengthSec", prop ("integer", "Durée conseillée en secondes"_u8) },
                          { "explanation", prop ("string", "Pourquoi cette instru colle au texte (en français)"_u8) } });
    const auto res = askClaude (rq);
    if (! res.ok)
    {
        def.error = res.error;
        def.explanation = "IA indisponible (" + res.error + ") — critères par défaut du style"_u8;
        return def;
    }
    InstruBrief b;
    const auto& j = res.json;
    b.ok = true;
    b.usedAi = true;
    b.prompt = j.getProperty ("prompt", def.prompt).toString().substring (0, 3500);
    b.bpmMin = juce::jlimit (50.0, 200.0, static_cast<double> (j.getProperty ("bpmMin", def.bpmMin)));
    b.bpmMax = juce::jlimit (b.bpmMin, 210.0, static_cast<double> (j.getProperty ("bpmMax", def.bpmMax)));
    b.energy = num01 (j, "energy", def.energy);
    b.minor = static_cast<bool> (j.getProperty ("minor", true));
    b.lengthSec = juce::jlimit (30, 300, static_cast<int> (j.getProperty ("lengthSec", 120)));
    b.explanation = j.getProperty ("explanation", {}).toString();
    return b;
}
} // namespace sv::ai
