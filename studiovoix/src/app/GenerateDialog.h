#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Fenêtre de génération : cases pré-cochées selon le style, une piste par élément généré.
namespace sv::app
{
class GenerateDialog final : public juce::Component
{
public:
    GenerateDialog (Session& session, int leadTrackId);
    void resized() override;
    void paint (juce::Graphics& g) override;

    static void show (Session& session, int leadTrackId);

private:
    void applyDefaults();
    void launch();
    void close();

    Session& session;
    const int leadId;
    juce::Label title, styleInfo;
    juce::ToggleButton doublesOn { "Doublage(s)" }, harmoniesOn { "Harmonie(s)" }, backsOn { juce::String (juce::CharPointer_UTF8 ("Backs sur les mots clés (fins de phrases)")) },
        adlibsOn { "Ad-libs automatiques" }, ambianceOn { "Piste d'ambiance" };
    juce::ComboBox doublesCount, harmoniesCount, syllables, ambianceType;
    juce::Slider density;
    juce::Label densityLabel, adlibInfo;
    juce::TextButton generateBtn { juce::String (juce::CharPointer_UTF8 ("Générer")) }, cancelBtn { "Annuler" }, defaultsBtn { "Réglages du style"_u8 };
};
} // namespace sv::app
