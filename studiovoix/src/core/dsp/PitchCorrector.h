#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"

// Correction de justesse type "autotune" : accroche chaque note voisée sur la gamme de l'instru.
namespace sv::dsp
{
struct PitchCorrectionParams
{
    MusicalKey key;
    bool chromatic = false;     // toutes les notes autorisées
    float amount = 1.0f;        // 0 = aucune correction, 1 = correction complète
    float retuneMs = 20.0f;     // 0-5 ms = effet robot, 50-150 ms = naturel
    float humanize = 0.0f;      // 0..1 : conserve le vibrato et les inflexions
    float hysteresisSemis = 0.25f;
};

struct PitchCorrectionResult
{
    Mono audio;
    analysis::PitchTrack track;          // hauteur d'origine
    std::vector<float> outputMidi;       // hauteur corrigée (0 si non voisé)
    std::vector<float> targetMidi;       // note visée
    float meanAbsCorrectionCents = 0.0f;
};

/** Note de la gamme la plus proche (en demi-tons MIDI). */
float nearestScaleMidi (float midi, const MusicalKey& key, bool chromatic);

/** Degré (0..6) de la note de gamme la plus proche et octave MIDI correspondante. */
int scaleDegreeOf (float midi, const MusicalKey& key, int& octaveBaseMidi);

/** Note obtenue en montant (steps > 0) ou descendant de 'steps' degrés dans la gamme. */
float diatonicShift (float midi, const MusicalKey& key, int steps);

PitchCorrectionResult correctPitch (const Mono& input, double sampleRate, const PitchCorrectionParams& params,
                                    const analysis::PitchTrack* precomputedTrack = nullptr);
} // namespace sv::dsp
