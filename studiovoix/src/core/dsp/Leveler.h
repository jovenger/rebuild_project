#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

// « Ingénieur du son » : niveleur adaptatif (le niveau d'un passage à l'autre reste régulier, comme un fader
// tenu à la main) et suppresseur de résonances (une bande qui dépasse son voisinage spectral est rabaissée
// le temps qu'elle dépasse : dureté, « ça monte » par moments). Hors temps réel, mono ou stéréo lié.
namespace sv::dsp
{
struct LevelerSettings
{
    bool enabled = false;
    float targetDb = -20.0f;          // RMS court terme visé sur les passages actifs (dBFS)
    float maxBoostDb = 6.0f;          // montée maximale d'un passage trop bas
    float maxCutDb = 6.0f;            // baisse maximale d'un passage trop fort
    float windowMs = 400.0f;          // fenêtre de mesure (sonie court terme)
    float attackMs = 250.0f;          // vitesse quand le niveau monte (on baisse)
    float releaseMs = 1200.0f;        // vitesse quand le niveau redescend (on remonte)
    float gateBelowTargetDb = 25.0f;  // en dessous de cible - gate : silence ou bruit, gain tenu (jamais amplifié)
    float surgeAboveDb = 9.0f;        // un passage à plus de N dB au-dessus du niveau médian « monte en flèche »
    float surgeCutDb = 12.0f;         // baisse autorisée sur ces montées (au-delà de maxCutDb)
};

/** Passage qui monte brusquement au-dessus du niveau médian de la piste. */
struct LevelSurge
{
    double startSec = 0.0, endSec = 0.0;
    float overDb = 0.0f;   // dépassement maximal du niveau médian
    juce::String describe() const;   // « à 1:32 (+14 dB pendant 2,3 s) »
};

struct LevelerReport
{
    float rangeBeforeDb = 0.0f;   // étendue P90 - P10 du niveau court terme avant
    float rangeAfterDb = 0.0f;
    float maxBoostDb = 0.0f;      // montée réellement appliquée
    float maxCutDb = 0.0f;        // baisse réellement appliquée
    int framesAdjusted = 0;       // trames actives dont le gain a bougé de plus de 0,5 dB
    std::vector<LevelSurge> surges;   // montées brusques détectées (et rabaissées)
    bool applied = false;
};

/** Niveleur mono. */
LevelerReport autoLevel (Mono& x, double sampleRate, const LevelerSettings& s);
/** Niveleur stéréo lié : gain calculé sur la somme mono, appliqué aux deux canaux (image inchangée). */
LevelerReport autoLevelStereo (Stereo& x, double sampleRate, const LevelerSettings& s);
/** Étendue du niveau court terme (P90 - P10 des fenêtres actives, au-dessus de gateDb), en dB. */
float shortTermRangeDb (const Mono& x, double sampleRate, float windowMs = 400.0f, float gateDb = -50.0f);
/** Montées brusques : fenêtres à plus de aboveDb au-dessus du niveau médian des passages actifs. */
std::vector<LevelSurge> levelSurges (const Mono& x, double sampleRate, float aboveDb = 9.0f, float windowMs = 400.0f, float gateDb = -50.0f);

struct ResonanceSettings
{
    bool enabled = false;
    float thresholdDb = 3.0f;        // dépassement du voisinage spectral à partir duquel on rabaisse
    float maxReductionDb = 6.0f;
    float attackMs = 10.0f;
    float releaseMs = 80.0f;
    float protectBelowHz = 500.0f;   // graves et fondamentales protégés (rampe de la moitié jusqu'à cette fréquence)
    float softAboveHz = 10000.0f;    // au-dessus : réduction progressivement allégée
    float mix = 1.0f;
};

struct ResonanceReport
{
    float meanReductionDb = 0.0f;   // réduction moyenne de la bande la plus rabaissée, trames actives
    float maxReductionDb = 0.0f;
    float activeFraction = 0.0f;    // part des trames où au moins une bande a été rabaissée
    bool applied = false;
};

ResonanceReport suppressResonances (Mono& x, double sampleRate, const ResonanceSettings& s);
/** Stéréo lié : détection sur la somme mono, mêmes gains sur les deux canaux. */
ResonanceReport suppressResonancesStereo (Stereo& x, double sampleRate, const ResonanceSettings& s);
/** Mesure : dépassement moyen (dB) de la bande la plus saillante au-dessus de son voisinage, trames actives. */
float resonanceExcessDb (const Mono& x, double sampleRate);
} // namespace sv::dsp
