#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// « Nouvelle piste » (clic droit sur la timeline) : type de piste (voix principale, back, doublage, harmonie,
// ad-libs, ambiance, instrument) et nom. Les effets se règlent automatiquement selon le type et le style
// du projet ; la piste créée est sélectionnée et armée (le micro enregistre dessus).
namespace sv::app
{
void showNewTrackDialog (Session& session, style::Role preselected = style::Role::ManualBack);

/** Glisser-déposer de fichiers audio : une nouvelle piste par fichier, type proposé d'après le nom du fichier
    (« instru », « beat » -> instru ; « voix », « vocal » -> voix ; « guitare », « piano » -> instrument…).
    startSec : position de dépôt sur la timeline (0 hors de la timeline). */
void showImportDialog (Session& session, const juce::StringArray& files, double startSec);

/** Extensions audio acceptées (minuscules, avec le point). */
bool isImportableAudioFile (const juce::String& path);
} // namespace sv::app
