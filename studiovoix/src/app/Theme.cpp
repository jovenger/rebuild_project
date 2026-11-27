#include "Theme.h"

#include "core/Log.h"

namespace sv::app
{
namespace theme
{
    juce::ColourGradient accentGradient (juce::Rectangle<float> r)
    {
        return juce::ColourGradient::horizontal (accent, accent2, r);
    }

    void setButtonKind (juce::Button& b, const juce::String& kind)
    {
        b.getProperties().set ("kind", kind);
        b.repaint();
    }

    juce::String buttonKind (const juce::Button& b)
    {
        return b.getProperties().getWithDefault ("kind", juce::String()).toString();
    }
} // namespace theme

StudioLookAndFeel::StudioLookAndFeel()
{
    using namespace juce;
    setColour (ResizableWindow::backgroundColourId, theme::bg);
    setColour (DocumentWindow::textColourId, theme::text);
    setColour (TextButton::buttonColourId, theme::card);
    setColour (TextButton::buttonOnColourId, theme::accent);
    setColour (TextButton::textColourOffId, theme::text);
    setColour (TextButton::textColourOnId, Colours::white);
    setColour (ToggleButton::textColourId, theme::text);
    setColour (ToggleButton::tickColourId, Colours::white);
    setColour (ToggleButton::tickDisabledColourId, theme::textDim);
    setColour (Label::textColourId, theme::text);
    setColour (Label::backgroundColourId, Colours::transparentBlack);
    setColour (Slider::backgroundColourId, theme::line);
    setColour (Slider::trackColourId, theme::accent);
    setColour (Slider::thumbColourId, Colours::white);
    setColour (Slider::textBoxTextColourId, theme::text);
    setColour (Slider::textBoxBackgroundColourId, theme::bg);
    setColour (Slider::textBoxOutlineColourId, theme::line);
    setColour (Slider::textBoxHighlightColourId, theme::accent.withAlpha (0.4f));
    setColour (ComboBox::backgroundColourId, theme::card);
    setColour (ComboBox::textColourId, theme::text);
    setColour (ComboBox::outlineColourId, theme::line);
    setColour (ComboBox::arrowColourId, theme::textDim);
    setColour (ComboBox::buttonColourId, theme::card);
    setColour (ComboBox::focusedOutlineColourId, theme::accent);
    setColour (PopupMenu::backgroundColourId, theme::card);
    setColour (PopupMenu::textColourId, theme::text);
    setColour (PopupMenu::highlightedBackgroundColourId, theme::accent.withAlpha (0.45f));
    setColour (PopupMenu::highlightedTextColourId, Colours::white);
    setColour (PopupMenu::headerTextColourId, theme::textDim);
    setColour (TextEditor::backgroundColourId, theme::bg);
    setColour (TextEditor::textColourId, theme::text);
    setColour (TextEditor::outlineColourId, theme::line);
    setColour (TextEditor::focusedOutlineColourId, theme::accent);
    setColour (TextEditor::highlightColourId, theme::accent.withAlpha (0.4f));
    setColour (TextEditor::highlightedTextColourId, Colours::white);
    setColour (CaretComponent::caretColourId, theme::accent2);
    setColour (TabbedComponent::backgroundColourId, theme::panel);
    setColour (TabbedComponent::outlineColourId, theme::panel);
    setColour (TabbedButtonBar::tabOutlineColourId, theme::panel);
    setColour (TabbedButtonBar::frontOutlineColourId, theme::panel);
    setColour (TabbedButtonBar::tabTextColourId, theme::textDim);
    setColour (TabbedButtonBar::frontTextColourId, theme::text);
    setColour (ScrollBar::thumbColourId, theme::line.brighter (0.6f));
    setColour (ScrollBar::backgroundColourId, Colours::transparentBlack);
    setColour (ScrollBar::trackColourId, Colours::transparentBlack);
    setColour (ListBox::backgroundColourId, theme::bg);
    setColour (ListBox::outlineColourId, theme::line);
    setColour (ListBox::textColourId, theme::text);
    setColour (AlertWindow::backgroundColourId, theme::card);
    setColour (AlertWindow::textColourId, theme::text);
    setColour (AlertWindow::outlineColourId, theme::line);
    setColour (TooltipWindow::backgroundColourId, theme::card);
    setColour (TooltipWindow::textColourId, theme::text);
    setColour (TooltipWindow::outlineColourId, theme::line);
    setColour (ProgressBar::backgroundColourId, theme::bg);
    setColour (ProgressBar::foregroundColourId, theme::accent);
    setColour (GroupComponent::outlineColourId, theme::line);
    setColour (GroupComponent::textColourId, theme::textDim);
    setColour (TableHeaderComponent::backgroundColourId, theme::card);
    setColour (TableHeaderComponent::textColourId, theme::text);
    setColour (TableHeaderComponent::outlineColourId, theme::line);
    setColour (TableHeaderComponent::highlightColourId, theme::cardHover);
    setColour (HyperlinkButton::textColourId, theme::accent2);
    setColour (FileBrowserComponent::currentPathBoxBackgroundColourId, theme::card);
    setColour (FileBrowserComponent::currentPathBoxTextColourId, theme::text);
    setColour (FileBrowserComponent::filenameBoxBackgroundColourId, theme::bg);
    setColour (FileBrowserComponent::filenameBoxTextColourId, theme::text);
    setColour (DirectoryContentsDisplayComponent::highlightColourId, theme::accent.withAlpha (0.4f));
    setColour (DirectoryContentsDisplayComponent::textColourId, theme::text);
#if JUCE_WINDOWS
    setDefaultSansSerifTypefaceName ("Segoe UI");   // police système moderne, rien à embarquer
#endif
    SV_LOG_INFO ("Habillage", "Habillage StudioVoix chargé (fond sombre, accent violet / rose)"_u8);
}

juce::Font StudioLookAndFeel::getTextButtonFont (juce::TextButton&, int buttonHeight)
{
    return juce::Font (juce::FontOptions (juce::jmin (14.0f, static_cast<float> (buttonHeight) * 0.55f)));
}

void StudioLookAndFeel::drawButtonBackground (juce::Graphics& g, juce::Button& b, const juce::Colour& backgroundColour,
                                              bool highlighted, bool down)
{
    const auto r = b.getLocalBounds().toFloat().reduced (0.5f);
    const float rad = juce::jmin (theme::radius, r.getHeight() * 0.5f);
    const auto kind = theme::buttonKind (b);
    const bool on = b.getToggleState();
    if (kind == "ghost" && ! on && ! highlighted && ! down)
        return;
    if (kind == "primary" || (kind.isEmpty() && on && backgroundColour == theme::accent))
    {
        g.setGradientFill (theme::accentGradient (r));
        g.fillRoundedRectangle (r, rad);
        if (highlighted || down)
        {
            g.setColour (juce::Colours::white.withAlpha (down ? 0.18f : 0.10f));
            g.fillRoundedRectangle (r, rad);
        }
        return;
    }
    juce::Colour fill = backgroundColour;
    if (kind == "danger")
        fill = on ? theme::danger : theme::danger.withAlpha (0.25f);
    else if (fill == theme::card || kind == "ghost")
        fill = on ? theme::accent.withAlpha (0.85f) : theme::card;
    if (down)
        fill = fill.brighter (0.25f);
    else if (highlighted)
        fill = fill.brighter (0.12f);
    g.setColour (fill);
    g.fillRoundedRectangle (r, rad);
    g.setColour (on || kind == "danger" ? fill.brighter (0.3f) : theme::line);
    g.drawRoundedRectangle (r, rad, 1.0f);
}

void StudioLookAndFeel::drawTickBox (juce::Graphics& g, juce::Component&, float x, float y, float w, float h, bool ticked, bool isEnabled,
                                     bool highlighted, bool)
{
    const auto box = juce::Rectangle<float> (x, y, w, h).reduced (1.0f);
    const float rad = 4.0f;
    if (ticked)
    {
        g.setGradientFill (theme::accentGradient (box));
        g.fillRoundedRectangle (box, rad);
        juce::Path tick;
        tick.startNewSubPath (box.getX() + box.getWidth() * 0.25f, box.getCentreY());
        tick.lineTo (box.getX() + box.getWidth() * 0.45f, box.getBottom() - box.getHeight() * 0.3f);
        tick.lineTo (box.getRight() - box.getWidth() * 0.22f, box.getY() + box.getHeight() * 0.3f);
        g.setColour (juce::Colours::white);
        g.strokePath (tick, juce::PathStrokeType (2.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }
    else
    {
        g.setColour (highlighted ? theme::cardHover : theme::card);
        g.fillRoundedRectangle (box, rad);
        g.setColour (isEnabled ? theme::line.brighter (0.4f) : theme::line);
        g.drawRoundedRectangle (box, rad, 1.0f);
    }
}

void StudioLookAndFeel::drawToggleButton (juce::Graphics& g, juce::ToggleButton& b, bool highlighted, bool down)
{
    const float size = juce::jmin (18.0f, static_cast<float> (b.getHeight()) - 4.0f);
    drawTickBox (g, b, 2.0f, (static_cast<float> (b.getHeight()) - size) * 0.5f, size, size, b.getToggleState(), b.isEnabled(), highlighted, down);
    g.setColour (b.findColour (juce::ToggleButton::textColourId).withMultipliedAlpha (b.isEnabled() ? 1.0f : 0.5f));
    g.setFont (juce::FontOptions (juce::jmin (14.0f, static_cast<float> (b.getHeight()) * 0.6f)));
    g.drawFittedText (b.getButtonText(), b.getLocalBounds().withTrimmedLeft (static_cast<int> (size) + 8), juce::Justification::centredLeft, 2);
}

void StudioLookAndFeel::drawComboBox (juce::Graphics& g, int width, int height, bool, int, int, int, int, juce::ComboBox& box)
{
    auto r = juce::Rectangle<int> (0, 0, width, height).toFloat().reduced (0.5f);
    const float rad = juce::jmin (theme::radius, r.getHeight() * 0.5f);
    g.setColour (box.findColour (juce::ComboBox::backgroundColourId));
    g.fillRoundedRectangle (r, rad);
    g.setColour (box.hasKeyboardFocus (true) ? theme::accent : theme::line);
    g.drawRoundedRectangle (r, rad, 1.0f);
    // Chevron à droite.
    const auto arrow = r.removeFromRight (static_cast<float> (height)).reduced (static_cast<float> (height) * 0.32f);
    juce::Path p;
    p.startNewSubPath (arrow.getX(), arrow.getCentreY() - arrow.getHeight() * 0.15f);
    p.lineTo (arrow.getCentreX(), arrow.getCentreY() + arrow.getHeight() * 0.2f);
    p.lineTo (arrow.getRight(), arrow.getCentreY() - arrow.getHeight() * 0.15f);
    g.setColour (box.findColour (juce::ComboBox::arrowColourId).withMultipliedAlpha (box.isEnabled() ? 1.0f : 0.4f));
    g.strokePath (p, juce::PathStrokeType (1.8f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
}

int StudioLookAndFeel::getSliderThumbRadius (juce::Slider& s)
{
    return juce::jmin (7, s.isHorizontal() ? s.getHeight() / 2 : s.getWidth() / 2);
}

void StudioLookAndFeel::drawLinearSlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos, float minSliderPos,
                                          float maxSliderPos, juce::Slider::SliderStyle style, juce::Slider& s)
{
    if (style != juce::Slider::LinearHorizontal && style != juce::Slider::LinearVertical && style != juce::Slider::LinearBar)
    {
        juce::LookAndFeel_V4::drawLinearSlider (g, x, y, width, height, sliderPos, minSliderPos, maxSliderPos, style, s);
        return;
    }
    const bool horizontal = style != juce::Slider::LinearVertical;
    const float thickness = style == juce::Slider::LinearBar ? static_cast<float> (height) - 4.0f : 4.0f;
    const auto fx = static_cast<float> (x), fy = static_cast<float> (y), fw = static_cast<float> (width), fh = static_cast<float> (height);
    juce::Rectangle<float> track = horizontal ? juce::Rectangle<float> (fx, fy + (fh - thickness) * 0.5f, fw, thickness)
                                              : juce::Rectangle<float> (fx + (fw - thickness) * 0.5f, fy, thickness, fh);
    const float rad = thickness * 0.5f;
    g.setColour (s.findColour (juce::Slider::backgroundColourId));
    g.fillRoundedRectangle (track, rad);
    // Partie « remplie » : du début (ou du zéro pour un curseur bipolaire) jusqu'à la position.
    const double zero = s.getMinimum() < 0.0 && s.getMaximum() > 0.0 ? s.valueToProportionOfLength (0.0) : 0.0;
    juce::Rectangle<float> filled;
    if (horizontal)
    {
        const float zx = fx + static_cast<float> (zero) * fw;
        filled = juce::Rectangle<float> (juce::jmin (zx, sliderPos), track.getY(), std::abs (sliderPos - zx), thickness);
    }
    else
    {
        const float zy = fy + fh - static_cast<float> (zero) * fh;
        filled = juce::Rectangle<float> (track.getX(), juce::jmin (zy, sliderPos), thickness, std::abs (sliderPos - zy));
    }
    g.setGradientFill (theme::accentGradient (track));
    g.fillRoundedRectangle (filled, rad);
    if (style != juce::Slider::LinearBar)
    {
        const float tr = static_cast<float> (getSliderThumbRadius (s));
        const auto centre = horizontal ? juce::Point<float> (sliderPos, track.getCentreY()) : juce::Point<float> (track.getCentreX(), sliderPos);
        g.setColour (juce::Colours::black.withAlpha (0.35f));
        g.fillEllipse (juce::Rectangle<float> (tr * 2.0f + 2.0f, tr * 2.0f + 2.0f).withCentre (centre.translated (0.0f, 1.0f)));
        g.setColour (s.isEnabled() ? s.findColour (juce::Slider::thumbColourId) : theme::textDim);
        g.fillEllipse (juce::Rectangle<float> (tr * 2.0f, tr * 2.0f).withCentre (centre));
    }
}

int StudioLookAndFeel::getTabButtonBestWidth (juce::TabBarButton& b, int tabDepth)
{
    const auto font = juce::Font (juce::FontOptions (13.5f, juce::Font::bold));
    return juce::jmax (60, juce::GlyphArrangement::getStringWidthInt (font, b.getButtonText()) + tabDepth);
}

void StudioLookAndFeel::drawTabButton (juce::TabBarButton& b, juce::Graphics& g, bool isMouseOver, bool)
{
    auto area = b.getActiveArea().toFloat();
    const bool front = b.isFrontTab();
    if (isMouseOver && ! front)
    {
        g.setColour (theme::cardHover.withAlpha (0.6f));
        g.fillRoundedRectangle (area.reduced (2.0f), 6.0f);
    }
    g.setColour (front ? theme::text : theme::textDim);
    g.setFont (juce::FontOptions (13.5f, front ? juce::Font::bold : juce::Font::plain));
    g.drawFittedText (b.getButtonText(), area.toNearestInt().reduced (4, 0), juce::Justification::centred, 1);
    if (front)
    {
        auto under = area.removeFromBottom (3.0f).reduced (8.0f, 0.0f);
        g.setGradientFill (theme::accentGradient (under));
        g.fillRoundedRectangle (under, 1.5f);
    }
}

void StudioLookAndFeel::drawTabAreaBehindFrontButton (juce::TabbedButtonBar&, juce::Graphics&, int, int) {}

void StudioLookAndFeel::drawTabbedButtonBarBackground (juce::TabbedButtonBar& bar, juce::Graphics& g)
{
    g.fillAll (theme::panel);
    g.setColour (theme::line);
    g.fillRect (0, bar.getHeight() - 1, bar.getWidth(), 1);
}

void StudioLookAndFeel::drawPopupMenuBackground (juce::Graphics& g, int width, int height)
{
    const auto r = juce::Rectangle<int> (0, 0, width, height).toFloat().reduced (0.5f);
    g.setColour (theme::card);
    g.fillRoundedRectangle (r, 6.0f);
    g.setColour (theme::line.brighter (0.3f));
    g.drawRoundedRectangle (r, 6.0f, 1.0f);
}

void StudioLookAndFeel::fillTextEditorBackground (juce::Graphics& g, int width, int height, juce::TextEditor& e)
{
    g.setColour (e.findColour (juce::TextEditor::backgroundColourId));
    g.fillRoundedRectangle (juce::Rectangle<int> (0, 0, width, height).toFloat(), 6.0f);
}

void StudioLookAndFeel::drawTextEditorOutline (juce::Graphics& g, int width, int height, juce::TextEditor& e)
{
    if (! e.isEnabled() || e.findColour (juce::TextEditor::outlineColourId).isTransparent())
        return;
    g.setColour (e.hasKeyboardFocus (true) && ! e.isReadOnly() ? e.findColour (juce::TextEditor::focusedOutlineColourId)
                                                               : e.findColour (juce::TextEditor::outlineColourId));
    g.drawRoundedRectangle (juce::Rectangle<int> (0, 0, width, height).toFloat().reduced (0.5f), 6.0f, 1.0f);
}

void StudioLookAndFeel::drawScrollbar (juce::Graphics& g, juce::ScrollBar& bar, int x, int y, int width, int height, bool vertical,
                                       int thumbStart, int thumbSize, bool isMouseOver, bool isMouseDown)
{
    juce::ignoreUnused (bar);
    auto thumb = vertical ? juce::Rectangle<int> (x, thumbStart, width, thumbSize) : juce::Rectangle<int> (thumbStart, y, thumbSize, height);
    if (thumbSize <= 0)
        return;
    g.setColour (theme::line.brighter (isMouseDown ? 1.0f : isMouseOver ? 0.8f : 0.5f));
    g.fillRoundedRectangle (thumb.toFloat().reduced (vertical ? 3.0f : 1.0f, vertical ? 1.0f : 3.0f), 3.0f);
}
} // namespace sv::app
