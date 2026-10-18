#include "SettingsDialog.h"

#include "PluginManager.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "Settings";
}

SettingsDialog::SettingsDialog (Session& s)
    : session (s),
      deviceSelector (s.engine().deviceManager(), 1, 2, 2, 2, false, false, false, false)
{
    for (auto* c : std::initializer_list<juce::Component*> { &deviceSelector, &latencyInfo, &offsetL, &calibResult, &levelResult, &inputL, &trimL,
                                                             &countL, &aiTitle, &aiInfo, &textKeyL, &modelL, &musicKeyL, &updateL, &pluginTitle, &pluginStatus, &scanPlugins, &pluginFolderBtn, &offset, &trim,
                                                             &calibrate, &resetCalib, &levelTest, &openLogs, &closeBtn, &monitoring, &propose, &aiEnabled,
                                                             &inputMode, &textKey, &model, &musicKey, &updateToken })
        addAndMakeVisible (*c);

    auto& st = session.settings();
    latencyInfo.setFont (juce::FontOptions (12.0f));
    latencyInfo.setJustificationType (juce::Justification::topLeft);
    calibResult.setFont (juce::FontOptions (12.0f));
    calibResult.setJustificationType (juce::Justification::topLeft);
    levelResult.setFont (juce::FontOptions (12.0f));

    offsetL.setText ("Décalage manuel de la prise"_u8, juce::dontSendNotification);
    offset.setRange (-100.0, 100.0, 1.0);
    offset.setTextValueSuffix (" ms");
    offset.setValue (st.manualLatencyOffsetMs(), juce::dontSendNotification);
    offset.setTooltip ("Positif : la prise est avancée davantage. À utiliser si ta voix tombe un peu en retard ou en avance."_u8);
    offset.onValueChange = [this] { session.settings().setManualLatencyOffsetMs (static_cast<int> (offset.getValue())); };

    refreshCalibrationText();
    resetCalib.setTooltip ("Oublie le calibrage : seules les latences annoncées par le pilote sont utilisées."_u8);
    resetCalib.onClick = [this]
    {
        session.settings().clearCalibration();
        refreshCalibrationText();
    };
    calibrate.setTooltip ("Pose le casque contre le micro, volume moyen, puis clique : 5 clics sont joués et mesurés."_u8);
    calibrate.onClick = [this]
    {
        juce::String err;
        if (! session.engine().startCalibration (err))
        {
            calibResult.setText (err, juce::dontSendNotification);
            return;
        }
        calibResult.setText ("Calibrage en cours… (casque contre le micro)"_u8, juce::dontSendNotification);
        calibrate.setEnabled (false);
    };

    monitoring.setToggleState (st.softwareMonitoring(), juce::dontSendNotification);
    monitoring.onClick = [this]
    {
        session.settings().setSoftwareMonitoring (monitoring.getToggleState());
        session.engine().setMonitoring (monitoring.getToggleState());
    };
    propose.setToggleState (st.proposeGenerationAfterTake(), juce::dontSendNotification);
    propose.onClick = [this] { session.settings().setProposeGenerationAfterTake (propose.getToggleState()); };

    inputL.setText ("Entrée du micro"_u8, juce::dontSendNotification);
    inputMode.addItem ("Auto (moyenne des entrées)"_u8, 1);
    inputMode.addItem ("Entrée 1 seulement"_u8, 2);
    inputMode.addItem ("Entrée 2 seulement"_u8, 3);
    inputMode.setSelectedId (st.inputChannelMode() + 1, juce::dontSendNotification);
    inputMode.onChange = [this]
    {
        session.settings().setInputChannelMode (inputMode.getSelectedId() - 1);
        session.engine().setInputChannelMode (inputMode.getSelectedId() - 1);
    };
    trimL.setText ("Gain numérique d'entrée"_u8, juce::dontSendNotification);
    trim.setRange (-24.0, 24.0, 0.5);
    trim.setTextValueSuffix (" dB");
    trim.setValue (st.inputTrimDb(), juce::dontSendNotification);
    trim.setTooltip ("Ne corrige pas une saturation du micro : baisse plutôt la molette de gain du micro."_u8);
    trim.onValueChange = [this]
    {
        session.settings().setInputTrimDb (static_cast<float> (trim.getValue()));
        session.engine().setInputTrimDb (static_cast<float> (trim.getValue()));
    };
    levelTest.onClick = [this]
    {
        levelTesting = true;
        levelTestPeak = 0.0f;
        session.engine().resetHoldPeak();
        levelTestEnd = juce::Time::currentTimeMillis() + 5000;
        levelResult.setText ("Chante ou rappe ta partie la plus forte pendant 5 secondes…"_u8, juce::dontSendNotification);
    };
    openLogs.onClick = [] { AppSettings::logsFolder().startAsProcess(); };

    aiTitle.setText ("IA connectée (facultatif)"_u8, juce::dontSendNotification);
    aiTitle.setFont (juce::FontOptions (14.0f, juce::Font::bold));
    aiInfo.setFont (juce::FontOptions (11.0f));
    aiInfo.setColour (juce::Label::textColourId, juce::Colours::lightgrey);
    aiInfo.setText ("Sans clé, tout fonctionne en local. Les clés restent sur ce PC ; l'audio n'est jamais envoyé, seulement du texte."_u8,
                    juce::dontSendNotification);
    aiEnabled.setToggleState (st.aiEnabled(), juce::dontSendNotification);
    aiEnabled.onClick = [this] { session.settings().setAiEnabled (aiEnabled.getToggleState()); };
    textKeyL.setText ("Clé IA texte (Claude)"_u8, juce::dontSendNotification);
    textKey.setPasswordCharacter (static_cast<juce::juce_wchar> ('*'));
    textKey.setText (st.textAiKey(), false);
    textKey.onTextChange = [this] { session.settings().setTextAiKey (textKey.getText()); };
    modelL.setText ("Modèle"_u8, juce::dontSendNotification);
    model.setText (st.textAiModel(), false);
    model.onTextChange = [this] { session.settings().setTextAiModel (model.getText()); };
    musicKeyL.setText ("Clé génération musicale"_u8, juce::dontSendNotification);
    musicKey.setPasswordCharacter (static_cast<juce::juce_wchar> ('*'));
    musicKey.setText (st.musicAiKey(), false);
    musicKey.onTextChange = [this] { session.settings().setMusicAiKey (musicKey.getText()); };
    updateL.setText ("Jeton GitHub (mises à jour)"_u8, juce::dontSendNotification);
    updateToken.setPasswordCharacter (static_cast<juce::juce_wchar> ('*'));
    updateToken.setText (st.updateToken(), false);
    updateToken.setTooltip ("Facultatif. Seulement si le dépôt du programme est privé : jeton GitHub « fine-grained » limité "
                            "au dépôt, permission Contents en lecture seule. Le bouton Mise à jour (en haut à droite) l'utilise."_u8);
    updateToken.onTextChange = [this] { session.settings().setUpdateToken (updateToken.getText()); };

    pluginTitle.setText ("Plugins VST3 (facultatif)", juce::dontSendNotification);
    pluginTitle.setFont (juce::FontOptions (14.0f, juce::Font::bold));
    pluginStatus.setFont (juce::FontOptions (11.0f));
    pluginStatus.setColour (juce::Label::textColourId, juce::Colours::lightgrey);
    scanPlugins.setTooltip ("Cherche les plugins d'effet VST3 installés (dossiers standard de Windows + dossier en plus). "
                            "Ils s'ajoutent ensuite piste par piste dans l'onglet Voix IA."_u8);
    scanPlugins.onClick = [this]
    {
        PluginManager::instance().scan (juce::File (session.settings().props().getValue ("vst3Folder")));
        refreshPluginStatus();
    };
    pluginFolderBtn.onClick = [this]
    {
        auto chooserPtr = std::make_shared<juce::FileChooser> ("Dossier de plugins VST3 en plus", juce::File (session.settings().props().getValue ("vst3Folder")));
        chooserPtr->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories,
                                 [this, chooserPtr] (const juce::FileChooser& fc)
                                 {
                                     if (fc.getResult() != juce::File())
                                     {
                                         session.settings().props().setValue ("vst3Folder", fc.getResult().getFullPathName());
                                         refreshPluginStatus();
                                     }
                                 });
    };
    PluginManager::instance().addChangeListener (this);
    refreshPluginStatus();

    closeBtn.onClick = [this]
    {
        session.settings().save();
        if (auto* dw = findParentComponentOfClass<juce::DialogWindow>())
            dw->exitModalState (0);
    };
    refreshLatency();
    startTimer (100);
    setSize (760, 960);
}

