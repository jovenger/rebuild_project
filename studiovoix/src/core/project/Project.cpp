#include "Project.h"

#include "../Log.h"

#include <set>

namespace sv::project
{
namespace
{
    constexpr const char* kMod = "Project";
    constexpr int kFormatVersion = 1;

    juce::var num (double d) { return juce::var (d); }

    double getD (const juce::var& v, const char* key, double def)
    {
        const auto x = v.getProperty (key, def);
        if (x.isString())
        {
            // Projet modifié à la main : "2" accepté comme 2.
            const auto s = x.toString().trim();
            if (s.isEmpty() || ! s.containsOnly ("0123456789.-+eE"))
                return def;
            const double d = s.getDoubleValue();
            return std::isfinite (d) ? d : def;
        }
        if (! (x.isDouble() || x.isInt() || x.isInt64() || x.isBool()))
            return def;
        const double d = static_cast<double> (x);
        return std::isfinite (d) ? d : def;
    }

    int getI (const juce::var& v, const char* key, int def) { return static_cast<int> (getD (v, key, def)); }
    bool getB (const juce::var& v, const char* key, bool def) { return std::abs (getD (v, key, def ? 1.0 : 0.0)) > 0.5; }
    juce::String getS (const juce::var& v, const char* key, const juce::String& def = {})
    {
        const auto x = v.getProperty (key, def);
        return x.isString() ? x.toString() : def;
    }

    bool writeJson (const juce::File& file, const juce::var& v, juce::String& error)
    {
        const auto dir = file.getParentDirectory().createDirectory();
        if (dir.failed())
        {
            error = "Dossier impossible à créer : "_u8 + dir.getErrorMessage();
            return false;
        }
        // Écriture atomique : fichier temporaire vérifié (disque plein, erreur d'écriture), puis remplacement.
        juce::TemporaryFile tmp (file);
        const auto text = juce::JSON::toString (v, false);
        {
            juce::FileOutputStream out (tmp.getFile());
            if (out.failedToOpen())
            {
                error = "Écriture impossible : "_u8 + tmp.getFile().getFullPathName() + " (" + out.getStatus().getErrorMessage() + ")";
                return false;
            }
            const bool written = out.writeText (text, false, false, nullptr);
            out.flush();
            if (! written || out.getStatus().failed())
            {
                error = "Écriture incomplète (disque plein ?) : "_u8 + tmp.getFile().getFullPathName() + " " + out.getStatus().getErrorMessage();
                return false;
            }
        }
        const auto expected = static_cast<juce::int64> (text.getNumBytesAsUTF8());
        if (tmp.getFile().getSize() != expected)
        {
            error = "Fichier écrit tronqué ("_u8 + juce::String (tmp.getFile().getSize()) + "/" + juce::String (expected) + " octets) : "
                    + file.getFullPathName();
            return false;
        }
        if (! tmp.overwriteTargetFileWithTemporary())
        {
            error = "Remplacement impossible : " + file.getFullPathName();
            return false;
        }
        return true;
    }
}

Track* Project::findTrack (int id)
{
    for (auto& t : tracks)
        if (t.id == id)
            return &t;
    return nullptr;
}

const Track* Project::findTrack (int id) const
{
    for (const auto& t : tracks)
        if (t.id == id)
            return &t;
    return nullptr;
}

Track& Project::addTrack (style::Role role, const juce::String& trackName)
{
    Track t;
    t.id = nextTrackId++;
    t.role = role;
    t.name = trackName;
    tracks.push_back (t);
    SV_LOG_INFO (kMod, "Piste ajoutée #"_u8 + juce::String (t.id) + " " + trackName + " (" + style::roleName (role) + ")");
    return tracks.back();
}

bool Project::removeTrack (int id)
{
    const auto before = tracks.size();
    tracks.erase (std::remove_if (tracks.begin(), tracks.end(), [id] (const Track& t) { return t.id == id; }), tracks.end());
    if (tracks.size() != before)
    {
        if (armedTrackId == id)
            armedTrackId = -1;
        SV_LOG_INFO (kMod, "Piste supprimée #"_u8 + juce::String (id));
        return true;
    }
    return false;
}

int Project::leadTrackId() const
{
    for (const auto& t : tracks)
        if (t.role == style::Role::Lead)
            return t.id;
    return -1;
}

const Track* Project::instruTrack() const
{
    for (const auto& t : tracks)
        if (t.role == style::Role::Instru)
            return &t;
    return nullptr;
}

double Project::lengthSec() const
{
    long end = 0;
    for (const auto& t : tracks)
        for (const auto& tk : t.takes)
            end = std::max (end, tk.regionEnd);
    double sec = static_cast<double> (end) / sampleRate;
    if (! sections.empty())
        sec = std::max (sec, sections.back().endSec);
    return sec;
}

juce::var Project::toVar() const
{
    auto* root = new juce::DynamicObject();
    root->setProperty ("format", "studiovoix-project");
    root->setProperty ("version", kFormatVersion);
    root->setProperty ("name", name);
    root->setProperty ("sampleRate", sampleRate);
    root->setProperty ("style", style::styleId (style));

    auto* k = new juce::DynamicObject();
    k->setProperty ("root", key.root);
    k->setProperty ("minor", key.minor);
    k->setProperty ("confidence", key.confidence);
    k->setProperty ("manual", keyManual);
    root->setProperty ("key", juce::var (k));

    auto* tp = new juce::DynamicObject();
    tp->setProperty ("bpm", tempo.bpm);
    tp->setProperty ("firstBeatSec", tempo.firstBeatSec);
    tp->setProperty ("beatsPerBar", tempo.beatsPerBar);
    tp->setProperty ("confidence", tempo.confidence);
    tp->setProperty ("manual", tempoManual);
    root->setProperty ("tempo", juce::var (tp));

    juce::Array<juce::var> secs;
    for (const auto& s : sections)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("start", s.startSec);
        o->setProperty ("end", s.endSec);
        o->setProperty ("label", s.label);
        o->setProperty ("kind", s.kind);
        o->setProperty ("group", s.group);
        o->setProperty ("energyDb", s.energyDb);
        secs.add (juce::var (o));
    }
    root->setProperty ("sections", secs);

