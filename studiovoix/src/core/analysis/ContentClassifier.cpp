#include "ContentClassifier.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "PitchDetector.h"
#include "TempoDetector.h"
#include "VoiceActivity.h"

#include <cmath>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Contenu";
}

ContentGuess classifyContent (const Stereo& audio, double sampleRate, double maxSeconds)
{
    log::ScopedTimer timer (kMod, "reconnaissance voix / musique"_u8);
    ContentGuess g;
    const int n = std::min (audio.getNumSamples(), static_cast<int> (maxSeconds * sampleRate));
    if (n < static_cast<int> (sampleRate) || audio.getNumChannels() < 1 || sampleRate <= 0.0)
    {
        g.reason = "fichier trop court pour reconnaître le contenu"_u8;
        return g;
    }

    // 1) Largeur stéréo : 1 - corrélation gauche / droite (0 pour un fichier mono ou une voix centrée).
    const float* l = audio.getReadPointer (0);
    const float* r = audio.getReadPointer (audio.getNumChannels() > 1 ? 1 : 0);
    double sll = 0.0, srr = 0.0, slr = 0.0;
    for (int i = 0; i < n; ++i)
    {
        sll += static_cast<double> (l[i]) * l[i];
        srr += static_cast<double> (r[i]) * r[i];
        slr += static_cast<double> (l[i]) * r[i];
    }
    const double corr = (sll > 1e-9 && srr > 1e-9) ? slr / std::sqrt (sll * srr) : 1.0;
    g.stereoWidth = static_cast<float> (juce::jlimit (0.0, 1.0, 1.0 - corr));

    // 2) Poids des graves : passe-bas 1 pôle à 120 Hz sur le mono, énergie basse / totale.
    Mono mono (static_cast<size_t> (n));
    double mean = 0.0;
    for (int i = 0; i < n; ++i)
        mean += 0.5 * (l[i] + r[i]);
    mean /= n;
    for (int i = 0; i < n; ++i)
        mono[static_cast<size_t> (i)] = 0.5f * (l[i] + r[i]) - static_cast<float> (mean);   // sans composante continue (sinon comptée comme des graves)
    const float a = static_cast<float> (std::exp (-2.0 * juce::MathConstants<double>::pi * 120.0 / sampleRate));
    float lp = 0.0f;
    double eLow = 0.0, eAll = 0.0;
    for (const float v : mono)
    {
        lp = a * lp + (1.0f - a) * v;
        eLow += static_cast<double> (lp) * lp;
        eAll += static_cast<double> (v) * v;
    }
    g.lowRatio = eAll > 1e-12 ? static_cast<float> (eLow / eAll) : 0.0f;

    // 3) Part des trames actives où une hauteur de voix (70-1000 Hz) est détectée. Niveau ramené à -6 dB crête :
    //    un fichier enregistré bas ne doit pas passer pour « sans voix ».
    float pk = 0.0f;
    for (const float v : mono)
        pk = std::max (pk, std::abs (v));
    if (pk > 1.0e-6f)
        for (auto& v : mono)
            v *= 0.5f / pk;
    const auto va = analyzeVoice (mono, sampleRate);
    const auto track = detectPitch (mono, sampleRate);
    int active = 0, voiced = 0;
    for (size_t i = 0; i < track.frames.size(); ++i)
    {
        const double t = static_cast<double> (i) * track.hopSec;
        if (! va.isActiveAt (t))
            continue;
        ++active;
        const auto& f = track.frames[i];
        if (f.voiced && f.f0 >= 70.0f && f.f0 <= 1000.0f && f.confidence > 0.5f)
            ++voiced;
    }
    g.voicedFraction = active > 0 ? static_cast<float> (voiced) / static_cast<float> (active) : 0.0f;

    // Régularité rythmique : un beat a des transitoires périodiques (tempo sûr), une voix non.
    const auto tempo = detectTempo (mono, sampleRate);
    g.beatRegularity = tempo.confidence;

    // Décision. Une voix exportée avec réverb peut être stéréo large : la largeur n'est qu'un indice faible.
    // Graves marqués (kick, basse, 808) = musique ; battement très régulier avec peu de chant = musique ;
    // sinon voix si « chantée » ≥ 35 % du temps.
    if (g.lowRatio >= 0.40f)
    {
        g.voice = false;
        g.confidence = juce::jlimit (0.3f, 1.0f, (g.lowRatio - 0.40f) / 0.3f + 0.3f);
    }
    else if (g.beatRegularity >= 0.6f && g.voicedFraction < 0.6f)
    {
        g.voice = false;
        g.confidence = juce::jlimit (0.3f, 1.0f, (g.beatRegularity - 0.6f) / 0.4f + 0.3f);
    }
    else
    {
        g.voice = g.voicedFraction >= 0.35f;
        g.confidence = juce::jlimit (0.0f, 1.0f, std::abs (g.voicedFraction - 0.35f) / 0.25f);
    }
    g.reason = (g.voice ? "voix seule"_u8 : "musique"_u8) + juce::String (" (hauteur de voix sur ") + juce::String (juce::roundToInt (g.voicedFraction * 100.0f))
               + " % du temps, " + (g.stereoWidth < 0.1f ? "mono / centrée"_u8 : "stéréo"_u8) + ", graves "
               + juce::String (juce::roundToInt (g.lowRatio * 100.0f)) + " %, battement régulier "_u8
               + juce::String (juce::roundToInt (g.beatRegularity * 100.0f)) + " %)";
    SV_LOG_INFO (kMod, "Reconnu : " + g.reason + ", confiance " + juce::String (g.confidence, 2));
    return g;
}
} // namespace sv::analysis
