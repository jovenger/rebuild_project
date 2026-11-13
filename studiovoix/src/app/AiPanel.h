#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"
#include "core/ai/AiFeatures.h"
#include "core/analysis/BeatLibrary.h"

// Onglet "IA" : assistant avancé, diagnostic du mix, aide à l'écriture, style sur mesure, recherche et
// génération d'instru. Tout fonctionne en local sans clé (avec moins de finesse) ; l'IA connectée affine.
namespace sv::app
{
class AiPanel final : public juce::Component
{
public:
    explicit AiPanel (Session& session);
    void refresh();
    void resized() override;
    void paint (juce::Graphics& g) override;

private:
    class Content;
    ai::AiSettings aiSettings() const;
    void runAsync (const juce::String& what, std::function<std::function<void()> ()> job);
    void setBusy (bool b, const juce::String& what);

    Session& session;
    std::unique_ptr<Content> content;
    juce::Viewport viewport;
    bool busy = false;
};
} // namespace sv::app
