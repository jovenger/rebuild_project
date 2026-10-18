#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Panneau "Voix IA" de la piste sélectionnée : curseurs simples, options, assistant texte, "Mon son".
namespace sv::app
{
class RemixPanel final : public juce::Component
{
public:
    explicit RemixPanel (Session& session);
    void refresh();
    void resized() override;
    void paint (juce::Graphics& g) override;

private:
    void setupMacro (juce::Slider& s, juce::Label& l, const juce::String& name, const juce::String& tip);
    void commitMacros (const juce::String& undoLabel);
    void applyAssistant();

    Session& session;
    juce::Label title, roleLabel, assistantResult;
    juce::TextEditor report;   // lecture seule, défilant : état de la piste + effets appliqués par le style
    juce::ComboBox roleBox, compBox;
    juce::Slider autotune, presence, space, energy, level, timing;
    juce::Label autotuneL, presenceL, spaceL, energyL, levelL, timingL;
    juce::ToggleButton cleaning { "Nettoyage automatique (bruit, souffle, plosives)" },
        referenceEq { juce::String (juce::CharPointer_UTF8 ("EQ d'après le morceau de référence")) },
        rawListen { "Écouter la voix brute (A/B)"_u8 };
    juce::TextButton referenceBtn { juce::String (juce::CharPointer_UTF8 ("Morceau de référence...")) },
        savePresetBtn { "Sauver mon son" }, loadPresetBtn { "Charger mon son" }, resetBtn { juce::String (juce::CharPointer_UTF8 ("Réglages du style")) },
        generateBtn { juce::String (juce::CharPointer_UTF8 ("Générer backs / harmonies...")) }, assistantBtn { "Appliquer" };
    juce::TextEditor assistantText;
    std::unique_ptr<juce::FileChooser> chooser;
    int shownTrack = -1;
    bool updating = false;
    bool dragging = false;   // glisser (ou molette, que JUCE présente comme un glisser) en cours
};
} // namespace sv::app
