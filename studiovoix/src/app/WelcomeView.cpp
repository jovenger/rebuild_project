#include "WelcomeView.h"

#include "Theme.h"
#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "Accueil";

    struct RecentProject
    {
        juce::File folder;
        juce::Time modified;
        int tracks = 0;
        juce::String style;
    };

    /** Projets du dossier Projets, du plus récent au plus ancien (lecture rapide du JSON, sans audio). */
    std::vector<RecentProject> recentProjects (int maxCount)
    {
        std::vector<RecentProject> list;
        const auto root = project::defaultProjectsRoot();
        for (const auto& entry : juce::RangedDirectoryIterator (root, false, "*", juce::File::findDirectories))
        {
            const auto file = entry.getFile().getChildFile ("projet.svx");
            if (! file.existsAsFile())
                continue;
            RecentProject rp;
            rp.folder = entry.getFile();
            rp.modified = file.getLastModificationTime();
            juce::var v;
            if (juce::JSON::parse (file.loadFileAsString(), v).wasOk())
            {
                if (const auto* tr = v.getProperty ("tracks", {}).getArray())
                    rp.tracks = tr->size();
                rp.style = style::styleName (style::styleFromId (v.getProperty ("style", {}).toString()));
            }
            list.push_back (rp);
        }
        std::sort (list.begin(), list.end(), [] (const RecentProject& a, const RecentProject& b) { return a.modified > b.modified; });
        if (static_cast<int> (list.size()) > maxCount)
            list.resize (static_cast<size_t> (maxCount));
        SV_LOG_INFO (kMod, juce::String (static_cast<int> (list.size())) + " projet(s) récent(s) dans "_u8 + root.getFullPathName());
        return list;
    }

    juce::String frenchDate (const juce::Time& t)
    {
        const auto today = juce::Time::getCurrentTime();
        if (t.toString (true, false) == today.toString (true, false))
            return "aujourd'hui " + t.formatted ("%H:%M");
        return t.formatted ("%d/%m/%Y %H:%M");
    }
} // namespace

WelcomeView::WelcomeView (Session& s) : session (s)
{
    setWantsKeyboardFocus (true);
    addAndMakeVisible (folderBtn);
    theme::setButtonKind (folderBtn, "ghost");
    folderBtn.onClick = [] { project::defaultProjectsRoot().revealToUser(); };
    refresh();
}

void WelcomeView::refresh()
{
    cards.clear();
    const auto& p = session.project();
    Card n;
    n.title = "Nouveau projet";
    n.subtitle = "Choisis un style, pose une instru, enregistre"_u8;
    n.action = Action::New;
    n.primary = true;
    cards.push_back (n);
    Card o;
    o.title = "Ouvrir un projet...";
    o.subtitle = "Un dossier StudioVoix (projet.svx)";
    o.action = Action::Open;
    cards.push_back (o);
    if (p.folder != juce::File())
    {
        Card r;
        r.title = "Reprendre « "_u8 + p.name + " »"_u8;
        r.subtitle = juce::String (static_cast<int> (p.tracks.size())) + " piste(s), style " + style::styleName (p.style);
        r.action = Action::Resume;
        cards.push_back (r);
    }
    for (const auto& rp : recentProjects (8))
    {
        if (rp.folder == p.folder)
            continue;
        Card c;
        c.title = rp.folder.getFileName();
        c.subtitle = frenchDate (rp.modified);
        c.detail = juce::String (rp.tracks) + " piste(s)" + (rp.style.isNotEmpty() ? ", " + rp.style : juce::String());
        c.folder = rp.folder;
        cards.push_back (c);
    }
    resized();
    repaint();
}

void WelcomeView::resized()
{
    auto r = getLocalBounds().reduced (juce::jmax (40, getWidth() / 10), 40);
    r.removeFromTop (150);   // titre
    const int gap = 16;
    // Trois grandes cartes d'action sur une ligne, puis les projets récents en grille de 4.
    int actions = 0;
    for (const auto& c : cards)
        actions += c.action != Action::Recent ? 1 : 0;
    auto row = r.removeFromTop (110);
    const int aw = actions > 0 ? (row.getWidth() - gap * (actions - 1)) / actions : row.getWidth();
    size_t i = 0;
    for (; i < cards.size() && cards[i].action != Action::Recent; ++i)
    {
        cards[i].bounds = row.removeFromLeft (aw);
        row.removeFromLeft (gap);
    }
    r.removeFromTop (gap + 30);   // sous-titre « Projets récents »
    const int perRow = juce::jmax (1, juce::jmin (4, r.getWidth() / 220));
    const int cw = (r.getWidth() - gap * (perRow - 1)) / perRow;
    int col = 0;
    auto line = r.removeFromTop (84);
    for (; i < cards.size(); ++i)
    {
        if (col == perRow)
        {
            col = 0;
            r.removeFromTop (gap);
            line = r.removeFromTop (84);
        }
        cards[i].bounds = line.withX (line.getX() + col * (cw + gap)).withWidth (cw);
        ++col;
    }
    folderBtn.setBounds (getLocalBounds().reduced (24).removeFromBottom (28).removeFromLeft (200));
}

