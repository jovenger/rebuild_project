#pragma once

#include <juce_events/juce_events.h>

#include "AppSettings.h"
#include "AudioEngine.h"
#include "core/project/Renderer.h"

#include <deque>
#include <set>

// Contrôleur central : projet + rendus en tâche de fond + moteur audio + annuler/rétablir + sauvegarde auto.
// Toutes les méthodes publiques s'appellent depuis le thread UI.
namespace sv::app
{
class Session final : public juce::ChangeBroadcaster, private juce::Timer
{
public:
    Session (AudioEngine& engine, AppSettings& settings);
    ~Session() override;

    project::Project& project() { return proj; }
    const project::Project& project() const { return proj; }
    AudioEngine& engine() { return audioEngine; }
    AppSettings& settings() { return appSettings; }

    // --- Fichiers ---------------------------------------------------------------------------
    bool newProject (const juce::String& name, juce::String& error, style::Style projectStyle = style::Style::Rap);
    bool openProject (const juce::File& folderOrFile, bool preferAutosave, juce::String& error);
    bool save (juce::String& error);
    void importInstru (const juce::File& file);
    void importVoice (const juce::File& file, int trackId, double startSec = 0.0);
    /** Glisser-déposer : crée une piste du type choisi avec le fichier (une seule étape d'annulation).
        Instru : remplace l'instru du projet. Renvoie l'id de la piste, -1 si le fichier est illisible. */
    int importAsNewTrack (const juce::File& file, style::Role role, const juce::String& name, double startSec);
    void restoreVersion (const juce::String& versionFileName);

    // --- Pistes -----------------------------------------------------------------------------
    int addVocalTrack (style::Role role, const juce::String& name);
    /** Ajoute une prise déjà décodée à une piste (sans étape d'annulation). */
    bool addTakeFromAudio (int trackId, const Mono& data, double startSec, juce::String& error);
    /** « Nouvelle piste » : réglages auto selon le type, piste sélectionnée et armée (le micro enregistre dessus). */
    int addUserTrack (style::Role role, const juce::String& name);
    /** Nom libre pour une nouvelle piste de ce type ("Back 1", "Back 2"…). */
    juce::String nextTrackName (style::Role role) const;
    void removeTrack (int trackId);
    /** Panneau de la piste : brut (aucun effet, hors mix auto) ou traité dans un style (vide = style du projet).
        Pour l'instru : non brute = creux sous la voix (mix auto). */
    void setTrackTreatment (int trackId, bool raw, const juce::String& trackStyleId);
    /** Inserts VST3 d'une piste (ajout, retrait, état, contournement) ; rendu recalculé. */
    void setTrackPlugins (int trackId, std::vector<plugins::PluginSlot> slots, const juce::String& undoLabel);
    /** Correction automatique sur toutes les pistes enregistrées / importées (pas l'instru, pas les générées). */
    void correctAllTracks();
    /** Bouton REC d'une piste : une seule piste armée à la fois ; -1 = désarmer.
        Cliquer sur une piste enregistrable l'arme aussi (selectTrack). */
    void armTrack (int trackId);
    int armedTrack() const { return proj.armedTrackId; }
    /** Piste qui recevra la prochaine prise : armée, sinon sélectionnée (si enregistrable), sinon voix principale. */
    int recordTargetTrack() const;
    /** Modifie une piste ; rerender = recalcul des effets ; undoLabel vide = pas d'étape d'annulation. */
    void updateTrack (int trackId, const std::function<void (project::Track&)>& change, bool rerender,
                      const juce::String& undoLabel);
    int selectedTrack() const { return selectedTrackId; }
    /** Clic simple : sélectionne (et arme) la piste. Ctrl : ajoute / retire. Maj : étend depuis la dernière. */
    void selectTrack (int trackId, bool addToSelection = false, bool extendRange = false);
    bool isTrackSelected (int trackId) const { return selectedTracks.count (trackId) > 0; }
    const std::set<int>& selectedTrackIds() const { return selectedTracks; }
    /** Déplace l'audio d'une piste sur la timeline (glisser du bloc) : takeId = prise, -1 = fichier source
        (instru, piste générée). Le début ne passe jamais avant 0. */
    void moveTrackAudio (int trackId, int takeId, double deltaSec);
    /** Cale l'audio de la piste au début du morceau (la première prise à 0 s, les autres gardent leurs écarts). */
    void moveTrackAudioToStart (int trackId);
    /** Supprime plusieurs pistes en une seule étape d'annulation. */
    void removeTracks (const std::vector<int>& trackIds);

