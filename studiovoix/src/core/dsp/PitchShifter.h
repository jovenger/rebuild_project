#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"

// Transposition TD-PSOLA à rapport variable : conserve les formants (pas d'effet "chipmunk" fort)
// et la durée. Le rapport est donné par trame de la piste de hauteur.
namespace sv::dsp
{
struct PsolaOptions
{
    float unvoicedGain = 1.0f;       // gain appliqué aux parties non voisées (consonnes, souffle)
    float defaultUnvoicedHz = 160.0f;
};

/** ratioPerFrame : même taille que track.frames ; 1 = inchangé, 2 = octave au-dessus. */
Mono psolaShift (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                 const std::vector<float>& ratioPerFrame, const PsolaOptions& options = {});

/** Transposition constante en demi-tons (parties voisées seulement). */
Mono psolaShiftSemitones (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                          float semitones, const PsolaOptions& options = {});
} // namespace sv::dsp
