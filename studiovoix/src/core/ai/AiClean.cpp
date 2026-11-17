#include "AiClean.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "LocalTools.h"

#include <juce_cryptography/juce_cryptography.h>

namespace sv::ai::local
{
namespace
{
    constexpr const char* kMod = "NettoyageIA";
}

juce::String aiCleanKey (const Mono& audio, double sampleRate)
{
    juce::MemoryOutputStream m;
    m.writeDouble (sampleRate);
    m.writeInt (static_cast<int> (audio.size()));
    if (! audio.empty())
        m.write (audio.data(), audio.size() * sizeof (float));
    return juce::SHA256 (m.getData(), m.getDataSize()).toHexString().substring (0, 16);
}

bool deepFilterAvailable()
{
    const auto* t = findTool ("deep-filter");
    return t != nullptr && isInstalled (*t);
}

AiCleanResult cleanWithDeepFilter (Mono& audio, double sampleRate, const juce::File& cacheDir)
{
    AiCleanResult res;
    const auto* tool = findTool ("deep-filter");
    if (tool == nullptr || ! isInstalled (*tool))
    {
        res.note = "Nettoyage IA : DeepFilterNet non installé (onglet IA locale)"_u8;
        return res;
    }
    if (audio.empty())
    {
        res.note = "Nettoyage IA : prise vide"_u8;
        return res;
    }
    if (std::abs (sampleRate - 48000.0) > 1.0)
    {
        res.note = "Nettoyage IA : l'outil exige 48 kHz (projet à "_u8 + juce::String (sampleRate, 0) + " Hz)";
        SV_LOG_WARN (kMod, res.note);
        return res;
    }
    const auto key = aiCleanKey (audio, sampleRate);
    const auto outFile = cacheDir.getChildFile ("ia_nettoyage_" + key + ".wav");
    juce::String err;
    Mono cleaned;
    if (outFile.existsAsFile() && audio::loadMono (outFile, sampleRate, cleaned, err) && ! cleaned.empty())
    {
        cleaned.resize (audio.size(), 0.0f);
        audio = std::move (cleaned);
        res.applied = true;
        res.fromCache = true;
        res.note = "Nettoyage IA : DeepFilterNet (déjà calculé)"_u8;
        SV_LOG_INFO (kMod, res.note + " " + key);
        return res;
    }
    // L'outil écrit <dossier de sortie>/<nom du fichier d'entrée> : l'entrée porte déjà le nom final, dans un sous-dossier.
    const auto inDir = cacheDir.getChildFile ("entree");
    if (! inDir.createDirectory())
    {
        res.note = "Nettoyage IA : dossier de cache impossible ("_u8 + inDir.getFullPathName() + ")";
        SV_LOG_ERROR (kMod, res.note);
        return res;
    }
    const auto inFile = inDir.getChildFile (outFile.getFileName());
    if (! audio::writeMonoWavFloat (inFile, audio, sampleRate, err))
    {
        res.note = "Nettoyage IA : écriture impossible : "_u8 + err;
        SV_LOG_ERROR (kMod, res.note);
        return res;
    }
    const double durationSec = static_cast<double> (audio.size()) / sampleRate;
    const int timeoutMs = 60000 + static_cast<int> (durationSec * 2000.0);   // 1 min + 2 s par seconde d'audio
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    juce::String output;
    int code = -1;
    const bool ran = run (*tool, { "-o", cacheDir.getFullPathName(), inFile.getFullPathName() }, output, code, timeoutMs);
    res.seconds = (juce::Time::getMillisecondCounterHiRes() - t0) / 1000.0;
    inFile.deleteFile();
    if (! ran || code != 0 || ! outFile.existsAsFile())
    {
        res.note = "Nettoyage IA : échec de deep-filter (code "_u8 + juce::String (code) + ") : " + output.trim().substring (0, 200);
        SV_LOG_ERROR (kMod, res.note);
        outFile.deleteFile();
        return res;
    }
    if (! audio::loadMono (outFile, sampleRate, cleaned, err) || cleaned.empty())
    {
        res.note = "Nettoyage IA : sortie illisible : "_u8 + err;
        SV_LOG_ERROR (kMod, res.note);
        outFile.deleteFile();
        return res;
    }
    // Même longueur que l'entrée (l'outil peut ajouter ou retirer quelques échantillons en bout).
    cleaned.resize (audio.size(), 0.0f);
    // Garde-fou : une sortie quasi muette ou avec des valeurs non finies est refusée.
    if (audio::hasNonFinite (cleaned.data(), cleaned.size()))
    {
        res.note = "Nettoyage IA : sortie invalide (valeurs non finies), ignorée"_u8;
        SV_LOG_ERROR (kMod, res.note);
        outFile.deleteFile();
        return res;
    }
    double inRms = 0.0, outRms = 0.0;
    for (size_t i = 0; i < audio.size(); ++i)
    {
        inRms += static_cast<double> (audio[i]) * audio[i];
        outRms += static_cast<double> (cleaned[i]) * cleaned[i];
    }
    if (inRms > 0.0 && outRms < inRms * 1e-4)
    {
        res.note = "Nettoyage IA : sortie quasi muette (-40 dB), ignorée"_u8;
        SV_LOG_WARN (kMod, res.note);
        outFile.deleteFile();
        return res;
    }
    audio = std::move (cleaned);
    res.applied = true;
    res.note = "Nettoyage IA : DeepFilterNet appliqué ("_u8 + juce::String (res.seconds, 1) + " s)";
    SV_LOG_INFO (kMod, res.note + " clé " + key + ", niveau " + juce::String (10.0 * std::log10 (std::max (1e-12, outRms / std::max (1e-12, inRms))), 1) + " dB");
    return res;
}
} // namespace sv::ai::local
