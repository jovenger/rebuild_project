#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

// Reconnaissance du contenu d'un fichier déposé : voix seule (a cappella) ou musique (instru, morceau).
// Indices : part du temps avec une hauteur de voix détectée, largeur stéréo, poids des graves (< 120 Hz).
namespace sv::analysis
{
struct ContentGuess
{
    bool voice = false;           // voix seule (chant / rap) plutôt que musique
    float voicedFraction = 0.0f;  // 0..1 : part des trames actives avec une hauteur de voix
    float stereoWidth = 0.0f;     // 0 = mono, 1 = canaux indépendants
    float lowRatio = 0.0f;        // énergie sous 120 Hz / énergie totale
    float beatRegularity = 0.0f;  // confiance du tempo (0..1) : un beat a des transitoires périodiques
    float confidence = 0.0f;      // 0..1
    juce::String reason;          // lisible, pour la fenêtre d'import et le journal
};

/** Analyse les 60 premières secondes (au plus). */
ContentGuess classifyContent (const Stereo& audio, double sampleRate, double maxSeconds = 60.0);
} // namespace sv::analysis
