#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// « Nouvelle piste » (clic droit sur la timeline) : type de piste (voix principale, back, doublage, harmonie,
// ad-libs, ambiance, instrument) et nom. Les effets se règlent automatiquement selon le type et le style
// du projet ; la piste créée est sélectionnée et armée (le micro enregistre dessus).
namespace sv::app
{
void showNewTrackDialog (Session& session, style::Role preselected = style::Role::ManualBack);
} // namespace sv::app
