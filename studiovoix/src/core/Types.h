#pragma once

#include <juce_audio_basics/juce_audio_basics.h>

#include "Text.h"

#include <array>
#include <atomic>
#include <cmath>
#include <functional>
#include <vector>

namespace sv
{
/** Signal mono (voix). */
using Mono = std::vector<float>;

/** Signal stéréo : toujours 2 canaux. */
using Stereo = juce::AudioBuffer<float>;

constexpr double kProjectSampleRate = 48000.0;

/** Rappel de progression [0..1]. Retourne false pour demander l'annulation. */
using ProgressFn = std::function<bool (float)>;

inline float dbToGain (float db) noexcept { return std::pow (10.0f, db / 20.0f); }
inline float gainToDb (float g, float floorDb = -120.0f) noexcept
{
    return g > 0.0f ? std::max (floorDb, 20.0f * std::log10 (g)) : floorDb;
}

/** Gain gauche/droite à puissance constante (-3 dB au centre). pan dans [-1, 1]. */
inline void panGains (float pan, float& gl, float& gr) noexcept
{
    const float p = juce::jlimit (-1.0f, 1.0f, pan);
    const float angle = (p + 1.0f) * juce::MathConstants<float>::pi * 0.25f;
    gl = std::cos (angle);
    gr = std::sin (angle);
}

inline Stereo makeStereo (int numSamples)
{
    Stereo s (2, std::max (0, numSamples));
    s.clear();
    return s;
}

/** Note de musique : classe de hauteur (0 = Do) et mode. */
struct MusicalKey
{
    int root = 9;        // La
    bool minor = true;
    float confidence = 0.0f;

    juce::String toFrench() const;
    /** Vrai si la classe de hauteur appartient à la gamme. */
    bool contains (int pitchClass) const;
    /** Classes de hauteur de la gamme, dans l'ordre des degrés. */
    std::array<int, 7> scale() const;
};

struct TempoInfo
{
    double bpm = 120.0;
    double firstBeatSec = 0.0;   // premier temps fort estimé
    int beatsPerBar = 4;
    float confidence = 0.0f;

    double beatSec() const { return 60.0 / juce::jmax (1.0, bpm); }
    double barSec() const { return beatSec() * beatsPerBar; }
};
} // namespace sv
