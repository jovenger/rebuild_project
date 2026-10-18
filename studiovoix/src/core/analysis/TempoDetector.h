#pragma once

#include "../Types.h"

// Détection du tempo et du premier temps fort : flux spectral + autocorrélation en peigne.
namespace sv::analysis
{
struct OnsetEnvelope
{
    double frameRate = 0.0;           // trames par seconde
    std::vector<float> full;          // flux spectral large bande
    std::vector<float> low;           // flux < 150 Hz (grosse caisse)
};

OnsetEnvelope computeOnsetEnvelope (const Mono& signal, double sampleRate);

TempoInfo detectTempo (const Mono& signal, double sampleRate, double minBpm = 60.0, double maxBpm = 200.0);
} // namespace sv::analysis
