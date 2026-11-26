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
    // Grandeurs signées (mêmes bandes et même courbe attendue que mudExcessDb / harshExcessDb, sans la borne à 0) :
    // positif = en trop, négatif = MANQUE. mudExcessDb = max (0, bodyBalanceDb) ; harshExcessDb = max (0, presenceBalanceDb).
    float bodyBalanceDb = 0.0f;      // corps : 200-400 Hz par rapport au médium (500 Hz - 2 kHz)
    float presenceBalanceDb = 0.0f;  // présence : 2,5-5 kHz par rapport au médium - 3 dB
    float medianF0Hz = 0.0f;         // hauteur médiane de la voix (0 = inconnue) : le corps ne se juge que si la fondamentale est sous la bande
    float pitchDeviationCents = 0.0f; // écart moyen à la gamme (voix seulement)
    float voicedFraction = 0.0f;
    // Part des trames voisées sûres qui appartiennent à une note tenue (hauteur dans ± kHeldNoteHalfWidthCents pendant au
    // moins kHeldNoteMinMs). Voix chantée : élevée ; voix parlée ou rappée (hauteur qui glisse sans viser de note) : ~0.
    float heldNoteFraction = 0.0f;
    bool vocal = false;
    bool polyphonic = false;         // chœurs, piano, musique : jamais de correction de justesse
    juce::String instrumentKind;     // piste non vocale : "basse", "batterie", "harmonique" (clavier, guitare, synthé) ou "autre"
    float centroidHz = 0.0f;         // centre de gravité spectral
    float onsetsPerSec = 0.0f;       // densité de transitoires (batterie, percussions)
    juce::StringArray found;         // défauts constatés, lisibles
    juce::StringArray fixes;         // corrections appliquées, lisibles
};

/** Correction automatique d'une voix : seuils et bornes, étalonnés sur 26 voix réelles (parlées et chantées, 26/11/2026).
    Voix normales mesurées : présence de -1 à -12 dB ; corps des voix graves (fondamentale <= 260 Hz) de -3 à +11 dB.
    Les seuils sont sous ces plages : aucune de ces voix n'est retouchée ; la même voix creusée exprès de 6 dB (cloche
    large : la mesure baisse de 3,5 à 4 dB) n'est compensée que si elle était déjà dans le bas de la plage. */
constexpr float kBodyLackDb = -5.5f;         // bodyBalanceDb à partir duquel le manque de corps est net
constexpr float kPresenceLackDb = -13.0f;    // presenceBalanceDb à partir duquel le manque de présence est net
constexpr float kBodyLackMaxF0Hz = 260.0f;   // au-dessus, la fondamentale est déjà dans ou au-dessus de la bande du corps (voix aiguës : de -17 à -1 dB sans manque)
constexpr float kLackMaxBoostDb = 3.0f;      // compensation maximale (cloche large)
// Prise bruitée = bruit de fond à moins de kLackMinSnrDb sous le niveau actif : pas de compensation. Mesuré (voix réelle
// + bruit blanc) : une cloche de +3 dB à 3,5 kHz remonte le souffle des pauses de 0,5 à 1,2 dB (1,2 à 1,8 dB dans sa
// bande), quel que soit le bruit ; à 25 dB d'écart ce souffle sort à -32 dBFS (refusé), à 34 dB et plus sous -40 dBFS.
constexpr float kLackMinSnrDb = 30.0f;
// Justesse de la correction : seulement sur une voix CHANTÉE (des notes tenues). Mesuré sur 26 voix réelles (26/11/2026),
// note tenue = ±50 cents pendant 300 ms : 13 voix parlées 0 à 7 % ; rap 0 % et 35 % (un extrait « hip-hop » mélodique) ;
// 11 voix chantées 0 à 68 % (4 au-dessus du seuil). Le seuil est au-dessus de toutes les voix parlées et rappées : une
// voix chantée laissée sans justesse est le moindre mal, une voix parlée ou rappée accordée de force est abîmée.
constexpr float kHeldNoteHalfWidthCents = 50.0f;
constexpr float kHeldNoteMinMs = 300.0f;
constexpr float kSungMinHeldFraction = 0.45f;
constexpr float kCorrectionMinRatio = 1.3f;  // compresseur de la correction : prise déjà régulière (étendue <= 4 dB)
constexpr float kCorrectionMaxRatio = 3.0f;  // prise très irrégulière (étendue >= 14 dB)

/** Mesure les défauts. key : tonalité du morceau (justesse) ; vocal : analyse de la justesse. */
TrackProblems analyzeTrackProblems (const Mono& x, double sampleRate, const MusicalKey& key, bool vocal);

/** Réglages de correction déduits des défauts : nettoyage, justesse douce vers la gamme (voix chantée seulement :
    heldNoteFraction >= kSungMinHeldFraction ; voix parlée ou rappée : pas de justesse), EQ corrective (excès coupés,
    manques nets de corps / de présence compensés doucement sur une voix), de-esser dosé, compression proportionnelle
    à la dynamique mesurée (voix : de kCorrectionMinRatio à kCorrectionMaxRatio), niveau cible ; ni saturation, ni
    réverb, ni délai, ni recalage rythmique. Remplit fixes. */
style::VocalParams correctionParams (TrackProblems& problems, bool vocal);

/** Résumé lisible (défauts puis corrections). */
juce::String describeProblems (const TrackProblems& p);

/** Ingénieur du son : adapte les réglages d'un style aux mesures de la prise (dynamique, sifflantes, boue, dureté,
    bruit, résonances, écrêtage) et au tempo. Le style donne le caractère (attaque, relâchement, couleur, quantité de
    réverb / délai) ; la mesure donne les valeurs (ratio et seuil du compresseur, de-esser, EQ corrective, niveleur,
    saturation, pré-délai). Retourne les lignes lisibles (« compresseur 3:1 … (dynamique mesurée 8 dB) »). */
juce::StringArray fitStyleToMeasurement (style::VocalParams& v, const TrackProblems& p, double bpm);
} // namespace sv::dsp
