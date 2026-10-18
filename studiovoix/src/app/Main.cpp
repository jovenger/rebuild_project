#include <juce_gui_basics/juce_gui_basics.h>

#include "AppSettings.h"
#include "AudioEngine.h"
#include "MainComponent.h"
#include "Session.h"
#include "core/Log.h"

#if JUCE_WINDOWS
 #include <windows.h>
#endif

namespace
{
constexpr const char* kMod = "App";

void onCrash (void*)
{
    // Dernier recours : trace de pile dans le journal pour le diagnostic.
    sv::log::write (sv::log::Level::Error, "Crash", "Plantage de StudioVoix :\n" + juce::SystemStats::getStackBacktrace());
    sv::log::shutdown();
}

class MainWindow final : public juce::DocumentWindow
{
public:
    MainWindow (const juce::String& name, sv::app::Session& session)
        : DocumentWindow (name, juce::Desktop::getInstance().getDefaultLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId),
                          DocumentWindow::allButtons)
    {
        setUsingNativeTitleBar (true);
        setContentOwned (new sv::app::MainComponent (session), true);
        setResizable (true, true);
        setResizeLimits (1000, 640, 10000, 10000);
        centreWithSize (1440, 880);
        setVisible (true);
    }

    void closeButtonPressed() override
    {
        juce::JUCEApplication::getInstance()->systemRequestedQuit();
    }

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainWindow)
};
} // namespace

class StudioVoixApplication final : public juce::JUCEApplication
{
public:
    const juce::String getApplicationName() override { return JUCE_APPLICATION_NAME_STRING; }
    const juce::String getApplicationVersion() override { return JUCE_APPLICATION_VERSION_STRING; }
    bool moreThanOneInstanceAllowed() override { return false; }

    void initialise (const juce::String& commandLine) override
    {
        const auto logFile = sv::app::AppSettings::logsFolder().getChildFile ("studiovoix_" + juce::Time::getCurrentTime().formatted ("%Y%m%d") + ".log");
        sv::log::init (logFile, sv::log::Level::Debug, false);
        juce::SystemStats::setApplicationCrashHandler (onCrash);
        // Verrou nommé tenu tant que le programme tourne : l'installateur de mise à jour attend qu'il soit libéré.
        if (! runningLock.enter (0))
            SV_LOG_WARN (kMod, "Verrou « StudioVoix_en_cours » déjà pris (autre instance ?)"_u8);
        SV_LOG_INFO (kMod, "Démarrage de StudioVoix "_u8 + getApplicationVersion() + " (" + juce::SystemStats::getOperatingSystemName()
                           + ", " + juce::String (juce::SystemStats::getNumCpus()) + " coeurs, " + juce::String (juce::SystemStats::getMemorySizeInMegabytes())
                           + " Mo) — journal : "_u8 + logFile.getFullPathName());

#if JUCE_WINDOWS
        // Lancé « en tant qu'administrateur » : Windows bloque le glisser-déposer depuis l'Explorateur (UIPI).
        {
            HANDLE token = nullptr;
            if (OpenProcessToken (GetCurrentProcess(), TOKEN_QUERY, &token))
            {
                TOKEN_ELEVATION elev {};
                DWORD size = sizeof (elev);
                if (GetTokenInformation (token, TokenElevation, &elev, sizeof (elev), &size) && elev.TokenIsElevated)
                    SV_LOG_WARN (kMod, "Programme lancé en administrateur : le glisser-déposer de fichiers depuis l'Explorateur "
                                       "est bloqué par Windows. Lance StudioVoix normalement (sans « Exécuter en tant qu'administrateur »)."_u8);
                else
                    SV_LOG_INFO (kMod, "Programme lancé sans élévation (glisser-déposer possible)"_u8);
                CloseHandle (token);
            }
        }
#endif
        settings = std::make_unique<sv::app::AppSettings>();
        engine = std::make_unique<sv::app::AudioEngine>();
        auto saved = settings->audioDeviceState();
        const auto err = engine->openDevice (saved.get());
        if (err.isNotEmpty())
            SV_LOG_ERROR (kMod, "Carte son : " + err);
        engine->setMonitoring (settings->softwareMonitoring());
        engine->setInputChannelMode (settings->inputChannelMode());
        engine->setInputTrimDb (settings->inputTrimDb());
        engine->setMetronome (settings->metronome());

        session = std::make_unique<sv::app::Session> (*engine, *settings);
        mainWindow = std::make_unique<MainWindow> (getApplicationName(), *session);

        if (auto* mc = dynamic_cast<sv::app::MainComponent*> (mainWindow->getContentComponent()))
            mc->startup (commandLine);
    }

    void shutdown() override
    {
        SV_LOG_INFO (kMod, "Fermeture de StudioVoix");
        if (engine != nullptr && settings != nullptr)
        {
            auto state = engine->deviceManager().createStateXml();
            settings->setAudioDeviceState (state.get());
            settings->save();
        }
        mainWindow = nullptr;
        session = nullptr;
        engine = nullptr;
        settings = nullptr;
        sv::log::shutdown();
    }

    void systemRequestedQuit() override
    {
        if (session != nullptr && session->isRecording())
            session->stopRecording();
        quit();
    }

    void anotherInstanceStarted (const juce::String&) override {}

private:
    juce::InterProcessLock runningLock { "StudioVoix_en_cours" };
    std::unique_ptr<sv::app::AppSettings> settings;
    std::unique_ptr<sv::app::AudioEngine> engine;
    std::unique_ptr<sv::app::Session> session;
    std::unique_ptr<MainWindow> mainWindow;
};

START_JUCE_APPLICATION (StudioVoixApplication)
