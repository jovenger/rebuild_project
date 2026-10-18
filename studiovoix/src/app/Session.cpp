#include "Session.h"

#include "core/Log.h"
#include "core/analysis/KeyDetector.h"
#include "core/analysis/StructureDetector.h"
#include "core/analysis/TempoDetector.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "Session";
    constexpr int kMaxUndo = 50;
    constexpr size_t kMaxMemoRenders = 12;

    juce::String trackJson (const project::Project& p, int id)
    {
        project::Project single;
        single.style = p.style;
        if (const auto* t = p.findTrack (id))
            single.tracks.push_back (*t);
        return juce::JSON::toString (single.toVar(), true);
    }

    // Contexte d'analyse partagé par toutes les pistes (style, tonalité, tempo, référence).
    juce::String globalSignature (const project::Project& p)
    {
        return "|" + style::styleId (p.style) + "|" + juce::String (p.key.root) + (p.key.minor ? "m" : "M") + "|"
               + juce::String (p.tempo.bpm, 6) + "|" + juce::String (p.tempo.firstBeatSec, 6) + "|" + p.referenceFile;
    }

    juce::String uniqueStamp() { return juce::Time::getCurrentTime().formatted ("%Y%m%d_%H%M%S"); }
}

Session::Session (AudioEngine& e, AppSettings& s)
    : audioEngine (e),
      appSettings (s),
      context (std::make_shared<dsp::AnalysisContext>()),
      pool (juce::ThreadPoolOptions{}.withNumberOfThreads (juce::jlimit (1, 4, juce::SystemStats::getNumCpus() - 1)).withThreadName ("Rendu"))
{
    startTimer (200);
}

Session::~Session()
{
    stopTimer();
    pool.removeAllJobs (true, 15000);
    if (dirty && proj.folder != juce::File())
    {
        juce::String err;
        if (! proj.saveAutosave (err))
            SV_LOG_ERROR (kMod, "Sauvegarde auto à la fermeture impossible : "_u8 + err);
    }
}

// ---------------------------------------------------------------------------------------------
void Session::setStatus (const juce::String& text)
{
    status = text;
    SV_LOG_INFO (kMod, "Statut : " + text);
    sendChangeMessage();
}

void Session::markDirty()
{
    dirty = true;
    sendChangeMessage();
}

long Session::toDevice (long projectSamples) const
{
    const double r = deviceRate() / proj.sampleRate;
    return static_cast<long> (std::llround (static_cast<double> (projectSamples) * r));
}

long Session::toProject (long deviceSamples) const
{
    const double r = proj.sampleRate / deviceRate();
    return static_cast<long> (std::llround (static_cast<double> (deviceSamples) * r));
}

double Session::deviceRate() const
{
    const double sr = audioEngine.sampleRate();
    return sr > 0.0 ? sr : proj.sampleRate;
}

// ---------------------------------------------------------------------------------------------
bool Session::newProject (const juce::String& name, juce::String& error)
{
    const auto folder = project::createProjectFolder (project::defaultProjectsRoot(), name, error);
    if (folder == juce::File())
        return false;
    pool.removeAllJobs (true, 15000);
    proj = project::Project();
    proj.folder = folder;
    proj.name = name;
    proj.adLibFolder = appSettings.adLibFolder().getFullPathName();
    auto& lead = proj.addTrack (style::Role::Lead, "Voix principale");
    if (appSettings.hasUserPreset (proj.style))
        lead.macros = appSettings.userPreset (proj.style);
    if (! proj.save (error))
        return false;
    appSettings.setLastProject (folder);
    afterProjectLoaded();
    setStatus ("Nouveau projet : " + name + " — importe une instru pour commencer"_u8);
    return true;
}

bool Session::openProject (const juce::File& folderOrFile, bool preferAutosave, juce::String& error)
{
    project::Project loaded;
    if (! project::Project::load (folderOrFile, loaded, error, preferAutosave))
        return false;
    pool.removeAllJobs (true, 15000);
    proj = std::move (loaded);
    appSettings.setLastProject (proj.folder);
    afterProjectLoaded();
    setStatus ("Projet ouvert : "_u8 + proj.name);
    renderAll();
    return true;
}

void Session::afterProjectLoaded()
{
    renders.clear();
    renderGeneration.clear();
    trackStatuses.clear();
    pendingRenders.clear();
    pendingGeneration.clear();
    mixState = {};
    undoStack.clear();
    redoStack.clear();
    renderMemo.clear();
    storedGeneration.clear();
    cache.clear();
    dirty = false;
    selectedTrackId = proj.leadTrackId();
    refreshContext();
    audioEngine.stop();
    audioEngine.setPosition (0);
    audioEngine.setTempo (proj.tempo.bpm, proj.tempo.firstBeatSec);
    rebuildPlayState();
    sendChangeMessage();
}

bool Session::save (juce::String& error)
{
    if (! proj.save (error))
    {
        setStatus ("Échec de la sauvegarde : "_u8 + error);
        return false;
    }
    juce::String verr;
    if (! proj.saveVersion ("sauvegarde", verr))
        SV_LOG_WARN (kMod, "Version non enregistrée : "_u8 + verr);
    dirty = false;
    setStatus ("Projet sauvegardé"_u8);
    return true;
}

