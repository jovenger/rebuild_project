#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Paroles + prompteur : la ligne en cours suit la tête de lecture (N mesures par ligne).
namespace sv::app
{
class Prompter final : public juce::Component
{
public:
    explicit Prompter (Session& s) : session (s) {}
    void paint (juce::Graphics& g) override;
    void update();

private:
    Session& session;
    int lastLine = -2;
    int lastWord = -2;
};

class LyricsPanel final : public juce::Component
{
public:
    explicit LyricsPanel (Session& session);
    void refresh();
    void updatePrompter() { prompter.update(); }
    void resized() override;
    void paint (juce::Graphics& g) override;

private:
    Session& session;
    juce::TextEditor editor;
    juce::ComboBox barsPerLine;
    juce::Label barsLabel, startLabel;
    juce::TextButton startHere { juce::String (juce::CharPointer_UTF8 ("Les paroles démarrent ici")) };
    juce::TextButton recognize { "Reconnaître les paroles (IA)"_u8 };   // édition IA
    Prompter prompter;
    bool updating = false;
};
} // namespace sv::app
