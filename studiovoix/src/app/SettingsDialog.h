#pragma once

#include <juce_audio_utils/juce_audio_utils.h>

#include "Session.h"

// Paramètres : carte son, latence (calibrage + décalage manuel), écoute, niveau du micro, IA (clés facultatives).
namespace sv::app
{
class SettingsDialog final : public juce::Component, private juce::Timer, private juce::ChangeListener
{
public:
    explicit SettingsDialog (Session& session);
    ~SettingsDialog() override;
    void resized() override;
    void paint (juce::Graphics& g) override;

    static void show (Session& session);

private:
    void timerCallback() override;
    void changeListenerCallback (juce::ChangeBroadcaster*) override;
    void refreshLatency();
    void refreshPluginStatus();

    Session& session;
    juce::AudioDeviceSelectorComponent deviceSelector;
    juce::Label latencyInfo, offsetL, calibResult, levelResult, inputL, trimL, countL, aiTitle, aiInfo, textKeyL, modelL, musicKeyL, updateL, pluginTitle, pluginStatus;
    juce::Slider offset, trim;
    void refreshCalibrationText();

    juce::TextButton calibrate { "Calibrer la latence" }, resetCalib { juce::String (juce::CharPointer_UTF8 ("Réinitialiser")) }, levelTest { "Test du niveau du micro (5 s)" }, openLogs { "Ouvrir le dossier des journaux" },
        closeBtn { "Fermer" }, scanPlugins { "Rechercher les plugins VST3" }, pluginFolderBtn { "Dossier en plus..." };
    juce::ToggleButton monitoring { "M'entendre à travers le logiciel (sinon : retour direct du micro, 0 ms)"_u8 },
        propose { "Proposer la génération des backs après chaque prise"_u8 }, aiEnabled { "Activer l'IA connectée (facultatif)"_u8 };
    juce::ComboBox inputMode;
    juce::TextEditor textKey, model, musicKey, updateToken;
    bool levelTesting = false;
    juce::int64 levelTestEnd = 0;
    float levelTestPeak = 0.0f;
};
} // namespace sv::app
