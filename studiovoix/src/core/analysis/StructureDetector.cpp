#include "StructureDetector.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

#include <map>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Structure";
    constexpr double kSr = 12000.0;
    constexpr int kOrder = 12;
    constexpr int kFft = 1 << kOrder;

    struct Feature
    {
        std::array<float, 12> chroma {};
        float energyDb = -120.0f;
        float lowRatio = 0.0f;
        float highRatio = 0.0f;   // brillance (charleston, effets) : distingue couplet et refrain
    };

    float chromaCos (const std::array<float, 12>& a, const std::array<float, 12>& b)
    {
        float num = 0.0f, da = 0.0f, db = 0.0f;
        for (size_t i = 0; i < 12; ++i)
        {
            num += a[i] * b[i];
            da += a[i] * a[i];
            db += b[i] * b[i];
        }
        const float den = std::sqrt (da * db);
        return den > 1.0e-9f ? num / den : 0.0f;
    }

    float distance (const Feature& a, const Feature& b)
    {
        return (1.0f - chromaCos (a.chroma, b.chroma)) * 4.0f
             + std::abs (a.energyDb - b.energyDb) / 3.0f
             + std::abs (a.lowRatio - b.lowRatio) * 2.0f
             + std::abs (a.highRatio - b.highRatio) * 10.0f;
    }

    Feature meanOf (const std::vector<Feature>& fs, int a, int b)
    {
        Feature m;
        double e = 0.0;
        int count = 0;
        for (int i = a; i < b && i < static_cast<int> (fs.size()); ++i)
        {
            for (size_t k = 0; k < 12; ++k)
                m.chroma[k] += fs[static_cast<size_t> (i)].chroma[k];
            e += std::pow (10.0, fs[static_cast<size_t> (i)].energyDb / 10.0);
            m.lowRatio += fs[static_cast<size_t> (i)].lowRatio;
            m.highRatio += fs[static_cast<size_t> (i)].highRatio;
            ++count;
        }
        if (count > 0)
        {
            for (auto& c : m.chroma)
                c /= static_cast<float> (count);
            m.lowRatio /= static_cast<float> (count);
            m.highRatio /= static_cast<float> (count);
            m.energyDb = static_cast<float> (10.0 * std::log10 (std::max (1.0e-12, e / count)));
        }
        return m;
    }
}

