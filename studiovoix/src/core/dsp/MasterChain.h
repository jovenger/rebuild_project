#pragma once

#include "../Types.h"

// Mastering automatique : compression de cohésion, couleur par style, limiteur à anticipation
// et normalisation de sonie selon la plateforme visée.
namespace sv::dsp
{
enum class LoudnessTarget { Spotify = 0, YouTube, AppleMusic, TikTok, Fort, None, Count };

struct TargetInfo
{
    juce::String id;
    juce::String name;
    float lufs = -14.0f;
    float ceilingDbTp = -1.0f;
};

TargetInfo targetInfo (LoudnessTarget t);
LoudnessTarget targetFromId (const juce::String& id);

struct MasterSettings
{
    bool enabled = true;
    LoudnessTarget target = LoudnessTarget::Spotify;
    float glueRatio = 2.0f;
    float lowShelfDb = 0.0f;    // 100 Hz
    float highShelfDb = 0.0f;   // 10 kHz
    float extraHeadroomDb = 0.0f;   // marge sous le plafond de crête vraie (format avec perte : MP3)
};

struct MasterReport
{
    double inputLufs = -120.0;
    double outputLufs = -120.0;
    double truePeakDb = -120.0;
    float glueGrDb = 0.0f;
    float limiterMaxGrDb = 0.0f;
    int iterations = 0;
    int hardClippedSamples = 0;
};

/** Limiteur stéréo lié, anticipation lookaheadMs. Retourne la réduction maximale (dB). */
float limitStereo (Stereo& buffer, double sampleRate, float ceilingDb, float lookaheadMs = 5.0f,
                   float releaseMs = 120.0f, int* hardClipped = nullptr);

Stereo master (const Stereo& mix, double sampleRate, const MasterSettings& settings, MasterReport& report);
} // namespace sv::dsp
