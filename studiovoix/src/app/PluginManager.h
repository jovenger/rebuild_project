#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_gui_basics/juce_gui_basics.h>

#include "core/plugins/PluginChain.h"

#include <atomic>
#include <functional>
#include <memory>

// Hôte de plugins VST3 : recherche (emplacements standard + dossier au choix), liste connue (plugins.xml),
// fabrique d'instances pour le rendu hors temps réel, fenêtre d'édition d'un plugin (l'état est repris à la
// fermeture et le rendu de la piste est recalculé).
namespace sv::app
{
class PluginManager final : public juce::ChangeBroadcaster, private juce::Timer
{
public:
    PluginManager();
    ~PluginManager() override;

    static PluginManager& instance();

    /** Plugins d'effet connus (les instruments sont écartés), triés par éditeur puis nom. */
    juce::Array<juce::PluginDescription> effects() const;
    int numKnown() const { return known.getNumTypes(); }

    /** Recherche en arrière-plan ; extraFolder facultatif. Diffuse un changement à la fin. */
    void scan (const juce::File& extraFolder);
    bool isScanning() const { return scanning.load(); }
    juce::String scanStatus() const;   // en cours : "12 / 40 : Nom" ; sinon "N plugins connus"

    /** Menu « Ajouter un plugin » ; renvoie la description choisie (nullptr = aucune). */
    void showAddMenu (juce::Component* anchor, std::function<void (const juce::PluginDescription&)> onChosen);

    /** Ouvre la fenêtre d'un plugin avec son état ; onClosed reçoit le nouvel état à la fermeture. */
    void openEditor (const plugins::PluginSlot& slot, std::function<void (const juce::MemoryBlock& newState)> onClosed);
    void closeAllEditors();

    static juce::File pluginsFile();
    static juce::File deadMansPedalFile();

private:
    void timerCallback() override;
    void saveList();
    std::unique_ptr<juce::AudioPluginInstance> createInstance (const juce::String& identifier, double sr, int block, juce::String& err);

    juce::AudioPluginFormatManager formats;
    juce::KnownPluginList known;
    juce::CriticalSection knownLock;
    std::unique_ptr<juce::Thread> scanner;
    std::atomic<bool> scanning { false };
    std::atomic<bool> scanFinished { false };
    juce::String currentFile;
    juce::CriticalSection statusLock;
    float progress = 0.0f;
    juce::StringArray failedFiles;
    std::vector<std::unique_ptr<juce::DocumentWindow>> editors;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PluginManager)
};
} // namespace sv::app
