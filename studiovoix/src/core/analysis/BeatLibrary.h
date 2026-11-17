#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

// Bibliothèque de beats locale : analyse un dossier d'instrus (tempo, tonalité, énergie) avec cache,
// puis classe les instrus selon des critères (tempo visé, énergie, mode).
namespace sv::analysis
{
struct BeatInfo
{
    juce::String path;
    double bpm = 0.0;
    MusicalKey key;
    float energy = 0.0f;       // 0 calme .. 1 énergique
    double durationSec = 0.0;
    juce::int64 modifiedMs = 0;
};

struct BeatCriteria
{
    double bpmMin = 60.0;
    double bpmMax = 180.0;
    float energy = 0.5f;
    bool minor = true;
    bool useMode = true;
};

class BeatLibrary
{
public:
    std::vector<BeatInfo> beats;

    static juce::File cacheFileFor (const juce::File& folder) { return folder.getChildFile (".studiovoix_beats.json"); }
    bool loadCache (const juce::File& folder);
    bool saveCache (const juce::File& folder) const;

    /** Analyse les fichiers nouveaux ou modifiés. Retourne le nombre de fichiers analysés. */
    int scan (const juce::File& folder, const ProgressFn& progress = {});

    /** Instrus triées de la plus adaptée à la moins adaptée (score 0..1). */
    std::vector<std::pair<float, BeatInfo>> rank (const BeatCriteria& criteria) const;

    static BeatInfo analyse (const juce::File& file, juce::String& error);
};
} // namespace sv::analysis
