#pragma once

#include "../Types.h"

// Détection de hauteur YIN (de Cheveigné & Kawahara 2002), calculée à 16 kHz pour la rapidité.
namespace sv::analysis
{
struct PitchFrame
{
    float f0 = 0.0f;          // Hz, 0 si non voisé
    float confidence = 0.0f;  // 1 - d'(tau)
    float rmsDb = -120.0f;
    bool voiced = false;
};

struct PitchTrack
{
    double hopSec = 0.008;
    std::vector<PitchFrame> frames;

    int frameAt (double timeSec) const;
    /** f0 interpolée (0 si non voisé). */
    float f0At (double timeSec) const;
    bool voicedAt (double timeSec) const;
    double durationSec() const { return hopSec * static_cast<double> (frames.size()); }
};

struct PitchParams
{
    float minHz = 70.0f;
    float maxHz = 1000.0f;
    float threshold = 0.15f;
    float voicedMax = 0.30f;   // d' maximal accepté comme voisé
    double hopSec = 0.008;
    double windowSec = 0.032;
    float silenceDb = -50.0f;  // relatif à la pleine échelle
};

PitchTrack detectPitch (const Mono& signal, double sampleRate, const PitchParams& params = {});

inline float hzToMidi (float hz) noexcept { return hz > 0.0f ? 69.0f + 12.0f * std::log2 (hz / 440.0f) : 0.0f; }
inline float midiToHz (float midi) noexcept { return 440.0f * std::pow (2.0f, (midi - 69.0f) / 12.0f); }
} // namespace sv::analysis
