#include "Separate.h"

#include "LocalTools.h"
#include "../AudioIO.h"
#include "../Log.h"

namespace sv::ai::local
{
namespace
{
    constexpr const char* kMod = "SeparationIA";
    constexpr double kDemucsRate = 44100.0;   // demucs.cpp attend du 44,1 kHz stéréo
    constexpr const char* kNames[4] = { "target_0_drums.wav", "target_1_bass.wav", "target_2_other.wav", "target_3_vocals.wav" };
}

bool demucsAvailable()
{
    const auto* exe = findTool ("demucs");
    const auto* model = findTool ("demucs-htdemucs");
    return exe != nullptr && model != nullptr && isInstalled (*exe) && isInstalled (*model);
}

bool readDemucsOutputs (const juce::File& outDir, double sampleRate, StemSet& out, juce::String& error)
{
    Mono* targets[4] = { &out.drums, &out.bass, &out.other, &out.vocals };
    for (int i = 0; i < 4; ++i)
    {
        const auto f = outDir.getChildFile (kNames[i]);
        if (! f.existsAsFile())
        {
            error = "fichier manquant : " + f.getFileName();
            return false;
        }
        juce::String err;
        if (! audio::loadMono (f, sampleRate, *targets[i], err))
        {
            error = f.getFileName() + " : " + err;
            return false;
        }
    }
    return true;
}

StemSet separateWithDemucs (const Stereo& mix, double sampleRate, const juce::File& workDir)
{
    StemSet res;
    const auto* exe = findTool ("demucs");
    const auto* model = findTool ("demucs-htdemucs");
    if (exe == nullptr || model == nullptr || ! isInstalled (*exe) || ! isInstalled (*model))
    {
        res.note = "Demucs ou son modèle n'est pas installé (onglet IA locale)"_u8;
        SV_LOG_WARN (kMod, res.note);
        return res;
    }
    if (mix.getNumSamples() < static_cast<int> (sampleRate))
    {
        res.note = "Instru trop courte pour être séparée"_u8;
        return res;
    }
    if (! workDir.createDirectory())
    {
        res.note = "Dossier de travail impossible : "_u8 + workDir.getFullPathName();
        SV_LOG_ERROR (kMod, res.note);
        return res;
    }
    const auto in = workDir.getChildFile ("separation_entree.wav");
    const auto outDir = workDir.getChildFile ("separation_sortie");
    outDir.deleteRecursively();
    outDir.createDirectory();
    juce::String err;
    const Stereo at44 = std::abs (sampleRate - kDemucsRate) < 1.0 ? mix : audio::resample (mix, sampleRate, kDemucsRate);
    if (! audio::writeFile (in, at44, kDemucsRate, audio::FileFormat::Wav16, err))
    {
        res.note = "Écriture du WAV 44,1 kHz : "_u8 + err;
        SV_LOG_ERROR (kMod, res.note);
        return res;
    }
    const double durationSec = static_cast<double> (mix.getNumSamples()) / sampleRate;
    const int timeoutMs = 15 * 60 * 1000 + static_cast<int> (durationSec * 6000.0);
    SV_LOG_INFO (kMod, "Séparation Demucs : "_u8 + juce::String (durationSec, 1) + " s d'audio, délai max " + juce::String (timeoutMs / 1000) + " s");
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    juce::String output;
    int code = -1;
    // demucs_mt <modèle> <entrée.wav> <dossier de sortie> <nombre de fils>  → target_0_drums.wav … target_3_vocals.wav
    const int threads = juce::jlimit (1, 8, juce::SystemStats::getNumCpus());
    SV_LOG_INFO (kMod, "demucs_mt sur "_u8 + juce::String (threads) + " fil(s)");
    const bool ran = run (*exe, { toolFile (*model).getFullPathName(), in.getFullPathName(), outDir.getFullPathName() + juce::File::getSeparatorString(),
                                  juce::String (threads) },
                          output, code, timeoutMs);
    res.seconds = (juce::Time::getMillisecondCounterHiRes() - t0) / 1000.0;
    in.deleteFile();
    if (! ran || code != 0)
    {
        res.note = "Demucs a échoué (code "_u8 + juce::String (code) + ") : " + output.trim().fromLastOccurrenceOf ("\n", false, false).substring (0, 300);
        SV_LOG_ERROR (kMod, res.note + " | sortie : " + output.trim().substring (0, 1500));
        return res;
    }
    if (! readDemucsOutputs (outDir, sampleRate, res, err))
    {
        res.note = "Sortie de Demucs illisible : "_u8 + err;
        SV_LOG_ERROR (kMod, res.note + " | " + output.trim().substring (0, 800));
        return res;
    }
    outDir.deleteRecursively();
    res.ok = true;
    res.note = "4 parties séparées en "_u8 + juce::String (res.seconds, 1) + " s";
    SV_LOG_INFO (kMod, res.note + " (" + juce::String (durationSec, 1) + " s d'audio)");
    return res;
}
} // namespace sv::ai::local
