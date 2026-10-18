#pragma once

#include "../Types.h"
#include "../style/StyleProfiles.h"

// Assemblage des prises : "dernière prise" (punch-in) ou "meilleure prise automatique"
// (choix phrase par phrase selon justesse, rythme, saturation, bruit, régularité, complétude).
namespace sv::gen
{
struct TakeInput
{
    const Mono* audio = nullptr;   // audio de la prise ; audio[0] est à startSample sur la timeline
    long startSample = 0;
    long regionStart = 0;          // zone utilisée (absolue, timeline)
    long regionEnd = 0;
    int id = 0;
};

struct CompSegment
{
    long start = 0;
    long end = 0;
    int takeIndex = -1;    // index dans le vecteur d'entrée
    float score = 0.0f;    // pénalité (plus bas = meilleur)
};

struct CompResult
{
    Mono audio;            // audio assemblé ; audio[0] à startSample
    long startSample = 0;
    std::vector<CompSegment> segments;
    juce::String summary;
};

/** La prise la plus récente gagne sur sa zone (fondus de 15 ms). */
CompResult compLatest (const std::vector<TakeInput>& takes, double sampleRate);

/** Meilleure prise par phrase. */
CompResult compBest (const std::vector<TakeInput>& takes, double sampleRate, const MusicalKey& key,
                     const TempoInfo& tempo, style::Style style);
} // namespace sv::gen