void WelcomeView::paint (juce::Graphics& g)
{
    g.fillAll (theme::bg);
    // Halo d'accent en haut, comme une page d'accueil.
    const auto top = getLocalBounds().toFloat().withHeight (320.0f);
    g.setGradientFill (juce::ColourGradient (theme::accent.withAlpha (0.25f), top.getCentreX(), 0.0f, theme::bg.withAlpha (0.0f), top.getCentreX(), 320.0f, false));
    g.fillRect (top);
    const auto area = getLocalBounds().reduced (juce::jmax (40, getWidth() / 10), 40);
    g.setColour (theme::text);
    g.setFont (juce::FontOptions (40.0f, juce::Font::bold));
    g.drawText ("StudioVoix", area.withHeight (60), juce::Justification::centredLeft);
    g.setColour (theme::textDim);
    g.setFont (juce::FontOptions (16.0f));
    g.drawText ("Pose une instru, enregistre ta voix : le studio règle tout (autotune, effets, niveaux, mix) selon le style."_u8,
                area.withY (area.getY() + 62).withHeight (24), juce::Justification::centredLeft);

    bool recentTitleDrawn = false;
    for (size_t i = 0; i < cards.size(); ++i)
    {
        const auto& c = cards[i];
        if (c.action == Action::Recent && ! recentTitleDrawn)
        {
            recentTitleDrawn = true;
            g.setColour (theme::textDim);
            g.setFont (juce::FontOptions (13.0f, juce::Font::bold));
            g.drawText ("PROJETS RÉCENTS"_u8, c.bounds.withY (c.bounds.getY() - 26).withHeight (20).withX (area.getX()), juce::Justification::centredLeft);
        }
        const auto rf = c.bounds.toFloat();
        const bool hot = static_cast<int> (i) == hover;
        if (c.primary)
            g.setGradientFill (theme::accentGradient (rf));
        else
            g.setColour (hot ? theme::cardHover : theme::card);
        g.fillRoundedRectangle (rf, 12.0f);
        if (hot && c.primary)
        {
            g.setColour (juce::Colours::white.withAlpha (0.12f));
            g.fillRoundedRectangle (rf, 12.0f);
        }
        g.setColour (c.primary ? juce::Colours::transparentBlack : (hot ? theme::accent.withAlpha (0.7f) : theme::line));
        g.drawRoundedRectangle (rf, 12.0f, 1.0f);
        auto inner = c.bounds.reduced (16, 12);
        g.setColour (juce::Colours::white);
        g.setFont (juce::FontOptions (c.action == Action::Recent ? 15.0f : 18.0f, juce::Font::bold));
        g.drawFittedText (c.title, inner.removeFromTop (c.action == Action::Recent ? 22 : 30), juce::Justification::centredLeft, 1);
        g.setColour (c.primary ? juce::Colours::white.withAlpha (0.85f) : theme::textDim);
        g.setFont (juce::FontOptions (13.0f));
        g.drawFittedText (c.subtitle, inner.removeFromTop (20), juce::Justification::centredLeft, 1);
        if (c.detail.isNotEmpty())
            g.drawFittedText (c.detail, inner.removeFromTop (20), juce::Justification::centredLeft, 1);
    }
    if (! recentTitleDrawn)
    {
        g.setColour (theme::textDim);
        g.setFont (juce::FontOptions (13.0f));
        g.drawText ("Aucun autre projet dans le dossier Projets pour l'instant."_u8, area.withY (area.getY() + 300).withHeight (20), juce::Justification::centredLeft);
    }
    g.setColour (theme::textDim);
    g.setFont (juce::FontOptions (12.0f));
    g.drawText ("Échap : revenir au studio"_u8, getLocalBounds().reduced (24).removeFromBottom (28), juce::Justification::centredRight);
}

int WelcomeView::cardAt (juce::Point<int> p) const
{
    for (size_t i = 0; i < cards.size(); ++i)
        if (cards[i].bounds.contains (p))
            return static_cast<int> (i);
    return -1;
}

void WelcomeView::mouseMove (const juce::MouseEvent& e)
{
    const int h = cardAt (e.getPosition());
    if (h != hover)
    {
        hover = h;
        setMouseCursor (h >= 0 ? juce::MouseCursor::PointingHandCursor : juce::MouseCursor::NormalCursor);
        repaint();
    }
}

void WelcomeView::mouseExit (const juce::MouseEvent&)
{
    hover = -1;
    repaint();
}

void WelcomeView::mouseDown (const juce::MouseEvent& e)
{
    const int h = cardAt (e.getPosition());
    if (h >= 0)
        activate (cards[static_cast<size_t> (h)]);
}

void WelcomeView::activate (const Card& c)
{
    SV_LOG_INFO (kMod, "Carte choisie : " + c.title);
    switch (c.action)
    {
        case Action::New:    if (onNew) onNew(); break;
        case Action::Open:   if (onOpen) onOpen(); break;
        case Action::Resume: if (onClose) onClose(); break;
        case Action::Recent: if (onOpenProject) onOpenProject (c.folder); break;
    }
}

bool WelcomeView::keyPressed (const juce::KeyPress& key)
{
    if (key == juce::KeyPress::escapeKey)
    {
        if (onClose)
            onClose();
        return true;
    }
    return false;
}
} // namespace sv::app
