#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "AiPanel.h"
#include "LyricsPanel.h"
#include "MixPanel.h"
#include "RemixPanel.h"
#include "Session.h"
#include "TimelineView.h"
#include "TransportBar.h"
#include "UpdateManager.h"

namespace sv::app
{
class MainComponent final : public juce::Component, public juce::FileDragAndDropTarget, private juce::ChangeListener, private juce::Timer
{
public:
    explicit MainComponent (Session& session);
    ~MainComponent() override;

    /** Ouvre le dernier projet (avec proposition de récupération) ou en crée un nouveau. */
    void startup (const juce::String& commandLine);

    void resized() override;
    void paint (juce::Graphics& g) override;
    bool keyPressed (const juce::KeyPress& key) override;
    void paintOverChildren (juce::Graphics& g) override;

    // Glisser-déposer de fichiers audio (MP3, WAV…) : une nouvelle piste par fichier.
    bool isInterestedInFileDrag (const juce::StringArray& files) override;
    void fileDragEnter (const juce::StringArray& files, int x, int y) override;
    void fileDragExit (const juce::StringArray& files) override;
    void filesDropped (const juce::StringArray& files, int x, int y) override;

private:
    void changeListenerCallback (juce::ChangeBroadcaster*) override;
    void timerCallback() override;
    void proposeGeneration (int trackId);
    int pendingProposalTrack = -1;
    void refreshAll();
    void doNew();
    void doOpen();
    void doSave();
    void doImportInstru();
    void doImportVoice();
    void doRecord();
    /** atStartup : en cas d'échec, un projet vide est créé (sinon le projet courant est conservé). */
    void openProjectWithRecovery (const juce::File& folder, bool atStartup = false);
    void createDefaultProject();
    void showWelcome();
    void hideWelcome();
    void showMessage (const juce::String& title, const juce::String& text);
    void startSelfTest (const juce::StringArray& args);
    void onUpdateClicked();
    void onUpdateStateChanged();
    void installUpdateAndRestart();

    Session& session;
    UpdateManager updates { session.settings() };
    TransportBar transport;
    TimelineView timeline;
    juce::TabbedComponent tabs { juce::TabbedButtonBar::TabsAtTop };
    RemixPanel* remix = nullptr;
    LyricsPanel* lyrics = nullptr;
    MixPanel* mixPanel = nullptr;
    AiPanel* aiPanel = nullptr;
    juce::Label statusBar;
    juce::TextButton homeBtn { "Accueil" };
    std::unique_ptr<class WelcomeView> welcome;   // écran d'accueil (cartes), par-dessus le studio
    juce::TooltipWindow tooltips { this, 700 };
    std::unique_ptr<juce::FileChooser> chooser;
    std::unique_ptr<juce::Timer> selfTest;
    int frame = 0;
    bool fileDragActive = false;
    int lastSelectedTrack = -1;   // clic sur une autre piste -> onglet de ses effets
};
} // namespace sv::app
