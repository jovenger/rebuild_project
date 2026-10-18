#include "LyricsPanel.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    int currentLine (const project::Project& p, double t)
    {
        const double lineSec = p.tempo.barSec() * std::max (1, p.lyricsBarsPerLine);
        if (lineSec <= 0.0 || t < p.lyricsStartSec)
            return -1;
        return static_cast<int> ((t - p.lyricsStartSec) / lineSec);
    }
}

void Prompter::update()
{
    const int line = currentLine (session.project(), session.positionSec());
    if (line != lastLine)
    {
        lastLine = line;
        repaint();
    }
}

void Prompter::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::black);
    const auto& p = session.project();
    juce::StringArray lines;
    lines.addLines (p.lyrics);
    lines.removeEmptyStrings (false);
    if (lines.isEmpty())
    {
        g.setColour (juce::Colours::grey);
        g.setFont (14.0f);
        g.drawFittedText ("Écris tes paroles au-dessus : elles défileront ici pendant l'enregistrement."_u8, getLocalBounds().reduced (10),
                          juce::Justification::centred, 3);
        return;
    }
    const int cur = currentLine (p, session.positionSec());
    const int h = getHeight();
    const int lineH = 34;
    int y = h / 2 - lineH;
    for (int i = std::max (0, cur - 1); i < lines.size() && y < h; ++i)
    {
        const bool now = i == cur;
        g.setColour (now ? juce::Colours::yellow : (i < cur ? juce::Colours::darkgrey : juce::Colours::lightgrey));
        g.setFont (juce::FontOptions (now ? 24.0f : 18.0f, now ? juce::Font::bold : juce::Font::plain));
        g.drawFittedText (lines[i], 10, y, getWidth() - 20, lineH, juce::Justification::centred, 1);
        y += lineH;
    }
    if (cur < 0)
    {
        g.setColour (juce::Colours::grey);
        g.setFont (12.0f);
        g.drawText ("Départ des paroles à "_u8 + juce::String (p.lyricsStartSec, 1) + " s", 0, 4, getWidth(), 16, juce::Justification::centred);
    }
}

LyricsPanel::LyricsPanel (Session& s) : session (s), prompter (s)
{
    addAndMakeVisible (editor);
    addAndMakeVisible (barsPerLine);
    addAndMakeVisible (barsLabel);
    addAndMakeVisible (startLabel);
    addAndMakeVisible (startHere);
    addAndMakeVisible (prompter);

    editor.setMultiLine (true, true);
    editor.setReturnKeyStartsNewLine (true);
    editor.setFont (juce::FontOptions (15.0f));
    editor.setTextToShowWhenEmpty ("Une ligne = une phrase. Colle ou écris tes paroles ici."_u8, juce::Colours::grey);
    editor.onTextChange = [this]
    {
        if (! updating)
            session.setLyrics (editor.getText());
    };
    barsLabel.setText ("Mesures par ligne", juce::dontSendNotification);
    for (int v : { 1, 2, 4 })
        barsPerLine.addItem (juce::String (v), v);
    barsPerLine.onChange = [this]
    {
        if (! updating)
            session.updateProject ([v = barsPerLine.getSelectedId()] (project::Project& p) { p.lyricsBarsPerLine = v; }, false, "Mesures par ligne");
    };
    startHere.setTooltip ("La première ligne s'affichera à la position actuelle de la tête de lecture"_u8);
    startHere.onClick = [this]
    {
        const double t = session.positionSec();
        session.updateProject ([t] (project::Project& p) { p.lyricsStartSec = t; }, false, "Début des paroles"_u8);
        refresh();
    };
    refresh();
}

void LyricsPanel::refresh()
{
    const juce::ScopedValueSetter<bool> svs (updating, true);
    const auto& p = session.project();
    if (editor.getText() != p.lyrics)
        editor.setText (p.lyrics, false);
    barsPerLine.setSelectedId (p.lyricsBarsPerLine, juce::dontSendNotification);
    startLabel.setText ("Départ : "_u8 + juce::String (p.lyricsStartSec, 2) + " s", juce::dontSendNotification);
    prompter.repaint();
}

void LyricsPanel::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff1e2228));
}

void LyricsPanel::resized()
{
    auto r = getLocalBounds().reduced (8);
    prompter.setBounds (r.removeFromBottom (r.getHeight() / 2));
    r.removeFromBottom (6);
    auto bar = r.removeFromBottom (26);
    barsLabel.setBounds (bar.removeFromLeft (120));
    barsPerLine.setBounds (bar.removeFromLeft (60));
    bar.removeFromLeft (6);
    startHere.setBounds (bar.removeFromLeft (170));
    startLabel.setBounds (bar);
    r.removeFromBottom (4);
    editor.setBounds (r);
}
} // namespace sv::app
