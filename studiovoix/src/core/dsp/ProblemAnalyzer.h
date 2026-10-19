#pragma once

#include "../Types.h"
#include "../style/StyleProfiles.h"
#include "Leveler.h"

#include <juce_core/juce_core.h>

// Analyse des défauts d'une piste (niveau, saturation, bruit, boue, dureté, sifflantes, justesse) et
// réglages de correction : un son propre et à la bonne hauteur, sans effet « de style ».
namespace sv::dsp
{
/** Identifiant du pseudo-style « Correction automatique » (champ style d'une piste). */
constexpr const char* kCorrectionStyleId = "correction";

struct TrackProblems
{
    float peakDb = -120.0f;
    float activeLevelDb = -120.0f;   // RMS des passages actifs
    float dcOffset = 0.0f;
    int clippedSamples = 0;
    float noiseFloorDb = -120.0f;
    float levelRangeDb = 0.0f;       // étendue du niveau court terme (P90 - P10, fenêtre 400 ms) : passages qui montent / descendent
    float resonanceDb = 0.0f;        // dépassement moyen de la bande la plus saillante au-dessus de son voisinage
    std::vector<LevelSurge> surges;  // passages qui montent en flèche (horodatés)
    float mudExcessDb = 0.0f;        // 200-400 Hz au-dessus de la courbe attendue
    float harshExcessDb = 0.0f;      // 2,5-5 kHz
    float sibilanceDb = 0.0f;        // 5-9 kHz par rapport à 1-4 kHz
    float pitchDeviationCents = 0.0f; // écart moyen à la gamme (voix seulement)
    float voicedFraction = 0.0f;
    bool vocal = false;
    bool polyphonic = false;         // chœurs, piano, musique : jamais de correction de justesse
    juce::String instrumentKind;     // piste non vocale : "basse", "batterie", "harmonique" (clavier, guitare, synthé) ou "autre"
    float centroidHz = 0.0f;         // centre de gravité spectral
    float onsetsPerSec = 0.0f;       // densité de transitoires (batterie, percussions)
    juce::StringArray found;         // défauts constatés, lisibles
    juce::StringArray fixes;         // corrections appliquées, lisibles
};

/** Mesure les défauts. key : tonalité du morceau (justesse) ; vocal : analyse de la justesse. */
TrackProblems analyzeTrackProblems (const Mono& x, double sampleRate, const MusicalKey& key, bool vocal);

/** Réglages de correction déduits des défauts : nettoyage, justesse douce vers la gamme, EQ corrective,
    de-esser dosé, compression légère, niveau cible ; ni saturation, ni réverb, ni délai. Remplit fixes. */
style::VocalParams correctionParams (TrackProblems& problems, bool vocal);

/** Résumé lisible (défauts puis corrections). */
juce::String describeProblems (const TrackProblems& p);

/** Ingénieur du son : adapte les réglages d'un style aux mesures de la prise (dynamique, sifflantes, boue, dureté,
    bruit, résonances, écrêtage) et au tempo. Le style donne le caractère (attaque, relâchement, couleur, quantité de
    réverb / délai) ; la mesure donne les valeurs (ratio et seuil du compresseur, de-esser, EQ corrective, niveleur,
    saturation, pré-délai). Retourne les lignes lisibles (« compresseur 3:1 … (dynamique mesurée 8 dB) »). */
juce::StringArray fitStyleToMeasurement (style::VocalParams& v, const TrackProblems& p, double bpm);
} // namespace sv::dsp
