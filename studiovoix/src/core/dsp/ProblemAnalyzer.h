#pragma once

#include "../Types.h"
#include "../style/StyleProfiles.h"

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
    float mudExcessDb = 0.0f;        // 200-400 Hz au-dessus de la courbe attendue
    float harshExcessDb = 0.0f;      // 2,5-5 kHz
    float sibilanceDb = 0.0f;        // 5-9 kHz par rapport à 1-4 kHz
    float pitchDeviationCents = 0.0f; // écart moyen à la gamme (voix seulement)
    float voicedFraction = 0.0f;
    bool vocal = false;
    bool polyphonic = false;         // chœurs, piano, musique : jamais de correction de justesse
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
} // namespace sv::dsp
