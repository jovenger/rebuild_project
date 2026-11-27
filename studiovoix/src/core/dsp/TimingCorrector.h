#pragma once

#include "../Types.h"
#include "../analysis/VoiceActivity.h"

// Recalage rythmique léger : rapproche les attaques de syllabes de la grille (doubles croches),
// sans étirement temporel (déplacement de segments avec fondus).
namespace sv::dsp
{
struct TimingParams
{
    float strength = 0.0f;       // 0 = désactivé, 1 = calage complet
    float toleranceMs = 70.0f;   // au-delà, l'attaque est jugée volontaire et n'est pas déplacée
    int divisionsPerBeat = 4;    // 4 = doubles croches
};

struct TimingResult
{
    Mono audio;
    int segmentsMoved = 0;
    float meanShiftMs = 0.0f;
};

TimingResult correctTiming (const Mono& input, double sampleRate, const TempoInfo& tempo,
                            const analysis::VoiceActivity& va, const TimingParams& params);
} // namespace sv::dsp
