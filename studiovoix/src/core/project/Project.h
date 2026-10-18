#pragma once

#include "../Types.h"
#include "../analysis/StructureDetector.h"
#include "../dsp/MasterChain.h"
#include "../gen/BackingGenerator.h"
#include "../plugins/PluginChain.h"
#include "../style/StyleProfiles.h"

#include <juce_core/juce_core.h>

#include <map>

// Modèle de projet StudioVoix. Un projet = un dossier :
//   projet.svx        description JSON
//   audio/            prises (WAV 32 bits flottants, jamais modifiées) et pistes générées
//   historique/       versions horodatées (sauvegardes manuelles et avant chaque génération)
//   projet.autosave   sauvegarde automatique (récupération après plantage)
namespace sv::project
{
enum class CompMode { Latest = 0, Best };

struct Take
{
    int id = 0;
    juce::String file;          // relatif au dossier audio/
    long startSample = 0;       // position du premier échantillon du fichier sur la timeline
    long regionStart = 0;       // zone utilisée (absolue)
    long regionEnd = 0;
    juce::int64 createdMs = 0;
    bool punch = false;
    long fadeIn = 0;            // fondu d'entrée (échantillons) à partir de regionStart
    long fadeOut = 0;           // fondu de sortie (échantillons) jusqu'à regionEnd
};

struct Track
{
    int id = 0;
    juce::String name;
    style::Role role = style::Role::Lead;
    float volumeDb = 0.0f;
    float pan = 0.0f;
    bool mute = false;
    bool solo = false;
    bool processingEnabled = true;   // false = écoute de la voix brute (A/B)
    style::Macros macros;
    float timingStrength = 0.0f;
    bool cleaning = true;
    bool referenceEq = false;
    CompMode comp = CompMode::Latest;
    std::vector<Take> takes;
    // Fichier importé / glissé : brut (aucun effet, hors mix auto) tant qu'aucun style n'est choisi dans le panneau.
    bool raw = false;
    juce::String styleId;            // style propre à la piste ; vide = style du projet ; "correction" = correction automatique
    bool isCorrection() const { return styleId == "correction"; }
    std::vector<plugins::PluginSlot> plugins;   // inserts VST3 appliqués après les effets
    std::map<juce::String, plugins::StageOverride> stages;   // chaîne visible : étapes contournées / réglées à la main (clé = étape)

    // Pistes générées / instru
    juce::String sourceFile;         // relatif à audio/ (piste générée) ou chemin de l'instru
    long sourceStart = 0;
    int generatedFrom = -1;          // id de la piste principale d'origine
    juce::String detail;
    float genPan = 0.0f;
    float genWidth = 0.0f;

    bool isVocal() const { return role != style::Role::Instru; }
    bool isGenerated() const { return generatedFrom >= 0; }
    /** Peut recevoir une prise au micro (ni l'instru importée, ni une piste générée). */
    bool isRecordable() const { return isVocal() && ! isGenerated(); }
    /** Voix (pour le mix auto : sonie de la voix, creux de l'instru) — un instrument enregistré n'en est pas une. */
    bool isVoice() const { return isVocal() && role != style::Role::Instrument; }
};

/** Édition des blocs (prises) : chaque fonction retourne false si la prise n'existe pas ou si l'opération est impossible
    (journalisé). Les positions sont absolues (timeline, échantillons). */
Take* findTake (Track& t, int takeId);
/** Coupe la prise en deux à atSample : la partie gauche garde l'id et le fondu d'entrée, la droite devient une nouvelle
    prise (même fichier, nextTakeId) avec le fondu de sortie. */
bool splitTake (Track& t, int takeId, long atSample, int& nextTakeId);
/** Rogne les bords : nouvelle zone [newStart, newEnd), bornée au fichier (fileLength échantillons ; 0 = inconnue) et
    longue d'au moins minLength échantillons. Les fondus sont réduits si la zone devient plus courte. */
bool trimTake (Track& t, int takeId, long newStart, long newEnd, long fileLength, long minLength);
/** Fondus d'entrée / sortie (échantillons), bornés à la zone (leur somme ne dépasse pas sa longueur). */
bool setTakeFades (Track& t, int takeId, long fadeIn, long fadeOut);
bool removeTake (Track& t, int takeId);

struct Marker
{
    double timeSec = 0.0;
    juce::String name;
};

struct Project
{
    juce::String name = "Nouveau projet";
    double sampleRate = kProjectSampleRate;
    style::Style style = style::Style::Rap;
    MusicalKey key;
    bool keyManual = false;
    TempoInfo tempo;
    bool tempoManual = false;
    std::vector<analysis::Section> sections;
    std::vector<Marker> markers;
    juce::String lyrics;
    int lyricsBarsPerLine = 1;
    double lyricsStartSec = 0.0;     // position où la première ligne doit être chantée
    dsp::LoudnessTarget target = dsp::LoudnessTarget::Spotify;
    bool masterEnabled = true;
    bool autoMixEnabled = true;
    bool vocalBusEnabled = true;     // bus voix : toutes les voix passent ensemble dans le compresseur « colle »
    float duckingDb = 2.5f;
    juce::String referenceFile;      // morceau de référence (chemin absolu)
    juce::StringArray loadWarnings;  // réparations faites au chargement (non enregistré)
    juce::String adLibFolder;        // banque d'ad-libs (chemin absolu)
    std::vector<Track> tracks;
    int nextTrackId = 1;
    int armedTrackId = -1;   // piste armée (bouton REC) : le micro enregistre sur elle ; -1 = aucune
    int nextTakeId = 1;
    juce::File folder;

    // Fichiers du projet
    juce::File projectFile() const { return folder.getChildFile ("projet.svx"); }
    juce::File autosaveFile() const { return folder.getChildFile ("projet.autosave"); }
    juce::File audioDir() const { return folder.getChildFile ("audio"); }
    juce::File historyDir() const { return folder.getChildFile ("historique"); }
    juce::File exportDir() const { return folder.getChildFile ("exports"); }

    Track* findTrack (int id);
    const Track* findTrack (int id) const;
    Track& addTrack (style::Role role, const juce::String& trackName);
    bool removeTrack (int id);
    int leadTrackId() const;
    const Track* instruTrack() const;
    /** Style qui traite cette piste : le sien s'il est choisi, sinon celui du projet. */
    style::Style trackStyle (const Track& t) const { return t.styleId.isNotEmpty() && ! t.isCorrection() ? style::styleFromId (t.styleId) : style; }
    double lengthSec() const;   // fin de la dernière prise ou de l'instru (approx.)

    juce::var toVar() const;
    static bool fromVar (const juce::var& v, Project& out, juce::String& error);

    bool save (juce::String& error) const;
    bool saveAutosave (juce::String& error) const;
    /** Copie horodatée dans historique/ (garde les 50 dernières). */
    bool saveVersion (const juce::String& label, juce::String& error) const;
    static bool load (const juce::File& folderOrFile, Project& out, juce::String& error, bool preferAutosave = false);
    static bool hasNewerAutosave (const juce::File& folder);
    juce::StringArray listVersions() const;
};

juce::File defaultProjectsRoot();
/** Crée un dossier de projet unique sous root (nom nettoyé). */
juce::File createProjectFolder (const juce::File& root, const juce::String& name, juce::String& error);

/** Recalage de latence : position timeline du premier échantillon enregistré. */
long compensatedTakeStart (long recordStartSample, int inputLatency, int outputLatency, int manualOffsetSamples);
} // namespace sv::project
