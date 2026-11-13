#include "Lyrics.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "LocalTools.h"

#include <algorithm>

namespace sv::ai::local
{
namespace
{
    constexpr const char* kMod = "ParolesIA";
}

std::vector<LyricWord> parseWhisperJson (const juce::String& json, double offsetSec)
{
    std::vector<LyricWord> words;
    juce::var v;
    if (juce::JSON::parse (json, v).failed() || ! v.isObject())
    {
        SV_LOG_WARN (kMod, "Sortie whisper illisible");
        return words;
    }
    const auto* segs = v.getProperty ("transcription", {}).getArray();
    if (segs == nullptr)
        return words;
    for (const auto& s : *segs)
    {
        const auto text = s.getProperty ("text", {}).toString().trim();
        if (text.isEmpty() || text.startsWith ("[") || text.startsWith ("("))   // [Musique], (rires)…
            continue;
        const auto off = s.getProperty ("offsets", {});
        const double from = static_cast<double> (off.getProperty ("from", 0)) / 1000.0;
        const double to = static_cast<double> (off.getProperty ("to", 0)) / 1000.0;
        if (to < from)
            continue;
        LyricWord w;
        w.text = text;
        w.startSec = offsetSec + from;
        w.endSec = offsetSec + std::max (to, from + 0.05);
        words.push_back (w);
    }
    std::stable_sort (words.begin(), words.end(), [] (const LyricWord& a, const LyricWord& b) { return a.startSec < b.startSec; });
    return words;
}

juce::String wordsToLyrics (const std::vector<LyricWord>& words, double gapSec)
{
    juce::String out;
    double lastEnd = -1.0;
    for (const auto& w : words)
    {
        if (out.isNotEmpty())
            out << (lastEnd >= 0.0 && w.startSec - lastEnd > gapSec ? "\n" : " ");
        out << w.text;
        lastEnd = w.endSec;
    }
    return out;
}

bool whisperAvailable()
{
    const auto* cli = findTool ("whisper-cli");
    const auto* model = findTool ("whisper-base");
    return cli != nullptr && model != nullptr && isInstalled (*cli) && isInstalled (*model);
}

std::vector<LyricWord> transcribeWithWhisper (const Mono& audio, double sampleRate, const juce::File& workDir, double offsetSec,
                                              juce::String& error, double& seconds)
{
    seconds = 0.0;
    const auto* cli = findTool ("whisper-cli");
    const auto* model = findTool ("whisper-base");
    if (cli == nullptr || model == nullptr || ! isInstalled (*cli) || ! isInstalled (*model))
    {
        error = "whisper-cli ou le modèle Whisper base n'est pas installé (onglet IA locale)"_u8;
        SV_LOG_WARN (kMod, error);
        return {};
    }
    if (audio.size() < static_cast<size_t> (sampleRate * 0.5))
    {
        error = "Voix trop courte pour être reconnue"_u8;
        return {};
    }
    if (! workDir.createDirectory())
    {
        error = "Dossier de travail impossible : "_u8 + workDir.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return {};
    }
    // whisper-cli lit un WAV 16 kHz, 16 bits, mono.
    const auto wav = workDir.getChildFile ("paroles_entree.wav");
    const Mono at16k = std::abs (sampleRate - 16000.0) < 1.0 ? audio : audio::resample (audio, sampleRate, 16000.0);
    if (! audio::writeMonoWav16 (wav, at16k, 16000.0, error))
    {
        SV_LOG_ERROR (kMod, "Écriture du WAV 16 kHz : "_u8 + error);
        return {};
    }
    const auto prefix = workDir.getChildFile ("paroles_sortie");
    const auto jsonFile = workDir.getChildFile ("paroles_sortie.json");
    jsonFile.deleteFile();
    const double durationSec = static_cast<double> (audio.size()) / sampleRate;
    const int timeoutMs = 120000 + static_cast<int> (durationSec * 4000.0);   // 2 min + 4 s par seconde de voix (CPU)
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    juce::String output;
    int code = -1;
    const bool ran = run (*cli, { "-m", toolFile (*model).getFullPathName(), "-f", wav.getFullPathName(), "-l", "auto", "-ml", "1", "-sow",
                                  "-oj", "-of", prefix.getFullPathName(), "-np" },
                          output, code, timeoutMs);
    seconds = (juce::Time::getMillisecondCounterHiRes() - t0) / 1000.0;
    wav.deleteFile();
    if (! ran || code != 0 || ! jsonFile.existsAsFile())
    {
        error = "whisper-cli a échoué (code "_u8 + juce::String (code) + ") : " + output.trim().substring (0, 300);
        SV_LOG_ERROR (kMod, error);
        return {};
    }
    auto words = parseWhisperJson (jsonFile.loadFileAsString(), offsetSec);
    SV_LOG_INFO (kMod, juce::String (static_cast<int> (words.size())) + " mot(s) reconnu(s) en " + juce::String (seconds, 1) + " s ("
                       + juce::String (durationSec, 1) + " s de voix)");
    if (words.empty())
        error = "Aucun mot reconnu (voix trop faible ou bruit)"_u8;
    return words;
}
} // namespace sv::ai::local
