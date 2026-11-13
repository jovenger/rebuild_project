#include "UpdateManager.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "MiseAJour";
    constexpr int kFirstCheckMs = 5000;
    constexpr int kPeriodMs = 30 * 60 * 1000;
}

UpdateManager::UpdateManager (AppSettings& s) : settings (s) {}

UpdateManager::~UpdateManager()
{
    stopTimer();
    alive->store (false);
    cancel->store (true);
    pool.removeAllJobs (true, 5000);
}

void UpdateManager::start()
{
    SV_LOG_INFO (kMod, "Ce programme : build "_u8 + juce::String (update::currentBuild())
                       + (update::currentBuild() == 0 ? " (compilation locale)" : "") + ", dépôt " + update::kRepo);
    startTimer (kFirstCheckMs);
}

void UpdateManager::timerCallback()
{
    if (! firstCheckDone)
    {
        firstCheckDone = true;
        startTimer (kPeriodMs);
    }
    if (currentState == State::Idle || currentState == State::UpToDate || currentState == State::Error)
        checkNow (false);
}

void UpdateManager::setState (State s)
{
    currentState = s;
    if (onChange)
        onChange();
}

void UpdateManager::checkNow (bool userRequested)
{
    if (currentState == State::Checking || currentState == State::Downloading)
        return;
    userRequestedCheck = userRequested;
    error.clear();
    setState (State::Checking);
    const auto token = settings.updateToken();
    auto flag = alive;
    pool.addJob ([this, flag, token]
    {
        auto info = update::fetchLatest (token);
        juce::MessageManager::callAsync ([this, flag, info = std::move (info)]() mutable
        {
            if (! flag->load())
                return;
            release = std::move (info);
            if (! release.ok)
            {
                error = release.error;
                setState (State::Error);
            }
            else if (release.build > update::currentBuild())
            {
                SV_LOG_INFO (kMod, "Mise à jour disponible : build "_u8 + juce::String (release.build) + " (installé : "_u8
                                   + juce::String (update::currentBuild()) + ")");
                setState (State::Available);
            }
            else
            {
                setState (State::UpToDate);
            }
        });
    });
}

void UpdateManager::download()
{
    if (currentState != State::Available || ! release.ok)
        return;
    progress = 0.0;
    error.clear();
    userRequestedCheck = true;   // une erreur de téléchargement est affichée (le clic vient de l'utilisateur)
    cancel->store (false);
    installer = juce::File::getSpecialLocation (juce::File::tempDirectory).getChildFile ("StudioVoix").getChildFile ("mise_a_jour")
                    .getChildFile (juce::File::createLegalFileName (release.assetName));
    setState (State::Downloading);
    const auto token = settings.updateToken();
    auto flag = alive;
    auto stop = cancel;
    pool.addJob ([this, flag, stop, token, rel = release, dest = installer]
    {
        juce::String err;
        int lastPct = -1;
        const bool ok = update::download (rel, token, dest, [this, flag, stop, &lastPct] (double p)
        {
            const int pct = juce::jlimit (0, 100, juce::roundToInt (p * 100.0));
            if (pct != lastPct)
            {
                lastPct = pct;
                juce::MessageManager::callAsync ([this, flag, pct]
                {
                    if (! flag->load() || currentState != State::Downloading)
                        return;
                    progress = pct / 100.0;
                    if (onChange)
                        onChange();
                });
            }
            return ! stop->load();
        }, err);
        juce::MessageManager::callAsync ([this, flag, ok, err]
        {
            if (! flag->load())
                return;
            if (ok)
            {
                progress = 1.0;
                setState (State::Ready);
            }
            else
            {
                error = err;
                SV_LOG_ERROR (kMod, "Mise à jour non téléchargée : "_u8 + err);
                setState (State::Error);
            }
        });
    });
}

bool UpdateManager::launchInstaller (juce::String& err)
{
    if (currentState != State::Ready || ! installer.existsAsFile())
    {
        err = "Installateur absent"_u8;
        return false;
    }
#if JUCE_WINDOWS
    const auto logFile = AppSettings::logsFolder().getChildFile ("installation_build" + juce::String (release.build) + ".log");
    const auto args = update::installerArguments (logFile);
    SV_LOG_INFO (kMod, "Lancement de l'installateur : "_u8 + installer.getFullPathName() + " " + args);
    if (! installer.startAsProcess (args))
    {
        err = "Windows a refusé de lancer l'installateur (antivirus ?) : "_u8 + installer.getFullPathName();
        SV_LOG_ERROR (kMod, err);
        error = err;
        setState (State::Error);
        return false;
    }
    return true;
#else
    err = "Installation automatique disponible sous Windows uniquement ; installateur téléchargé : "_u8 + installer.getFullPathName();
    SV_LOG_WARN (kMod, err);
    error = err;
    setState (State::Error);
    return false;
#endif
}
} // namespace sv::app
