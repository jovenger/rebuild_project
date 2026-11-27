#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

// Habillage de StudioVoix : une palette unique (fond sombre bleuté, un seul accent violet → rose) et un LookAndFeel
// arrondi pour tout le programme (boutons, curseurs, cases à cocher, listes, onglets, menus, champs de texte).
// Purement visuel : aucun calcul audio, aucune latence ajoutée. Les composants ne codent plus de couleurs en dur.
namespace sv::app::theme
{
const juce::Colour bg        (0xff0f1117);   // fond de fenêtre, fond des pistes
const juce::Colour panel     (0xff161922);   // barre du haut, panneaux de droite, barre d'état
const juce::Colour card      (0xff1e2230);   // cartes : en-têtes de pistes, dialogues, menus, boutons neutres
const juce::Colour cardHover (0xff272c3b);
const juce::Colour line      (0xff2b3040);   // séparateurs, contours
const juce::Colour text      (0xffe9ebf2);
const juce::Colour textDim   (0xff8f96a8);
const juce::Colour accent    (0xff8b5cf6);   // violet
const juce::Colour accent2   (0xffec4899);   // rose (fin du dégradé)
const juce::Colour danger    (0xffef4444);   // REC, saturation, suppression
const juce::Colour ok        (0xff22c55e);
const juce::Colour warn      (0xfff59e0b);
const juce::Colour selection (0xff2a2f4a);   // piste sélectionnée
constexpr float radius = 8.0f;

/** Dégradé violet → rose (boutons principaux, onglet actif). */
juce::ColourGradient accentGradient (juce::Rectangle<float> r);
/** Rôle visuel d'un bouton : "primary" (dégradé d'accent), "danger" (rouge), "ghost" (sans fond) ; vide = neutre. */
void setButtonKind (juce::Button& b, const juce::String& kind);
juce::String buttonKind (const juce::Button& b);
} // namespace sv::app::theme

namespace sv::app
{
class StudioLookAndFeel final : public juce::LookAndFeel_V4
{
public:
    StudioLookAndFeel();

    juce::Font getTextButtonFont (juce::TextButton&, int buttonHeight) override;
    void drawButtonBackground (juce::Graphics&, juce::Button&, const juce::Colour& backgroundColour,
                               bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override;
    void drawToggleButton (juce::Graphics&, juce::ToggleButton&, bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override;
    void drawTickBox (juce::Graphics&, juce::Component&, float x, float y, float w, float h, bool ticked, bool isEnabled,
                      bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override;
    void drawComboBox (juce::Graphics&, int width, int height, bool isButtonDown, int buttonX, int buttonY, int buttonW, int buttonH,
                       juce::ComboBox&) override;
    int getSliderThumbRadius (juce::Slider&) override;
    void drawLinearSlider (juce::Graphics&, int x, int y, int width, int height, float sliderPos, float minSliderPos, float maxSliderPos,
                           juce::Slider::SliderStyle, juce::Slider&) override;
    void drawTabButton (juce::TabBarButton&, juce::Graphics&, bool isMouseOver, bool isMouseDown) override;
    int getTabButtonBestWidth (juce::TabBarButton&, int tabDepth) override;
    void drawTabAreaBehindFrontButton (juce::TabbedButtonBar&, juce::Graphics&, int w, int h) override;
    void drawTabbedButtonBarBackground (juce::TabbedButtonBar&, juce::Graphics&) override;
    void drawPopupMenuBackground (juce::Graphics&, int width, int height) override;
    void fillTextEditorBackground (juce::Graphics&, int width, int height, juce::TextEditor&) override;
    void drawTextEditorOutline (juce::Graphics&, int width, int height, juce::TextEditor&) override;
    void drawScrollbar (juce::Graphics&, juce::ScrollBar&, int x, int y, int width, int height, bool isScrollbarVertical,
                        int thumbStartPosition, int thumbSize, bool isMouseOver, bool isMouseDown) override;
};
} // namespace sv::app
