#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/VoiceActivity.h"

// Nettoyage « son propre » :
//  - débruitage spectral : profil de bruit appris sur les silences, gain par bande (Wiener) lissé en temps et en
//    fréquence pour éviter le bruit « musical » ; le souffle, le ronflement et le bruit de pièce baissent, la voix reste ;
//  - dé-écrêtage : les échantillons écrêtés (plats au maximum) sont reconstruits par interpolation cubique.
namespace sv::dsp
{
struct DenoiseReport
{
    float noiseBeforeDb = -120.0f;   // niveau du bruit dans les silences avant
    float noiseAfterDb = -120.0f;    // après
    int noiseFrames = 0;             // trames ayant servi au profil
    float reductionDb() const { return noiseBeforeDb - noiseAfterDb; }
};

/** maxReductionDb : atténuation maximale du bruit (12 dB = discret, 20 dB = fort). */
/** voiced (facultatif) : suivi de hauteur ; sur une trame voisée ou active, la réduction est limitée à 6 dB et la
    sur-soustraction coupée (le bruit y est masqué par la voix ; une note douce ne doit pas être creusée). */
DenoiseReport spectralDenoise (Mono& x, double sampleRate, const analysis::VoiceActivity& va, float maxReductionDb,
                               const analysis::PitchTrack* voiced = nullptr);

/** Reconstruit les passages écrêtés (|x| >= threshold) ; renvoie le nombre d'échantillons réparés. */
int declip (Mono& x, float threshold = 0.985f);
} // namespace sv::dsp
