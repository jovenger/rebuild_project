#include "Log.h"

#include <juce_events/juce_events.h>

#include <iostream>
#include <mutex>

namespace sv::log
{
namespace
{
    struct State
    {
        std::mutex mutex;
        std::unique_ptr<juce::FileOutputStream> stream;
        juce::File file;
        Level minLevel = Level::Debug;
        bool alsoStderr = true;
    };

    State& state()
    {
        static State s;
        return s;
    }

    juce::String timestamp()
    {
        const auto now = juce::Time::getCurrentTime();
        return now.formatted ("%Y-%m-%d %H:%M:%S") + "." + juce::String (now.getMilliseconds()).paddedLeft ('0', 3);
    }
}

const char* levelName (Level level)
{
    switch (level)
    {
        case Level::Debug: return "DEBUG";
        case Level::Info:  return "INFO ";
        case Level::Warn:  return "WARN ";
        case Level::Error: return "ERROR";
    }
    return "?????";
}

void init (const juce::File& logFile, Level minLevel, bool alsoStderr)
{
    auto& s = state();
    std::lock_guard<std::mutex> lock (s.mutex);
    s.minLevel = minLevel;
    s.alsoStderr = alsoStderr;
    s.stream.reset();

    if (logFile == juce::File())
        return;

    const auto dirResult = logFile.getParentDirectory().createDirectory();
    if (dirResult.failed())
    {
        std::cerr << "[Log] impossible de créer le dossier du journal : "_u8 << dirResult.getErrorMessage() << std::endl;
        return;
    }

    auto stream = std::make_unique<juce::FileOutputStream> (logFile);
    if (stream->failedToOpen())
    {
        std::cerr << "[Log] impossible d'ouvrir " << logFile.getFullPathName() << " : "
                  << stream->getStatus().getErrorMessage() << std::endl;
        return;
    }

    s.file = logFile;
    s.stream = std::move (stream);
}

void setMinLevel (Level level)
{
    auto& s = state();
    std::lock_guard<std::mutex> lock (s.mutex);
    s.minLevel = level;
}

juce::File getLogFile()
{
    auto& s = state();
    std::lock_guard<std::mutex> lock (s.mutex);
    return s.file;
}

void write (Level level, const char* module, const juce::String& message)
{
    auto& s = state();
    std::lock_guard<std::mutex> lock (s.mutex);

    if (static_cast<int> (level) < static_cast<int> (s.minLevel))
        return;

    const auto threadName = juce::Thread::getCurrentThread() != nullptr
                              ? juce::Thread::getCurrentThread()->getThreadName()
                              : (juce::MessageManager::getInstanceWithoutCreating() != nullptr
                                 && juce::MessageManager::getInstanceWithoutCreating()->isThisTheMessageThread()
                                   ? juce::String ("ui") : juce::String ("main"));

    const auto line = timestamp() + " [" + levelName (level) + "] [" + juce::String (module) + "] ("
                    + threadName + ") " + message;

    if (s.stream != nullptr)
    {
        s.stream->writeText (line + "\n", false, false, nullptr);
        s.stream->flush();
    }

    if (s.alsoStderr || s.stream == nullptr)
        std::cerr << line << std::endl;
}

void shutdown()
{
    auto& s = state();
    std::lock_guard<std::mutex> lock (s.mutex);
    if (s.stream != nullptr)
        s.stream->flush();
    s.stream.reset();
}

ScopedTimer::ScopedTimer (const char* m, juce::String w)
    : module (m), what (std::move (w)), startMs (juce::Time::getMillisecondCounterHiRes())
{
}

double ScopedTimer::elapsedMs() const
{
    return juce::Time::getMillisecondCounterHiRes() - startMs;
}

ScopedTimer::~ScopedTimer()
{
    write (Level::Debug, module, what + " : " + juce::String (elapsedMs(), 1) + " ms");
}
} // namespace sv::log
