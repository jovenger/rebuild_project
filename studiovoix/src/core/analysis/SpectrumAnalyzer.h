#pragma once

#include "../Types.h"

// Spectre moyen par tiers d'octave (pour l'égalisation d'après un morceau de référence).
namespace sv::analysis
{
struct BandSpectrum
{
    std::vector<float> centersHz;
    std::vector<float> levelsDb;
    bool valid() const { return ! levelsDb.empty() && levelsDb.size() == centersHz.size(); }
};

/** Centres normalisés des tiers d'octave entre 25 Hz et 16 kHz. */
std::vector<float> thirdOctaveCenters();

/** Spectre moyen des trames au-dessus de gateDb (relatif au maximum du signal). */
BandSpectrum averageSpectrum (const Mono& signal, double sampleRate, float gateBelowPeakDb = 40.0f);

/** Courbe de correction par bande pour rapprocher source de cible : lissée, centrée, bornée à ±maxDb,
    nulle hors de [minHz, maxHz]. */
std::vector<float> matchCurve (const BandSpectrum& source, const BandSpectrum& target, float maxDb,
                               float minHz, float maxHz, float strength);
} // namespace sv::analysis
