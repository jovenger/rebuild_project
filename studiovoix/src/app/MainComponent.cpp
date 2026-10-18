#include "MainComponent.h"

#include "ExportDialog.h"
#include "GenerateDialog.h"
#include "SettingsDialog.h"
#include "StyleMenu.h"
#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "UI";
    const char* kAudioPatterns = "*.wav;*.mp3;*.flac;*.aif;*.aiff;*.ogg";
}

MainComponent::MainComponent (Session& s)
    : session (s), transport (s), timeline (s)
{
    addAndMakeVisible (transport);
    addAndMakeVisible (timeline);
    addAndMakeVisible (tabs);
    addAndMakeVisible (statusBar);

    remix = new RemixPanel (session);
    lyrics = new LyricsPanel (session);
    mixPanel = new MixPanel (session);
    aiPanel = new AiPanel (session);
    const auto tabColour = juce::Colour (0xff1e2228);
    tabs.addTab ("Voix IA", tabColour, remix, true);
    tabs.addTab ("Paroles", tabColour, lyrics, true);
    tabs.addTab ("Mix & Master", tabColour, mixPanel, true);
    tabs.addTab ("IA", tabColour, aiPanel, true);
    tabs.setTabBarDepth (28);

    statusBar.setFont (juce::FontOptions (13.0f));
    statusBar.setColour (juce::Label::backgroundColourId, juce::Colour (0xff101317));

    transport.onNew = [this] { doNew(); };
    transport.onOpen = [this] { doOpen(); };
    transport.onSave = [this] { doSave(); };
    transport.onImportInstru = [this] { doImportInstru(); };
    transport.onImportVoice = [this] { doImportVoice(); };
    transport.onExport = [this] { ExportDialog::show (session); };
    transport.onSettings = [this]
    {
        if (session.isRecording())
        {
            session.setStatus ("Paramètres indisponibles pendant l'enregistrement : arrête la prise d'abord"_u8);
            return;
        }
        SettingsDialog::show (session);
    };
    transport.onRecord = [this] { doRecord(); };
    transport.onLoopToggled = [this]
    {
        session.setLoopRegion (transport.loopEnabled(), timeline.loopStartSec(), timeline.loopEndSec());
    };
    timeline.onRegionsChanged = [this]
    {
        session.setLoopRegion (transport.loopEnabled(), timeline.loopStartSec(), timeline.loopEndSec());
    };

    juce::Component::SafePointer<MainComponent> safeThis (this);
    session.onLeadTakeReady = [safeThis] (int trackId)
    {
        if (safeThis != nullptr)
            safeThis->proposeGeneration (trackId);
    };

    session.addChangeListener (this);
    setWantsKeyboardFocus (true);
    setSize (1440, 880);
    startTimerHz (30);
}

MainComponent::~MainComponent()
{
    stopTimer();
    selfTest.reset();
    session.removeChangeListener (this);
    session.onLeadTakeReady = nullptr;
}

void MainComponent::startup (const juce::String& commandLine)
{
    juce::StringArray args;
    args.addTokens (commandLine, true);
    args.trim();
    args.removeEmptyStrings();
    for (auto& a : args)
        a = a.unquoted();
    if (args.size() >= 3 && args[0] == "--selftest")
    {
        startSelfTest (args);
        return;
    }
    const juce::File arg (commandLine.unquoted().trim());
    if (commandLine.isNotEmpty() && arg.exists())
    {
        openProjectWithRecovery (arg, true);
        return;
    }
    const auto last = session.settings().lastProject();
    if (last.isDirectory() && last.getChildFile ("projet.svx").existsAsFile())
        openProjectWithRecovery (last, true);
    else
        createDefaultProject();
    grabKeyboardFocus();
}

// Auto-test de l'application réelle (sans clic) :
//   StudioVoix --selftest <instru> <voix>
// Enchaîne import, rendu, génération, annuler / rétablir, export, puis quitte (code 0 si tout est bon).
namespace
{
    class SelfTestRunner final : public juce::Timer
    {
    public:
        SelfTestRunner (Session& s, juce::File instruFile, juce::File voiceFile)
            : session (s), instru (std::move (instruFile)), voice (std::move (voiceFile))
        {
            session.onLeadTakeReady = nullptr;   // pas de fenêtre pendant le test
            stepStart = juce::Time::currentTimeMillis();
            startTimer (250);
        }

    private:
        void log (const juce::String& m) { SV_LOG_INFO ("AUTOTEST", m); }

