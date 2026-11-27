#pragma once

#include "../style/StyleProfiles.h"

// Assistant local (hors ligne) : comprend des demandes simples en français
// ("plus de réverb", "voix plus sombre", "beaucoup moins d'autotune") et ajuste les curseurs.
namespace sv::assistant
{
struct CommandResult
{
    style::Macros macros;          // curseurs après modification
    juce::StringArray changes;     // explications lisibles
    bool understood = false;
};

CommandResult apply (const juce::String& text, const style::Macros& current);

/** Minuscule + suppression des accents (pour une comparaison tolérante). */
juce::String normalise (const juce::String& text);
} // namespace sv::assistant
