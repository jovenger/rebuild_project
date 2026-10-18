#include "BeatLibrary.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../Loudness.h"
#include "KeyDetector.h"
#include "TempoDetector.h"

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "BeatLibrary";
    constexpr double kAnalysisSr = 12000.0;   // suffisant pour tempo / tonalité / énergie, et rapide
}

BeatInfo BeatLibrary::analyse (const juce::File& file, juce::String& error)
{
    BeatInfo b;
    b.path = file.getFullPathName();
    b.modifiedMs = file.getLastModificationTime().toMilliseconds();
    auto loaded = audio::loadStereo (file, kAnalysisSr, 900.0);
    if (! loaded.ok())
    {
        error = loaded.error;
        return b;
    }
    const auto mono = audio::toMono (loaded.buffer);
    b.durationSec = static_cast<double> (mono.size()) / kAnalysisSr;
    b.key = detectKey (mono, kAnalysisSr).key;
    b.bpm = detectTempo (mono, kAnalysisSr).bpm;

    // Énergie : sonie + densité d'attaques.
    const double lufs = loudness::integratedLufs (loaded.buffer, kAnalysisSr);
    const auto env = computeOnsetEnvelope (mono, kAnalysisSr);
    double mean = 0.0;
    for (float v : env.full)
        mean += v;
    mean /= std::max<size_t> (1, env.full.size());
    int peaks = 0;
    for (size_t i = 1; i + 1 < env.full.size(); ++i)
        if (env.full[i] > 2.0 * mean && env.full[i] >= env.full[i - 1] && env.full[i] > env.full[i + 1])
            ++peaks;
    const double onsetRate = peaks / std::max (1.0, b.durationSec);
    b.energy = static_cast<float> (0.6 * juce::jlimit (0.0, 1.0, (lufs + 24.0) / 14.0) + 0.4 * juce::jlimit (0.0, 1.0, onsetRate / 8.0));
    return b;
}

bool BeatLibrary::loadCache (const juce::File& folder)
{
    beats.clear();
    const auto f = cacheFileFor (folder);
    if (! f.existsAsFile())
        return false;
    juce::var v;
    if (juce::JSON::parse (f.loadFileAsString(), v).failed())
    {
        SV_LOG_WARN (kMod, "Cache de bibliothèque illisible, nouvelle analyse"_u8);
        return false;
    }
    if (const auto* arr = v.getArray())
        for (const auto& e : *arr)
        {
            BeatInfo b;
            b.path = e.getProperty ("path", {}).toString();
            b.bpm = static_cast<double> (e.getProperty ("bpm", 0.0));
            b.key.root = juce::jlimit (0, 11, static_cast<int> (e.getProperty ("root", 9)));
            b.key.minor = static_cast<bool> (e.getProperty ("minor", true));
            b.energy = static_cast<float> (static_cast<double> (e.getProperty ("energy", 0.5)));
            b.durationSec = static_cast<double> (e.getProperty ("duration", 0.0));
            b.modifiedMs = static_cast<juce::int64> (static_cast<double> (e.getProperty ("modified", 0.0)));
            if (b.path.isNotEmpty())
                beats.push_back (b);
        }
    return true;
}

bool BeatLibrary::saveCache (const juce::File& folder) const
{
    juce::Array<juce::var> arr;
    for (const auto& b : beats)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("path", b.path);
        o->setProperty ("bpm", b.bpm);
        o->setProperty ("root", b.key.root);
        o->setProperty ("minor", b.key.minor);
        o->setProperty ("energy", b.energy);
        o->setProperty ("duration", b.durationSec);
        o->setProperty ("modified", static_cast<double> (b.modifiedMs));
        arr.add (juce::var (o));
    }
    const bool ok = cacheFileFor (folder).replaceWithText (juce::JSON::toString (arr, false));
    if (! ok)
        SV_LOG_WARN (kMod, "Cache non écrit dans "_u8 + folder.getFullPathName());
    return ok;
}

int BeatLibrary::scan (const juce::File& folder, const ProgressFn& progress)
{
    log::ScopedTimer timer (kMod, "analyse du dossier de beats");
    if (! folder.isDirectory())
        return 0;
    loadCache (folder);
    std::map<juce::String, BeatInfo> known;
    for (const auto& b : beats)
        known[b.path] = b;

    const auto files = folder.findChildFiles (juce::File::findFiles, true, "*.wav;*.mp3;*.flac;*.aif;*.aiff;*.ogg");
    std::vector<BeatInfo> result;
    int analysed = 0;
    for (int i = 0; i < files.size(); ++i)
    {
        const auto& f = files.getReference (i);
        const auto it = known.find (f.getFullPathName());
        if (it != known.end() && it->second.modifiedMs == f.getLastModificationTime().toMilliseconds())
        {
            result.push_back (it->second);
        }
        else
        {
            juce::String err;
            auto b = analyse (f, err);
            if (err.isEmpty())
            {
                result.push_back (b);
                ++analysed;
            }
            else
            {
                SV_LOG_WARN (kMod, "Beat ignoré (" + f.getFileName() + ") : " + err);
            }
        }
        if (progress && ! progress (static_cast<float> (i + 1) / static_cast<float> (files.size())))
            break;
    }
    beats = std::move (result);
    saveCache (folder);
    SV_LOG_INFO (kMod, juce::String ((int) beats.size()) + " beats dans la bibliothèque (" + juce::String (analysed) + " nouvellement analysés)");
    return analysed;
}

std::vector<std::pair<float, BeatInfo>> BeatLibrary::rank (const BeatCriteria& c) const
{
    std::vector<std::pair<float, BeatInfo>> out;
    const double target = 0.5 * (c.bpmMin + c.bpmMax);
    for (const auto& b : beats)
    {
        // Tempo : tolère le double / la moitié (même ressenti rythmique).
        double bpm = b.bpm;
        double best = 1.0e9;
        for (double f : { 0.5, 1.0, 2.0 })
            best = std::min (best, std::abs (bpm * f - target));
        const bool inRange = (b.bpm >= c.bpmMin && b.bpm <= c.bpmMax) || (b.bpm * 2 >= c.bpmMin && b.bpm * 2 <= c.bpmMax)
                             || (b.bpm / 2 >= c.bpmMin && b.bpm / 2 <= c.bpmMax);
        const float tempoScore = inRange ? 1.0f : static_cast<float> (std::max (0.0, 1.0 - best / 30.0));
        const float energyScore = 1.0f - std::abs (b.energy - c.energy);
        const float modeScore = ! c.useMode || b.key.minor == c.minor ? 1.0f : 0.6f;
        out.push_back ({ tempoScore * 0.5f + energyScore * 0.35f + modeScore * 0.15f, b });
    }
    std::sort (out.begin(), out.end(), [] (const auto& a, const auto& b) { return a.first > b.first; });
    return out;
}
} // namespace sv::analysis
