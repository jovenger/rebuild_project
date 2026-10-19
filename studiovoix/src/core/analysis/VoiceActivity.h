#pragma once

#include "../Types.h"

// Détection d'activité vocale : phrases (séparées par des silences) et attaques de syllabes.
namespace sv::analysis
{
struct Phrase
{
    double startSec = 0.0;
    double endSec = 0.0;
    float levelDb = -120.0f;                 // RMS moyen de la phrase
    std::vector<double> syllableOnsets;      // secondes, croissantes, dans [start, end]

    double duration() const { return endSec - startSec; }
};

struct VoiceActivity
{
    double frameSec = 0.01;
    std::vector<float> envDb;                // RMS par trame de 10 ms
    std::vector<char> active;
    float noiseFloorDb = -120.0f;
    float thresholdDb = -60.0f;
    std::vector<Phrase> phrases;

    bool isActiveAt (double timeSec) const;
};

struct VoiceActivityParams
{
    double minGapSec = 0.25;       // un silence plus court ne coupe pas la phrase
    double minPhraseSec = 0.15;
    float marginAboveNoiseDb = 12.0f;
    float minOnsetRiseDb = 6.0f;
    double minSyllableSpacingSec = 0.08;
};

VoiceActivity analyzeVoice (const Mono& signal, double sampleRate, const VoiceActivityParams& params = {});
} // namespace sv::analysis
