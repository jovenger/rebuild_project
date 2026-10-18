#include "KeyDetector.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

namespace sv
{
juce::String MusicalKey::toFrench() const
{
    return analysis::pitchClassName (root) + (minor ? " mineur" : " majeur");
}

std::array<int, 7> MusicalKey::scale() const
{
    static constexpr std::array<int, 7> majorSteps { 0, 2, 4, 5, 7, 9, 11 };
    static constexpr std::array<int, 7> minorSteps { 0, 2, 3, 5, 7, 8, 10 };
    std::array<int, 7> out {};
    const auto& steps = minor ? minorSteps : majorSteps;
    for (size_t i = 0; i < 7; ++i)
        out[i] = (root + steps[i]) % 12;
    return out;
}

bool MusicalKey::contains (int pitchClass) const
{
    const int pc = ((pitchClass % 12) + 12) % 12;
    for (int s : scale())
        if (s == pc)
            return true;
    return false;
}
} // namespace sv

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Key";
    constexpr double kSr = 12000.0;
    constexpr int kOrder = 13;   // FFT 8192
    constexpr int kFft = 1 << kOrder;
    constexpr int kHop = 2048;

    constexpr std::array<float, 12> kMajor { 6.35f, 2.23f, 3.48f, 2.33f, 4.38f, 4.09f, 2.52f, 5.19f, 2.39f, 3.66f, 2.29f, 2.88f };
    constexpr std::array<float, 12> kMinor { 6.33f, 2.68f, 3.52f, 5.38f, 2.60f, 3.53f, 2.54f, 4.75f, 3.98f, 2.69f, 3.34f, 3.17f };

    float pearson (const std::array<float, 12>& a, const std::array<float, 12>& profile, int rotation)
    {
        float ma = 0.0f, mb = 0.0f;
        for (int i = 0; i < 12; ++i)
        {
            ma += a[static_cast<size_t> (i)];
            mb += profile[static_cast<size_t> (i)];
        }
        ma /= 12.0f;
        mb /= 12.0f;
        float num = 0.0f, da = 0.0f, db = 0.0f;
        for (int i = 0; i < 12; ++i)
        {
            const float x = a[static_cast<size_t> ((i + rotation) % 12)] - ma;
            const float y = profile[static_cast<size_t> (i)] - mb;
            num += x * y;
            da += x * x;
            db += y * y;
        }
        const float den = std::sqrt (da * db);
        return den > 1.0e-12f ? num / den : 0.0f;
    }
}

juce::String pitchClassName (int pc)
{
    static const char* names[12] = { "Do", "Do#", "Ré", "Mib", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "Sib", "Si" };
    return juce::String (juce::CharPointer_UTF8 (names[((pc % 12) + 12) % 12]));
}