        void fail (const juce::String& why)
        {
            stopTimer();
            SV_LOG_ERROR ("AUTOTEST", "ÉCHEC : "_u8 + why);
            juce::JUCEApplication::getInstance()->setApplicationReturnValue (1);
            juce::JUCEApplication::quit();
        }

        void next()
        {
            ++step;
            stepStart = juce::Time::currentTimeMillis();
        }

        bool idle() const { return ! session.isBusy(); }

        int countGenerated() const
        {
            int n = 0;
            for (const auto& t : session.project().tracks)
                n += t.isGenerated() ? 1 : 0;
            return n;
        }

        bool allRendered() const
        {
            for (const auto& t : session.project().tracks)
            {
                auto r = session.renderFor (t.id);
                if (r == nullptr || ! r->ok())
                    return false;
            }
            return true;
        }

        void timerCallback() override
        {
            if (juce::Time::currentTimeMillis() - stepStart > 180000)
            {
                fail ("délai dépassé à l'étape "_u8 + juce::String (step) + " (" + session.statusText() + ")");
                return;
            }
            juce::String err;
            switch (step)
            {
                case 0:
                    if (! session.newProject ("Autotest", err, style::Style::Trap)) { fail (err); return; }
                    if (session.project().style != style::Style::Trap) { fail ("style du nouveau projet non appliqué"_u8); return; }
                    session.importInstru (instru);
                    log ("étape 0 : projet créé, instru importée"_u8);
                    next();
                    break;
                case 1:
                    if (! idle() || session.project().instruTrack() == nullptr || session.renderFor (session.project().instruTrack()->id) == nullptr)
                        return;
                    log ("étape 1 : instru analysée : "_u8 + session.project().key.toFrench() + ", " + juce::String (session.project().tempo.bpm, 1) + " BPM, "
                         + juce::String ((int) session.project().sections.size()) + " sections");
                    session.importVoice (voice, session.project().leadTrackId());
                    next();
                    break;
                case 2:
                    if (! idle())
                        return;
                    if (! allRendered()) { fail ("rendu de la voix principale absent : "_u8 + session.trackStatus (session.project().leadTrackId())); return; }
                    log ("étape 2 : voix principale traitée — "_u8 + session.trackStatus (session.project().leadTrackId()));
                    session.generate (session.project().leadTrackId(),
                                      gen::GenerationOptions::fromDefaults (style::generationDefaults (session.project().style)));
                    next();
                    break;
                case 3:
                    if (! idle() || countGenerated() == 0 || ! allRendered())
                        return;
                    generated = countGenerated();
                    tracksAfterGen = static_cast<int> (session.project().tracks.size());
                    log ("étape 3 : "_u8 + juce::String (generated) + " pistes générées et traitées");
                    session.undo();
                    next();
                    break;
                case 4:
                    if (! idle())
                        return;
                    if (countGenerated() != 0) { fail ("annuler n'a pas retiré les pistes générées"_u8); return; }
                    log ("étape 4 : annuler OK"_u8);
                    session.redo();
                    next();
                    break;
                case 5:
                    if (! idle() || ! allRendered())
                        return;
                    if (static_cast<int> (session.project().tracks.size()) != tracksAfterGen) { fail ("rétablir n'a pas restauré les pistes"_u8); return; }
                    log ("étape 5 : rétablir OK"_u8);
                    // Comme une modification du projet juste avant l'export : un mix auto en cours ne doit pas bloquer.
                    session.updateProject ([] (project::Project& p) { p.masterEnabled = true; }, false, {});
                    {
                        render::ExportOptions o;
                        o.outDir = session.project().exportDir();
                        o.baseName = "autotest";
                        o.stems = true;
                        juce::WeakReference<Session> weak (&session);
                        session.exportMix (o, [this] (const render::ExportReport& rep)
                        {
                            exportDone = true;
                            exportOk = rep.ok;
                            exportInfo = rep.ok ? rep.mixFile.getFullPathName() + " (" + juce::String (rep.master.outputLufs, 2) + " LUFS, "
                                                      + juce::String (rep.master.truePeakDb, 2) + " dBTP, " + juce::String (rep.stemFiles.size()) + " pistes séparées)"_u8
                                                : rep.error;
                        });
                    }
                    next();
                    break;
                case 6:
                    if (! exportDone)
                        return;
                    if (! exportOk) { fail ("export : " + exportInfo); return; }
                    log ("étape 6 : export OK — "_u8 + exportInfo);
                    if (! session.save (err)) { fail ("sauvegarde : " + err); return; }
                    // Étapes 7-9 : une prise annulée pendant son traitement ne doit pas revenir.
                    backTrackId = session.addVocalTrack (style::Role::ManualBack, "Autotest back");
                    session.importVoice (voice, backTrackId);
                    next();
                    break;
                case 7:
                    if (session.trackStatus (backTrackId).startsWith ("Traitement"))
                    {
                        session.undo();   // annule l'import pendant le rendu
                        log ("étape 7 : annuler pendant le traitement de la prise"_u8);
                        next();
                    }
                    else if (idle() && session.renderFor (backTrackId) != nullptr)
                    {
                        log ("étape 7 : rendu terminé avant l'annulation (fenêtre manquée), annulation quand même"_u8);
                        session.undo();
                        next();
                    }
                    break;
                case 8:
                    if (! idle())
                        return;
                    if (const auto* t = session.project().findTrack (backTrackId); t == nullptr || ! t->takes.empty())
                    {
                        fail ("annuler n'a pas retiré la prise de la piste de test"_u8);
                        return;
                    }
                    if (session.renderFor (backTrackId) != nullptr)
                    {
                        fail ("la prise annulée est revenue (rendu périmé appliqué)"_u8);
                        return;
                    }
                    log ("étape 8 : prise annulée pendant son traitement : bien absente"_u8);
                    // Étapes 9-10 : rouvrir le projet pendant des calculs ne doit pas bloquer l'état « occupé ».
                    session.renderAll();
                    next();
                    break;
                case 9:
                    {
                        int running = 0;
                        for (const auto& t : session.project().tracks)
                            running += session.trackStatus (t.id).startsWith ("Traitement") ? 1 : 0;
                        // Rendus très courts (petite démo) : après 10 s sans en voir un en cours, on rouvre quand même.
                        if (running == 0 && juce::Time::currentTimeMillis() - stepStart < 10000)
                            return;
                        const auto folder = session.project().folder;
                        if (! session.openProject (folder, false, err)) { fail ("réouverture : "_u8 + err); return; }
                        log (running > 0 ? "étape 9 : projet rouvert pendant "_u8 + juce::String (running) + " rendu(s) en cours"
                                         : "étape 9 : aucun rendu vu en cours (fenêtre manquée), projet rouvert quand même"_u8);
                    }
                    next();
                    break;
                case 10:
                    if (! idle() || ! allRendered())
                        return;
                    log ("étape 10 : après réouverture, tous les rendus terminés (pas de blocage)"_u8);
                    stopTimer();
                    SV_LOG_INFO ("AUTOTEST", "RÉUSSI"_u8);
                    juce::JUCEApplication::getInstance()->setApplicationReturnValue (0);
                    juce::JUCEApplication::quit();
                    break;
                default:
                    break;
            }
        }

