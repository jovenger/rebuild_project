#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/SpectrumAnalyzer.h"
#include "../analysis/VoiceActivity.h"
#include "../style/StyleProfiles.h"
#include "Processors.h"

// Chaîne vocale complète hors temps réel ("Remix auto") :
// normalisation -> nettoyage -> recalage rythmique -> justesse -> EQ (+ référence) -> compression
// -> de-esser -> saturation -> niveau -> placement stéréo -> réverbération + délai.
namespace sv::dsp
{
struct AnalysisContext
{
    MusicalKey key;
    TempoInfo tempo;
    analysis::BandSpectrum reference;   // spectre du morceau de référence (optionnel)
};

struct VocalReport
{
    float inputGainDb = 0.0f;
    float meanCorrectionCents = 0.0f;
    float compGrDb = 0.0f;
    float deEssGrDb = 0.0f;
    int syllablesRetimed = 0;
    CleanReport clean;
    int phrases = 0;
    bool nearSilent = false;   // prise quasi silencieuse (mauvaise entrée ?) : pas amplifiée
};

struct VocalResult
{
    Stereo audio;                    // voix traitée + effets (durée = entrée + traîne)
    Mono prepared;                   // voix nettoyée et accordée, avant EQ (base des pistes générées)
    analysis::PitchTrack track;      // hauteur de la voix préparée
    analysis::VoiceActivity va;
    VocalReport report;
    bool cancelled = false;
};

constexpr double kTailSec = 3.0;

VocalResult processVocal (const Mono& raw, double sampleRate, const style::VocalParams& params,
                          const AnalysisContext& context, const ProgressFn& progress = {});

/** Résumé lisible des réglages (journal et interface). */
juce::String describeParams (const style::VocalParams& p);
} // namespace sv::dsp
