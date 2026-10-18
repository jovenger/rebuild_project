#include "PluginManager.h"

#include "AppSettings.h"
#include "core/Log.h"
#include "core/plugins/InternalPlugins.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "Plugins";

    class ScanThread final : public juce::Thread
    {
    public:
        ScanThread (PluginManager& m, juce::AudioPluginFormatManager& formats, juce::KnownPluginList& list, juce::CriticalSection& lock,
                    juce::FileSearchPath paths, juce::CriticalSection& statusLock, juce::String& currentFile, float& progress,
                    juce::StringArray& failed, std::atomic<bool>& finished)
            : juce::Thread ("Recherche de plugins"), manager (m), fm (formats), known (list), knownLock (lock), searchPaths (std::move (paths)),
              stLock (statusLock), current (currentFile), prog (progress), failedFiles (failed), done (finished) {}

        void run() override
        {
            for (auto* format : fm.getFormats())
            {
                if (format->getName() != "VST3")
                    continue;
                juce::KnownPluginList tmp;
                {
                    const juce::ScopedLock sl (knownLock);
                    if (auto xml = known.createXml())
                        tmp.recreateFromXml (*xml);
                }
                juce::PluginDirectoryScanner scanner (tmp, *format, searchPaths, true, PluginManager::deadMansPedalFile(), false);
                juce::String name;
                int count = 0;
                while (! threadShouldExit() && scanner.scanNextFile (true, name))
                {
                    const juce::ScopedLock sl (stLock);
                    current = name;
                    prog = scanner.getProgress();
                    ++count;
                }
                {
                    const juce::ScopedLock sl (stLock);
                    failedFiles = scanner.getFailedFiles();
                }
                {
                    const juce::ScopedLock sl (knownLock);
                    if (auto xml = tmp.createXml())
                        known.recreateFromXml (*xml);
                }
                SV_LOG_INFO (kMod, "Recherche VST3 terminée : "_u8 + juce::String (count) + " fichier(s) examiné(s), " + juce::String (tmp.getNumTypes())
                                   + " plugin(s) connu(s), " + juce::String (failedFiles.size()) + " échec(s)"_u8);
                for (const auto& f : failedFiles)
                    SV_LOG_WARN (kMod, "Plugin non chargé : "_u8 + f);
            }
            done.store (true);
        }

    private:
        PluginManager& manager;
        juce::AudioPluginFormatManager& fm;
        juce::KnownPluginList& known;
        juce::CriticalSection& knownLock;
        juce::FileSearchPath searchPaths;
        juce::CriticalSection& stLock;
        juce::String& current;
        float& prog;
        juce::StringArray& failedFiles;
        std::atomic<bool>& done;
    };

    // Fenêtre de réglage d'un effet intégré : un curseur par paramètre ; l'état (JSON) est repris à la fermeture.
    class InternalEditorWindow final : public juce::DocumentWindow
    {
    public:
        InternalEditorWindow (const plugins::InternalPluginDef& def, juce::MemoryBlock initialState,
                              std::function<void (const juce::MemoryBlock&)> onClosed, std::function<void (InternalEditorWindow*)> onDestroy)
            : juce::DocumentWindow (juce::String (juce::CharPointer_UTF8 (def.name)), juce::Colour (0xff23282f), DocumentWindow::closeButton),
              definition (def), state (std::move (initialState)), closed (std::move (onClosed)), destroy (std::move (onDestroy))
        {
            setUsingNativeTitleBar (true);
            auto* content = new juce::Component();
            const int rowH = 30;
            int y = 10;
            for (const auto& p : def.params)
            {
                auto* label = new juce::Label ({}, juce::String (juce::CharPointer_UTF8 (p.label)));
                label->setFont (juce::FontOptions (13.0f));
                label->setBounds (10, y, 260, rowH - 6);
                content->addAndMakeVisible (label);
                auto* slider = new juce::Slider (juce::Slider::LinearHorizontal, juce::Slider::TextBoxRight);
                slider->setRange (p.min, p.max, (p.max - p.min) > 50.0f ? 1.0 : 0.01);
                slider->setTextValueSuffix (juce::String (" ") + juce::String (juce::CharPointer_UTF8 (p.unit)));
                slider->setValue (plugins::internalParam (def, state, p.id), juce::dontSendNotification);
                slider->setDoubleClickReturnValue (true, p.def);
                slider->setBounds (280, y, 360, rowH - 6);
                const juce::String id (p.id);
                slider->onValueChange = [this, slider, id] { state = plugins::withInternalParam (definition, state, id, static_cast<float> (slider->getValue())); };
                content->addAndMakeVisible (slider);
                labels.add (label);
                sliders.add (slider);
                y += rowH;
            }
            auto* hint = new juce::Label ({}, "Les réglages s'appliquent à la fermeture de cette fenêtre (double-clic sur un curseur = valeur de départ)."_u8);
            hint->setFont (juce::FontOptions (11.0f));
            hint->setColour (juce::Label::textColourId, juce::Colours::lightgrey);
            hint->setBounds (10, y + 4, 630, 20);
            content->addAndMakeVisible (hint);
            labels.add (hint);
            content->setSize (650, y + 36);
            setContentOwned (content, true);
            centreWithSize (getWidth(), getHeight());
            setVisible (true);
            toFront (true);
        }

        void closeButtonPressed() override
        {
            SV_LOG_INFO (kMod, "Réglages de « "_u8 + getName() + " » repris : "_u8 + state.toString());
            if (closed)
                closed (state);
            if (destroy)
                destroy (this);
        }

    private:
        const plugins::InternalPluginDef& definition;
        juce::MemoryBlock state;
        juce::OwnedArray<juce::Label> labels;
        juce::OwnedArray<juce::Slider> sliders;
        std::function<void (const juce::MemoryBlock&)> closed;
        std::function<void (InternalEditorWindow*)> destroy;
    };

    class EditorWindow final : public juce::DocumentWindow
    {
    public:
        EditorWindow (std::unique_ptr<juce::AudioPluginInstance> inst, const juce::String& title,
                      std::function<void (const juce::MemoryBlock&)> onClosed, std::function<void (EditorWindow*)> onDestroy)
            : juce::DocumentWindow (title, juce::Colour (0xff23282f), DocumentWindow::closeButton),
              instance (std::move (inst)), closed (std::move (onClosed)), destroy (std::move (onDestroy))
        {
            setUsingNativeTitleBar (true);
            if (auto* ed = instance->createEditorAndMakeActive())
            {
                setContentOwned (ed, true);
            }
            else
            {
                setContentOwned (new juce::GenericAudioProcessorEditor (*instance), true);
                setResizable (true, false);
            }
            centreWithSize (std::max (320, getWidth()), std::max (200, getHeight()));
            setVisible (true);
            toFront (true);
        }

        ~EditorWindow() override
        {
            clearContentComponent();   // l'éditeur disparaît avant l'instance
            instance.reset();
        }

        void closeButtonPressed() override
        {
            juce::MemoryBlock state;
            instance->getStateInformation (state);
            SV_LOG_INFO (kMod, "Fenêtre de « "_u8 + getName() + " » fermée : état repris ("_u8 + juce::String (static_cast<juce::int64> (state.getSize())) + " octets)");
            if (closed)
                closed (state);
            if (destroy)
                destroy (this);
        }

    private:
        std::unique_ptr<juce::AudioPluginInstance> instance;
        std::function<void (const juce::MemoryBlock&)> closed;
        std::function<void (EditorWindow*)> destroy;
    };
}

