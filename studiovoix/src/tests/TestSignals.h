#pragma once

#include "core/Types.h"

// Signaux de synthèse pour les tests et la démo (aucun fichier externe nécessaire).
namespace sv::test
{
Mono sine (double freqHz, double seconds, double sampleRate, float amplitude);

struct VoiceNote
{
    float midi = 57.0f;        // La 2 (220 Hz)
    double seconds = 0.4;
    float centsOffset = 0.0f;  // désaccord volontaire
};

struct VoicePhrase
{
    std::vector<VoiceNote> notes;
    double gapAfterSec = 0.6;
    bool sibilantAtEnd = false;   // "s" final
    bool breathBefore = false;
};

/** Voix chantée de synthèse : harmoniques + formants de voyelle, vibrato, attaques de syllabes. */
Mono synthVoice (const std::vector<VoicePhrase>& phrases, double sampleRate, double leadInSec = 0.5,
                 float vibratoCents = 15.0f, juce::int64 seed = 7);

/** Instru de synthèse : grosse caisse, caisse claire, charleston, basse, accords. */
Stereo synthInstru (double bpm, const MusicalKey& key, int bars, double sampleRate, bool chorusEnergy = true,
                    juce::int64 seed = 11);

/** Phrases par défaut : 4 phrases de 4 notes dans la gamme. */
std::vector<VoicePhrase> defaultPhrases (const MusicalKey& key, double bpm, float detuneCents = 0.0f);

/** Fréquence fondamentale médiane mesurée (Hz), 0 si non voisé. */
float medianF0 (const Mono& x, double sampleRate, double fromSec = 0.0, double toSec = 1.0e9);
} // namespace sv::test
