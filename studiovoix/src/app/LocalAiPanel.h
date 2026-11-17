#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"
#include "core/ai/LocalTools.h"

// Onglet « IA locale » (édition StudioVoix IA) : une ligne par outil libre (nom, à quoi ça sert, état, taille),
// Installer / Supprimer, progression du téléchargement, journal. Les téléchargements se font en arrière-plan.
namespace sv::app
{
class LocalAiPanel final : public juce::Component, private juce::Timer
{
public:
    explicit LocalAiPanel (Session& session);
    ~LocalAiPanel() override;
    void refresh();
    void resized() override;
    void paint (juce::Graphics& g) override;

private:
    struct Row
    {
        const ai::local::ToolDef* def = nullptr;
        juce::Label name, info, state;
        juce::TextButton install { "Installer" }, remove { "Supprimer" };
        std::shared_ptr<ai::local::Progress> progress;   // non nul pendant un téléchargement
        juce::String lastError;
    };
    std::vector<std::unique_ptr<Row>> rows;
    juce::Label title, intro, folderLabel;
    juce::TextButton folderBtn { "Ouvrir le dossier des outils" };
    juce::TextButton separateBtn { "Séparer l'instru en 4 pistes (Demucs)" };
    juce::Label separateInfo;
    Session& session;
    juce::ThreadPool pool { 1 };
    void timerCallback() override;
    void startInstall (Row& row);
};
} // namespace sv::app