PluginManager& PluginManager::instance()
{
    static PluginManager pm;
    return pm;
}

juce::File PluginManager::pluginsFile()
{
    return AppSettings::logsFolder().getParentDirectory().getChildFile ("plugins.xml");
}

juce::File PluginManager::deadMansPedalFile()
{
    return AppSettings::logsFolder().getParentDirectory().getChildFile ("plugins_en_cours.txt");
}

PluginManager::PluginManager()
{
    juce::addDefaultFormatsToManager (formats);
    juce::StringArray names;
    for (auto* f : formats.getFormats())
        names.add (f->getName());
    if (auto xml = juce::XmlDocument::parse (pluginsFile()))
    {
        const juce::ScopedLock sl (knownLock);
        known.recreateFromXml (*xml);
    }
    juce::PluginDirectoryScanner::applyBlacklistingsFromDeadMansPedal (known, deadMansPedalFile());
    SV_LOG_INFO (kMod, "Hôte de plugins : formats " + names.joinIntoString (", ") + ", " + juce::String (known.getNumTypes()) + " plugin(s) connu(s)");

    // Fabrique utilisée par le rendu (threads de calcul) : VST3 s'instancie hors du thread de l'interface.
    plugins::setInstanceFactory ([this] (const plugins::PluginSlot& slot, double sr, int block, juce::String& err) -> std::unique_ptr<juce::AudioProcessor>
    {
        return createInstance (slot.identifier, sr, block, err);
    });
}

