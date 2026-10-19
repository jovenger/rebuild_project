#pragma once

#include "InternalPlugins.h"
#include "../style/StyleProfiles.h"

#include <map>

// Chaîne visible d'une piste voix : chaque étape de la chaîne du style est une case (allumée, éteinte ou contournée)
// réglable dans la fenêtre de l'effet intégré correspondant. Le style choisit tout automatiquement ; un réglage manuel
// (StageOverride) s'applique par-dessus, étape par étape, au rendu.
namespace sv::plugins
{
struct ChainStage
{
    const char* id;         // clé dans Track::stages ("comp", "eq"…)
    const char* name;       // UTF-8, libellé de la case
    const char* pluginId;   // effet intégré dont la fenêtre règle l'étape
};

/** Étapes dans l'ordre de la chaîne voix (nettoyage … délai). */
const std::vector<ChainStage>& chainStages();
const ChainStage* findStage (const juce::String& id);

/** Réglages actuels de l'étape, sous forme d'état JSON (paramètres de l'effet intégré) : point de départ de la fenêtre. */
juce::MemoryBlock stageState (const ChainStage& s, const style::VocalParams& p);
/** Reporte un état (sortie de la fenêtre de réglage) dans les réglages de l'étape. */
void applyStageState (const ChainStage& s, const juce::MemoryBlock& state, style::VocalParams& p);
/** Neutralise l'étape (aucun effet). */
void bypassStage (const ChainStage& s, style::VocalParams& p);
/** L'étape fait quelque chose avec ces réglages (case allumée). */
bool stageActive (const ChainStage& s, const style::VocalParams& p);
/** Résumé court pour la case (« 4:1 -20 dB », « -12 dB souffle »…). */
juce::String stageSummary (const ChainStage& s, const style::VocalParams& p);
/** Applique les réglages manuels d'une piste par-dessus ceux du style ; retourne une ligne lisible (vide si rien). */
juce::String applyStageOverrides (const std::map<juce::String, StageOverride>& overrides, style::VocalParams& p);
} // namespace sv::plugins