void Session::restoreVersion (const juce::String& versionFileName)
{
    const auto file = proj.historyDir().getChildFile (versionFileName);
    project::Project loaded;
    loaded.folder = proj.folder;
    juce::String err;
    if (! project::Project::load (file, loaded, err))
    {
        setStatus ("Version illisible : " + err);
        return;
    }
    pushUndo ("Restauration de version");
    restoreSnapshot (loaded.toVar());
    setStatus ("Version restaurée : "_u8 + versionFileName);
}

// ---------------------------------------------------------------------------------------------
void Session::importInstru (const juce::File& file)
{
    if (! file.existsAsFile())
    {
        setStatus ("Instru introuvable : " + file.getFullPathName());
        return;
    }
    const auto dest = proj.audioDir().getChildFile ("instru_" + uniqueStamp() + file.getFileExtension());
    if (! file.copyFileTo (dest))
    {
        setStatus ("Copie de l'instru impossible vers le projet");
        return;
    }
    pushUndo ("Import de l'instru");

    project::Track* instru = nullptr;
    for (auto& t : proj.tracks)
        if (t.role == style::Role::Instru)
            instru = &t;
    if (instru == nullptr)
    {
        proj.tracks.insert (proj.tracks.begin(), project::Track());
        instru = &proj.tracks.front();
        instru->id = proj.nextTrackId++;
        instru->role = style::Role::Instru;
    }
    instru->name = "Instru : " + file.getFileNameWithoutExtension();
    instru->sourceFile = dest.getFileName();
    instru->sourceStart = 0;
    const int instruId = instru->id;
    markDirty();
    setStatus ("Analyse de l'instru (tempo, tonalité, structure)…"_u8);

    ++activeJobs;
    const double sr = proj.sampleRate;
    juce::WeakReference<Session> weak (this);
    pool.addJob ([weak, dest, sr, instruId]
    {
        struct Result
        {
            bool ok = false;
            juce::String error;
            MusicalKey key;
            TempoInfo tempo;
            std::vector<analysis::Section> sections;
        };
        auto res = std::make_shared<Result>();
        auto loaded = audio::loadStereo (dest, sr);
        if (loaded.ok())
        {
            const auto mono = audio::toMono (loaded.buffer);
            res->key = analysis::detectKey (mono, sr).key;
            res->tempo = analysis::detectTempo (mono, sr);
            res->sections = analysis::detectStructure (mono, sr, res->tempo);
            res->ok = true;
        }
        else
        {
            res->error = loaded.error;
        }
        juce::MessageManager::callAsync ([weak, res, instruId]
        {
            auto* s = weak.get();
            if (s == nullptr)
                return;
            --s->activeJobs;
            if (! res->ok)
            {
                s->setStatus ("Instru illisible : " + res->error);
                return;
            }
            if (! s->proj.keyManual)
                s->proj.key = res->key;
            if (! s->proj.tempoManual)
                s->proj.tempo = res->tempo;
            s->proj.sections = res->sections;
            s->audioEngine.setTempo (s->proj.tempo.bpm, s->proj.tempo.firstBeatSec);
            s->refreshContext();
            s->requestRender (instruId);
            for (const auto& t : s->proj.tracks)
                if (t.isVocal())
                    s->requestRender (t.id);
            s->markDirty();
            s->setStatus ("Instru analysée : "_u8 + juce::String (s->proj.tempo.bpm, 1) + " BPM, " + s->proj.key.toFrench() + ", "
                          + juce::String ((int) s->proj.sections.size()) + " sections");
        });
    });
}

void Session::reanalyseInstru()
{
    const auto* instru = proj.instruTrack();
    if (instru == nullptr)
    {
        setStatus ("Aucune instru à analyser"_u8);
        return;
    }
    proj.keyManual = false;
    proj.tempoManual = false;
    const auto file = proj.audioDir().getChildFile (instru->sourceFile);
    // Réutilise le chemin d'import sans recopier le fichier.
    const int instruId = instru->id;
    ++activeJobs;
    const double sr = proj.sampleRate;
    juce::WeakReference<Session> weak (this);
    setStatus ("Nouvelle analyse de l'instru…"_u8);
    pool.addJob ([weak, file, sr, instruId]
    {
        auto loaded = audio::loadStereo (file, sr);
        auto mono = std::make_shared<Mono> (loaded.ok() ? audio::toMono (loaded.buffer) : Mono());
        const auto key = analysis::detectKey (*mono, sr).key;
        const auto tempo = analysis::detectTempo (*mono, sr);
        const auto sections = analysis::detectStructure (*mono, sr, tempo);
        juce::MessageManager::callAsync ([weak, key, tempo, sections, instruId]
        {
            if (auto* s = weak.get())
            {
                --s->activeJobs;
                s->pushUndo ("Nouvelle analyse de l'instru");
                s->proj.key = key;
                s->proj.tempo = tempo;
                s->proj.sections = sections;
                s->audioEngine.setTempo (tempo.bpm, tempo.firstBeatSec);
                s->refreshContext();
                juce::ignoreUnused (instruId);
                for (const auto& t : s->proj.tracks)
                    if (t.isVocal())
                        s->requestRender (t.id);
                s->markDirty();
                s->setStatus ("Instru réanalysée : "_u8 + juce::String (tempo.bpm, 1) + " BPM, " + key.toFrench());
            }
        });
    });
}

