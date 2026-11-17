#pragma once

#include "../Types.h"

// Retrait de la musique captée par le micro (« repisse ») : quand l'instru sort des haut-parleurs pendant la prise,
// le micro l'enregistre avec la voix. On connaît le signal joué (l'instru) : on mesure le décalage exact entre l'instru
// et sa trace dans la prise (corrélation croisée GCC-PHAT, puis affinage à l'échantillon), on estime la façon dont la
// pièce et le micro la colorent (fonction de transfert par bande, moindres carrés sur toute la prise), on la soustrait,
// puis on atténue ce qui reste (suppression résiduelle douce, plancher -14 dB).
// Le même décalage est la latence aller-retour (sortie + entrée) : il sert à recaler la voix sur l'instru.
namespace sv::dsp
{
struct BleedReport
{
    bool detected = false;          // l'instru est présente dans la prise (pic de corrélation net)
    double lagSec = 0.0;            // décalage instru -> prise (latence aller-retour mesurée)
    float peakRatio = 0.0f;         // netteté du pic (pic / RMS de la corrélation) ; > 8 = présence certaine
    float bleedBeforeDb = -120.0f;  // part de la musique dans la prise avant (dB par rapport à la prise)
    float bleedAfterDb = -120.0f;   // après retrait
    float reductionDb() const { return bleedBeforeDb - bleedAfterDb; }
    juce::String describe() const;
};

/** Cherche l'instru (ref, alignée sur la prise : ref[i] = ce qui était joué quand rec[i] a été écrit, latence comprise
    en moins) dans la prise, pour un décalage entre minLagSec et maxLagSec. */
BleedReport findBleedLag (const Mono& rec, const Mono& ref, double sampleRate, double minLagSec = -0.02, double maxLagSec = 0.8);

/** Retire l'instru de la prise (en place). Sans instru détectée, la prise n'est pas modifiée. */
BleedReport removeBleed (Mono& rec, const Mono& ref, double sampleRate, double minLagSec = -0.02, double maxLagSec = 0.8);
} // namespace sv::dsp