PluginManager::~PluginManager()
{
    if (scanner != nullptr)
        scanner->stopThread (10000);
    closeAllEditors();
    plugins::setInstanceFactory (nullptr);
}

std::unique_ptr<juce::AudioPluginInstance> PluginManager::createInstance (const juce::String& identifier, double sr, int block, juce::String& err)
{
    std::unique_ptr<juce::PluginDescription> desc;
    {
        const juce::ScopedLock sl (knownLock);
        desc = known.getTypeForIdentifierString (identifier);
    }
    if (desc == nullptr)
    {
        err = "plugin inconnu (relance la recherche dans Paramètres) : "_u8 + identifier;
        return nullptr;
    }
    auto inst = formats.createPluginInstance (*desc, sr, block, err);
    if (inst == nullptr && err.isEmpty())
        err = "instanciation refusée"_u8;
    return inst;
}

juce::Array<juce::PluginDescription> PluginManager::effects() const
{
    juce::Array<juce::PluginDescription> out;
    const juce::ScopedLock sl (knownLock);
    for (const auto& d : known.getTypes())
        if (! d.isInstrument)
            out.add (d);
    std::sort (out.begin(), out.end(), [] (const juce::PluginDescription& a, const juce::PluginDescription& b)
    {
        const int m = a.manufacturerName.compareIgnoreCase (b.manufacturerName);
        return m != 0 ? m < 0 : a.name.compareIgnoreCase (b.name) < 0;
    });
    return out;
}

void PluginManager::scan (const juce::File& extraFolder)
{
    if (scanning.load())
        return;
    juce::FileSearchPath paths;
    for (auto* f : formats.getFormats())
        if (f->getName() == "VST3")
            paths = f->getDefaultLocationsToSearch();
    if (extraFolder.isDirectory())
        paths.add (extraFolder);
    SV_LOG_INFO (kMod, "Recherche VST3 dans : " + paths.toString());
    scanFinished.store (false);
    scanning.store (true);
    {
        const juce::ScopedLock sl (statusLock);
        currentFile.clear();
        progress = 0.0f;
    }
    scanner = std::make_unique<ScanThread> (*this, formats, known, knownLock, paths, statusLock, currentFile, progress, failedFiles, scanFinished);
    scanner->startThread();
    startTimer (300);
    sendChangeMessage();
}

void PluginManager::timerCallback()
{
    if (scanFinished.load())
    {
        stopTimer();
        if (scanner != nullptr)
            scanner->stopThread (5000);
        scanner.reset();
        scanning.store (false);
        saveList();
    }
    sendChangeMessage();
}

void PluginManager::saveList()
{
    const juce::ScopedLock sl (knownLock);
    if (auto xml = known.createXml())
    {
        pluginsFile().getParentDirectory().createDirectory();
        if (! xml->writeTo (pluginsFile()))
            SV_LOG_ERROR (kMod, "Liste des plugins non enregistrée : "_u8 + pluginsFile().getFullPathName());
    }
}

juce::String PluginManager::scanStatus() const
{
    if (scanning.load())
    {
        const juce::ScopedLock sl (statusLock);
        return "Recherche en cours ("_u8 + juce::String (juce::roundToInt (progress * 100.0f)) + " %) : " + currentFile;
    }
    const int n = numKnown();
    juce::String s = juce::String (n) + " plugin(s) VST3 connu(s)";
    if (! failedFiles.isEmpty())
        s << ", " << failedFiles.size() << " non chargé(s)"_u8;
    return s;
}

