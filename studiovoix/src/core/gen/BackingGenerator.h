#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/VoiceActivity.h"
#include "../style/StyleProfiles.h"

// Génération automatique des pistes d'accompagnement vocal à partir de la voix principale
// (nettoyée et accordée) : doublages, harmonies, backs sur les mots clés, ad-libs, ambiance.
// Chaque élément produit sa propre piste.
namespace sv::gen
{
enum class AmbianceType { NappeVoix = 0, ChoeurAerien, EchoLointain, Count };

juce::String ambianceId (AmbianceType t);
juce::String ambianceName (AmbianceType t);
AmbianceType ambianceFromId (const juce::String& id);

struct GenerationOptions
{
    int doubles = 1;               // 0..3
    int harmonies = 0;             // 0..3
    bool keywordBacks = true;
    int keywordSyllables = 2;
    bool adLibs = false;
    float adLibDensity = 0.5f;
    bool ambiance = false;
    AmbianceType ambianceType = AmbianceType::NappeVoix;
    juce::File adLibFolder;        // banque d'ad-libs de l'utilisateur (WAV/MP3/FLAC)
    juce::int64 seed = 1234;       // tirages reproductibles

    static GenerationOptions fromDefaults (const style::GenerationDefaults& d);
};

struct GeneratedTrack
{
    style::Role role = style::Role::Double;
    juce::String name;
    Mono audio;          // signal brut de la piste (avant sa propre chaîne de traitement)
    float pan = 0.0f;
    float width = 0.0f;
    juce::String detail; // ex. "tierce au-dessus"
};

struct LeadAnalysis
{
    Mono prepared;                       // voix nettoyée + accordée
    analysis::PitchTrack track;
    analysis::VoiceActivity va;
    MusicalKey key;
    TempoInfo tempo;
};

std::vector<GeneratedTrack> generate (const LeadAnalysis& lead, double sampleRate, const GenerationOptions& options,
                                      const ProgressFn& progress = {});

// Fonctions élémentaires (exposées pour les tests).
GeneratedTrack makeDouble (const LeadAnalysis& lead, double sr, int index, int total, juce::Random& rng);
GeneratedTrack makeHarmony (const LeadAnalysis& lead, double sr, int index);
GeneratedTrack makeKeywordBacks (const LeadAnalysis& lead, double sr, int syllables);
GeneratedTrack makeAdLibs (const LeadAnalysis& lead, double sr, const GenerationOptions& options, juce::Random& rng,
                           int& placedCount);
GeneratedTrack makeAmbiance (const LeadAnalysis& lead, double sr, AmbianceType type);
} // namespace sv::gen
