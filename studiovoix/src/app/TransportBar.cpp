#include "TransportBar.h"

#include "StyleMenu.h"

#include "Theme.h"
#include "core/Log.h"
#include "core/analysis/KeyDetector.h"

namespace sv::app
{
void LevelMeter::setLevel (float peak, bool clip)
{
    level = std::max (peak, level * 0.85f);
    if (clip)
    {
        clipped = true;
        clipUntilMs = juce::Time::currentTimeMillis() + 2000;
    }
    else if (juce::Time::currentTimeMillis() > clipUntilMs)
    {
        clipped = false;
    }
    repaint();
}

void LevelMeter::paint (juce::Graphics& g)
{
    auto r = getLocalBounds().toFloat();
    g.setColour (juce::Colours::black);
    g.fillRoundedRectangle (r, 3.0f);
    const float db = gainToDb (level);
    const float norm = juce::jlimit (0.0f, 1.0f, (db + 60.0f) / 60.0f);
    auto bar = r.reduced (2.0f).withWidth ((r.getWidth() - 4.0f) * norm);
    g.setColour (db > -3.0f ? juce::Colours::red : (db > -12.0f ? juce::Colours::orange : juce::Colours::limegreen));
    g.fillRect (bar);
    if (clipped)
    {
        g.setColour (juce::Colours::red);
        g.fillRect (r.removeFromRight (14.0f).reduced (2.0f));
    }
    if (compact)
        return;
    g.setColour (juce::Colours::white);
    g.setFont (11.0f);
    g.drawText (clipped ? juce::String ("SATURATION") : label + " " + juce::String (juce::roundToInt (db)) + " dB", getLocalBounds().reduced (4, 0),
                juce::Justification::centredLeft);
}

TransportBar::TransportBar (Session& s) : session (s)
{
    for (auto* b : { &newBtn, &openBtn, &saveBtn, &instruBtn, &voiceBtn, &exportBtn, &settingsBtn, &undoBtn, &redoBtn, &homeBtn, &playBtn, &stopBtn, &recBtn, &updateBtn, &correctBtn })
        addAndMakeVisible (*b);
    // Rôles visuels : lecture et ingénieur du son en accent, REC en rouge.
    theme::setButtonKind (playBtn, "primary");
    theme::setButtonKind (correctBtn, "primary");
    theme::setButtonKind (recBtn, "danger");
    for (auto* t : { &punch, &loop, &metronome })
        addAndMakeVisible (*t);
    addAndMakeVisible (scaleToggle);
    scaleToggle.setTooltip ("Coché : l'autotune tire les notes vers la gamme de la tonalité choisie. Décoché : correction note par note, "
                            "sans gamme (la tonalité ne sert plus qu'aux harmonies générées)."_u8);
    scaleToggle.onClick = [this]
    {
        if (updating)
            return;
        const bool v = scaleToggle.getToggleState();
        session.updateProject ([v] (project::Project& p) { p.scaleCorrection = v; }, true, v ? "Accordage sur la gamme"_u8 : "Correction note par note"_u8);
    };
    for (auto* c : { &countdown, &keyBox, &styleBox })
        addAndMakeVisible (*c);
    outputMeter.setLabel ("Sortie");
    addAndMakeVisible (outputMeter);
    mixLabel.setTooltip ("Sonie du mixage (avant mastering), mesurée après le mix auto et l'orchestre"_u8);
    for (auto* l : { &timeLabel, &bpmLabel, &bpmTitle, &keyTitle, &styleTitle, &countTitle, &mixLabel })
        addAndMakeVisible (*l);
    addAndMakeVisible (inputMeter);

    recBtn.setColour (juce::TextButton::buttonColourId, juce::Colours::darkred);
    recBtn.setTooltip ("Enregistrer sur la piste armée (rond rouge à gauche de la piste) — touche R"_u8);
    playBtn.setTooltip ("Lecture / pause (barre d'espace)");
    punch.setTooltip ("Réenregistre seulement la zone rouge (Maj + glisser sur la règle)"_u8);
    loop.setTooltip ("Lecture en boucle de la zone verte (Alt + glisser sur la règle)"_u8);

    timeLabel.setFont (juce::FontOptions (20.0f, juce::Font::bold));
    timeLabel.setJustificationType (juce::Justification::centred);
    bpmTitle.setText ("BPM", juce::dontSendNotification);
    keyTitle.setText ("Tonalité"_u8, juce::dontSendNotification);
    styleTitle.setText ("Style", juce::dontSendNotification);
    countTitle.setText ("Compte", juce::dontSendNotification);
    bpmLabel.setEditable (true);
    bpmLabel.setColour (juce::Label::outlineColourId, juce::Colours::grey);
    bpmLabel.setTooltip ("Tempo détecté automatiquement ; double-clic pour le corriger"_u8);

    countdown.addItem ("Aucun", 1);
    countdown.addItem ("1 mesure", 2);
    countdown.addItem ("2 mesures", 3);
    for (int pc = 0; pc < 12; ++pc)
    {
        keyBox.addItem (analysis::pitchClassName (pc) + " majeur", 1 + pc);
        keyBox.addItem (analysis::pitchClassName (pc) + " mineur", 13 + pc);
    }
    fillStyleBox (styleBox);

    newBtn.onClick = [this] { if (onNew) onNew(); };
    openBtn.onClick = [this] { if (onOpen) onOpen(); };
    saveBtn.onClick = [this] { if (onSave) onSave(); };
    instruBtn.onClick = [this] { if (onImportInstru) onImportInstru(); };
    voiceBtn.onClick = [this] { if (onImportVoice) onImportVoice(); };
    voiceBtn.setTooltip ("Importer une voix déjà enregistrée dans la piste sélectionnée"_u8);
    exportBtn.onClick = [this] { if (onExport) onExport(); };
    updateBtn.onClick = [this] { if (onUpdate) onUpdate(); };
    correctBtn.onClick = [this] { if (onCorrectAll) onCorrectAll(); };
    correctBtn.setTooltip ("Ingénieur du son automatique : analyse chaque piste voix et la remet propre : niveau régulier d'un passage "
                           "à l'autre, bruit, écrêtage, résonances, équilibre, sifflantes, justesse (sans effet de style), puis mix auto. "
                           "Ne touche jamais aux instruments ni à l'instru. Annulable."_u8);
    setUpdateButton ("Mise à jour"_u8, "Vérifier s'il existe une nouvelle version"_u8, false, true);
    settingsBtn.onClick = [this] { if (onSettings) onSettings(); };
    undoBtn.onClick = [this] { session.undo(); };
    redoBtn.onClick = [this] { session.redo(); };
    homeBtn.onClick = [this] { session.setPositionSec (0.0); };
    playBtn.onClick = [this] { session.togglePlay(); };
    stopBtn.onClick = [this] { session.stopTransport(); };
    recBtn.onClick = [this] { if (onRecord) onRecord(); };
    loop.onClick = [this] { if (onLoopToggled) onLoopToggled(); };
    metronome.onClick = [this]
    {
        session.settings().setMetronome (metronome.getToggleState());
        session.engine().setMetronome (metronome.getToggleState());
    };
    countdown.onChange = [this]
    {
        if (! updating)
            session.settings().setCountdownBars (countdown.getSelectedId() - 1);
    };
    keyBox.onChange = [this]
    {
        if (updating)
            return;
        const int id = keyBox.getSelectedId();
        MusicalKey k;
        k.root = (id - 1) % 12;
        k.minor = id > 12;
        session.setKey (k);
    };
    styleBox.onChange = [this]
    {
        if (! updating)
            session.setStyle (static_cast<style::Style> (styleBox.getSelectedId() - 1));
    };
    bpmLabel.onTextChange = [this]
    {
        const double v = bpmLabel.getText().replaceCharacter (',', '.').getDoubleValue();
        if (v >= 40.0 && v <= 240.0)
            session.setTempo (v);
        else
            refresh();
    };
    refresh();
}

void TransportBar::refresh()
{
    const juce::ScopedValueSetter<bool> svs (updating, true);
    const auto& p = session.project();
    if (! bpmLabel.isBeingEdited())   // setText fermerait l'éditeur en cours de saisie
        bpmLabel.setText (juce::String (p.tempo.bpm, 1), juce::dontSendNotification);
    keyBox.setSelectedId ((p.key.minor ? 13 : 1) + p.key.root, juce::dontSendNotification);
    scaleToggle.setToggleState (p.scaleCorrection, juce::dontSendNotification);
    styleBox.setSelectedId (static_cast<int> (p.style) + 1, juce::dontSendNotification);
    countdown.setSelectedId (session.settings().countdownBars() + 1, juce::dontSendNotification);
    metronome.setToggleState (session.settings().metronome(), juce::dontSendNotification);
    undoBtn.setEnabled (session.canUndo());
    undoBtn.setTooltip (session.canUndo() ? "Annuler : " + session.undoLabel() : juce::String());
    redoBtn.setEnabled (session.canRedo());
    const float ag = session.vocalAutoGainDb();
    // Sonie du mixage + gain auto de la voix sur une seule étiquette (place limitée).
    mixLabel.setText ((session.mixLufs() > -100.0 ? "Mix " + juce::String (session.mixLufs(), 1) + " LUFS" : juce::String ("Mix - LUFS"))
                          + (p.autoMixEnabled ? " | voix " + juce::String (ag >= 0.0f ? "+" : "") + juce::String (ag, 1) + " dB" : juce::String (" | mix auto off")),
                      juce::dontSendNotification);
    mixLabel.setFont (juce::FontOptions (11.0f));
    mixLabel.setJustificationType (juce::Justification::centredRight);
}

void TransportBar::updateTime()
{
    const double t = session.positionSec();
    const auto& tempo = session.project().tempo;
    const double beats = (t - tempo.firstBeatSec) / tempo.beatSec();
    const int bar = static_cast<int> (std::floor (beats / tempo.beatsPerBar)) + 1;
    const int beat = static_cast<int> (std::floor (beats)) % tempo.beatsPerBar;
    const int mins = static_cast<int> (t / 60.0);
    const double secs = t - mins * 60.0;
    timeLabel.setText (juce::String (mins) + ":" + juce::String (secs, 2).paddedLeft ('0', 5) + "   " + juce::String (bar) + "."
                           + juce::String ((beat + tempo.beatsPerBar) % tempo.beatsPerBar + 1),
                       juce::dontSendNotification);
    auto& e = session.engine();
    const bool rec = e.isRecording();
    recBtn.setButtonText (rec ? (e.isInCountdown() ? "Compte..." : "STOP REC") : "REC");
    recBtn.setColour (juce::TextButton::buttonColourId, rec ? juce::Colours::red : juce::Colours::darkred);
    playBtn.setButtonText (e.isPlaying() ? "Pause" : "Lecture");
    inputMeter.setLevel (e.inputPeak(), e.consumeClipFlag());
    outputMeter.setLevel (std::max (e.outputPeakL(), e.outputPeakR()), false);
    e.resetMeters();
}

void TransportBar::paint (juce::Graphics& g)
{
    g.fillAll (theme::panel);
    g.setColour (theme::line);
    g.drawLine (0.0f, static_cast<float> (getHeight()) - 0.5f, static_cast<float> (getWidth()), static_cast<float> (getHeight()) - 0.5f);
}

void TransportBar::setUpdateButton (const juce::String& text, const juce::String& tooltip, bool highlight, bool enabled)
{
    updateBtn.setButtonText (text);
    updateBtn.setTooltip (tooltip);
    updateBtn.setEnabled (enabled);
    if (highlight)
    {
        updateBtn.setColour (juce::TextButton::buttonColourId, juce::Colour (0xff2e7d32));
        updateBtn.setColour (juce::TextButton::textColourOffId, juce::Colours::white);
    }
    else
    {
        updateBtn.removeColour (juce::TextButton::buttonColourId);
        updateBtn.removeColour (juce::TextButton::textColourOffId);
    }
}

void TransportBar::resized()
{
    auto r = getLocalBounds().reduced (6, 4);
    auto row1 = r.removeFromTop (30);
    r.removeFromTop (4);
    auto row2 = r.removeFromTop (30);

    // Largeur minimale 1440 px : tout doit tenir sans recouvrement (vumètres et sonie à droite).
    for (auto* b : { &newBtn, &openBtn, &saveBtn, &instruBtn, &voiceBtn, &exportBtn, &settingsBtn })
    {
        b->setBounds (row1.removeFromLeft (80));
        row1.removeFromLeft (3);
    }
    row1.removeFromLeft (8);
    undoBtn.setBounds (row1.removeFromLeft (72));
    row1.removeFromLeft (3);
    redoBtn.setBounds (row1.removeFromLeft (72));
    row1.removeFromLeft (8);
    correctBtn.setBounds (row1.removeFromLeft (128));
    row1.removeFromLeft (8);
    updateBtn.setBounds (row1.removeFromRight (140));
    row1.removeFromRight (6);
    inputMeter.setBounds (row1.removeFromRight (120));
    row1.removeFromRight (4);
    outputMeter.setBounds (row1.removeFromRight (110));
    row1.removeFromRight (4);
    mixLabel.setBounds (row1.removeFromRight (std::min (190, std::max (120, row1.getWidth()))));


    homeBtn.setBounds (row2.removeFromLeft (40));
    row2.removeFromLeft (4);
    playBtn.setBounds (row2.removeFromLeft (80));
    row2.removeFromLeft (4);
    stopBtn.setBounds (row2.removeFromLeft (60));
    row2.removeFromLeft (4);
    recBtn.setBounds (row2.removeFromLeft (90));
    row2.removeFromLeft (8);
    punch.setBounds (row2.removeFromLeft (90));
    loop.setBounds (row2.removeFromLeft (80));
    metronome.setBounds (row2.removeFromLeft (100));
    countTitle.setBounds (row2.removeFromLeft (55));
    countdown.setBounds (row2.removeFromLeft (100));
    row2.removeFromLeft (8);
    timeLabel.setBounds (row2.removeFromLeft (200));
    row2.removeFromLeft (8);
    bpmTitle.setBounds (row2.removeFromLeft (36));
    bpmLabel.setBounds (row2.removeFromLeft (60));
    row2.removeFromLeft (8);
    keyTitle.setBounds (row2.removeFromLeft (64));
    keyBox.setBounds (row2.removeFromLeft (130));
    row2.removeFromLeft (4);
    scaleToggle.setBounds (row2.removeFromLeft (72));
    row2.removeFromLeft (8);
    styleTitle.setBounds (row2.removeFromLeft (40));
    styleBox.setBounds (row2.removeFromLeft (165));
}
} // namespace sv::app
