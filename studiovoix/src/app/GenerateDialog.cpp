#include "GenerateDialog.h"

#include "core/Log.h"

namespace sv::app
{
GenerateDialog::GenerateDialog (Session& s, int leadTrackId) : session (s), leadId (leadTrackId)
{
    for (auto* c : std::initializer_list<juce::Component*> { &title, &styleInfo, &doublesOn, &harmoniesOn, &backsOn, &adlibsOn, &ambianceOn,
                                                             &doublesCount, &harmoniesCount, &syllables, &ambianceType, &density,
                                                             &densityLabel, &adlibInfo, &generateBtn, &cancelBtn, &defaultsBtn })
        addAndMakeVisible (*c);

    title.setText ("Voix posée — que veux-tu ajouter ?"_u8, juce::dontSendNotification);
    title.setFont (juce::FontOptions (18.0f, juce::Font::bold));
    for (int i = 1; i <= 3; ++i)
    {
        doublesCount.addItem (juce::String (i) + " piste(s)", i);
        harmoniesCount.addItem (juce::String (i) + " piste(s)", i);
        syllables.addItem (juce::String (i) + " syllabe(s)", i);
    }
    for (int i = 0; i < static_cast<int> (gen::AmbianceType::Count); ++i)
        ambianceType.addItem (gen::ambianceName (static_cast<gen::AmbianceType> (i)), i + 1);
    density.setRange (0.1, 1.0, 0.05);
    density.setTextBoxStyle (juce::Slider::TextBoxRight, false, 50, 20);
    densityLabel.setText ("Fréquence des ad-libs"_u8, juce::dontSendNotification);
    adlibInfo.setFont (juce::FontOptions (11.0f));
    adlibInfo.setColour (juce::Label::textColourId, juce::Colours::lightgrey);
    const auto folder = session.project().adLibFolder;
    adlibInfo.setText (folder.isNotEmpty() ? "Banque d'ad-libs : " + folder
                                           : juce::String ("Pas de banque d'ad-libs (Mix & Master > Banque d'ad-libs) : échos du dernier mot à la place"_u8),
                       juce::dontSendNotification);

    defaultsBtn.onClick = [this] { applyDefaults(); };
    generateBtn.onClick = [this] { launch(); };
    cancelBtn.onClick = [this] { close(); };
    applyDefaults();
    setSize (520, 360);
}

void GenerateDialog::applyDefaults()
{
    const auto st = session.project().style;
    const auto d = style::generationDefaults (st);
    styleInfo.setText ("Pré-réglé pour le style "_u8 + style::styleName (st) + " (tu peux tout changer)", juce::dontSendNotification);
    doublesOn.setToggleState (d.doubles > 0, juce::dontSendNotification);
    doublesCount.setSelectedId (std::max (1, d.doubles), juce::dontSendNotification);
    harmoniesOn.setToggleState (d.harmonies > 0, juce::dontSendNotification);
    harmoniesCount.setSelectedId (std::max (1, d.harmonies), juce::dontSendNotification);
    backsOn.setToggleState (d.keywordBacks, juce::dontSendNotification);
    syllables.setSelectedId (juce::jlimit (1, 3, d.keywordSyllables), juce::dontSendNotification);
    adlibsOn.setToggleState (d.adLibs, juce::dontSendNotification);
    density.setValue (d.adLibDensity, juce::dontSendNotification);
    ambianceOn.setToggleState (d.ambiance, juce::dontSendNotification);
    ambianceType.setSelectedId (1, juce::dontSendNotification);
}

void GenerateDialog::launch()
{
    gen::GenerationOptions o;
    o.doubles = doublesOn.getToggleState() ? doublesCount.getSelectedId() : 0;
    o.harmonies = harmoniesOn.getToggleState() ? harmoniesCount.getSelectedId() : 0;
    o.keywordBacks = backsOn.getToggleState();
    o.keywordSyllables = syllables.getSelectedId();
    o.adLibs = adlibsOn.getToggleState();
    o.adLibDensity = static_cast<float> (density.getValue());
    o.ambiance = ambianceOn.getToggleState();
    o.ambianceType = static_cast<gen::AmbianceType> (ambianceType.getSelectedId() - 1);
    o.seed = juce::Time::currentTimeMillis();
    SV_LOG_INFO ("GenerateDialog", "Génération demandée : "_u8 + juce::String (o.doubles) + " doublage(s), " + juce::String (o.harmonies)
                                       + " harmonie(s), backs " + juce::String (o.keywordBacks ? "oui" : "non") + ", ad-libs "
                                       + juce::String (o.adLibs ? "oui" : "non") + ", ambiance " + juce::String (o.ambiance ? "oui" : "non"));
    session.generate (leadId, o);
    close();
}

void GenerateDialog::close()
{
    if (auto* dw = findParentComponentOfClass<juce::DialogWindow>())
        dw->exitModalState (0);
}

void GenerateDialog::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff23282f));
}

void GenerateDialog::resized()
{
    auto r = getLocalBounds().reduced (14);
    title.setBounds (r.removeFromTop (28));
    styleInfo.setBounds (r.removeFromTop (22));
    r.removeFromTop (8);
    auto row = [&r] (int h = 28) { auto x = r.removeFromTop (h); r.removeFromTop (4); return x; };
    auto a = row();
    doublesOn.setBounds (a.removeFromLeft (300));
    doublesCount.setBounds (a.removeFromLeft (140));
    a = row();
    harmoniesOn.setBounds (a.removeFromLeft (300));
    harmoniesCount.setBounds (a.removeFromLeft (140));
    a = row();
    backsOn.setBounds (a.removeFromLeft (300));
    syllables.setBounds (a.removeFromLeft (140));
    a = row();
    adlibsOn.setBounds (a.removeFromLeft (300));
    a = row();
    densityLabel.setBounds (a.removeFromLeft (150));
    density.setBounds (a.removeFromLeft (290));
    adlibInfo.setBounds (row (20));
    a = row();
    ambianceOn.setBounds (a.removeFromLeft (300));
    ambianceType.setBounds (a.removeFromLeft (140));
    auto buttons = r.removeFromBottom (32);
    generateBtn.setBounds (buttons.removeFromRight (120));
    buttons.removeFromRight (8);
    cancelBtn.setBounds (buttons.removeFromRight (100));
    defaultsBtn.setBounds (buttons.removeFromLeft (150));
}

void GenerateDialog::show (Session& session, int leadTrackId)
{
    juce::DialogWindow::LaunchOptions o;
    o.content.setOwned (new GenerateDialog (session, leadTrackId));
    o.dialogTitle = "Générer les pistes d'accompagnement"_u8;
    o.dialogBackgroundColour = juce::Colour (0xff23282f);
    o.escapeKeyTriggersCloseButton = true;
    o.useNativeTitleBar = true;
    o.resizable = false;
    o.launchAsync();
}
} // namespace sv::app