        Session& session;
        juce::File instru, voice;
        int step = 0;
        juce::int64 stepStart = 0;
        int generated = 0, tracksAfterGen = 0, backTrackId = -1;
        bool exportDone = false, exportOk = false;
        juce::String exportInfo;
    };
}

void MainComponent::startSelfTest (const juce::StringArray& args)
{
    const auto cwd = juce::File::getCurrentWorkingDirectory();
    const auto instru = cwd.getChildFile (args[1]);
    const auto voice = cwd.getChildFile (args[2]);
    SV_LOG_INFO ("AUTOTEST", "Démarrage : instru "_u8 + instru.getFullPathName() + ", voix " + voice.getFullPathName());
    selfTest = std::make_unique<SelfTestRunner> (session, instru, voice);
}

void MainComponent::createDefaultProject()
{
    juce::String err;
    const auto name = "Projet " + juce::Time::getCurrentTime().formatted ("%Y-%m-%d %Hh%M");
    if (! session.newProject (name, err))
        showMessage ("Création du projet impossible"_u8, err);
}

void MainComponent::openProjectWithRecovery (const juce::File& folder, bool atStartup)
{
    if (! folder.isDirectory() && folder.getFileName() != "projet.svx")
    {
        showMessage ("Ouverture impossible",
                     "Choisis le fichier projet.svx d'un dossier de projet. Les anciennes versions (dossier historique) "
                     "se restaurent depuis l'onglet Mix & Master."_u8);
        if (atStartup)
            createDefaultProject();
        return;
    }
    const auto dir = folder.isDirectory() ? folder : folder.getParentDirectory();
    if (project::Project::hasNewerAutosave (dir))
    {
        juce::Component::SafePointer<MainComponent> safe (this);
        juce::AlertWindow::showAsync (juce::MessageBoxOptions().withIconType (juce::MessageBoxIconType::QuestionIcon)
                                          .withTitle ("Récupération"_u8)
                                          .withMessage ("Une sauvegarde automatique plus récente existe (fermeture inattendue ?). La restaurer ?"_u8)
                                          .withButton ("Restaurer")
                                          .withButton ("Ouvrir la version enregistrée"_u8),
                                      [safe, dir, atStartup] (int r)
                                      {
                                          if (safe == nullptr)
                                              return;
                                          juce::String err;
                                          if (! safe->session.openProject (dir, r == 1, err))
                                          {
                                              safe->showMessage ("Ouverture impossible", err);
                                              if (atStartup)
                                                  safe->createDefaultProject();   // sinon le projet courant reste ouvert
                                          }
                                      });
        return;
    }
    juce::String err;
    if (! session.openProject (dir, false, err))
    {
        showMessage ("Ouverture impossible", err);
        if (atStartup)
            createDefaultProject();   // sinon le projet courant reste ouvert
    }
}