void Session::importVoice (const juce::File& file, int trackId)
{
    auto* t = proj.findTrack (trackId);
    if (t == nullptr || ! t->isVocal() || t->isGenerated())
    {
        setStatus ("Choisis d'abord une piste voix (non générée)"_u8);
        return;
    }
    Mono data;
    juce::String err;
    if (! audio::loadMono (file, proj.sampleRate, data, err))
    {
        setStatus ("Voix illisible : " + err);
        return;
    }
    pushUndo ("Import d'une voix");
    project::Take tk;
    tk.id = proj.nextTakeId++;
    tk.file = "import_" + juce::String (tk.id) + "_" + uniqueStamp() + ".wav";
    if (! audio::writeMonoWavFloat (proj.audioDir().getChildFile (tk.file), data, proj.sampleRate, err))
    {
        setStatus ("Copie de la voix impossible : " + err);
        return;
    }
    tk.startSample = 0;
    tk.regionStart = 0;
    tk.regionEnd = static_cast<long> (data.size());
    tk.createdMs = juce::Time::currentTimeMillis();
    t->takes.push_back (tk);
    markDirty();
    if (t->role == style::Role::Lead)
        leadAwaitingProposal.insert (trackId);
    requestRender (trackId);
    setStatus ("Voix importée dans "_u8 + t->name);
}

// ---------------------------------------------------------------------------------------------
int Session::addVocalTrack (style::Role role, const juce::String& name)
{
    pushUndo ("Ajout de piste");
    auto& t = proj.addTrack (role, name);
    if (appSettings.hasUserPreset (proj.style))
        t.macros = appSettings.userPreset (proj.style);
    selectedTrackId = t.id;
    markDirty();
    rebuildPlayState();
    return t.id;
}

void Session::removeTrack (int trackId)
{
    if (proj.findTrack (trackId) == nullptr)
        return;
    pushUndo ("Suppression de piste");
    proj.removeTrack (trackId);
    renders.erase (trackId);
    if (selectedTrackId == trackId)
        selectedTrackId = proj.leadTrackId();
    markDirty();
    launchAutoMix();
    rebuildPlayState();
}

void Session::updateTrack (int trackId, const std::function<void (project::Track&)>& change, bool rerender,
                           const juce::String& undoLabelText)
{
    auto* t = proj.findTrack (trackId);
    if (t == nullptr)
        return;
    if (undoLabelText.isNotEmpty())
        pushUndo (undoLabelText);
    change (*t);
    markDirty();
    if (rerender)
        requestRender (trackId);
    else
        rebuildPlayState();
}

void Session::selectTrack (int trackId)
{
    selectedTrackId = trackId;
    sendChangeMessage();
}

void Session::setStyle (style::Style s)
{
    if (s == proj.style)
        return;
    pushUndo ("Changement de style");
    proj.style = s;
    if (appSettings.hasUserPreset (s))
        for (auto& t : proj.tracks)
            if (t.isVocal() && ! t.isGenerated())
                t.macros = appSettings.userPreset (s);
    markDirty();
    renderAll();
    setStatus ("Style : " + style::styleName (s));
}

void Session::setKey (const MusicalKey& key)
{
    pushUndo ("Changement de tonalité"_u8);
    proj.key = key;
    proj.keyManual = true;
    refreshContext();
    for (const auto& t : proj.tracks)
        if (t.isVocal())
            requestRender (t.id);
    markDirty();
}

void Session::setTempo (double bpm)
{
    if (bpm < 40.0 || bpm > 240.0)
    {
        setStatus ("Tempo invalide (40 à 240 BPM)"_u8);
        return;
    }
    pushUndo ("Changement de tempo");
    proj.tempo.bpm = bpm;
    proj.tempoManual = true;
    audioEngine.setTempo (bpm, proj.tempo.firstBeatSec);
    refreshContext();
    for (const auto& t : proj.tracks)
        if (t.isVocal())
            requestRender (t.id);
    markDirty();
}

void Session::updateProject (const std::function<void (project::Project&)>& change, bool rerenderVocals, const juce::String& undoLabelText)
{
    if (undoLabelText.isNotEmpty())
        pushUndo (undoLabelText);
    change (proj);
    markDirty();
    if (rerenderVocals)
    {
        refreshContext();
        for (const auto& t : proj.tracks)
            if (t.isVocal())
                requestRender (t.id);
    }
    else
    {
        launchAutoMix();
    }
}

void Session::setReferenceTrack (const juce::File& file)
{
    pushUndo ("Morceau de référence"_u8);
    proj.referenceFile = file.getFullPathName();
    markDirty();
    refreshContext();
    for (const auto& t : proj.tracks)
        if (t.isVocal() && t.referenceEq)
            requestRender (t.id);
    setStatus (file == juce::File() ? juce::String ("Morceau de référence retiré"_u8)
                                    : "Morceau de référence : "_u8 + file.getFileName());
}

