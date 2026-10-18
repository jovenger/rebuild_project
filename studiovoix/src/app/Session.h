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
    bool newProject (const juce::String& name, juce::String& error);
    bool openProject (const juce::File& folderOrFile, bool preferAutosave, juce::String& error);
    bool save (juce::String& error);
    void importInstru (const juce::File& file);
    void importVoice (const juce::File& file, int trackId);
    void restoreVersion (const juce::String& versionFileName);

    // --- Pistes -----------------------------------------------------------------------------
    int addVocalTrack (style::Role role, const juce::String& name);
    void removeTrack (int trackId);
    /** Modifie une piste ; rerender = recalcul des effets ; undoLabel vide = pas d'étape d'annulation. */
    void updateTrack (int trackId, const std::function<void (project::Track&)>& change, bool rerender,
                      const juce::String& undoLabel);
    int selectedTrack() const { return selectedTrackId; }
    void selectTrack (int trackId);

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
    juce::String statusText() const { return status; }
    bool isBusy() const { return activeJobs > 0 || ! pendingRenders.empty(); }
    float vocalAutoGainDb() const { return mixState.autoMixApplied ? mixState.autoMix.vocalGainDb : 0.0f; }

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
    std::set<int> pendingRenders;
    juce::int64 pendingSinceMs = 0;
    std::map<int, gen::GenerationOptions> pendingGeneration;
    std::set<int> leadAwaitingProposal;
    int autoMixGeneration = 0;
    int activeJobs = 0;
    juce::String status;
    int selectedTrackId = -1;
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

    juce::ThreadPool pool;   // déclaré en dernier : détruit en premier (attend les tâches)

    JUCE_DECLARE_WEAK_REFERENCEABLE (Session)
    JUCE_DECLARE_NON_COPYABLE (Session)
};
} // namespace sv::app