    // --- Projet -----------------------------------------------------------------------------
    void setStyle (style::Style s);
    void setKey (const MusicalKey& key);
    void setTempo (double bpm);
    void updateProject (const std::function<void (project::Project&)>& change, bool rerenderVocals, const juce::String& undoLabel);
    void setReferenceTrack (const juce::File& file);
    void addMarkerAtPlayhead();
    void copySectionToSimilar (int trackId, int sectionIndex);
    void reanalyseInstru();

    // --- Transport --------------------------------------------------------------------------
    double positionSec() const;
    void setPositionSec (double sec);
    void togglePlay();
    void stopTransport();
    /** Paroles : une étape d'annulation par rafale de frappe, sans recalcul. */
    void setLyrics (const juce::String& text);
    void setLoopRegion (bool enabled, double startSec, double endSec);
    double deviceRate() const;

    // --- Enregistrement ---------------------------------------------------------------------
    bool startRecording (int trackId, bool punch, double punchInSec, double punchOutSec, juce::String& error);
    void stopRecording();
    bool isRecording() const { return audioEngine.isRecording(); }
    std::function<void (int trackId)> onLeadTakeReady;   // la voix principale vient d'être traitée après une prise

    // --- Rendu / génération / export --------------------------------------------------------
    void requestRender (int trackId);
    void renderAll();
    void generate (int leadTrackId, const gen::GenerationOptions& options);
    void exportMix (const render::ExportOptions& options, std::function<void (const render::ExportReport&)> done);

    std::shared_ptr<const render::TrackRender> renderFor (int trackId) const;
    juce::String trackStatus (int trackId) const;
    /** Alertes de l'ingénieur du son sur le rendu actuel : sature, monte en flèche, plus fort que la voix principale. */
    juce::String trackWarnings (int trackId) const;
    struct TrackMetrics { float peakDb = -120.0f; float rawPeakDb = -120.0f; double lufs = -120.0; };
    juce::String statusText() const { return status; }
    bool isBusy() const { return activeJobs > 0 || ! pendingRenders.empty(); }
    float vocalAutoGainDb() const { return mixState.autoMixApplied ? mixState.autoMix.vocalGainDb : 0.0f; }
    /** Orchestre : gain automatique de la piste selon son rôle (0 pour la voix principale, l'instru et les pistes brutes). */
    float autoTrackGainDb (int trackId) const { return mixState.autoTrackGain (trackId); }
    double mixLufs() const { return mixState.mixLufs; }
    juce::String balanceReport() const { return mixState.balanceReport; }
    /** Crête (linéaire) jouée sur cette piste depuis le dernier appel ; 0 si rien n'est joué. */
    float trackPeakNow (int trackId);

    // --- Annuler / rétablir -----------------------------------------------------------------
    bool canUndo() const { return ! undoStack.empty(); }
    bool canRedo() const { return ! redoStack.empty(); }
    juce::String undoLabel() const { return undoStack.empty() ? juce::String() : undoStack.back().label; }
    void undo();
    void redo();

    void rebuildPlayState();
    void setStatus (const juce::String& text);
    void markDirty();

private:
    struct Snapshot
    {
        juce::String label;
        juce::var state;
    };

