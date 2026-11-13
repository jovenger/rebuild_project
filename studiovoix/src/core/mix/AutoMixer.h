#pragma once

#include "../Types.h"

// Mix automatique : équilibre voix / instru par la sonie et creux dynamique de l'instru
// dans la zone de présence de la voix quand elle chante.
namespace sv::mix
{
struct AutoMixSettings
{
    bool enabled = true;
    float vocalOverInstruLu = 1.0f;   // sonie voix principale - sonie instru
    float duckingDb = 2.5f;           // creux max de l'instru vers 2,5 kHz (0 = désactivé)
};

struct AutoMixResult
{
    float vocalGainDb = 0.0f;   // gain à appliquer à toutes les pistes voix
    float instruLufs = -120.0f;
    float leadLufs = -120.0f;
    Stereo duckedInstru;        // instru avec creux dynamique
};

AutoMixResult autoMix (const Stereo& instru, const Stereo& leadProcessed, const Stereo& allVocals,
                       double sampleRate, const AutoMixSettings& settings);
} // namespace sv::mix