void MainComponent::showMessage (const juce::String& title, const juce::String& text)
{
    SV_LOG_WARN (kMod, title + " : " + text);
    juce::AlertWindow::showAsync (juce::MessageBoxOptions().withIconType (juce::MessageBoxIconType::WarningIcon)
                                      .withTitle (title)
                                      .withMessage (text)
                                      .withButton ("OK"),
                                  nullptr);
}

void MainComponent::doNew()
{
    auto* w = new juce::AlertWindow ("Nouveau projet", "Nom du projet :", juce::MessageBoxIconType::QuestionIcon);
    w->addTextEditor ("name", "Mon morceau");
    w->addComboBox ("style", {}, "Style");
    if (auto* box = w->getComboBoxComponent ("style"))
    {
        fillStyleBox (*box);
        box->setSelectedId (static_cast<int> (session.project().style) + 1, juce::dontSendNotification);
    }
    w->addTextBlock ("Autotune, EQ, compresseurs, de-esser, saturation, réverb et délai sont réglés automatiquement "
                     "pour ce style (modifiable ensuite dans la barre du haut et l'onglet Voix IA)."_u8);
    w->addButton ("Créer"_u8, 1, juce::KeyPress (juce::KeyPress::returnKey));
    w->addButton ("Annuler", 0, juce::KeyPress (juce::KeyPress::escapeKey));
    juce::Component::SafePointer<MainComponent> safe (this);
    w->enterModalState (true, juce::ModalCallbackFunction::create ([safe, w] (int r)
    {
        const auto name = w->getTextEditorContents ("name").trim();
        const auto* box = w->getComboBoxComponent ("style");
        const int styleIndex = box != nullptr ? box->getSelectedId() - 1 : -1;   // id = indice du style + 1
        delete w;
        if (safe == nullptr || r != 1 || name.isEmpty())
            return;
        const auto st = (styleIndex >= 0 && styleIndex < static_cast<int> (style::Style::Count)) ? static_cast<style::Style> (styleIndex)
                                                                                                 : style::Style::Rap;
        juce::String err;
        if (! safe->session.newProject (name, err, st))
            safe->showMessage ("Création impossible"_u8, err);
    }), false);
}

void MainComponent::doOpen()
{
    chooser = std::make_unique<juce::FileChooser> ("Ouvrir un projet StudioVoix", project::defaultProjectsRoot(), "*.svx");
    juce::Component::SafePointer<MainComponent> safe (this);
    chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles, [safe] (const juce::FileChooser& fc)
    {
        if (safe != nullptr && fc.getResult() != juce::File())
            safe->openProjectWithRecovery (fc.getResult());
    });
}

void MainComponent::doSave()
{
    juce::String err;
    if (! session.save (err))
        showMessage ("Sauvegarde impossible", err);
}

void MainComponent::doImportInstru()
{
    chooser = std::make_unique<juce::FileChooser> ("Choisir l'instru", juce::File::getSpecialLocation (juce::File::userMusicDirectory), kAudioPatterns);
    juce::Component::SafePointer<MainComponent> safe (this);
    chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles, [safe] (const juce::FileChooser& fc)
    {
        if (safe != nullptr && fc.getResult() != juce::File())
            safe->session.importInstru (fc.getResult());
    });
}