SettingsDialog::~SettingsDialog()
{
    stopTimer();
    PluginManager::instance().removeChangeListener (this);
    auto state = session.engine().deviceManager().createStateXml();
    session.settings().setAudioDeviceState (state.get());
    session.settings().save();
    SV_LOG_INFO (kMod, "Paramètres fermés : "_u8 + session.engine().describeDevice());
    session.sendChangeMessage();   // onglet IA, boutons : prise en compte des clés saisies
}

void SettingsDialog::refreshCalibrationText()
{
    const auto& st = session.settings();
    juce::String text;
    if (! st.hasCalibration())
        text = "Pas de calibrage : la latence annoncée par le pilote est utilisée."_u8;
    else if (st.calibrationDeviceKey() != session.engine().deviceKey())
        text = "Calibrage fait pour un autre matériel : ignoré. Refais-le avec la carte actuelle."_u8;
    else
        text = "Calibrage actif : "_u8 + juce::String (st.calibrationResidualMs(), 1) + " ms ajoutées aux latences du pilote."_u8;
    calibResult.setText (text, juce::dontSendNotification);
}

void SettingsDialog::refreshLatency()
{
    latencyInfo.setText (session.engine().describeDevice()
                             + "\nAvec le casque branché sur le micro ou sur l'interface audio (retour direct), tu t'entends sans retard ; StudioVoix recale chaque prise automatiquement."_u8,
                         juce::dontSendNotification);
}

