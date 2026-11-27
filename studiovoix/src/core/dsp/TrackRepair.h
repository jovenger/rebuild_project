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

/** Réglage de base d'un mix entier (instru déjà produite) : seulement ce qui ne peut pas l'abîmer.
      1. écrêtage : si une part nette des échantillons est collée au sommet (plateaux), les crêtes sont reconstruites ;
      2. marge : si la crête dépasse ceilingDb, un gain CONSTANT, le même sur les deux canaux, la ramène à ceilingDb.
    Ni égaliseur, ni débruitage, ni niveleur, ni résonances, ni compression, ni limiteur. Mesuré le 27/11/2026 sur trois
    musiques : la réparation d'instrument (repairStereo avec correctionParams) traite un mix entier comme un seul
    instrument — coupe de 3,5 à 5,4 dB à 300 Hz, résonances rabaissées jusqu'à 9 dB, passages calmes pris pour du bruit
    (débruitage jusqu'à 20 dB), limiteur jusqu'à 5,7 dB : elle abîme une instru déjà masterisée. Ici, une instru propre
    dont la crête est sous ceilingDb ressort identique au bit près (changed = false). */
struct MixBaseReport
{
    int clippedSamples = 0;       // échantillons en plateau au sommet, les deux canaux
    double clippedShare = 0.0;    // leur part des échantillons
    int clippedRepaired = 0;      // échantillons reconstruits (0 si la part est sous le seuil)
    float gainDb = 0.0f;          // gain constant appliqué (<= 0)
    float peakBeforeDb = -120.0f;
    float peakAfterDb = -120.0f;
    bool changed = false;
};
constexpr double kMixBaseMinClippedShare = 0.0003;   // 0,03 % : sous cette part, des plateaux isolés ne sont pas un écrêtage
MixBaseReport fixMixBase (Stereo& audio, double sampleRate, float ceilingDb = -1.0f, double minClippedShare = kMixBaseMinClippedShare);

} // namespace sv::dsp
