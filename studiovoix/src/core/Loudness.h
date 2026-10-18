#pragma once

#include "Types.h"

// Mesure de sonie ITU-R BS.1770-4 / EBU R128 (LUFS intégré) et crête vraie approchée (suréchantillonnage x4).
namespace sv::loudness
{
struct Report
{
    double integratedLufs = -120.0;
    double truePeakDb = -120.0;
    double samplePeakDb = -120.0;
};

/** Sonie intégrée (LUFS) d'un signal stéréo ou mono. Retourne -120 si silence. */
double integratedLufs (const Stereo& buffer, double sampleRate);
double integratedLufs (const Mono& mono, double sampleRate);

/** Crête vraie approchée en dBTP (interpolation x4). */
double truePeakDb (const Stereo& buffer);

Report measure (const Stereo& buffer, double sampleRate);

/** Courbe de sonie à court terme (fenêtre 400 ms, pas 100 ms), en LUFS par bloc. */
std::vector<float> momentaryCurve (const Mono& mono, double sampleRate);
} // namespace sv::loudness