    juce::Array<juce::var> marks;
    for (const auto& m : markers)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("time", m.timeSec);
        o->setProperty ("name", m.name);
        marks.add (juce::var (o));
    }
    root->setProperty ("markers", marks);

    root->setProperty ("lyrics", lyrics);
    root->setProperty ("lyricsBarsPerLine", lyricsBarsPerLine);
    root->setProperty ("lyricsStartSec", lyricsStartSec);
    root->setProperty ("target", dsp::targetInfo (target).id);
    root->setProperty ("masterEnabled", masterEnabled);
    root->setProperty ("autoMixEnabled", autoMixEnabled);
    root->setProperty ("vocalBusEnabled", vocalBusEnabled);
    root->setProperty ("duckingDb", duckingDb);
    root->setProperty ("referenceFile", referenceFile);
    root->setProperty ("adLibFolder", adLibFolder);
    root->setProperty ("nextTrackId", nextTrackId);
    root->setProperty ("armedTrack", armedTrackId);
    root->setProperty ("nextTakeId", nextTakeId);

    juce::Array<juce::var> trs;
    for (const auto& t : tracks)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("id", t.id);
        o->setProperty ("name", t.name);
        o->setProperty ("role", style::roleId (t.role));
        o->setProperty ("volumeDb", t.volumeDb);
        o->setProperty ("pan", t.pan);
        o->setProperty ("mute", t.mute);
        o->setProperty ("solo", t.solo);
        o->setProperty ("processing", t.processingEnabled);
        o->setProperty ("macros", t.macros.toVar());
        o->setProperty ("timingStrength", t.timingStrength);
        o->setProperty ("cleaning", t.cleaning);
        o->setProperty ("raw", t.raw);
        o->setProperty ("style", t.styleId);
        o->setProperty ("referenceEq", t.referenceEq);
        o->setProperty ("comp", t.comp == CompMode::Best ? "best" : "latest");
        o->setProperty ("sourceFile", t.sourceFile);
        o->setProperty ("sourceStart", num (static_cast<double> (t.sourceStart)));
        o->setProperty ("generatedFrom", t.generatedFrom);
        o->setProperty ("detail", t.detail);
        o->setProperty ("genPan", t.genPan);
        o->setProperty ("genWidth", t.genWidth);

        juce::Array<juce::var> tks;
        for (const auto& tk : t.takes)
        {
            auto* x = new juce::DynamicObject();
            x->setProperty ("id", tk.id);
            x->setProperty ("file", tk.file);
            x->setProperty ("start", num (static_cast<double> (tk.startSample)));
            x->setProperty ("regionStart", num (static_cast<double> (tk.regionStart)));
            x->setProperty ("regionEnd", num (static_cast<double> (tk.regionEnd)));
            x->setProperty ("created", num (static_cast<double> (tk.createdMs)));
            x->setProperty ("punch", tk.punch);
            x->setProperty ("fadeIn", num (static_cast<double> (tk.fadeIn)));
            x->setProperty ("fadeOut", num (static_cast<double> (tk.fadeOut)));
            tks.add (juce::var (x));
        }
        o->setProperty ("takes", tks);
        if (! t.stages.empty())
        {
            auto* so = new juce::DynamicObject();
            for (const auto& [id, ov] : t.stages)
                so->setProperty (juce::Identifier (id), ov.toVar());
            o->setProperty ("stages", juce::var (so));
        }
        if (! t.plugins.empty())
        {
            juce::Array<juce::var> pl;
            for (const auto& s : t.plugins)
                pl.add (s.toVar());
            o->setProperty ("plugins", pl);
        }
        trs.add (juce::var (o));
    }
    root->setProperty ("tracks", trs);
    return juce::var (root);
}