void PluginManager::showAddMenu (juce::Component* anchor, std::function<void (const plugins::PluginSlot&)> onChosen)
{
    const auto types = effects();
    juce::PopupMenu m;
    m.addSectionHeader ("Effets intégrés"_u8);
    const auto& internals = plugins::internalPlugins();
    for (size_t i = 0; i < internals.size(); ++i)
        m.addItem (100000 + static_cast<int> (i), juce::String (juce::CharPointer_UTF8 (internals[i].name)));
    m.addSeparator();
    m.addSectionHeader ("Plugins VST3");
    if (types.isEmpty())
        m.addItem (1, "Aucun plugin VST3 connu : lance la recherche dans Paramètres"_u8, false);
    else
        juce::KnownPluginList::addToMenu (m, types, juce::KnownPluginList::sortByManufacturer);
    m.showMenuAsync (juce::PopupMenu::Options().withTargetComponent (anchor), [types, onChosen] (int r)
    {
        if (! onChosen || r == 0)
            return;
        const auto& internalDefs = plugins::internalPlugins();
        if (r >= 100000 && r < 100000 + static_cast<int> (internalDefs.size()))
        {
            const auto& def = internalDefs[static_cast<size_t> (r - 100000)];
            plugins::PluginSlot s;
            s.identifier = def.identifier;
            s.name = juce::String (juce::CharPointer_UTF8 (def.name));
            s.state = plugins::defaultInternalState (def);
            onChosen (s);
            return;
        }
        const int idx = juce::KnownPluginList::getIndexChosenByMenu (types, r);
        if (idx >= 0 && idx < types.size())
        {
            plugins::PluginSlot s;
            s.identifier = types[idx].createIdentifierString();
            s.name = types[idx].name;
            onChosen (s);
        }
    });
}

void PluginManager::openEditor (const plugins::PluginSlot& slot, std::function<void (const juce::MemoryBlock&)> onClosed)
{
    if (const auto* def = plugins::findInternal (slot.identifier))
    {
        SV_LOG_INFO (kMod, "Réglages de « "_u8 + slot.name + " » ouverts"_u8);
        editors.push_back (std::make_unique<InternalEditorWindow> (*def, slot.state, std::move (onClosed), [this] (InternalEditorWindow* w)
        {
            juce::MessageManager::callAsync ([this, w]
            {
                editors.erase (std::remove_if (editors.begin(), editors.end(), [w] (const auto& p) { return p.get() == w; }), editors.end());
            });
        }));
        return;
    }
    juce::String err;
    auto inst = createInstance (slot.identifier, 48000.0, 1024, err);
    if (inst == nullptr)
    {
        SV_LOG_ERROR (kMod, "Ouverture de « "_u8 + slot.name + " » impossible : "_u8 + err);
        juce::AlertWindow::showAsync (juce::MessageBoxOptions().withIconType (juce::MessageBoxIconType::WarningIcon)
                                          .withTitle ("Plugin").withMessage (err).withButton ("OK"), nullptr);
        return;
    }
    inst->setNonRealtime (true);
    inst->setPlayConfigDetails (2, 2, 48000.0, 1024);
    inst->prepareToPlay (48000.0, 1024);
    if (slot.state.getSize() > 0)
        inst->setStateInformation (slot.state.getData(), static_cast<int> (slot.state.getSize()));
    SV_LOG_INFO (kMod, "Fenêtre de « "_u8 + slot.name + " » ouverte"_u8);
    editors.push_back (std::make_unique<EditorWindow> (std::move (inst), slot.name, std::move (onClosed), [this] (EditorWindow* w)
    {
        juce::MessageManager::callAsync ([this, w]
        {
            editors.erase (std::remove_if (editors.begin(), editors.end(), [w] (const auto& p) { return p.get() == w; }), editors.end());
        });
    }));
}

void PluginManager::closeAllEditors()
{
    editors.clear();
}
} // namespace sv::app
