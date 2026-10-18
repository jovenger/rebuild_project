#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "LyricsPanel.h"
#include "MixPanel.h"
#include "RemixPanel.h"
#include "Session.h"
#include "TimelineView.h"
#include "TransportBar.h"

namespace sv::app
{
class MainComponent final : public juce::Component, private juce::ChangeListener, private juce::Timer
{
public:
    explicit MainComponent (Session& session);
    ~MainComponent() override;

    /** Ouvre le dernier projet (avec proposition de récupération) ou en crée un nouveau. */
    void startup (const juce::String& commandLine);

    void resized() override;
    void paint (juce::Graphics& g) override;
    bool keyPressed (const juce::KeyPress& key) override;

private:
    void changeListenerCallback (juce::ChangeBroadcaster*) override;
    void timerCallback() override;
    void refreshAll();
    void doNew();
    void doOpen();
    void doSave();
    void doImportInstru();
    void doImportVoice();
    void doRecord();
    void openProjectWithRecovery (const juce::File& folder);
    void createDefaultProject();
    void showMessage (const juce::String& title, const juce::String& text);
    void startSelfTest (const juce::StringArray& args);

    Session& session;
    TransportBar transport;
    TimelineView timeline;
    juce::TabbedComponent tabs { juce::TabbedButtonBar::TabsAtTop };
    RemixPanel* remix = nullptr;
    LyricsPanel* lyrics = nullptr;
    MixPanel* mixPanel = nullptr;
    juce::Label statusBar;
    juce::TooltipWindow tooltips { this, 700 };
    std::unique_ptr<juce::FileChooser> chooser;
    std::unique_ptr<juce::Timer> selfTest;
    int frame = 0;
};
} // namespace sv::app