bool Project::fromVar (const juce::var& v, Project& out, juce::String& error)
{
    if (! v.isObject() || getS (v, "format") != "studiovoix-project")
    {
        error = "Ce fichier n'est pas un projet StudioVoix";
        return false;
    }
    const int version = getI (v, "version", 0);
    if (version < 1 || version > kFormatVersion)
    {
        error = "Version de projet non prise en charge : " + juce::String (version);
        return false;
    }

    Project p;
    p.folder = out.folder;
    p.name = getS (v, "name", "Projet");
    p.sampleRate = juce::jlimit (22050.0, 192000.0, getD (v, "sampleRate", kProjectSampleRate));
    p.style = style::styleFromId (getS (v, "style", "rap"));

    const auto k = v.getProperty ("key", {});
    p.key.root = juce::jlimit (0, 11, getI (k, "root", 9));
    p.key.minor = getB (k, "minor", true);
    p.key.confidence = static_cast<float> (getD (k, "confidence", 0.0));
    p.keyManual = getB (k, "manual", false);

    const auto tp = v.getProperty ("tempo", {});
    p.tempo.bpm = juce::jlimit (40.0, 240.0, getD (tp, "bpm", 120.0));
    p.tempo.firstBeatSec = std::max (0.0, getD (tp, "firstBeatSec", 0.0));
    p.tempo.beatsPerBar = juce::jlimit (2, 7, getI (tp, "beatsPerBar", 4));
    p.tempo.confidence = static_cast<float> (getD (tp, "confidence", 0.0));
    p.tempoManual = getB (tp, "manual", false);

    if (const auto* secs = v.getProperty ("sections", {}).getArray())
        for (const auto& s : *secs)
        {
            analysis::Section sec;
            sec.startSec = getD (s, "start", 0.0);
            sec.endSec = getD (s, "end", 0.0);
            sec.label = getS (s, "label", "Section");
            sec.kind = getS (s, "kind", "couplet");
            sec.group = getI (s, "group", 0);
            sec.energyDb = static_cast<float> (getD (s, "energyDb", -120.0));
            if (sec.endSec > sec.startSec)
                p.sections.push_back (sec);
        }

    if (const auto* marks = v.getProperty ("markers", {}).getArray())
        for (const auto& m : *marks)
            p.markers.push_back ({ std::max (0.0, getD (m, "time", 0.0)), getS (m, "name", "Marqueur") });

    p.lyrics = getS (v, "lyrics");
    p.lyricsBarsPerLine = juce::jlimit (1, 8, getI (v, "lyricsBarsPerLine", 1));
    p.lyricsStartSec = std::max (0.0, getD (v, "lyricsStartSec", 0.0));
    p.target = dsp::targetFromId (getS (v, "target", "spotify"));
    p.masterEnabled = getB (v, "masterEnabled", true);
    p.autoMixEnabled = getB (v, "autoMixEnabled", true);
    p.vocalBusEnabled = getB (v, "vocalBusEnabled", true);
    p.duckingDb = static_cast<float> (juce::jlimit (0.0, 6.0, getD (v, "duckingDb", 2.5)));
    p.referenceFile = getS (v, "referenceFile");
    p.adLibFolder = getS (v, "adLibFolder");
    p.nextTrackId = std::max (1, getI (v, "nextTrackId", 1));
    p.nextTakeId = std::max (1, getI (v, "nextTakeId", 1));

    std::set<int> seenIds;
    std::vector<size_t> needNewId;   // pistes sans identifiant valide ou en double : réparées après la boucle
    if (const auto* trs = v.getProperty ("tracks", {}).getArray())
        for (const auto& o : *trs)
        {
            Track t;
            t.id = getI (o, "id", 0);
            t.name = getS (o, "name", "Piste");
            t.role = style::roleFromId (getS (o, "role", "lead"));
            const bool roleMissing = o.getProperty ("role", {}).isVoid();
            t.volumeDb = static_cast<float> (juce::jlimit (-60.0, 12.0, getD (o, "volumeDb", 0.0)));
            t.pan = static_cast<float> (juce::jlimit (-1.0, 1.0, getD (o, "pan", 0.0)));
            t.mute = getB (o, "mute", false);
            t.solo = getB (o, "solo", false);
            t.processingEnabled = getB (o, "processing", true);
            t.macros = style::Macros::fromVar (o.getProperty ("macros", {}));
            t.timingStrength = static_cast<float> (juce::jlimit (0.0, 1.0, getD (o, "timingStrength", 0.0)));
            t.cleaning = getB (o, "cleaning", true);
            t.raw = getB (o, "raw", false);
            t.styleId = getS (o, "style");
            if (t.styleId.isNotEmpty() && ! t.isCorrection() && style::styleId (style::styleFromId (t.styleId)) != t.styleId)
            {
                p.loadWarnings.add ("style inconnu « "_u8 + t.styleId + " » sur la piste " + t.name + " : style du projet utilisé"_u8);
                t.styleId.clear();
            }
            t.referenceEq = getB (o, "referenceEq", false);
            t.comp = getS (o, "comp", "latest") == "best" ? CompMode::Best : CompMode::Latest;
            t.sourceFile = getS (o, "sourceFile");
            t.sourceStart = static_cast<long> (getD (o, "sourceStart", 0.0));
            t.generatedFrom = getI (o, "generatedFrom", -1);
            t.detail = getS (o, "detail");
            t.genPan = static_cast<float> (getD (o, "genPan", 0.0));
            t.genWidth = static_cast<float> (getD (o, "genWidth", 0.0));
            if (const auto* tks = o.getProperty ("takes", {}).getArray())
                for (const auto& x : *tks)
                {
                    Take tk;
                    tk.id = getI (x, "id", 0);
                    tk.file = getS (x, "file");
                    tk.startSample = static_cast<long> (getD (x, "start", 0.0));
                    tk.regionStart = static_cast<long> (getD (x, "regionStart", 0.0));
                    tk.regionEnd = static_cast<long> (getD (x, "regionEnd", 0.0));
                    tk.createdMs = static_cast<juce::int64> (getD (x, "created", 0.0));
                    tk.punch = getB (x, "punch", false);
                    tk.fadeIn = std::max (0L, static_cast<long> (getD (x, "fadeIn", 0.0)));
                    tk.fadeOut = std::max (0L, static_cast<long> (getD (x, "fadeOut", 0.0)));
                    if (tk.file.isNotEmpty() && tk.regionEnd > tk.regionStart)
                        t.takes.push_back (tk);
                    else
                        SV_LOG_WARN (kMod, "Prise invalide ignorée dans la piste "_u8 + t.name);
                }
            if (auto* so = o.getProperty ("stages", {}).getDynamicObject())
                for (const auto& prop : so->getProperties())
                    t.stages[prop.name.toString()] = plugins::StageOverride::fromVar (prop.value);
            if (const auto* pl = o.getProperty ("plugins", {}).getArray())
                for (const auto& x : *pl)
                {
                    auto s = plugins::PluginSlot::fromVar (x);
                    if (s.identifier.isNotEmpty())
                        t.plugins.push_back (std::move (s));
                    else
                        p.loadWarnings.add ("plugin sans identifiant ignoré sur la piste "_u8 + t.name);
                }
            if (roleMissing && t.takes.empty() && t.sourceFile.isNotEmpty() && t.generatedFrom < 0)
            {
                t.role = style::Role::Instru;   // rôle absent : un fichier source sans prise est l'instru
                p.loadWarnings.add ("rôle absent, déduit « instru » : "_u8 + t.name);
            }
            if (t.id <= 0 || seenIds.count (t.id) > 0)
            {
                needNewId.push_back (p.tracks.size());
                p.loadWarnings.add ((t.id <= 0 ? "piste sans identifiant : "_u8 : "identifiant en double : "_u8) + t.name);
            }
            else
            {
                seenIds.insert (t.id);
                p.nextTrackId = std::max (p.nextTrackId, t.id + 1);
            }
            for (const auto& tk : t.takes)
                p.nextTakeId = std::max (p.nextTakeId, tk.id + 1);
            p.tracks.push_back (t);
        }
    for (size_t idx : needNewId)
        p.tracks[idx].id = p.nextTrackId++;
    p.armedTrackId = getI (v, "armedTrack", -1);
    if (p.armedTrackId >= 0)
        if (const auto* armed = p.findTrack (p.armedTrackId); armed == nullptr || ! armed->isRecordable())
        {
            SV_LOG_WARN (kMod, "Piste armée #"_u8 + juce::String (p.armedTrackId) + " absente ou non enregistrable : désarmée"_u8);
            p.armedTrackId = -1;
        }
    for (const auto& w : p.loadWarnings)
        SV_LOG_WARN (kMod, "Projet réparé au chargement : "_u8 + w);

    out = std::move (p);
    return true;
}

