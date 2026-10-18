#include "AppSettings.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "Settings";

    juce::PropertiesFile::Options options()
    {
        juce::PropertiesFile::Options o;
        o.applicationName = "StudioVoix";
        o.filenameSuffix = ".settings";
        o.folderName = "StudioVoix";
        o.osxLibrarySubFolder = "Application Support";
        o.storageFormat = juce::PropertiesFile::storeAsXML;
        o.millisecondsBeforeSaving = 500;
        return o;
    }
}

AppSettings::AppSettings()
    : file (std::make_unique<juce::PropertiesFile> (options()))
{
    SV_LOG_INFO (kMod, "Réglages : "_u8 + file->getFile().getFullPathName());
}

juce::File AppSettings::logsFolder()
{
    return juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory).getChildFile ("StudioVoix").getChildFile ("logs");
}

std::unique_ptr<juce::XmlElement> AppSettings::audioDeviceState() { return file->getXmlValue ("audioDevice"); }
void AppSettings::setAudioDeviceState (const juce::XmlElement* xml)
{
    if (xml != nullptr)
        file->setValue ("audioDevice", xml);
}

int AppSettings::manualLatencyOffsetMs() const { return juce::jlimit (-200, 200, file->getIntValue ("latencyOffsetMs", 0)); }
void AppSettings::setManualLatencyOffsetMs (int ms) { file->setValue ("latencyOffsetMs", juce::jlimit (-200, 200, ms)); }
int AppSettings::calibratedOffsetSamples() const { return juce::jlimit (-48000, 48000, file->getIntValue ("calibratedOffset", 0)); }
void AppSettings::setCalibratedOffsetSamples (int s) { file->setValue ("calibratedOffset", s); }
int AppSettings::inputChannelMode() const { return juce::jlimit (0, 2, file->getIntValue ("inputChannelMode", 0)); }
void AppSettings::setInputChannelMode (int m) { file->setValue ("inputChannelMode", juce::jlimit (0, 2, m)); }
float AppSettings::inputTrimDb() const { return static_cast<float> (juce::jlimit (-24.0, 24.0, file->getDoubleValue ("inputTrimDb", 0.0))); }
void AppSettings::setInputTrimDb (float db) { file->setValue ("inputTrimDb", juce::jlimit (-24.0f, 24.0f, db)); }
bool AppSettings::softwareMonitoring() const { return file->getBoolValue ("softwareMonitoring", false); }
void AppSettings::setSoftwareMonitoring (bool b) { file->setValue ("softwareMonitoring", b); }

int AppSettings::countdownBars() const { return juce::jlimit (0, 4, file->getIntValue ("countdownBars", 1)); }
void AppSettings::setCountdownBars (int bars) { file->setValue ("countdownBars", juce::jlimit (0, 4, bars)); }
bool AppSettings::metronome() const { return file->getBoolValue ("metronome", false); }
void AppSettings::setMetronome (bool b) { file->setValue ("metronome", b); }
bool AppSettings::proposeGenerationAfterTake() const { return file->getBoolValue ("proposeGeneration", true); }
void AppSettings::setProposeGenerationAfterTake (bool b) { file->setValue ("proposeGeneration", b); }

juce::File AppSettings::lastProject() const { return juce::File (file->getValue ("lastProject")); }
void AppSettings::setLastProject (const juce::File& f) { file->setValue ("lastProject", f.getFullPathName()); }
juce::File AppSettings::adLibFolder() const { return juce::File (file->getValue ("adLibFolder")); }
void AppSettings::setAdLibFolder (const juce::File& f) { file->setValue ("adLibFolder", f.getFullPathName()); }
juce::File AppSettings::beatFolder() const { return juce::File (file->getValue ("beatFolder")); }
void AppSettings::setBeatFolder (const juce::File& f) { file->setValue ("beatFolder", f.getFullPathName()); }

bool AppSettings::hasUserPreset (style::Style s) const { return file->containsKey ("preset_" + style::styleId (s)); }

style::Macros AppSettings::userPreset (style::Style s) const
{
    juce::var v;
    if (juce::JSON::parse (file->getValue ("preset_" + style::styleId (s)), v).failed())
        return {};
    return style::Macros::fromVar (v);
}

void AppSettings::setUserPreset (style::Style s, const style::Macros& m)
{
    file->setValue ("preset_" + style::styleId (s), juce::JSON::toString (m.toVar(), true));
    SV_LOG_INFO (kMod, "\"Mon son\" enregistré pour "_u8 + style::styleName (s));
}

juce::String AppSettings::textAiKey() const { return file->getValue ("textAiKey"); }
void AppSettings::setTextAiKey (const juce::String& key) { file->setValue ("textAiKey", key.trim()); }
juce::String AppSettings::textAiModel() const { return file->getValue ("textAiModel", "claude-opus-5-5"); }
void AppSettings::setTextAiModel (const juce::String& model) { file->setValue ("textAiModel", model.trim()); }
juce::String AppSettings::musicAiKey() const { return file->getValue ("musicAiKey"); }
void AppSettings::setMusicAiKey (const juce::String& key) { file->setValue ("musicAiKey", key.trim()); }
bool AppSettings::aiEnabled() const { return file->getBoolValue ("aiEnabled", false); }
void AppSettings::setAiEnabled (bool b) { file->setValue ("aiEnabled", b); }

void AppSettings::save()
{
    if (! file->saveIfNeeded())
        SV_LOG_ERROR (kMod, "Échec d'écriture des réglages : "_u8 + file->getFile().getFullPathName());
}
} // namespace sv::app
