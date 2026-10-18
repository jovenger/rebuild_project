#pragma once

#include "../Types.h"

#include <juce_audio_processors_headless/juce_audio_processors_headless.h>

#include <functional>
#include <memory>
#include <vector>

// Chaîne d'inserts VST3 d'une piste, appliquée hors temps réel après les effets du style.
// Le cœur ne connaît pas les formats de plugins : l'application fournit une fabrique d'instances
// (setInstanceFactory) ; sans fabrique, les slots sont ignorés et signalés.
namespace sv::plugins
{
struct PluginSlot
{
    juce::String identifier;   // identifiant JUCE du plugin (format + fichier + id)
    juce::String name;         // nom affiché
    juce::MemoryBlock state;   // état sauvegardé (getStateInformation)
    bool bypass = false;

    juce::var toVar() const;
    static PluginSlot fromVar (const juce::var& v);
};

/** Réglage manuel d'une étape de la chaîne du style (case de la chaîne visible d'une piste) : étape contournée
    et / ou réglages (JSON des paramètres de l'effet intégré correspondant ; vide = réglages du style). */
struct StageOverride
{
    bool bypass = false;
    juce::MemoryBlock state;

    juce::var toVar() const;
    static StageOverride fromVar (const juce::var& v);
};

/** Crée une instance prête (buses stéréo, non temps réel) ; nullptr + err si impossible. */
using InstanceFactory = std::function<std::unique_ptr<juce::AudioProcessor> (const PluginSlot& slot, double sampleRate,
                                                                              int blockSize, juce::String& error)>;
void setInstanceFactory (InstanceFactory factory);
bool hasInstanceFactory();

/** Applique la chaîne (slots non contournés) sur audio stéréo ; la latence déclarée par chaque plugin est
    compensée. Renvoie les notes (plugins appliqués, erreurs) lisibles ; les erreurs sont aussi journalisées. */
juce::StringArray applyPluginChain (Stereo& audio, double sampleRate, const std::vector<PluginSlot>& slots, double bpm = 120.0);
} // namespace sv::plugins
