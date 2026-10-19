#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Barre du haut : fichiers, transport, enregistrement, tempo, tonalité, style, vu-mètre d'entrée.
namespace sv::app
{
class LevelMeter final : public juce::Component
{
public:
    void setLevel (float peak, bool clip);
    void setLabel (const juce::String& l) { label = l; }
    void setCompact (bool c) { compact = c; }   // barre seule, sans texte (en-tête de piste)
    void paint (juce::Graphics& g) override;

private:
    float level = 0.0f;
    bool clipped = false;
    bool compact = false;
    juce::String label { "Micro" };
    juce::int64 clipUntilMs = 0;
};

class TransportBar final : public juce::Component
{
public:
    explicit TransportBar (Session& session);

    void refresh();          // état du projet -> contrôles
    void updateTime();       // appelé ~30 fois par seconde
    void resized() override;
    void paint (juce::Graphics& g) override;

    bool punchEnabled() const { return punch.getToggleState(); }
    bool loopEnabled() const { return loop.getToggleState(); }

    std::function<void()> onNew, onOpen, onSave, onImportInstru, onImportVoice, onExport, onSettings, onRecord, onLoopToggled, onUpdate, onCorrectAll;

    /** Bouton « Mise à jour » (en haut à droite) : texte, info-bulle, mise en avant (nouvelle version), cliquable. */
    void setUpdateButton (const juce::String& text, const juce::String& tooltip, bool highlight, bool enabled);

private:
    Session& session;
    juce::TextButton newBtn { "Nouveau" }, openBtn { "Ouvrir" }, saveBtn { "Sauver" }, instruBtn { "Instru..." },
        voiceBtn { "Voix..." }, exportBtn { "Exporter" }, settingsBtn { juce::String (juce::CharPointer_UTF8 ("Paramètres")) },
        undoBtn { "Annuler" }, redoBtn { juce::String (juce::CharPointer_UTF8 ("Rétablir")) },
        updateBtn { juce::String (juce::CharPointer_UTF8 ("Mise à jour")) }, correctBtn { juce::String (juce::CharPointer_UTF8 ("Ingénieur du son")) };
    juce::TextButton homeBtn { "|<" }, playBtn { "Lecture" }, stopBtn { "Stop" }, recBtn { "REC" };
    juce::ToggleButton punch { "Punch-in" }, loop { "Boucle" }, metronome { juce::String (juce::CharPointer_UTF8 ("Métronome")) },
        scaleToggle { "Gamme" };   // autotune contraint à la gamme de la tonalité (décoché : note par note)
    juce::ComboBox countdown, keyBox, styleBox;
    juce::Label timeLabel, bpmLabel, bpmTitle, keyTitle, styleTitle, countTitle, mixLabel;
    LevelMeter inputMeter, outputMeter;
    bool updating = false;
};
} // namespace sv::app
