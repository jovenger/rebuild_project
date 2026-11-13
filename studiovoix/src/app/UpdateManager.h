#pragma once

#include <juce_events/juce_events.h>

#include "AppSettings.h"
#include "core/update/Updater.h"

#include <atomic>
#include <memory>

// Vérification (au démarrage puis toutes les 30 min) et téléchargement des mises à jour en arrière-plan.
// Les rappels onChange arrivent sur le thread de l'interface.
namespace sv::app
{
class UpdateManager final : private juce::Timer
{
public:
    enum class State { Idle, Checking, UpToDate, Available, Downloading, Ready, Error };

    explicit UpdateManager (AppSettings& settings);
    ~UpdateManager() override;

    /** Première vérification après quelques secondes, puis vérification périodique. */
    void start();
    void checkNow (bool userRequested);
    void download();

    State state() const { return currentState; }
    const update::ReleaseInfo& latest() const { return release; }
    const juce::String& lastError() const { return error; }
    double downloadProgress() const { return progress; }
    juce::File installerFile() const { return installer; }
    bool lastCheckWasUserRequested() const { return userRequestedCheck; }

    /** Lance l'installateur (mode silencieux + relance). Le programme doit se fermer juste après. */
    bool launchInstaller (juce::String& err);

    std::function<void()> onChange;

private:
    void timerCallback() override;
    void setState (State s);

    AppSettings& settings;
    juce::ThreadPool pool { juce::ThreadPoolOptions{}.withThreadName ("MiseAJour").withNumberOfThreads (1) };
    std::shared_ptr<std::atomic<bool>> alive = std::make_shared<std::atomic<bool>> (true);
    std::shared_ptr<std::atomic<bool>> cancel = std::make_shared<std::atomic<bool>> (false);
    State currentState = State::Idle;
    update::ReleaseInfo release;
    juce::String error;
    double progress = 0.0;
    juce::File installer;
    bool userRequestedCheck = false;
    bool firstCheckDone = false;
};
} // namespace sv::app