void Session::refreshContext()
{
    auto ctx = std::make_shared<dsp::AnalysisContext>();
    ctx->key = proj.key;
    ctx->tempo = proj.tempo;
    if (context != nullptr)
        ctx->reference = context->reference;
    const juce::String refPath = proj.referenceFile;
    context = ctx;

    if (refPath.isEmpty())
    {
        auto c2 = std::make_shared<dsp::AnalysisContext> (*context);
        c2->reference = {};
        context = c2;
        return;
    }
    // Spectre de référence calculé en tâche de fond.
    ++activeJobs;
    const double sr = proj.sampleRate;
    juce::WeakReference<Session> weak (this);
    auto* cachePtr = &cache;
    pool.addJob ([weak, refPath, sr, cachePtr]
    {
        juce::String err;
        auto st = cachePtr->stereo (juce::File (refPath), sr, err);
        auto spectrum = std::make_shared<analysis::BandSpectrum> (st != nullptr ? analysis::averageSpectrum (audio::toMono (*st), sr)
                                                                                 : analysis::BandSpectrum());
        juce::MessageManager::callAsync ([weak, spectrum, refPath, err]
        {
            if (auto* s = weak.get())
            {
                --s->activeJobs;
                if (s->proj.referenceFile != refPath)
                    return;
                if (! spectrum->valid())
                {
                    s->setStatus ("Morceau de référence illisible : "_u8 + err);
                    return;
                }
                auto c = std::make_shared<dsp::AnalysisContext> (*s->context);
                c->reference = *spectrum;
                s->context = c;
                for (const auto& t : s->proj.tracks)
                    if (t.isVocal() && t.referenceEq)
                        s->requestRender (t.id);
                s->sendChangeMessage();
            }
        });
    });
}

void Session::addMarkerAtPlayhead()
{
    pushUndo ("Marqueur");
    const double t = positionSec();
    proj.markers.push_back ({ t, "Marqueur " + juce::String ((int) proj.markers.size() + 1) });
    markDirty();
    setStatus ("Marqueur ajouté à "_u8 + juce::String (t, 2) + " s");
}

void Session::copySectionToSimilar (int trackId, int sectionIndex)
{
    pushUndo ("Copie de section");
    juce::String err;
    const int copies = render::copySectionToSimilar (proj, trackId, sectionIndex, cache, err);
    if (copies <= 0)
    {
        undoStack.pop_back();
        setStatus (err.isNotEmpty() ? err : juce::String ("Aucune section semblable trouvée"_u8));
        return;
    }
    markDirty();
    requestRender (trackId);
    setStatus ("Section copiée "_u8 + juce::String (copies) + " fois");
}

// ---------------------------------------------------------------------------------------------
double Session::positionSec() const
{
    return static_cast<double> (audioEngine.getPosition()) / deviceRate();
}

void Session::setPositionSec (double sec)
{
    audioEngine.setPosition (static_cast<long> (std::max (0.0, sec) * deviceRate()));
    sendChangeMessage();
}

void Session::togglePlay()
{
    if (audioEngine.isRecording())
    {
        stopRecording();
        return;
    }
    if (audioEngine.isPlaying())
        audioEngine.stop();
    else
        audioEngine.play();
    sendChangeMessage();
}

void Session::stopTransport()
{
    if (audioEngine.isRecording())
        stopRecording();
    audioEngine.stop();
    sendChangeMessage();
}

void Session::setLoopRegion (bool enabled, double startSec, double endSec)
{
    audioEngine.setLoop (enabled, static_cast<long> (startSec * deviceRate()), static_cast<long> (endSec * deviceRate()));
}

// ---------------------------------------------------------------------------------------------
bool Session::startRecording (int trackId, bool punch, double punchInSec, double punchOutSec, juce::String& error)
{
    const auto* t = proj.findTrack (trackId);
    if (t == nullptr || ! t->isVocal() || t->isGenerated())
    {
        error = "Sélectionne une piste voix (pas une piste générée) avant d'enregistrer"_u8;
        return false;
    }
    if (punch && punchOutSec <= punchInSec + 0.1)
    {
        error = "Zone de punch-in invalide : définis-la sur la règle (Maj + glisser)"_u8;
        return false;
    }
    const double dsr = deviceRate();
    AudioEngine::RecordRequest req;
    req.file = proj.audioDir().getChildFile ("prise_" + juce::String (trackId) + "_" + juce::String (proj.nextTakeId) + "_" + uniqueStamp() + ".wav");
    req.punch = punch;
    req.punchIn = static_cast<long> (punchInSec * dsr);
    req.punchOut = static_cast<long> (punchOutSec * dsr);
    // En punch-in, on enregistre 0,5 s avant la zone pour les fondus.
    req.recordStart = punch ? std::max (0L, req.punchIn - static_cast<long> (0.5 * dsr)) : audioEngine.getPosition();
    req.prerollSamples = static_cast<long> (appSettings.countdownBars() * proj.tempo.barSec() * dsr);
    if (punch)
        req.prerollSamples = std::max (req.prerollSamples, static_cast<long> (proj.tempo.barSec() * dsr));

    audioEngine.setMetronome (appSettings.metronome());
    if (! audioEngine.startRecording (req, error))
        return false;
    selectedTrackId = trackId;
    setStatus (juce::String (punch ? "Punch-in" : "Enregistrement") + " sur " + t->name
               + (req.prerollSamples > 0 ? " — compte à rebours…"_u8 : juce::String()));
    return true;
}

