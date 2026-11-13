#pragma once

#include "../project/Renderer.h"
#include "AiClient.h"

// Fonctions IA facultatives. Principe : l'IA propose des réglages ou du texte, c'est toujours le moteur
// local qui traite le son. Sans clé, chaque fonction a un équivalent local (assistant simple, règles).
namespace sv::ai
{
struct AiSettings
{
    bool enabled = false;
    juce::String textKey;
    juce::String model = kDefaultClaudeModel;
    juce::String musicKey;

    bool textAvailable() const { return enabled && textKey.trim().isNotEmpty(); }
    bool musicAvailable() const { return enabled && musicKey.trim().isNotEmpty(); }
};

/** Résumé chiffré du projet (tonalité, tempo, niveaux, spectre par piste) envoyé à l'IA. */
juce::String describeProjectForAi (const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb);

// 1) Assistant avancé : demande libre -> curseurs de la piste.
struct MacroAdvice
{
    bool ok = false;
    style::Macros macros;
    float timingStrength = 0.0f;
    juce::String explanation;
    juce::String error;
    bool usedAi = false;
};
MacroAdvice adviseMacros (const AiSettings& s, const juce::String& request, const project::Project& p, int trackId,
                          const juce::String& projectSummary);

// 2) Diagnostic du mix.
struct MixDiagnosis
{
    bool ok = false;
    juce::String text;
    juce::String error;
    bool usedAi = false;
};
/** Diagnostic local (règles) toujours disponible. */
MixDiagnosis diagnoseMixLocal (const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb);
MixDiagnosis diagnoseMix (const AiSettings& s, const project::Project& p, const render::RenderSet& renders, float vocalAutoGainDb);

// 3) Aide à l'écriture (IA uniquement).
struct WritingResult
{
    bool ok = false;
    juce::String lyrics;
    juce::String notes;
    juce::String error;
};
WritingResult helpWrite (const AiSettings& s, const juce::String& request, const project::Project& p);

// 4) Style sur mesure : base de style + curseurs + génération pré-cochée.
struct CustomStyle
{
    bool ok = false;
    juce::String name;
    style::Style base = style::Style::Rap;
    style::Macros macros;
    style::GenerationDefaults generation;
    juce::String explanation;
    juce::String error;

    juce::var toVar() const;
    static CustomStyle fromVar (const juce::var& v);
};
CustomStyle createCustomStyle (const AiSettings& s, const juce::String& description);

// 5) Instru : description pour la génération, ou critères de recherche dans la bibliothèque.
struct InstruBrief
{
    bool ok = false;
    juce::String prompt;      // texte pour le générateur musical
    double bpmMin = 60.0, bpmMax = 180.0;
    float energy = 0.5f;      // 0 calme .. 1 énergique
    bool minor = true;
    int lengthSec = 120;
    juce::String explanation;
    juce::String error;
    bool usedAi = false;
};
/** Sans IA : brief par défaut selon le style (tempo typique, énergie). */
InstruBrief briefFromStyle (style::Style st);
InstruBrief briefFromLyrics (const AiSettings& s, const juce::String& lyrics, style::Style st);
} // namespace sv::ai
