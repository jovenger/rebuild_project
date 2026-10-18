#include "MixPanel.h"

#include "core/Log.h"

namespace sv::app
{
MixPanel::MixPanel (Session& s) : session (s)
{
    for (auto* c : std::initializer_list<juce::Component*> { &autoMix, &master, &ducking, &duckingL, &targetL, &sectionsL, &versionsL, &adlibL,
                                                             &info, &target, &sections, &versions, &copySection, &restore, &adlibBtn, &reanalyse })
        addAndMakeVisible (*c);

    duckingL.setText ("Creux de l'instru quand tu chantes"_u8, juce::dontSendNotification);
    ducking.setRange (0.0, 6.0, 0.5);
    ducking.setTextValueSuffix (" dB");
    ducking.setTextBoxStyle (juce::Slider::TextBoxRight, false, 56, 18);
    ducking.onDragEnd = [this]
    {
        session.updateProject ([v = static_cast<float> (ducking.getValue())] (project::Project& p) { p.duckingDb = v; }, false, "Creux de l'instru");
    };
    autoMix.onClick = [this]
    {
        if (! updating)
            session.updateProject ([v = autoMix.getToggleState()] (project::Project& p) { p.autoMixEnabled = v; }, false, "Mix automatique");
    };
    master.onClick = [this]
    {
        if (! updating)
            session.updateProject ([v = master.getToggleState()] (project::Project& p) { p.masterEnabled = v; }, false, "Mastering");
    };
    targetL.setText ("Destination", juce::dontSendNotification);
    for (int i = 0; i < static_cast<int> (dsp::LoudnessTarget::Count); ++i)
        target.addItem (dsp::targetInfo (static_cast<dsp::LoudnessTarget> (i)).name, i + 1);
    target.onChange = [this]
    {
        if (! updating)
            session.updateProject ([v = target.getSelectedId() - 1] (project::Project& p) { p.target = static_cast<dsp::LoudnessTarget> (v); },
                                   false, "Destination du mastering");
    };

    sectionsL.setText ("Structure (détectée automatiquement)"_u8, juce::dontSendNotification);
    copySection.onClick = [this]
    {
        const int idx = sections.getSelectedId() - 1;
        if (idx >= 0)
            session.copySectionToSimilar (session.selectedTrack(), idx);
    };
    versionsL.setText ("Historique des versions", juce::dontSendNotification);
    restore.onClick = [this]
    {
        const auto name = versions.getText();
        if (name.isEmpty())
            return;
        juce::WeakReference<Session> weak (&session);
        juce::AlertWindow::showAsync (juce::MessageBoxOptions().withIconType (juce::MessageBoxIconType::QuestionIcon)
                                          .withTitle ("Restaurer une version")
                                          .withMessage ("Revenir à la version "_u8 + name + " ? (Annuler permet de revenir en arrière)"_u8)
                                          .withButton ("Restaurer")
                                          .withButton ("Non"),
                                      [weak, name] (int r)
                                      {
                                          if (r == 1)
                                              if (auto* sess = weak.get())
                                                  sess->restoreVersion (name);
                                      });
    };
    adlibBtn.onClick = [this]
    {
        chooser = std::make_unique<juce::FileChooser> ("Dossier contenant tes ad-libs (WAV/MP3, courts)", session.settings().adLibFolder());
        juce::Component::SafePointer<MixPanel> safe (this);
        chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories, [safe] (const juce::FileChooser& fc)
        {
            if (safe == nullptr || fc.getResult() == juce::File())
                return;
            const auto dir = fc.getResult();
            safe->session.settings().setAdLibFolder (dir);
            safe->session.updateProject ([dir] (project::Project& p) { p.adLibFolder = dir.getFullPathName(); }, false, "Banque d'ad-libs");
            safe->refresh();
        });
    };
    reanalyse.onClick = [this] { session.reanalyseInstru(); };
    info.setFont (juce::FontOptions (11.0f));
    info.setColour (juce::Label::textColourId, juce::Colours::lightgrey);
    info.setJustificationType (juce::Justification::topLeft);
    refresh();
}

void MixPanel::refresh()
{
    const juce::ScopedValueSetter<bool> svs (updating, true);
    const auto& p = session.project();
    autoMix.setToggleState (p.autoMixEnabled, juce::dontSendNotification);
    master.setToggleState (p.masterEnabled, juce::dontSendNotification);
    ducking.setValue (p.duckingDb, juce::dontSendNotification);
    target.setSelectedId (static_cast<int> (p.target) + 1, juce::dontSendNotification);

    const int prevSection = sections.getSelectedId();
    sections.clear (juce::dontSendNotification);
    for (size_t i = 0; i < p.sections.size(); ++i)
        sections.addItem (p.sections[i].label + "  (" + juce::String (p.sections[i].startSec, 1) + " - " + juce::String (p.sections[i].endSec, 1) + " s)",
                          static_cast<int> (i) + 1);
    if (prevSection > 0 && prevSection <= sections.getNumItems())
        sections.setSelectedId (prevSection, juce::dontSendNotification);

    // Historique relu sur le disque seulement s'il a changé (refresh appelé à chaque modification du projet).
    const auto key = p.historyDir().getFullPathName() + "|" + juce::String (p.historyDir().getLastModificationTime().toMilliseconds());
    if (key != versionsKey)
    {
        versionsKey = key;
        const auto prevVersion = versions.getText();
        versions.clear (juce::dontSendNotification);
        const auto list = p.listVersions();
        for (int i = 0; i < list.size(); ++i)
            versions.addItem (list[i], i + 1);
        const int prevIdx = list.indexOf (prevVersion);
        if (prevIdx >= 0)
            versions.setSelectedId (prevIdx + 1, juce::dontSendNotification);
    }

    adlibL.setText (p.adLibFolder.isNotEmpty() ? "Ad-libs : " + juce::File (p.adLibFolder).getFileName() : juce::String ("Ad-libs : aucune banque"),
                    juce::dontSendNotification);
    juce::String txt;
    txt << "Tonalité "_u8 << p.key.toFrench() << (p.keyManual ? " (manuelle)" : " (auto)") << ", " << juce::String (p.tempo.bpm, 1) << " BPM"
        << (p.tempoManual ? " (manuel)" : " (auto)") << "\nGain voix du mix auto : " << juce::String (session.vocalAutoGainDb(), 1) << " dB"
        << "\nDossier du projet : " << p.folder.getFullPathName();
    info.setText (txt, juce::dontSendNotification);
}

void MixPanel::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff1e2228));
}

void MixPanel::resized()
{
    auto r = getLocalBounds().reduced (10);
    auto row = [&r] (int h = 26) { auto x = r.removeFromTop (h); r.removeFromTop (4); return x; };
    autoMix.setBounds (row());
    auto a = row();
    duckingL.setBounds (a.removeFromLeft (190));
    ducking.setBounds (a);
    master.setBounds (row());
    a = row();
    targetL.setBounds (a.removeFromLeft (90));
    target.setBounds (a);
    r.removeFromTop (8);
    sectionsL.setBounds (row (20));
    sections.setBounds (row());
    copySection.setBounds (row (28));
    reanalyse.setBounds (row (28));
    r.removeFromTop (8);
    adlibL.setBounds (row (20));
    adlibBtn.setBounds (row (28));
    r.removeFromTop (8);
    versionsL.setBounds (row (20));
    a = row();
    restore.setBounds (a.removeFromRight (90));
    a.removeFromRight (4);
    versions.setBounds (a);
    r.removeFromTop (8);
    info.setBounds (r);
}
} // namespace sv::app
