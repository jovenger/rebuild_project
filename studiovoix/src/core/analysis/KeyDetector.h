#pragma once

#include "../Types.h"

// Détection de tonalité : chromagramme + corrélation avec les profils de Krumhansl-Kessler.
namespace sv::analysis
{
struct KeyResult
{
    MusicalKey key;
    std::array<float, 12> chroma {};
    std::array<float, 24> scores {};   // 0..11 majeur, 12..23 mineur
};

KeyResult detectKey (const Mono& signal, double sampleRate);

/** Nom français d'une classe de hauteur (0 = Do). */
juce::String pitchClassName (int pc);
} // namespace sv::analysis
