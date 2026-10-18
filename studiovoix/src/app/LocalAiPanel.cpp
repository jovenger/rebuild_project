#include "LocalAiPanel.h"

#include "Theme.h"
#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "IALocale";
}

LocalAiPanel::LocalAiPanel (Session& s) : session (s)
{
    for (auto* c : std::initializer_list<juce::Component*> { &title, &intro, &folderLabel, &folderBtn })
        addAndMakeVisible (*c);
    title.setText ("IA locale (gratuite, sur ce PC)"_u8, juce::dontSendNotification);
    title.setFont (juce::FontOptions (16.0f, juce::Font::bold));
    intro.setText ("Ces briques libres sont téléchargées une fois, puis utilisées par le studio sans connexion. "
                   "Rien n'est envoyé sur Internet : les calculs se font sur ce PC (plus longs que les effets classiques)."_u8,
                   juce::dontSendNotification);
    intro.setFont (juce::FontOptions (12.0f));
    intro.setColour (juce::Label::textColourId, theme::textDim);
    intro.setJustificationType (juce::Justification::topLeft);
    folderLabel.setFont (juce::FontOptions (11.0f));
    folderLabel.setColour (juce::Label::textColourId, theme::textDim);
    folderBtn.onClick = []
    {
        ai::local::toolsFolder().createDirectory();
        ai::local::toolsFolder().revealToUser();
    };
    for (const auto& def : ai::local::tools())
    {
        auto row = std::make_unique<Row>();
        row->def = &def;
        row->name.setText (def.name, juce::dontSendNotification);
        row->name.setFont (juce::FontOptions (13.5f, juce::Font::bold));
        row->info.setText (def.description + " Licence " + def.licence + ".", juce::dontSendNotification);
        row->info.setFont (juce::FontOptions (11.5f));
        row->info.setColour (juce::Label::textColourId, theme::textDim);
        row->info.setJustificationType (juce::Justification::topLeft);
        row->state.setFont (juce::FontOptions (12.0f));
        theme::setButtonKind (row->install, "primary");
        auto* rp = row.get();
        row->install.onClick = [this, rp] { startInstall (*rp); };
        row->remove.onClick = [this, rp]
        {
            if (rp->def != nullptr && ai::local::remove (*rp->def))
                session.setStatus (rp->def->name + " supprimé"_u8);
            refresh();
        };
        for (auto* c : std::initializer_list<juce::Component*> { &row->name, &row->info, &row->state, &row->install, &row->remove })
            addAndMakeVisible (*c);
        rows.push_back (std::move (row));
    }
    refresh();
}

LocalAiPanel::~LocalAiPanel()
{
    for (auto& r : rows)
        if (r->progress != nullptr)
            r->progress->cancel.store (true);
    pool.removeAllJobs (true, 5000);
}

void LocalAiPanel::startInstall (Row& row)
{
    if (row.def == nullptr || row.progress != nullptr)
        return;
    row.progress = std::make_shared<ai::local::Progress>();
    row.lastError.clear();
    auto progress = row.progress;
    const auto* def = row.def;
    juce::Component::SafePointer<LocalAiPanel> safe (this);
    juce::WeakReference<Session> weak (&session);
    SV_LOG_INFO (kMod, "Installation demandée : "_u8 + def->name);
    session.setStatus ("Téléchargement de "_u8 + def->name + "…"_u8);
    pool.addJob ([safe, weak, def, progress]
    {
        juce::String error;
        const bool ok = ai::local::install (*def, *progress, error);
        juce::MessageManager::callAsync ([safe, weak, def, progress, ok, error]
        {
            if (auto* s = weak.get())
                s->setStatus (ok ? def->name + " installé"_u8 : def->name + " : " + error);
            if (safe == nullptr)
                return;
            for (auto& r : safe->rows)
                if (r->progress == progress)
                {
                    r->progress = nullptr;
                    r->lastError = ok ? juce::String() : error;
                }
            safe->refresh();
        });
    });
    startTimer (300);
    refresh();
}

void LocalAiPanel::timerCallback()
{
    bool active = false;
    for (auto& r : rows)
        if (r->progress != nullptr)
        {
            active = true;
            const auto mb = r->progress->downloaded.load() / 1024 / 1024;
            const float f = r->progress->fraction.load();
            r->state.setText ("Téléchargement… "_u8 + (f > 0.0f ? juce::String (juce::roundToInt (f * 100.0f)) + " % (" : "(") + juce::String (mb) + " Mo)",
                              juce::dontSendNotification);
        }
    if (! active)
        stopTimer();
}

void LocalAiPanel::refresh()
{
    folderLabel.setText ("Dossier : " + ai::local::toolsFolder().getFullPathName(), juce::dontSendNotification);
    for (auto& r : rows)
    {
        if (r->def == nullptr)
            continue;
        const bool downloading = r->progress != nullptr;
        const bool installed = ai::local::isInstalled (*r->def);
        const bool available = r->def->url.isNotEmpty();
        if (! downloading)
        {
            juce::String st = installed ? "Installé"_u8 + juce::String (" (") + juce::String (ai::local::toolFile (*r->def).getSize() / 1024 / 1024) + " Mo)"
                                        : (available ? juce::String ("Non installé"_u8) : juce::String ("Indisponible sur ce système"_u8));
            if (r->lastError.isNotEmpty())
                st << " — " << r->lastError;
            r->state.setText (st, juce::dontSendNotification);
            r->state.setColour (juce::Label::textColourId, r->lastError.isNotEmpty() ? theme::warn : (installed ? theme::ok : theme::textDim));
        }
        r->install.setEnabled (available && ! installed && ! downloading);
        r->install.setButtonText (downloading ? "En cours…"_u8 : (installed ? "Installé"_u8 : "Installer"));
        r->remove.setEnabled (installed && ! downloading);
    }
}

void LocalAiPanel::paint (juce::Graphics& g)
{
    g.fillAll (theme::panel);
    auto r = getLocalBounds().reduced (10);
    r.removeFromTop (24 + 4 + 54 + 8);
    for (auto& row : rows)
    {
        juce::ignoreUnused (row);
        const auto card = r.removeFromTop (118).toFloat();
        g.setColour (theme::card);
        g.fillRoundedRectangle (card, theme::radius);
        g.setColour (theme::line);
        g.drawRoundedRectangle (card, theme::radius, 1.0f);
        r.removeFromTop (8);
    }
}

void LocalAiPanel::resized()
{
    auto r = getLocalBounds().reduced (10);
    title.setBounds (r.removeFromTop (24));
    r.removeFromTop (4);
    intro.setBounds (r.removeFromTop (54));
    r.removeFromTop (8);
    for (auto& row : rows)
    {
        auto card = r.removeFromTop (118).reduced (10, 8);
        row->name.setBounds (card.removeFromTop (22));
        row->info.setBounds (card.removeFromTop (46));
        auto line = card.removeFromTop (26);
        row->remove.setBounds (line.removeFromRight (90));
        line.removeFromRight (6);
        row->install.setBounds (line.removeFromRight (100));
        line.removeFromRight (6);
        row->state.setBounds (line);
        r.removeFromTop (8);
    }
    r.removeFromTop (6);
    folderBtn.setBounds (r.removeFromTop (26).removeFromLeft (220));
    r.removeFromTop (4);
    folderLabel.setBounds (r.removeFromTop (18));
}
} // namespace sv::app
