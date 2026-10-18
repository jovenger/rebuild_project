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
    juce::Label title, roleLabel, assistantResult, treatmentLabel;
    juce::ComboBox treatmentBox;   // brut / style du projet / style au choix (instru : brute / creux sous la voix)
    bool treatmentForInstru = false;
    int treatmentProjectStyle = -1;   // style du projet affiché dans « Style du projet (…) »
    void fillTreatmentBox (bool instru);
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

    // Inserts VST3 de la piste : une ligne par plugin (nom = ouvrir, B = contourner, X = retirer).
    struct PluginRow
    {
        juce::TextButton open, bypass { "B" }, remove { "X" };
    };
    // Chaîne visible : une case par étape du style (clic = réglages dans la fenêtre de l'effet, clic droit = contourner /
    // revenir au style). Les inserts (effets en plus, VST3) viennent après.
    struct StageCase final : public juce::TextButton
    {
        std::function<void (bool popup)> onPress;
        void clicked (const juce::ModifierKeys& mods) override { if (onPress) onPress (mods.isPopupMenu()); }
    };
    juce::Label chainTitle;
    std::vector<std::unique_ptr<StageCase>> stageCases;
    bool chainVisible = false;
    void updateStageCases (const project::Track* t);
    style::VocalParams chainParams (const project::Track& t, bool withOverrides) const;
    void openStageEditor (const juce::String& stageId);
    void showStageMenu (const juce::String& stageId);
    juce::Label pluginsTitle;
    juce::TextButton addPluginBtn { "+ Effet / plugin..." };
    std::vector<std::unique_ptr<PluginRow>> pluginRows;
    void rebuildPluginRows (const project::Track& t);
    void modifyPlugins (const std::function<void (std::vector<plugins::PluginSlot>&)>& change, const juce::String& undoLabel);
    int shownTrack = -1;
    bool updating = false;
    bool dragging = false;   // glisser (ou molette, que JUCE présente comme un glisser) en cours
};
} // namespace sv::app
