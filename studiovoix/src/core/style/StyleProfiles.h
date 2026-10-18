#pragma once

#include "../Types.h"
#include "../dsp/Processors.h"
#include "../dsp/TimingCorrector.h"

#include <juce_core/juce_core.h>

#include <vector>

// Profils de style : réglages de départ de la chaîne vocale pour chaque style et chaque rôle de piste.
// Ce sont des points de départ raisonnables, à affiner à l'oreille.
namespace sv::style
{
// Ordre = ordre d'affichage. Les fichiers (projet, "Mon son", IA) stockent l'identifiant texte, jamais l'indice :
// ajouter un style à la fin ne casse aucun projet existant.
enum class Style
{
    Rap = 0, Trap, PopUrbaine, RnB, Drill, Afro, Rock, Latino,
    RapMelodique, BoomBap, Pop, Variete, Dancehall, Zouk, Amapiano, Gospel, Electro, Acoustique,
    RapConscient, RapHardcore, CloudRap, Rage, Plugg, EmoRap, AfroTrap, LoFi, Phonk, JerseyClub, Rai, Bouyon,
    FunkBresilien, AfroHouse, Country,
    Count
};

enum class Role
{
    Instru = 0,
    Lead,          // voix principale
    Double,        // doublage généré
    Harmony,       // harmonie générée
    KeywordBack,   // backs sur les mots clés (fins de phrases)
    AdLib,         // ad-libs
    Ambiance,      // nappe / ambiance
    ManualBack,    // back enregistré à la main
    Count
};

/** Familles affichées dans les listes (chaque style apparaît dans exactement une famille). */
struct StyleGroup
{
    const char* name;   // UTF-8
    std::vector<Style> styles;
};
const std::vector<StyleGroup>& styleGroups();

juce::String styleId (Style s);           // identifiant stable ("trap")
juce::String styleName (Style s);         // nom affiché ("Trap")
Style styleFromId (const juce::String& id);
juce::String roleId (Role r);
juce::String roleName (Role r);
Role roleFromId (const juce::String& id);

/** Curseurs simples (0..1, 0,5 = réglage du style). */
struct Macros
{
    float autotune = 0.5f;
    float presence = 0.5f;
    float space = 0.5f;
    float energy = 0.5f;
    float level = 0.5f;          // volume relatif de la piste (0,5 = 0 dB, ±12 dB)
    float reverbTrim = 0.5f;     // ajustements fins demandés par l'assistant
    float delayTrim = 0.5f;

    juce::var toVar() const;
    static Macros fromVar (const juce::var& v);
};

struct PitchSettings
{
    bool enabled = true;
    float amount = 0.5f;
    float retuneMs = 30.0f;
    float humanize = 0.5f;
};

/** Tous les réglages d'une piste vocale. */
struct VocalParams
{
    float inputTargetDb = -20.0f;   // normalisation d'entrée (RMS des passages actifs)
    dsp::CleanSettings clean;
    dsp::TimingParams timing;
    PitchSettings pitch;
    dsp::EqSettings eq;
    dsp::CompressorSettings comp;
    dsp::CompressorSettings comp2;   // compresseur de nivellement (ratio 1 = désactivé)
    dsp::DeEsserSettings deEss;
    dsp::SaturationSettings sat;
    dsp::ReverbSettings reverb;
    dsp::DelaySettings delay;
    float outputDb = -6.0f;          // niveau de sortie (RMS actif) avant le fader
    float dryGain = 1.0f;            // 0 = seulement les effets (ambiance)
    float pan = 0.0f;
    float width = 0.0f;
    bool referenceEq = false;
    float referenceStrength = 0.6f;
};

/** Réglages de départ pour un style et un rôle, puis application des curseurs. */
VocalParams makeParams (Style s, Role r, const Macros& macros);

/** Options de génération pré-cochées selon le style. */
struct GenerationDefaults
{
    int doubles = 1;
    int harmonies = 0;
    bool keywordBacks = true;
    bool adLibs = false;
    bool ambiance = false;
    float ambianceLevel = 0.5f;     // 0..1
    int keywordSyllables = 2;       // syllabes doublées en fin de phrase
    float adLibDensity = 0.5f;      // probabilité d'ad-lib dans un silence
};
GenerationDefaults generationDefaults (Style s);

/** Profils de mastering par style : inclinaison spectrale. */
struct MasterTone
{
    float lowShelfDb = 0.0f;
    float highShelfDb = 0.0f;
    float vocalOverInstruLu = 0.0f;   // sonie de la voix principale par rapport à l'instru
};
MasterTone masterTone (Style s);
} // namespace sv::style