KeyResult detectKey (const Mono& signal, double sampleRate)
{
    log::ScopedTimer timer (kMod, "détection de tonalité"_u8);
    KeyResult result;
    if (signal.empty())
        return result;

    const Mono x = audio::resample (signal, sampleRate, kSr);
    juce::dsp::FFT fft (kOrder);
    juce::dsp::WindowingFunction<float> window (static_cast<size_t> (kFft), juce::dsp::WindowingFunction<float>::hann, false);
    std::vector<float> buf (static_cast<size_t> (2 * kFft), 0.0f);

    // Table bin -> classe de hauteur (55 Hz à 5 kHz).
    std::vector<int> binPc (static_cast<size_t> (kFft / 2), -1);
    for (int k = 1; k < kFft / 2; ++k)
    {
        const double f = k * kSr / kFft;
        if (f < 55.0 || f > 5000.0)
            continue;
        const double midi = 69.0 + 12.0 * std::log2 (f / 440.0);
        binPc[static_cast<size_t> (k)] = ((static_cast<int> (std::lround (midi)) % 12) + 12) % 12;
    }

    std::array<double, 12> acc {};
    std::array<double, 12> bass {};   // basse (55-250 Hz), début du morceau pondéré x3 : indice de tonique
    int frames = 0;
    const int n = static_cast<int> (x.size());
    for (int start = 0; start + kFft <= std::max (n, kFft); start += kHop)
    {
        std::fill (buf.begin(), buf.end(), 0.0f);
        for (int i = 0; i < kFft; ++i)
        {
            const int idx = start + i;
            buf[static_cast<size_t> (i)] = idx < n ? x[static_cast<size_t> (idx)] : 0.0f;
        }
        window.multiplyWithWindowingTable (buf.data(), static_cast<size_t> (kFft));
        fft.performFrequencyOnlyForwardTransform (buf.data(), true);

        std::array<double, 12> chroma {}, bassChroma {};
        double total = 0.0, bassTotal = 0.0;
        for (int k = 1; k < kFft / 2; ++k)
        {
            const int pc = binPc[static_cast<size_t> (k)];
            if (pc < 0)
                continue;
            const double mag = buf[static_cast<size_t> (k)];
            chroma[static_cast<size_t> (pc)] += mag;
            total += mag;
            if (k * kSr / kFft < 250.0)
            {
                bassChroma[static_cast<size_t> (pc)] += mag;
                bassTotal += mag;
            }
        }
        if (total < 1.0e-6)
            continue;   // trame silencieuse
        const double earlyWeight = start < n / 10 ? 3.0 : 1.0;
        for (int i = 0; i < 12; ++i)
        {
            acc[static_cast<size_t> (i)] += chroma[static_cast<size_t> (i)] / total;
            if (bassTotal > 1.0e-6)
                bass[static_cast<size_t> (i)] += earlyWeight * bassChroma[static_cast<size_t> (i)] / bassTotal;
        }
        ++frames;
        if (start + kFft >= n)
            break;
    }

    if (frames == 0)
    {
        SV_LOG_WARN (kMod, "signal silencieux : tonalité par défaut"_u8);
        return result;
    }

    for (int i = 0; i < 12; ++i)
        result.chroma[static_cast<size_t> (i)] = static_cast<float> (acc[static_cast<size_t> (i)] / frames);

    float best = -2.0f, second = -2.0f;
    int bestIdx = 0;
    for (int r = 0; r < 12; ++r)
    {
        const float sMaj = pearson (result.chroma, kMajor, r);
        const float sMin = pearson (result.chroma, kMinor, r);
        result.scores[static_cast<size_t> (r)] = sMaj;
        result.scores[static_cast<size_t> (12 + r)] = sMin;
    }
    for (int i = 0; i < 24; ++i)
    {
        const float s = result.scores[static_cast<size_t> (i)];
        if (s > best)
        {
            second = best;
            best = s;
            bestIdx = i;
        }
        else if (s > second)
        {
            second = s;
        }
    }

    result.key.root = bestIdx % 12;
    result.key.minor = bestIdx >= 12;

    // Ambiguïté relatif majeur / mineur (mêmes notes, ex. Do majeur / La mineur) : la tonique est celle
    // que la basse appuie le plus (surtout au début). À égalité, le mineur l'emporte (fréquent en rap / trap).
    {
        const int relRoot = result.key.minor ? (result.key.root + 3) % 12 : (result.key.root + 9) % 12;
        const int relIdx = result.key.minor ? relRoot : 12 + relRoot;
        const float relScore = result.scores[static_cast<size_t> (relIdx)];
        if (best - relScore < 0.12f)
        {
            const double bassHere = bass[static_cast<size_t> (result.key.root)];
            const double bassRel = bass[static_cast<size_t> (relRoot)];
            const double margin = 0.08 * std::max (bassHere, bassRel);
            bool switchToRelative = bassRel > bassHere + margin;
            if (std::abs (bassRel - bassHere) <= margin)
                switchToRelative = ! result.key.minor;   // préférence mineure
            if (switchToRelative)
            {
                SV_LOG_DEBUG (kMod, "Relatif retenu (basse " + juce::String (bassRel, 2) + " contre " + juce::String (bassHere, 2) + ")");
                result.key.root = relRoot;
                result.key.minor = ! result.key.minor;
                second = best;
                best = relScore;
            }
        }
    }
    result.key.confidence = juce::jlimit (0.0f, 1.0f, (best - second) * 4.0f + 0.25f * best);

    SV_LOG_INFO (kMod, "Tonalité détectée : "_u8 + result.key.toFrench() + " (score " + juce::String (best, 3)
                       + ", confiance " + juce::String (result.key.confidence, 2) + ", " + juce::String (frames) + " trames)");
    return result;
}
} // namespace sv::analysis
