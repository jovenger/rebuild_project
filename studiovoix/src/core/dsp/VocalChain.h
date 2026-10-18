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
    double referenceLufs = -120.0;      // sonie intégrée du morceau de référence (mastering par référence)
};

struct VocalReport
{
    float inputGainDb = 0.0f;
    float meanCorrectionCents = 0.0f;
    float compGrDb = 0.0f;
    float deEssGrDb = 0.0f;
    float limiterGrDb = 0.0f;          // limiteur de sécurité en fin de piste (-1 dBTP), 0 si rien à faire
    float outOfScaleFraction = -1.0f;  // part des notes chantées hors de la gamme du morceau (avant autotune) ; -1 = inconnu
    bool scaleAdapted = false;         // la voix chante dans une autre gamme : autotune vers la gamme de la voix (adaptedKey)
    bool chromaticUsed = false;        // notes trop dispersées ou tonalité inconnue : correction note par note
    MusicalKey adaptedKey;             // gamme réellement utilisée par l'autotune
    int syllablesRetimed = 0;
    CleanReport clean;
    LevelerReport leveler;
    ResonanceReport resonance;
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

/** Détail lisible, une ligne par effet (« Compresseur : 4:1 au seuil -20 dB… »), pour l'onglet Voix IA. */
juce::String describeChain (const style::VocalParams& p);
} // namespace sv::dsp
