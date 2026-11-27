#pragma once

#include "../Types.h"

// Découpage approximatif de l'instru en sections (intro / couplet / refrain / outro), par blocs de 4 mesures.
namespace sv::analysis
{
struct Section
{
    double startSec = 0.0;
    double endSec = 0.0;
    juce::String label;     // "Intro", "Couplet 1", "Refrain 1", "Outro"…
    juce::String kind;      // "intro", "couplet", "refrain", "pont", "outro"
    int group = 0;          // sections semblables = même groupe
    float energyDb = -120.0f;
};

std::vector<Section> detectStructure (const Mono& instru, double sampleRate, const TempoInfo& tempo);
} // namespace sv::analysis
