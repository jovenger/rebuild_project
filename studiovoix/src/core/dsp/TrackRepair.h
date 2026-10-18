#pragma once

#include "../Types.h"
#include "../style/StyleProfiles.h"
#include "Leveler.h"
#include "Processors.h"

// Réparation d'une piste stéréo (instru, fichier mixé) avec les réglages de la correction automatique :
// dé-écrêtage, coupe-bas, débruitage, niveleur lié, EQ corrective, résonances, compression liée, niveau, limiteur.
namespace sv::dsp
{
struct RepairReport
{
    int clippedRepaired = 0;
    float noiseReducedDb = 0.0f;
    LevelerReport leveler;
    ResonanceReport resonance;
    float compGrDb = 0.0f;
    float outputGainDb = 0.0f;
    float limiterGrDb = 0.0f;
    juce::String summary() const;   // lisible, une ligne par étape utile
};

/** Applique la correction sur un son stéréo (canaux liés : image inchangée). */
RepairReport repairStereo (Stereo& audio, double sampleRate, const style::VocalParams& params);

/** Compresseur stéréo lié (détecteur = canal le plus fort). Renvoie la réduction moyenne (dB). */
float compressStereo (Stereo& audio, double sampleRate, const CompressorSettings& c);
} // namespace sv::dsp