void Session::stopRecording()
{
    auto take = audioEngine.stopRecording();
    audioEngine.setMetronome (appSettings.metronome());
    if (! take.ok)
    {
        setStatus ("Prise annulée : "_u8 + take.error);
        take.file.deleteFile();
        return;
    }

    const int trackId = selectedTrackId;
    auto* t = proj.findTrack (trackId);
    if (t == nullptr)
    {
        setStatus ("Piste de la prise introuvable (fichier conservé : "_u8 + take.file.getFileName() + ")");
        return;
    }

    // Recalage : la mesure du calibrage remplace les latences annoncées par le pilote si elle existe.
    const int calibrated = appSettings.calibratedOffsetSamples();
    const int manual = static_cast<int> (appSettings.manualLatencyOffsetMs() * 0.001 * deviceRate());
    long deviceStart;
    if (calibrated > 0)
        deviceStart = take.firstWrittenPosition - calibrated - manual;
    else
        deviceStart = project::compensatedTakeStart (take.firstWrittenPosition, take.inputLatency, take.outputLatency, manual);

    pushUndo ("Prise");
    project::Take tk;
    tk.id = proj.nextTakeId++;
    tk.file = take.file.getFileName();
    tk.startSample = toProject (deviceStart);
    const long len = toProject (take.numSamples);
    tk.punch = take.request.punch;
    if (tk.punch)
    {
        tk.regionStart = std::max (tk.startSample, toProject (take.request.punchIn));
        tk.regionEnd = std::min (tk.startSample + len, toProject (take.request.punchOut));
    }
    else
    {
        tk.regionStart = std::max (0L, tk.startSample);
        tk.regionEnd = tk.startSample + len;
    }
    tk.createdMs = juce::Time::currentTimeMillis();
    if (tk.regionEnd <= tk.regionStart)
    {
        undoStack.pop_back();
        setStatus ("Prise trop courte, ignorée"_u8);
        return;
    }
    t->takes.push_back (tk);
    const auto shiftMs = (take.firstWrittenPosition - deviceStart) * 1000.0 / deviceRate();
    SV_LOG_INFO (kMod, "Prise #" + juce::String (tk.id) + " ajoutée à "_u8 + t->name + " : recalage " + juce::String (shiftMs, 1)
                       + " ms, zone " + juce::String (tk.regionStart / proj.sampleRate, 2) + "-" + juce::String (tk.regionEnd / proj.sampleRate, 2) + " s");

    juce::String err;
    if (! proj.saveAutosave (err))
        SV_LOG_ERROR (kMod, "Sauvegarde auto après prise impossible : "_u8 + err);
    markDirty();
    if (t->role == style::Role::Lead && appSettings.proposeGenerationAfterTake())
        leadAwaitingProposal.insert (trackId);
    requestRender (trackId);
    setStatus ("Prise enregistrée (recalage "_u8 + juce::String (shiftMs, 1) + " ms)"
               + (take.clipped ? " — ATTENTION : saturation pendant la prise, baisse le gain du micro"_u8 : juce::String())
               + " — traitement en cours…"_u8);
}

// ---------------------------------------------------------------------------------------------
void Session::requestRender (int trackId)
{
    pendingRenders.insert (trackId);
    pendingSinceMs = juce::Time::currentTimeMillis();
    trackStatuses[trackId] = "En attente…"_u8;
    sendChangeMessage();
}

void Session::renderAll()
{
    for (const auto& t : proj.tracks)
        requestRender (t.id);
}

void Session::timerCallback()
{
    const auto now = juce::Time::currentTimeMillis();
    if (! pendingRenders.empty() && now - pendingSinceMs > 300)
    {
        const auto ids = pendingRenders;
        pendingRenders.clear();
        for (int id : ids)
            launchRender (id);
    }

    if (dirty && proj.folder != juce::File() && now - lastAutosaveMs > 60000)
    {
        lastAutosaveMs = now;
        juce::String err;
        if (! proj.saveAutosave (err))
            SV_LOG_ERROR (kMod, "Sauvegarde auto : " + err);
    }
}

