#include "LyricsPanel.h"

#include "Theme.h"
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

namespace
{
    /** Mots calés de la voix principale (vide si aucune reconnaissance). */
    const std::vector<LyricWord>& leadWords (const project::Project& p)
    {
        static const std::vector<LyricWord> none;
        const auto* t = p.findTrack (p.leadTrackId());
        return t != nullptr ? t->words : none;
    }

    int currentWord (const std::vector<LyricWord>& words, double t)
    {
        int cur = -1;
        for (size_t i = 0; i < words.size(); ++i)
            if (words[i].startSec <= t)
                cur = static_cast<int> (i);
        return cur;
    }
}

void Prompter::update()
{
    const auto& p = session.project();
    const int line = currentLine (p, session.positionSec());
    const int word = currentWord (leadWords (p), session.positionSec());
    if (line != lastLine || word != lastWord)
    {
        lastLine = line;
        lastWord = word;
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
    const auto& words = leadWords (p);
    if (! words.empty())
    {
        // Karaoké : mots reconnus et calés ; la ligne en cours en gros, le mot en cours en accent.
        const int cur = currentWord (words, session.positionSec());
        std::vector<std::pair<size_t, size_t>> lineRanges;   // [début, fin) dans words
        size_t start = 0;
        for (size_t i = 1; i <= words.size(); ++i)
            if (i == words.size() || words[i].startSec - words[i - 1].endSec > 0.7)
            {
                lineRanges.push_back ({ start, i });
                start = i;
            }
        int curLine = -1;
        for (size_t l = 0; l < lineRanges.size(); ++l)
            if (cur >= static_cast<int> (lineRanges[l].first) && cur < static_cast<int> (lineRanges[l].second))
                curLine = static_cast<int> (l);
        const int h2 = getHeight(), lineH2 = 34;
        int y2 = h2 / 2 - lineH2;
        for (int l = std::max (0, curLine - 1); l < static_cast<int> (lineRanges.size()) && y2 < h2; ++l)
        {
            const bool now = l == curLine;
            juce::String text;
            for (size_t i = lineRanges[static_cast<size_t> (l)].first; i < lineRanges[static_cast<size_t> (l)].second; ++i)
                text << (text.isEmpty() ? "" : " ") << words[i].text;
            g.setColour (now ? theme::text : (l < curLine ? theme::textDim.darker (0.3f) : theme::textDim));
            g.setFont (juce::FontOptions (now ? 22.0f : 16.0f, now ? juce::Font::bold : juce::Font::plain));
            g.drawFittedText (text, 10, y2, getWidth() - 20, lineH2, juce::Justification::centred, 1);
            y2 += lineH2;
        }
        if (cur >= 0)
        {
            g.setColour (theme::accent2);
            g.setFont (juce::FontOptions (26.0f, juce::Font::bold));
            g.drawFittedText (words[static_cast<size_t> (cur)].text, 10, h2 - 40, getWidth() - 20, 32, juce::Justification::centred, 1);
        }
        g.setColour (theme::textDim);
        g.setFont (12.0f);
        g.drawText (juce::String (static_cast<int> (words.size())) + " mots calés par l'IA"_u8, 0, 4, getWidth(), 16, juce::Justification::centred);
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
#if SV_EDITION_IA
    addAndMakeVisible (recognize);
    theme::setButtonKind (recognize, "primary");
    recognize.setTooltip ("whisper.cpp (gratuit, sur ce PC) écoute la voix principale, écrit les paroles si elles sont vides et cale chaque "
                          "mot sur la timeline (prompteur karaoké, mots sous les blocs). Outils à installer dans IA locale."_u8);
    recognize.onClick = [this] { session.recognizeLyrics(); };
#endif
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
    g.fillAll (theme::panel);
}

void LyricsPanel::resized()
{
    auto r = getLocalBounds().reduced (8);
    prompter.setBounds (r.removeFromBottom (r.getHeight() / 2));
    r.removeFromBottom (6);
#if SV_EDITION_IA
    recognize.setBounds (r.removeFromBottom (28));
    r.removeFromBottom (6);
#endif
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