    void timerCallback() override;
    void pushUndo (const juce::String& label);
    void restoreSnapshot (const juce::var& state);
    void launchRender (int trackId);
    void onRenderDone (int trackId, int generation, std::shared_ptr<const render::TrackRender> result);
    void launchAutoMix();
    void startGeneration (int leadTrackId, const gen::GenerationOptions& options);
    void refreshContext();
    void afterProjectLoaded();
    /** Avant de remplacer le projet : termine une prise, sauvegarde auto, ignore les tâches de l'ancien projet. */
    void beforeProjectChange();
    /** Ajoute une prise terminée (ou récupérée après plantage) à sa piste ; false si elle n'a pas pu l'être. */
    bool addRecordedTake (const AudioEngine::RecordedTake& take, int trackId, const juce::String& deviceKey, bool recovered);
    /** Prises interrompues (plantage, coupure) retrouvées grâce à leur fichier de description. */
    void recoverInterruptedTakes();
    void handleSampleRateChange (double oldRate, double newRate);
    long toDevice (long projectSamples) const;
    long toProject (long deviceSamples) const;

    AudioEngine& audioEngine;
    AppSettings& appSettings;
    project::Project proj;
    render::AudioCache cache;
    render::RenderSet renders;
    render::MixState mixState;
    std::shared_ptr<const dsp::AnalysisContext> context;

    std::map<int, int> renderGeneration;
    std::map<int, juce::String> trackStatuses;
    std::map<int, TrackMetrics> trackMetrics;   // crête et sonie du dernier rendu de chaque piste
    std::map<int, std::shared_ptr<std::atomic<float>>> trackPeaks;   // crêtes de lecture, écrites par le moteur audio
    std::set<int> pendingRenders;
    juce::int64 pendingSinceMs = 0;
    std::map<int, gen::GenerationOptions> pendingGeneration;
    std::set<int> leadAwaitingProposal;
    int autoMixGeneration = 0;
    int activeJobs = 0;
    juce::String status;
    int selectedTrackId = -1;
    std::set<int> selectedTracks;   // sélection multiple (contient selectedTrackId quand il est valide)
    bool dirty = false;
    juce::int64 lastAutosaveMs = 0;

    std::vector<Snapshot> undoStack, redoStack;

    // Rendus mis de côté par annuler / rétablir : réutilisés si la piste et le contexte sont identiques,
    // vidés dès que « rétablir » n'est plus possible (nouvelle action, autre projet).
    struct MemoRender
    {
        int trackId = -1;
        juce::String signature;
        std::shared_ptr<const render::TrackRender> render;
    };
    std::deque<MemoRender> renderMemo;
    std::map<int, int> storedGeneration;   // génération du rendu actuellement dans renders

    int epoch = 0;                        // change avec le projet : les résultats des anciennes tâches sont ignorés
    int autoMixJobs = 0;                  // part de activeJobs due au mix auto (l'export le recalcule lui-même)
    juce::int64 lastLyricsEditMs = 0;     // regroupe la frappe des paroles en une étape d'annulation
    int instruAnalysisGeneration = 0;     // seule la dernière analyse d'instru demandée est appliquée
    juce::String contextRefPath;          // fichier dont le spectre de référence est dans context

    // Enregistrement en cours
    int recordingTrackId = -1;
    juce::String recordingDeviceKey;
    juce::File recordingSidecar;          // description de la prise (récupération après plantage)

    // Boucle (en secondes, réappliquée si la fréquence de la carte change)
    bool loopEnabled = false;
    double loopStartSec = 0.0, loopEndSec = 0.0;

    // Lecture : instru avec creux (partagé, sans copie) et tampons rééchantillonnés à la fréquence de la carte
    std::shared_ptr<const Stereo> duckedInstruShared;
    struct ResampledBuffer
    {
        std::weak_ptr<const Stereo> source;
        double rate = 0.0;
        std::shared_ptr<const Stereo> buffer;
    };
    std::map<const Stereo*, ResampledBuffer> resampleCache;

    juce::ThreadPool pool;   // déclaré en dernier : détruit en premier (attend les tâches)

    JUCE_DECLARE_WEAK_REFERENCEABLE (Session)
    JUCE_DECLARE_NON_COPYABLE (Session)
};
} // namespace sv::app