void Session::launchRender (int trackId)
{
    const auto* t = proj.findTrack (trackId);
    if (t == nullptr)
        return;
    if (t->isVocal() && t->takes.empty() && t->sourceFile.isEmpty())
    {
        trackStatuses[trackId] = "Vide";
        renders.erase (trackId);
        rebuildPlayState();
        return;
    }

    const int gen = ++renderGeneration[trackId];
    trackStatuses[trackId] = "Traitement…"_u8;
    ++activeJobs;
    sendChangeMessage();

    auto snapshot = std::make_shared<const project::Project> (proj);
    auto ctx = context;
    auto* cachePtr = &cache;
    juce::WeakReference<Session> weak (this);
    pool.addJob ([weak, snapshot, ctx, cachePtr, trackId, gen]
    {
        std::shared_ptr<const render::TrackRender> result;
        try
        {
            const auto* track = snapshot->findTrack (trackId);
            result = track != nullptr ? render::renderTrack (*snapshot, *track, *cachePtr, *ctx) : nullptr;
        }
        catch (const std::exception& e)
        {
            auto r = std::make_shared<render::TrackRender>();
            r->trackId = trackId;
            r->error = juce::String ("Exception pendant le rendu : ") + e.what();
            result = r;
        }
        juce::MessageManager::callAsync ([weak, result, trackId, gen]
        {
            if (auto* s = weak.get())
                s->onRenderDone (trackId, gen, result);
        });
    });
}

void Session::onRenderDone (int trackId, int generation, std::shared_ptr<const render::TrackRender> result)
{
    --activeJobs;
    if (renderGeneration[trackId] != generation || proj.findTrack (trackId) == nullptr)
    {
        sendChangeMessage();
        return;   // résultat périmé (réglages modifiés entre-temps)
    }
    if (result == nullptr || ! result->ok())
    {
        trackStatuses[trackId] = "Erreur : " + (result != nullptr ? result->error : juce::String ("rendu impossible"));
        SV_LOG_ERROR (kMod, trackStatuses[trackId]);
        sendChangeMessage();
        return;
    }
    renders[trackId] = result;
    storedGeneration[trackId] = generation;
    const auto& rep = result->report;
    trackStatuses[trackId] = result->compSummary.isNotEmpty() && ! proj.findTrack (trackId)->isGenerated()
                               ? "Prêt — "_u8 + result->compSummary
                               : juce::String ("Prêt"_u8);
    if (proj.findTrack (trackId)->isVocal())
        trackStatuses[trackId] << " | justesse " << juce::String (juce::roundToInt (rep.meanCorrectionCents)) << " c, comp "
                               << juce::String (rep.compGrDb, 1) << " dB";

    // Génération en attente de ce rendu ?
    if (auto it = pendingGeneration.find (trackId); it != pendingGeneration.end())
    {
        const auto opts = it->second;
        pendingGeneration.erase (it);
        startGeneration (trackId, opts);
    }
    else if (leadAwaitingProposal.count (trackId) > 0)
    {
        leadAwaitingProposal.erase (trackId);
        if (onLeadTakeReady)
            onLeadTakeReady (trackId);
    }

    launchAutoMix();
    rebuildPlayState();
}

void Session::launchAutoMix()
{
    if (! proj.autoMixEnabled)
    {
        mixState = {};
        rebuildPlayState();
        return;
    }
    const int gen = ++autoMixGeneration;
    auto snapshot = std::make_shared<const project::Project> (proj);
    auto rendersCopy = std::make_shared<const render::RenderSet> (renders);
    ++activeJobs;
    juce::WeakReference<Session> weak (this);
    pool.addJob ([weak, snapshot, rendersCopy, gen]
    {
        auto ms = std::make_shared<render::MixState> (render::computeAutoMix (*snapshot, *rendersCopy));
        juce::MessageManager::callAsync ([weak, ms, gen]
        {
            if (auto* s = weak.get())
            {
                --s->activeJobs;
                if (gen != s->autoMixGeneration)
                    return;
                s->mixState = *ms;
                s->rebuildPlayState();
                s->sendChangeMessage();
            }
        });
    });
}

void Session::rebuildPlayState()
{
    auto st = std::make_shared<AudioEngine::PlayState>();
    bool solo = false;
    for (const auto& t : proj.tracks)
        solo = solo || t.solo;

    const double dsr = deviceRate();
    const bool resample = std::abs (dsr - proj.sampleRate) > 1.0;
    for (const auto& t : proj.tracks)
    {
        if (t.mute || (solo && ! t.solo))
            continue;
        auto it = renders.find (t.id);
        if (it == renders.end() || it->second == nullptr || ! it->second->ok())
            continue;
        const auto& r = it->second;
        std::shared_ptr<const Stereo> buf;
        if (t.role == style::Role::Instru && mixState.autoMixApplied && mixState.autoMix.duckedInstru.getNumSamples() > 0)
            buf = std::make_shared<const Stereo> (mixState.autoMix.duckedInstru);
        else if (t.isVocal() && ! t.processingEnabled)
            buf = std::shared_ptr<const Stereo> (r, &r->raw);
        else
            buf = std::shared_ptr<const Stereo> (r, &r->processed);
        if (resample)
            buf = std::make_shared<const Stereo> (audio::resample (*buf, proj.sampleRate, dsr));

        AudioEngine::PlayTrack pt;
        pt.buffer = buf;
        pt.start = toDevice (r->startSample);
        const float vocalGain = t.isVocal() && mixState.autoMixApplied ? mixState.autoMix.vocalGainDb : 0.0f;
        const float g = dbToGain (t.volumeDb + vocalGain);
        const float p = juce::jlimit (-1.0f, 1.0f, t.pan);
        pt.gainL = g * (p <= 0.0f ? 1.0f : 1.0f - p);
        pt.gainR = g * (p >= 0.0f ? 1.0f : 1.0f + p);
        st->length = std::max (st->length, pt.start + static_cast<long> (buf->getNumSamples()));
        st->tracks.push_back (pt);
    }
    audioEngine.setPlayState (st);
}

