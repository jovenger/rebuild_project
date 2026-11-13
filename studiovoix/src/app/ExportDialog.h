#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"

// Export : format, destination (sonie), mastering, pistes séparées.
namespace sv::app
{
class ExportDialog final : public juce::Component
{
public:
    explicit ExportDialog (Session& session);
    void resized() override;
    void paint (juce::Graphics& g) override;
    static void show (Session& session);

private:
    void launch();

    Session& session;
    juce::Label nameL, formatL, targetL, result;
    juce::TextEditor name;
    juce::ComboBox format, target;
    juce::ToggleButton master { "Mastering automatique" }, stems { juce::String (juce::CharPointer_UTF8 ("Exporter aussi les pistes séparées (pour un ingé son)")) };
    juce::TextButton exportBtn { "Exporter" }, openFolder { "Ouvrir le dossier" }, closeBtn { "Fermer" };
    juce::File lastFile;
};
} // namespace sv::app
