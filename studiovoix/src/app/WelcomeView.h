#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Écran d'accueil (par-dessus le studio) : grandes cartes « Nouveau projet », « Ouvrir », « Reprendre », puis les
// projets récents du dossier Projets (nom, date, pistes). Échap ou « Reprendre » le ferme ; « Accueil » le rouvre.
namespace sv::app
{
class WelcomeView final : public juce::Component
{
public:
    explicit WelcomeView (Session& session);
    void refresh();   // relit les projets récents (dossier Projets, les 8 plus récents)
    void paint (juce::Graphics& g) override;
    void resized() override;
    void mouseMove (const juce::MouseEvent& e) override;
    void mouseExit (const juce::MouseEvent& e) override;
    void mouseDown (const juce::MouseEvent& e) override;
    bool keyPressed (const juce::KeyPress& key) override;

    std::function<void()> onNew, onOpen, onClose;
    std::function<void (const juce::File&)> onOpenProject;

private:
    enum class Action { New, Open, Resume, Recent };
    struct Card
    {
        juce::Rectangle<int> bounds;
        juce::String title, subtitle, detail;
        Action action = Action::Recent;
        juce::File folder;
        bool primary = false;
    };
    std::vector<Card> cards;
    int hover = -1;
    Session& session;
    juce::TextButton folderBtn { "Dossier des projets..." };
    int cardAt (juce::Point<int> p) const;
    void activate (const Card& c);
};
} // namespace sv::app