// ---------------------------------------------------------------------------------------------
void Session::generate (int leadTrackId, const gen::GenerationOptions& options)
{
    const auto* lead = proj.findTrack (leadTrackId);
    if (lead == nullptr)
    {
        setStatus ("Voix principale introuvable");
        return;
    }
    auto it = renders.find (leadTrackId);
    const bool ready = it != renders.end() && it->second != nullptr && it->second->ok() && ! it->second->prepared.empty()
                       && pendingRenders.count (leadTrackId) == 0 && trackStatuses[leadTrackId].startsWith ("Pr");
    if (! ready)
    {
        pendingGeneration[leadTrackId] = options;
        setStatus ("Génération lancée dès que la voix principale est traitée…"_u8);
        return;
    }
    startGeneration (leadTrackId, options);
}

void Session::startGeneration (int leadTrackId, const gen::GenerationOptions& options)
{
    auto it = renders.find (leadTrackId);
    if (it == renders.end() || it->second == nullptr || ! it->second->ok())
    {
        setStatus ("Voix principale non traitée : génération impossible"_u8);
        return;
    }
    juce::String verr;
    if (! proj.saveVersion ("avant génération"_u8, verr))
        SV_LOG_WARN (kMod, verr);

    struct GenOut
    {
        juce::String name, detail, file;
        style::Role role;
        float pan, width;
    };
    auto leadRender = it->second;
    gen::LeadAnalysis la;
    la.prepared = leadRender->prepared;
    la.track = leadRender->track;
    la.va = leadRender->va;
    la.key = proj.key;
    la.tempo = proj.tempo;
    auto lead = std::make_shared<gen::LeadAnalysis> (std::move (la));
    auto opts = options;
    if (opts.adLibFolder == juce::File() && proj.adLibFolder.isNotEmpty())
        opts.adLibFolder = juce::File (proj.adLibFolder);
    const auto audioDir = proj.audioDir();
    const double sr = proj.sampleRate;
    const long start = leadRender->startSample;
    ++activeJobs;
    setStatus ("Génération des backs, harmonies, ad-libs…"_u8);
    juce::WeakReference<Session> weak (this);
    pool.addJob ([weak, lead, opts, audioDir, sr, leadTrackId, start]
    {
        auto outs = std::make_shared<std::vector<GenOut>>();
        auto errors = std::make_shared<juce::StringArray>();
        const auto tracks = gen::generate (*lead, sr, opts);
        int idx = 0;
        for (const auto& g : tracks)
        {
            GenOut o { g.name, g.detail, "gen_" + juce::String (leadTrackId) + "_" + juce::String (idx++) + "_" + uniqueStamp() + ".wav",
                       g.role, g.pan, g.width };
            juce::String err;
            if (audio::writeMonoWavFloat (audioDir.getChildFile (o.file), g.audio, sr, err))
                outs->push_back (o);
            else
                errors->add (g.name + " : " + err);
        }
        juce::MessageManager::callAsync ([weak, outs, errors, leadTrackId, start]
        {
            auto* s = weak.get();
            if (s == nullptr)
                return;
            --s->activeJobs;
            const auto* leadTrack = s->proj.findTrack (leadTrackId);
            if (leadTrack == nullptr)
                return;
            s->pushUndo ("Génération"_u8);
            const auto macros = leadTrack->macros;
            std::vector<int> old;
            for (const auto& t : s->proj.tracks)
                if (t.generatedFrom == leadTrackId)
                    old.push_back (t.id);
            for (int id : old)
            {
                s->proj.removeTrack (id);
                s->renders.erase (id);
            }
            for (const auto& o : *outs)
            {
                auto& t = s->proj.addTrack (o.role, o.name);
                t.generatedFrom = leadTrackId;
                t.detail = o.detail;
                t.genPan = o.pan;
                t.genWidth = o.width;
                t.sourceFile = o.file;
                t.sourceStart = start;
                t.macros = macros;
                t.macros.level = 0.5f;
                s->requestRender (t.id);
            }
            s->markDirty();
            s->setStatus (juce::String ((int) outs->size()) + " pistes générées"_u8
                          + (errors->isEmpty() ? juce::String() : " — erreurs : "_u8 + errors->joinIntoString ("; ")));
        });
    });
}

