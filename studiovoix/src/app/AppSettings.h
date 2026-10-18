#pragma once

#include <juce_data_structures/juce_data_structures.h>

#include "core/style/StyleProfiles.h"

// Réglages persistants de l'application (fichier StudioVoix.settings dans le dossier de données utilisateur).
namespace sv::app
{
class AppSettings
{
public:
    AppSettings();

    juce::PropertiesFile& props() { return *file; }

    // Audio
    std::unique_ptr<juce::XmlElement> audioDeviceState();
    void setAudioDeviceState (const juce::XmlElement* xml);
    int manualLatencyOffsetMs() const;          // ajouté au recalage (peut être négatif)
    void setManualLatencyOffsetMs (int ms);
    int calibratedOffsetSamples() const;        // mesuré par le calibrage, 0 sinon
    void setCalibratedOffsetSamples (int s);
    int inputChannelMode() const;               // 0 = auto (moyenne), 1 = entrée 1, 2 = entrée 2
    void setInputChannelMode (int m);
    float inputTrimDb() const;
    void setInputTrimDb (float db);
    bool softwareMonitoring() const;            // false : on s'écoute par le micro (retour direct)
    void setSoftwareMonitoring (bool b);

    // Enregistrement
    int countdownBars() const;
    void setCountdownBars (int bars);
    bool metronome() const;
    void setMetronome (bool b);
    bool proposeGenerationAfterTake() const;
    void setProposeGenerationAfterTake (bool b);

    // Projet
    juce::File lastProject() const;
    void setLastProject (const juce::File& f);
    juce::File adLibFolder() const;
    void setAdLibFolder (const juce::File& f);
    juce::File beatFolder() const;
    void setBeatFolder (const juce::File& f);

    // "Mon son" : curseurs préférés par style
    bool hasUserPreset (style::Style s) const;
    style::Macros userPreset (style::Style s) const;
    void setUserPreset (style::Style s, const style::Macros& m);

    // IA (facultatif) : clés stockées uniquement sur ce PC
    juce::String textAiKey() const;
    void setTextAiKey (const juce::String& key);
    juce::String textAiModel() const;
    void setTextAiModel (const juce::String& model);
    juce::String musicAiKey() const;
    void setMusicAiKey (const juce::String& key);
    bool aiEnabled() const;
    void setAiEnabled (bool b);

    void save();
    static juce::File logsFolder();

private:
    std::unique_ptr<juce::PropertiesFile> file;
};
} // namespace sv::app