void SettingsDialog::timerCallback()
{
    static int counter = 0;
    if (++counter % 10 == 0)
        refreshLatency();

    auto& e = session.engine();
    if (! calibrate.isEnabled() && ! e.isCalibrating())
    {
        juce::String report;
        const int off = e.finishCalibration (report);
        if (off > 0)
        {
            // On garde seulement l'écart que le pilote n'annonce pas : il reste valable si le tampon change.
            const double sr = e.sampleRate();
            const double residualMs = (off - (e.inputLatency() + e.outputLatency())) * 1000.0 / sr;
            session.settings().setCalibration (residualMs, e.deviceKey());
            report << "\nCalibrage enregistré pour ce matériel ("_u8 << juce::String (residualMs, 1) << " ms au-delà du pilote)."_u8;
        }
        calibResult.setText (report, juce::dontSendNotification);
        calibrate.setEnabled (true);
    }

    if (levelTesting)
    {
        levelTestPeak = std::max (levelTestPeak, e.holdPeak());
        if (juce::Time::currentTimeMillis() >= levelTestEnd)
        {
            levelTesting = false;
            const float db = gainToDb (levelTestPeak);
            juce::String msg = "Crête : "_u8 + juce::String (db, 1) + " dBFS — "_u8;
            if (db > -1.0f)
                msg << "TROP FORT : baisse la molette de gain du micro (risque de saturation)."_u8;
            else if (db < -24.0f)
                msg << "Trop faible : monte le gain du micro ou rapproche-toi."_u8;
            else
                msg << "Niveau correct."_u8;
            levelResult.setText (msg, juce::dontSendNotification);
            SV_LOG_INFO (kMod, "Test du niveau : "_u8 + msg);
        }
    }
}

void SettingsDialog::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff23282f));
}

void SettingsDialog::resized()
{
    auto r = getLocalBounds().reduced (12);
    deviceSelector.setBounds (r.removeFromTop (300));
    auto row = [&r] (int h = 26) { auto x = r.removeFromTop (h); r.removeFromTop (4); return x; };
    latencyInfo.setBounds (row (40));
    auto a = row();
    offsetL.setBounds (a.removeFromLeft (220));
    offset.setBounds (a);
    a = row (28);
    calibrate.setBounds (a.removeFromLeft (170));
    a.removeFromLeft (6);
    resetCalib.setBounds (a.removeFromLeft (110));
    a.removeFromLeft (8);
    calibResult.setBounds (a.withHeight (40));
    r.removeFromTop (14);
    monitoring.setBounds (row());
    propose.setBounds (row());
    a = row();
    inputL.setBounds (a.removeFromLeft (220));
    inputMode.setBounds (a.removeFromLeft (260));
    a = row();
    trimL.setBounds (a.removeFromLeft (220));
    trim.setBounds (a);
    a = row (28);
    levelTest.setBounds (a.removeFromLeft (240));
    a.removeFromLeft (8);
    levelResult.setBounds (a);
    r.removeFromTop (8);
    aiTitle.setBounds (row (22));
    aiInfo.setBounds (row (20));
    aiEnabled.setBounds (row());
    a = row();
    textKeyL.setBounds (a.removeFromLeft (180));
    textKey.setBounds (a);
    a = row();
    modelL.setBounds (a.removeFromLeft (180));
    model.setBounds (a);
    a = row();
    musicKeyL.setBounds (a.removeFromLeft (180));
    musicKey.setBounds (a);
    a = row();
    updateL.setBounds (a.removeFromLeft (180));
    updateToken.setBounds (a);
    r.removeFromTop (8);
    pluginTitle.setBounds (row (22));
    a = row (28);
    scanPlugins.setBounds (a.removeFromLeft (240));
    a.removeFromLeft (8);
    pluginFolderBtn.setBounds (a.removeFromLeft (150));
    pluginStatus.setBounds (row (20));
    auto bottom = r.removeFromBottom (30);
    closeBtn.setBounds (bottom.removeFromRight (100));
    openLogs.setBounds (bottom.removeFromLeft (240));
}

void SettingsDialog::changeListenerCallback (juce::ChangeBroadcaster*) { refreshPluginStatus(); }

void SettingsDialog::refreshPluginStatus()
{
    const auto folder = session.settings().props().getValue ("vst3Folder");
    pluginStatus.setText (PluginManager::instance().scanStatus() + (folder.isNotEmpty() ? " — dossier en plus : "_u8 + folder : juce::String()),
                          juce::dontSendNotification);
    scanPlugins.setEnabled (! PluginManager::instance().isScanning());
}

void SettingsDialog::show (Session& session)
{
    juce::DialogWindow::LaunchOptions o;
    o.content.setOwned (new SettingsDialog (session));
    o.dialogTitle = "Paramètres"_u8;
    o.dialogBackgroundColour = juce::Colour (0xff23282f);
    o.escapeKeyTriggersCloseButton = true;
    o.useNativeTitleBar = true;
    o.resizable = true;
    o.launchAsync();
}
} // namespace sv::app