void Session::exportMix (const render::ExportOptions& options, std::function<void (const render::ExportReport&)> done)
{
    if (! pendingRenders.empty())
    {
        render::ExportReport rep;
        rep.error = "Des pistes sont encore en cours de traitement : réessaie dans un instant"_u8;
        done (rep);
        return;
    }
    auto snapshot = std::make_shared<const project::Project> (proj);
    auto rendersCopy = std::make_shared<const render::RenderSet> (renders);
    ++activeJobs;
    setStatus ("Export en cours…"_u8);
    juce::WeakReference<Session> weak (this);
    pool.addJob ([weak, snapshot, rendersCopy, options, done]
    {
        auto rep = std::make_shared<render::ExportReport> (render::exportProject (*snapshot, *rendersCopy, options));
        juce::MessageManager::callAsync ([weak, rep, done]
        {
            if (auto* s = weak.get())
            {
                --s->activeJobs;
                s->setStatus (rep->ok ? "Export terminé : "_u8 + rep->mixFile.getFileName() + " (" + juce::String (rep->master.outputLufs, 1) + " LUFS)"
                                      : "Export impossible : " + rep->error);
            }
            done (*rep);
        });
    });
}

std::shared_ptr<const render::TrackRender> Session::renderFor (int trackId) const
{
    auto it = renders.find (trackId);
    return it != renders.end() ? it->second : nullptr;
}

juce::String Session::trackStatus (int trackId) const
{
    auto it = trackStatuses.find (trackId);
    return it != trackStatuses.end() ? it->second : juce::String();
}

// ---------------------------------------------------------------------------------------------
void Session::pushUndo (const juce::String& label)
{
    undoStack.push_back ({ label, proj.toVar() });
    if (static_cast<int> (undoStack.size()) > kMaxUndo)
        undoStack.erase (undoStack.begin());
    redoStack.clear();
    renderMemo.clear();
}

void Session::restoreSnapshot (const juce::var& state)
{
    project::Project restored;
    restored.folder = proj.folder;
    juce::String err;
    if (! project::Project::fromVar (state, restored, err))
    {
        setStatus ("Restauration impossible : " + err);
        return;
    }
    restored.folder = proj.folder;
    const auto before = proj;
    proj = std::move (restored);

    // Recalcul des seules pistes modifiées.
    std::set<int> toRender;
    const bool globalChange = before.style != proj.style || before.key.root != proj.key.root || before.key.minor != proj.key.minor
                              || std::abs (before.tempo.bpm - proj.tempo.bpm) > 1.0e-6 || before.referenceFile != proj.referenceFile;
    for (const auto& t : proj.tracks)
        if (globalChange || trackJson (before, t.id) != trackJson (proj, t.id))
            toRender.insert (t.id);

    // Mise de côté des rendus à jour des pistes qui changent ou disparaissent (pour rétablir / annuler).
    const auto beforeGlobal = globalSignature (before);
    for (const auto& t : before.tracks)
    {
        if (proj.findTrack (t.id) != nullptr && toRender.count (t.id) == 0)
            continue;
        const auto r = renders.find (t.id);
        if (r == renders.end() || r->second == nullptr || pendingRenders.count (t.id) > 0
            || storedGeneration[t.id] != renderGeneration[t.id])
            continue;   // rendu absent ou périmé : rien à garder
        renderMemo.push_back ({ t.id, trackJson (before, t.id) + beforeGlobal, r->second });
        if (renderMemo.size() > kMaxMemoRenders)
            renderMemo.pop_front();
    }

    for (auto it = renders.begin(); it != renders.end();)
        it = proj.findTrack (it->first) == nullptr ? renders.erase (it) : std::next (it);
    if (globalChange)
        refreshContext();
    audioEngine.setTempo (proj.tempo.bpm, proj.tempo.firstBeatSec);

    const auto nowGlobal = globalSignature (proj);
    int reused = 0;
    for (int id : toRender)
    {
        const auto sig = trackJson (proj, id) + nowGlobal;
        const auto m = std::find_if (renderMemo.begin(), renderMemo.end(),
                                     [&] (const MemoRender& e) { return e.trackId == id && e.signature == sig; });
        if (m == renderMemo.end())
        {
            requestRender (id);
            continue;
        }
        renders[id] = m->render;
        storedGeneration[id] = ++renderGeneration[id];   // invalide un rendu en cours pour cette piste
        pendingRenders.erase (id);
        trackStatuses[id] = "Prêt"_u8;
        renderMemo.erase (m);
        ++reused;
    }
    SV_LOG_INFO (kMod, "Restauration : " + juce::String (static_cast<int> (toRender.size())) + " piste(s) modifiée(s), "
                       + juce::String (reused) + " rendu(s) réutilisé(s) sans recalcul, "
                       + juce::String (static_cast<int> (renderMemo.size())) + " en réserve");
    if (proj.findTrack (selectedTrackId) == nullptr)
        selectedTrackId = proj.leadTrackId();
    markDirty();
    launchAutoMix();
    rebuildPlayState();
}

void Session::undo()
{
    if (undoStack.empty())
        return;
    auto snap = undoStack.back();
    undoStack.pop_back();
    redoStack.push_back ({ snap.label, proj.toVar() });
    restoreSnapshot (snap.state);
    setStatus ("Annulé : "_u8 + snap.label);
}

void Session::redo()
{
    if (redoStack.empty())
        return;
    auto snap = redoStack.back();
    redoStack.pop_back();
    undoStack.push_back ({ snap.label, proj.toVar() });
    restoreSnapshot (snap.state);
    setStatus ("Rétabli : "_u8 + snap.label);
}
} // namespace sv::app
