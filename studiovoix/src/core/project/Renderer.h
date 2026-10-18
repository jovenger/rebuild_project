#pragma once

#include "../AudioIO.h"
#include "../dsp/MasterChain.h"
#include "../dsp/VocalChain.h"
#include "../gen/BackingGenerator.h"
#include "../gen/TakeComper.h"
#include "../mix/AutoMixer.h"
#include "Project.h"

#include <map>
#include <memory>
#include <mutex>

// Rendu hors temps réel : assemblage des prises, chaîne vocale de chaque piste, génération des backs,
// mix automatique, mastering et export.
namespace sv::render
{
/** Cache des fichiers audio du projet (thread-safe). */
class AudioCache
{
public:
    std::shared_ptr<const Mono> mono (const juce::File& file, double sampleRate, juce::String& error);
    std::shared_ptr<const Stereo> stereo (const juce::File& file, double sampleRate, juce::String& error);
    void put (const juce::File& file, Mono data);
    void clear();

private:
    std::mutex mutex;
    std::map<juce::String, std::shared_ptr<const Mono>> monoCache;
    std::map<juce::String, std::shared_ptr<const Stereo>> stereoCache;
};

struct TrackRender
{
    int trackId = -1;
    long startSample = 0;
    Stereo processed;               // avec effets
    Stereo raw;                     // voix brute (écoute A/B)
    Mono prepared;                  // voix nettoyée + accordée (piste principale : base de la génération)
    analysis::PitchTrack track;
    analysis::VoiceActivity va;
    dsp::VocalReport report;
    juce::String compSummary;
    juce::String error;
    bool ok() const { return error.isEmpty(); }
};

using RenderSet = std::map<int, std::shared_ptr<const TrackRender>>;

/** Contexte musical du projet (tonalité, tempo, spectre de référence). */
dsp::AnalysisContext makeContext (const project::Project& p, AudioCache& cache);

/** Voix brute assemblée d'une piste (prises ou fichier généré). */
bool compositeRaw (const project::Project& p, const project::Track& t, AudioCache& cache, Mono& out, long& start,
                   juce::String& summary, juce::String& error);

std::shared_ptr<TrackRender> renderTrack (const project::Project& p, const project::Track& t, AudioCache& cache,
                                          const dsp::AnalysisContext& ctx, const ProgressFn& progress = {});

/** Génère les pistes d'accompagnement, écrit leurs fichiers et les ajoute au projet. Retourne les ids créés. */
std::vector<int> generateBackingTracks (project::Project& p, int leadTrackId, const TrackRender& leadRender,
                                        const gen::GenerationOptions& options, juce::String& error,
                                        const ProgressFn& progress = {});

struct MixState
{
    mix::AutoMixResult autoMix;
    bool autoMixApplied = false;
};

MixState computeAutoMix (const project::Project& p, const RenderSet& renders);

/** Somme des pistes (volume, panoramique, muet, solo, gain auto). */
Stereo mixdown (const project::Project& p, const RenderSet& renders, const MixState& mixState, bool useRaw = false);

struct ExportOptions
{
    juce::File outDir;
    juce::String baseName = "mix";
    audio::FileFormat format = audio::FileFormat::Wav24;
    bool stems = false;
    bool master = true;
};

struct ExportReport
{
    bool ok = false;
    juce::String error;
    juce::File mixFile;
    juce::StringArray stemFiles;
    dsp::MasterReport master;
    float vocalGainDb = 0.0f;
};

ExportReport exportProject (const project::Project& p, const RenderSet& renders, const ExportOptions& options,
                            const ProgressFn& progress = {});

/** Copie la partie de la piste principale d'une section vers les autres sections du même groupe
    (ex. refrain enregistré une fois). Retourne le nombre de copies. */
int copySectionToSimilar (project::Project& p, int trackId, int sectionIndex, AudioCache& cache, juce::String& error);
} // namespace sv::render
