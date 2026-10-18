#include "ExportDialog.h"

#include "core/Log.h"

namespace sv::app
{
ExportDialog::ExportDialog (Session& s) : session (s)
{
    for (auto* c : std::initializer_list<juce::Component*> { &nameL, &formatL, &targetL, &result, &name, &format, &target, &master, &stems,
                                                             &exportBtn, &openFolder, &closeBtn })
        addAndMakeVisible (*c);

    const auto& p = session.project();
    nameL.setText ("Nom du fichier", juce::dontSendNotification);
    name.setText (p.name + " - " + style::styleName (p.style), false);
    formatL.setText ("Format", juce::dontSendNotification);
    format.addItem ("WAV 24 bits", 1);
    format.addItem ("FLAC 24 bits", 2);
    format.addItem ("MP3 320 kbps (lame.exe requis)", 3);
    format.setSelectedId (1);
    targetL.setText ("Destination", juce::dontSendNotification);
    for (int i = 0; i < static_cast<int> (dsp::LoudnessTarget::Count); ++i)
        target.addItem (dsp::targetInfo (static_cast<dsp::LoudnessTarget> (i)).name, i + 1);
    target.setSelectedId (static_cast<int> (p.target) + 1);
    master.setToggleState (p.masterEnabled, juce::dontSendNotification);
    result.setJustificationType (juce::Justification::topLeft);
    result.setFont (juce::FontOptions (12.0f));
    openFolder.setEnabled (false);

    exportBtn.onClick = [this] { launch(); };
    openFolder.onClick = [this]
    {
        if (lastFile != juce::File())
            lastFile.revealToUser();
    };
    closeBtn.onClick = [this]
    {
        if (auto* dw = findParentComponentOfClass<juce::DialogWindow>())
            dw->exitModalState (0);
    };
    setSize (560, 300);
}

void ExportDialog::launch()
{
    const auto t = static_cast<dsp::LoudnessTarget> (target.getSelectedId() - 1);
    const bool m = master.getToggleState();
    // Cible et mastering n'influencent pas le mix auto (l'export le recalcule) : pas de calcul relancé ici.
    if (auto& p = session.project(); p.target != t || p.masterEnabled != m)
    {
        p.target = t;
        p.masterEnabled = m;
        session.markDirty();
    }

    render::ExportOptions o;
    o.outDir = session.project().exportDir();
    o.baseName = name.getText().trim().isNotEmpty() ? name.getText().trim() : juce::String ("mix");
    o.format = format.getSelectedId() == 2 ? audio::FileFormat::Flac24
             : format.getSelectedId() == 3 ? audio::FileFormat::Mp3_320
                                           : audio::FileFormat::Wav24;
    o.stems = stems.getToggleState();
    o.master = m;
    exportBtn.setEnabled (false);
    result.setText ("Export en cours…"_u8, juce::dontSendNotification);
    juce::Component::SafePointer<ExportDialog> safe (this);
    session.exportMix (o, [safe] (const render::ExportReport& rep)
    {
        if (safe == nullptr)
            return;
        safe->exportBtn.setEnabled (true);
        if (! rep.ok)
        {
            safe->result.setText ("Échec : "_u8 + rep.error, juce::dontSendNotification);
            return;
        }
        safe->lastFile = rep.mixFile;
        safe->openFolder.setEnabled (true);
        safe->result.setText ("Exporté : "_u8 + rep.mixFile.getFullPathName() + "\nSonie " + juce::String (rep.master.outputLufs, 1) + " LUFS, crête vraie "_u8
                                  + juce::String (rep.master.truePeakDb, 2) + " dBTP"
                                  + (rep.stemFiles.isEmpty() ? juce::String() : "\n" + juce::String (rep.stemFiles.size()) + " pistes séparées"_u8)
                                  + (rep.warning.isNotEmpty() ? "\nÀ VÉRIFIER : "_u8 + rep.warning : juce::String()),
                              juce::dontSendNotification);
    });
}

void ExportDialog::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff23282f));
}

void ExportDialog::resized()
{
    auto r = getLocalBounds().reduced (12);
    auto row = [&r] (int h = 26) { auto x = r.removeFromTop (h); r.removeFromTop (6); return x; };
    auto a = row();
    nameL.setBounds (a.removeFromLeft (120));
    name.setBounds (a);
    a = row();
    formatL.setBounds (a.removeFromLeft (120));
    format.setBounds (a);
    a = row();
    targetL.setBounds (a.removeFromLeft (120));
    target.setBounds (a);
    master.setBounds (row());
    stems.setBounds (row());
    auto bottom = r.removeFromBottom (30);
    closeBtn.setBounds (bottom.removeFromRight (90));
    bottom.removeFromRight (6);
    exportBtn.setBounds (bottom.removeFromRight (110));
    openFolder.setBounds (bottom.removeFromLeft (150));
    result.setBounds (r);
}

void ExportDialog::show (Session& session)
{
    juce::DialogWindow::LaunchOptions o;
    o.content.setOwned (new ExportDialog (session));
    o.dialogTitle = "Exporter le morceau";
    o.dialogBackgroundColour = juce::Colour (0xff23282f);
    o.escapeKeyTriggersCloseButton = true;
    o.useNativeTitleBar = true;
    o.resizable = false;
    o.launchAsync();
}
} // namespace sv::app