void MainComponent::doImportVoice()
{
    const int trackId = session.selectedTrack();
    chooser = std::make_unique<juce::FileChooser> ("Importer une voix (dans la piste sélectionnée)"_u8, juce::File::getSpecialLocation (juce::File::userMusicDirectory), kAudioPatterns);
    juce::Component::SafePointer<MainComponent> safe (this);
    chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles, [safe, trackId] (const juce::FileChooser& fc)
    {
        if (safe != nullptr && fc.getResult() != juce::File())
            safe->session.importVoice (fc.getResult(), trackId);
    });
}

void MainComponent::doRecord()
{
    if (session.isRecording())
    {
        session.stopRecording();
        return;
    }
    int trackId = session.selectedTrack();
    const auto* t = session.project().findTrack (trackId);
    if (t == nullptr || ! t->isVocal() || t->isGenerated())
        trackId = session.project().leadTrackId();
    if (trackId < 0)
        trackId = session.addVocalTrack (style::Role::Lead, "Voix principale");
    juce::String err;
    if (! session.startRecording (trackId, transport.punchEnabled(), timeline.punchInSec(), timeline.punchOutSec(), err))
        showMessage ("Enregistrement impossible", err);
}

bool MainComponent::keyPressed (const juce::KeyPress& key)
{
    const auto mods = key.getModifiers();
    if (key == juce::KeyPress::spaceKey)
    {
        session.togglePlay();
        return true;
    }
    if (key == juce::KeyPress::homeKey)
    {
        session.setPositionSec (0.0);
        return true;
    }
    if (mods.isCommandDown())
    {
        const auto c = juce::CharacterFunctions::toLowerCase (key.getTextCharacter() != 0 ? key.getTextCharacter() : static_cast<juce::juce_wchar> (key.getKeyCode()));
        // Dans un champ texte (paroles, assistant…), Ctrl+Z/Y ne doit jamais annuler une action du projet.
        if ((c == 'z' || c == 'y') && dynamic_cast<juce::TextEditor*> (juce::Component::getCurrentlyFocusedComponent()) != nullptr)
            return true;
        if (c == 's') { doSave(); return true; }
        if (c == 'z' && mods.isShiftDown()) { session.redo(); return true; }
        if (c == 'z') { session.undo(); return true; }
        if (c == 'y') { session.redo(); return true; }
        if (c == 'e') { ExportDialog::show (session); return true; }
        if (c == 'o') { doOpen(); return true; }
        return false;
    }
    const auto c = juce::CharacterFunctions::toLowerCase (key.getTextCharacter());
    if (c == 'r') { doRecord(); return true; }
    if (c == 'm') { session.addMarkerAtPlayhead(); return true; }
    return false;
}

void MainComponent::changeListenerCallback (juce::ChangeBroadcaster*)
{
    refreshAll();
}

void MainComponent::refreshAll()
{
    transport.refresh();
    timeline.refresh();
    if (remix != nullptr) remix->refresh();
    if (lyrics != nullptr) lyrics->refresh();
    if (mixPanel != nullptr) mixPanel->refresh();
    if (aiPanel != nullptr) aiPanel->refresh();
    statusBar.setText ((session.isBusy() ? juce::String ("[Calcul en cours] ") : juce::String()) + session.statusText(), juce::dontSendNotification);
}

void MainComponent::proposeGeneration (int trackId)
{
    // Jamais pendant une prise ni par-dessus une autre fenêtre : proposée dès que possible.
    if (session.isRecording() || juce::ModalComponentManager::getInstance()->getNumModalComponents() > 0)
    {
        pendingProposalTrack = trackId;
        SV_LOG_INFO (kMod, "Proposition de génération différée (prise ou fenêtre en cours)"_u8);
        return;
    }
    pendingProposalTrack = -1;
    GenerateDialog::show (session, trackId);
}

void MainComponent::timerCallback()
{
    if (pendingProposalTrack >= 0 && ! session.isRecording() && juce::ModalComponentManager::getInstance()->getNumModalComponents() == 0
        && session.project().findTrack (pendingProposalTrack) != nullptr)
        proposeGeneration (pendingProposalTrack);
    transport.updateTime();
    timeline.updatePlayhead();
    if (lyrics != nullptr)
        lyrics->updatePrompter();
    if (++frame % 15 == 0)
        statusBar.setText ((session.isBusy() ? juce::String ("[Calcul en cours] ") : juce::String()) + session.statusText(), juce::dontSendNotification);
}

void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff15181c));
}

void MainComponent::resized()
{
    auto r = getLocalBounds();
    transport.setBounds (r.removeFromTop (76));
    statusBar.setBounds (r.removeFromBottom (24));
    tabs.setBounds (r.removeFromRight (400));
    timeline.setBounds (r);
}
} // namespace sv::app
