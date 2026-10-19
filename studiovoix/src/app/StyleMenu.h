#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "core/style/StyleProfiles.h"

// Liste des styles rangée par famille (Rap, Chant / Pop / R&B…). Identifiant d'élément = indice du style + 1.
namespace sv::app
{
inline void fillStyleBox (juce::ComboBox& box)
{
    box.clear (juce::dontSendNotification);
    for (const auto& g : style::styleGroups())
    {
        box.addSectionHeading (juce::String (juce::CharPointer_UTF8 (g.name)));
        for (const auto st : g.styles)
            box.addItem (style::styleName (st), static_cast<int> (st) + 1);
    }
}
} // namespace sv::app
