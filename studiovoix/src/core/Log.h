#pragma once

#include <juce_core/juce_core.h>

/** Littéral UTF-8 : "é"_u8 donne une juce::String correctement décodée
    (juce::String ("é") interprète les octets comme de l'ASCII et produit "Ã©"). */
inline juce::String operator""_u8 (const char* text, std::size_t length)
{
    return juce::String::fromUTF8 (text, static_cast<int> (length));
}

// Journal StudioVoix : chaque ligne porte l'horodatage, le niveau, le module et le thread.
// Ne jamais appeler depuis le thread audio temps réel (écriture disque bloquante).
namespace sv::log
{
enum class Level { Debug = 0, Info, Warn, Error };

/** Ouvre le fichier journal (ajout en fin). Peut être appelé plusieurs fois. */
void init (const juce::File& logFile, Level minLevel = Level::Debug, bool alsoStderr = true);

/** Écrit une ligne. Sans init(), écrit seulement sur stderr. */
void write (Level level, const char* module, const juce::String& message);

void setMinLevel (Level level);
juce::File getLogFile();
void shutdown();

const char* levelName (Level level);

/** Mesure de durée : journalise "<what> : X ms" à la destruction. */
class ScopedTimer
{
public:
    ScopedTimer (const char* module, juce::String what);
    ~ScopedTimer();
    double elapsedMs() const;

private:
    const char* module;
    juce::String what;
    double startMs;
};
} // namespace sv::log

#define SV_LOG_DEBUG(module, msg) ::sv::log::write (::sv::log::Level::Debug, module, msg)
#define SV_LOG_INFO(module, msg)  ::sv::log::write (::sv::log::Level::Info,  module, msg)
#define SV_LOG_WARN(module, msg)  ::sv::log::write (::sv::log::Level::Warn,  module, msg)
#define SV_LOG_ERROR(module, msg) ::sv::log::write (::sv::log::Level::Error, module, msg)
