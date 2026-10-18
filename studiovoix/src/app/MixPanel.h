#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Mix auto, mastering, structure, banque d'ad-libs, historique des versions.
namespace sv::app
{
class MixPanel final : public juce::Component
{
public:
    explicit MixPanel (Session& session);
    void refresh();
    void resized() override;
    void paint (juce::Graphics& g) override;

private:
    Session& session;
    juce::ToggleButton autoMix { "Mix automatique (voix / instru)" },
        master { juce::String (juce::CharPointer_UTF8 ("Mastering automatique à l'export")) };
    juce::Slider ducking;
    juce::Label duckingL, targetL, sectionsL, versionsL, adlibL, info;
    juce::ComboBox target, sections, versions;
    juce::TextButton copySection { "Copier la voix vers les sections semblables" }, restore { "Restaurer" },
        adlibBtn { juce::String (juce::CharPointer_UTF8 ("Banque d'ad-libs...")) }, reanalyse { "Analyser à nouveau l'instru"_u8 };
    std::unique_ptr<juce::FileChooser> chooser;
    bool updating = false;
};
} // namespace sv::app