std::vector<Section> detectStructure (const Mono& instru, double sampleRate, const TempoInfo& tempo)
{
    log::ScopedTimer timer (kMod, "détection de structure"_u8);
    std::vector<Section> sections;
    const double total = static_cast<double> (instru.size()) / sampleRate;
    const double barSec = tempo.barSec();
    if (instru.empty() || barSec <= 0.0 || total < barSec * 8.0)
    {
        if (total > 0.0)
            sections.push_back ({ 0.0, total, "Morceau", "couplet", 0, -120.0f });
        SV_LOG_INFO (kMod, "instru trop courte pour un découpage : une seule section"_u8);
        return sections;
    }

    const Mono x = audio::resample (instru, sampleRate, kSr);
    juce::dsp::FFT fft (kOrder);
    juce::dsp::WindowingFunction<float> window (static_cast<size_t> (kFft), juce::dsp::WindowingFunction<float>::hann, false);
    std::vector<float> buf (static_cast<size_t> (2 * kFft));

    // Caractéristiques par mesure.
    const double gridStart = std::fmod (tempo.firstBeatSec, barSec);
    std::vector<double> barStarts;
    for (double t = gridStart; t + barSec * 0.5 < total; t += barSec)
        barStarts.push_back (t);

    std::vector<Feature> bars;
    for (double bs : barStarts)
    {
        Feature feat;
        double energy = 0.0, low = 0.0, all = 0.0, high = 0.0;
        int frames = 0;
        const int a = static_cast<int> (bs * kSr);
        const int b = std::min (static_cast<int> (x.size()), static_cast<int> ((bs + barSec) * kSr));
        for (int start = a; start + kFft / 2 < b; start += kFft / 2)
        {
            for (int i = 0; i < kFft; ++i)
            {
                const int idx = start + i;
                buf[static_cast<size_t> (i)] = idx < static_cast<int> (x.size()) ? x[static_cast<size_t> (idx)] : 0.0f;
            }
            std::fill (buf.begin() + kFft, buf.end(), 0.0f);
            energy += audio::rms (buf.data(), static_cast<size_t> (kFft));
            window.multiplyWithWindowingTable (buf.data(), static_cast<size_t> (kFft));
            fft.performFrequencyOnlyForwardTransform (buf.data(), true);
            for (int k = 1; k < kFft / 2; ++k)
            {
                const double f = k * kSr / kFft;
                const double mag = buf[static_cast<size_t> (k)];
                all += mag;
                if (f < 150.0)
                    low += mag;
                if (f > 3000.0)
                    high += mag;
                if (f >= 65.0 && f <= 4000.0)
                {
                    const int pc = ((static_cast<int> (std::lround (69.0 + 12.0 * std::log2 (f / 440.0))) % 12) + 12) % 12;
                    feat.chroma[static_cast<size_t> (pc)] += static_cast<float> (mag);
                }
            }
            ++frames;
        }
        float sum = 0.0f;
        for (auto c : feat.chroma)
            sum += c;
        if (sum > 0.0f)
            for (auto& c : feat.chroma)
                c /= sum;
        feat.energyDb = frames > 0 ? gainToDb (static_cast<float> (energy / frames)) : -120.0f;
        feat.lowRatio = all > 0.0 ? static_cast<float> (low / all) : 0.0f;
        feat.highRatio = all > 0.0 ? static_cast<float> (high / all) : 0.0f;
        bars.push_back (feat);
    }

    // Unités de 4 mesures.
    const int unitBars = 4;
    const int numUnits = static_cast<int> (bars.size()) / unitBars;
    if (numUnits < 2)
    {
        sections.push_back ({ 0.0, total, "Morceau", "couplet", 0, -120.0f });
        return sections;
    }
    std::vector<Feature> units;
    for (int u = 0; u < numUnits; ++u)
        units.push_back (meanOf (bars, u * unitBars, (u + 1) * unitBars));

    std::vector<float> novelty (static_cast<size_t> (numUnits), 0.0f);
    for (int u = 1; u < numUnits; ++u)
        novelty[static_cast<size_t> (u)] = distance (units[static_cast<size_t> (u)], units[static_cast<size_t> (u - 1)]);
    double mean = 0.0, var = 0.0;
    for (int u = 1; u < numUnits; ++u)
        mean += novelty[static_cast<size_t> (u)];
    mean /= std::max (1, numUnits - 1);
    for (int u = 1; u < numUnits; ++u)
        var += std::pow (novelty[static_cast<size_t> (u)] - mean, 2.0);
    const double stdev = std::sqrt (var / std::max (1, numUnits - 1));

    std::vector<int> boundaries { 0 };
    for (int u = 1; u < numUnits; ++u)
    {
        const bool peak = novelty[static_cast<size_t> (u)] > mean + 0.5 * stdev
                          && (u + 1 >= numUnits || novelty[static_cast<size_t> (u)] >= novelty[static_cast<size_t> (u + 1)]);
        if (peak && u - boundaries.back() >= 2)
            boundaries.push_back (u);
    }
    if (boundaries.size() < 2)
    {
        boundaries.clear();
        for (int u = 0; u < numUnits; u += 4)
            boundaries.push_back (u);
    }
    boundaries.push_back (numUnits);

    // Sections + regroupement des sections semblables.
    std::vector<Feature> secFeat;
    for (size_t i = 0; i + 1 < boundaries.size(); ++i)
    {
        Section s;
        const int ua = boundaries[i], ub = boundaries[i + 1];
        s.startSec = i == 0 ? 0.0 : barStarts[static_cast<size_t> (ua * unitBars)];
        s.endSec = (i + 2 == boundaries.size()) ? total : barStarts[static_cast<size_t> (ub * unitBars)];
        const auto f = meanOf (units, ua, ub);
        s.energyDb = f.energyDb;
        secFeat.push_back (f);
        sections.push_back (s);
    }

    // Seuil de regroupement relatif à l'écart maximal entre sections (couplet / refrain proches en absolu
    // sur une instru répétitive, mais nettement plus proches entre sections de même nature).
    float maxPair = 0.0f;
    for (size_t i = 0; i < sections.size(); ++i)
        for (size_t j = i + 1; j < sections.size(); ++j)
            maxPair = std::max (maxPair, distance (secFeat[i], secFeat[j]));
    const float groupThreshold = juce::jlimit (0.08f, 0.6f, 0.4f * maxPair);

    int nextGroup = 0;
    std::vector<int> groupOf (sections.size(), -1);
    for (size_t i = 0; i < sections.size(); ++i)
    {
        if (groupOf[i] >= 0)
            continue;
        groupOf[i] = nextGroup;
        for (size_t j = i + 1; j < sections.size(); ++j)
        {
            const float d = distance (secFeat[i], secFeat[j]);
            SV_LOG_DEBUG (kMod, "distance sections " + juce::String ((int) i) + "-" + juce::String ((int) j) + " : " + juce::String (d, 3));
            if (groupOf[j] < 0 && d < groupThreshold)
                groupOf[j] = nextGroup;
        }
        ++nextGroup;
    }

    std::map<int, int> groupCount;
    std::map<int, double> groupEnergy;
    for (size_t i = 0; i < sections.size(); ++i)
    {
        sections[i].group = groupOf[i];
        groupCount[groupOf[i]]++;
        groupEnergy[groupOf[i]] += sections[i].energyDb;
    }
    int chorusGroup = -1;
    double bestEnergy = -1.0e9;
    for (const auto& [g, c] : groupCount)
    {
        const double e = groupEnergy[g] / c;
        if (c >= 2 && e > bestEnergy)
        {
            bestEnergy = e;
            chorusGroup = g;
        }
    }

    std::vector<float> energies;
    for (const auto& s : sections)
        energies.push_back (s.energyDb);
    std::sort (energies.begin(), energies.end());
    const float median = energies[energies.size() / 2];

    int verseNum = 0, chorusNum = 0, bridgeNum = 0;
    for (size_t i = 0; i < sections.size(); ++i)
    {
        auto& s = sections[i];
        if (i == 0 && s.energyDb < median - 3.0f && sections.size() > 2)
        {
            s.kind = "intro";
            s.label = "Intro";
        }
        else if (i + 1 == sections.size() && s.energyDb < median - 3.0f && sections.size() > 2)
        {
            s.kind = "outro";
            s.label = "Outro";
        }
        else if (s.group == chorusGroup)
        {
            s.kind = "refrain";
            s.label = "Refrain " + juce::String (++chorusNum);
        }
        else if (groupCount[s.group] == 1 && chorusGroup >= 0 && verseNum > 0)
        {
            s.kind = "pont";
            s.label = "Pont " + juce::String (++bridgeNum);
        }
        else
        {
            s.kind = "couplet";
            s.label = "Couplet " + juce::String (++verseNum);
        }
    }

    juce::StringArray summary;
    for (const auto& s : sections)
        summary.add (s.label + " [" + juce::String (s.startSec, 1) + "-" + juce::String (s.endSec, 1) + "]");
    SV_LOG_INFO (kMod, "Structure (approximative) : " + summary.joinIntoString (", "));
    return sections;
}
} // namespace sv::analysis