bool Project::save (juce::String& error) const
{
    log::ScopedTimer timer (kMod, "sauvegarde");
    if (folder == juce::File())
    {
        error = "Projet sans dossier";
        return false;
    }
    if (! writeJson (projectFile(), toVar(), error))
    {
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    if (autosaveFile().existsAsFile() && ! autosaveFile().deleteFile())
        SV_LOG_WARN (kMod, "Impossible de supprimer l'ancienne sauvegarde auto");
    SV_LOG_INFO (kMod, "Projet sauvegardé : "_u8 + projectFile().getFullPathName());
    return true;
}

bool Project::saveAutosave (juce::String& error) const
{
    if (folder == juce::File())
    {
        error = "Projet sans dossier";
        return false;
    }
    if (! writeJson (autosaveFile(), toVar(), error))
    {
        SV_LOG_ERROR (kMod, "Sauvegarde auto : " + error);
        return false;
    }
    SV_LOG_DEBUG (kMod, "Sauvegarde auto écrite"_u8);
    return true;
}

bool Project::saveVersion (const juce::String& label, juce::String& error) const
{
    const auto stamp = juce::Time::getCurrentTime().formatted ("%Y%m%d-%H%M%S");
    const auto safe = juce::File::createLegalFileName (label).replaceCharacter (' ', '_').substring (0, 40);
    const auto file = historyDir().getChildFile (stamp + (safe.isNotEmpty() ? "_" + safe : juce::String()) + ".svx");
    if (! writeJson (file, toVar(), error))
    {
        SV_LOG_ERROR (kMod, "Version : " + error);
        return false;
    }
    auto files = historyDir().findChildFiles (juce::File::findFiles, false, "*.svx");
    std::sort (files.begin(), files.end(), [] (const juce::File& a, const juce::File& b) { return a.getFileName() < b.getFileName(); });
    while (files.size() > 50)
    {
        if (! files.getFirst().deleteFile())
            SV_LOG_WARN (kMod, "Ancienne version non supprimée : "_u8 + files.getFirst().getFileName());
        files.remove (0);
    }
    SV_LOG_INFO (kMod, "Version enregistrée : "_u8 + file.getFileName());
    return true;
}

juce::StringArray Project::listVersions() const
{
    std::vector<juce::String> v;
    for (const auto& f : historyDir().findChildFiles (juce::File::findFiles, false, "*.svx"))
        v.push_back (f.getFileName());
    std::sort (v.begin(), v.end(), [] (const juce::String& a, const juce::String& b) { return a > b; });   // plus récentes d'abord
    juce::StringArray names;
    for (const auto& s : v)
        names.add (s);
    return names;
}

bool Project::hasNewerAutosave (const juce::File& folder)
{
    const auto proj = folder.getChildFile ("projet.svx");
    const auto autoF = folder.getChildFile ("projet.autosave");
    return autoF.existsAsFile() && (! proj.existsAsFile() || autoF.getLastModificationTime() > proj.getLastModificationTime());
}

bool Project::load (const juce::File& folderOrFile, Project& out, juce::String& error, bool preferAutosave)
{
    log::ScopedTimer timer (kMod, "chargement projet");
    juce::File folder = folderOrFile.isDirectory() ? folderOrFile : folderOrFile.getParentDirectory();
    if (folder.getFileName() == "historique")
        folder = folder.getParentDirectory();   // version restaurée : les prises sont dans le dossier du projet
    juce::File file = folderOrFile.isDirectory() ? folder.getChildFile ("projet.svx") : folderOrFile;
    if (preferAutosave && hasNewerAutosave (folder))
        file = folder.getChildFile ("projet.autosave");

    if (! file.existsAsFile())
    {
        error = "Projet introuvable : " + file.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    if (file.getSize() > 50 * 1024 * 1024)
    {
        error = "Fichier de projet anormalement gros : " + file.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    juce::var v;
    const auto parse = juce::JSON::parse (file.loadFileAsString(), v);
    if (parse.failed())
    {
        error = "Projet illisible (" + parse.getErrorMessage() + ")";
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    out.folder = folder;
    if (! fromVar (v, out, error))
    {
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    out.folder = folder;

    // Vérifie la présence des fichiers audio.
    for (const auto& t : out.tracks)
        for (const auto& tk : t.takes)
            if (! out.audioDir().getChildFile (tk.file).existsAsFile())
                SV_LOG_WARN (kMod, "Fichier de prise manquant : " + tk.file + " (piste " + t.name + ")");

    SV_LOG_INFO (kMod, "Projet chargé : "_u8 + out.name + " (" + juce::String ((int) out.tracks.size()) + " pistes) depuis " + file.getFileName());
    return true;
}

juce::File defaultProjectsRoot()
{
    return juce::File::getSpecialLocation (juce::File::userDocumentsDirectory).getChildFile ("StudioVoix").getChildFile ("Projets");
}

juce::File createProjectFolder (const juce::File& root, const juce::String& name, juce::String& error)
{
    auto safe = juce::File::createLegalFileName (name.trim());
    if (safe.isEmpty())
        safe = "Projet";
    auto folder = root.getChildFile (safe);
    int n = 2;
    while (folder.exists())
        folder = root.getChildFile (safe + " (" + juce::String (n++) + ")");
    const auto r = folder.createDirectory();
    if (r.failed())
    {
        error = "Création du dossier impossible : "_u8 + r.getErrorMessage();
        SV_LOG_ERROR (kMod, error);
        return {};
    }
    folder.getChildFile ("audio").createDirectory();
    folder.getChildFile ("historique").createDirectory();
    SV_LOG_INFO (kMod, "Dossier de projet créé : "_u8 + folder.getFullPathName());
    return folder;
}

long compensatedTakeStart (long recordStartSample, int inputLatency, int outputLatency, int manualOffsetSamples)
{
    // Un échantillon capté au moment où l'appli joue la position P correspond à ce que le chanteur
    // entendait à P - (latence sortie + latence entrée) : on recule la prise d'autant.
    return recordStartSample - static_cast<long> (std::max (0, inputLatency)) - static_cast<long> (std::max (0, outputLatency))
           - static_cast<long> (manualOffsetSamples);
}
Take* findTake (Track& t, int takeId)
{
    for (auto& tk : t.takes)
        if (tk.id == takeId)
            return &tk;
    return nullptr;
}

bool splitTake (Track& t, int takeId, long atSample, int& nextTakeId)
{
    auto* tk = findTake (t, takeId);
    if (tk == nullptr || atSample <= tk->regionStart || atSample >= tk->regionEnd)
    {
        SV_LOG_WARN (kMod, "Couper : prise #" + juce::String (takeId) + " introuvable ou point hors du bloc (" + juce::String (atSample) + ")");
        return false;
    }
    Take right = *tk;
    right.id = nextTakeId++;
    right.regionStart = atSample;
    right.fadeIn = 0;
    right.fadeOut = std::min (right.fadeOut, right.regionEnd - right.regionStart);
    tk->regionEnd = atSample;
    tk->fadeOut = 0;
    tk->fadeIn = std::min (tk->fadeIn, tk->regionEnd - tk->regionStart);
    // Insérée juste après la partie gauche : l'ordre des prises (la plus récente gagne) reste cohérent.
    const auto pos = std::find_if (t.takes.begin(), t.takes.end(), [takeId] (const Take& x) { return x.id == takeId; });
    t.takes.insert (std::next (pos), right);
    SV_LOG_INFO (kMod, "Prise #" + juce::String (takeId) + " coupée à "_u8 + juce::String (atSample) + " : droite = prise #" + juce::String (right.id));
    return true;
}

bool trimTake (Track& t, int takeId, long newStart, long newEnd, long fileLength, long minLength)
{
    auto* tk = findTake (t, takeId);
    if (tk == nullptr)
        return false;
    const long fileStart = tk->startSample;
    const long fileEnd = fileLength > 0 ? tk->startSample + fileLength : std::numeric_limits<long>::max();
    newStart = std::max ({ 0L, fileStart, newStart });
    newEnd = std::min (fileEnd, newEnd);
    if (newEnd - newStart < std::max (1L, minLength))
    {
        SV_LOG_WARN (kMod, "Rogner : zone trop courte pour la prise #" + juce::String (takeId) + " (" + juce::String (newEnd - newStart) + " échantillons)"_u8);
        return false;
    }
    tk->regionStart = newStart;
    tk->regionEnd = newEnd;
    setTakeFades (t, takeId, tk->fadeIn, tk->fadeOut);   // fondus bornés à la nouvelle zone
    SV_LOG_INFO (kMod, "Prise #" + juce::String (takeId) + " rognée : zone "_u8 + juce::String (newStart) + "-" + juce::String (newEnd));
    return true;
}

bool setTakeFades (Track& t, int takeId, long fadeIn, long fadeOut)
{
    auto* tk = findTake (t, takeId);
    if (tk == nullptr)
        return false;
    const long len = std::max (0L, tk->regionEnd - tk->regionStart);
    fadeIn = juce::jlimit (0L, len, fadeIn);
    fadeOut = juce::jlimit (0L, len - fadeIn, fadeOut);
    tk->fadeIn = fadeIn;
    tk->fadeOut = fadeOut;
    return true;
}

bool removeTake (Track& t, int takeId)
{
    const auto n = t.takes.size();
    t.takes.erase (std::remove_if (t.takes.begin(), t.takes.end(), [takeId] (const Take& x) { return x.id == takeId; }), t.takes.end());
    if (t.takes.size() == n)
    {
        SV_LOG_WARN (kMod, "Supprimer le bloc : prise #" + juce::String (takeId) + " introuvable");
        return false;
    }
    SV_LOG_INFO (kMod, "Prise #" + juce::String (takeId) + " supprimée de la piste « "_u8 + t.name + " »"_u8);
    return true;
}
} // namespace sv::project
