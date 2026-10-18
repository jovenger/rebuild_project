#pragma once

#include "../Types.h"
#include "PluginChain.h"

#include <vector>

// Effets intégrés utilisables comme des plugins (sans rien installer) : égaliseur, compresseur, de-esser,
// saturation, réverb, délai, porte / débruiteur, limiteur, largeur stéréo. Réglages = JSON dans l'état du slot.
namespace sv::plugins
{
struct ParamSpec
{
    const char* id;
    const char* label;   // UTF-8
    float min, max, def;
    const char* unit;
};

struct InternalPluginDef
{
    const char* identifier;   // "interne:eq"…
    const char* name;         // UTF-8
    std::vector<ParamSpec> params;
};

const std::vector<InternalPluginDef>& internalPlugins();
const InternalPluginDef* findInternal (const juce::String& identifier);
bool isInternal (const juce::String& identifier);

/** État par défaut (JSON des paramètres) pour un slot de cet effet. */
juce::MemoryBlock defaultInternalState (const InternalPluginDef& def);
/** Lecture d'un paramètre dans l'état (valeur par défaut si absent). */
float internalParam (const InternalPluginDef& def, const juce::MemoryBlock& state, const juce::String& id);
juce::MemoryBlock withInternalParam (const InternalPluginDef& def, const juce::MemoryBlock& state, const juce::String& id, float value);

/** Applique l'effet intégré sur audio stéréo ; renvoie une note lisible. */
juce::String applyInternal (Stereo& audio, double sampleRate, double bpm, const PluginSlot& slot);
} // namespace sv::plugins
