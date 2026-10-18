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
    std::array<double, 12> early {};  // accords du début (130 Hz - 2 kHz) : indice de tonique
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

        std::array<double, 12> chroma {}, earlyChroma {};
        double total = 0.0, earlyTotal = 0.0;
        for (int k = 1; k < kFft / 2; ++k)
        {
            const int pc = binPc[static_cast<size_t> (k)];
            if (pc < 0)
                continue;
            const double mag = buf[static_cast<size_t> (k)];
            chroma[static_cast<size_t> (pc)] += mag;
            total += mag;
            const double f = k * kSr / kFft;
            if (f >= 130.0 && f <= 2000.0)
            {
                earlyChroma[static_cast<size_t> (pc)] += mag;
                earlyTotal += mag;
            }
        }
        if (total < 1.0e-6)
            continue;   // trame silencieuse
        const bool isEarly = start < std::max (kHop, n / 8);
        for (int i = 0; i < 12; ++i)
        {
            acc[static_cast<size_t> (i)] += chroma[static_cast<size_t> (i)] / total;
            if (isEarly && earlyTotal > 1.0e-6)
                early[static_cast<size_t> (i)] += earlyChroma[static_cast<size_t> (i)] / earlyTotal;
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

    // Ambiguïté relatif majeur / mineur (mêmes notes, ex. Do majeur / La mineur) : on compare l'accord de
    // tonique de chaque candidat dans les premières secondes (un morceau démarre en général sur sa tonique).
    // À égalité, le mineur l'emporte (fréquent en rap / trap).
    {
        const int relRoot = result.key.minor ? (result.key.root + 3) % 12 : (result.key.root + 9) % 12;
        const int relIdx = result.key.minor ? relRoot : 12 + relRoot;
        const float relScore = result.scores[static_cast<size_t> (relIdx)];
        if (best - relScore < 0.30f)
        {
            auto triad = [&] (int root, bool minor)
            {
                return early[static_cast<size_t> (root % 12)] + early[static_cast<size_t> ((root + (minor ? 3 : 4)) % 12)]
                     + early[static_cast<size_t> ((root + 7) % 12)];
            };
            const double here = triad (result.key.root, result.key.minor);
            const double rel = triad (relRoot, ! result.key.minor);
            const double margin = 0.05 * std::max (here, rel);
            bool switchToRelative = rel > here + margin;
            if (std::abs (rel - here) <= margin)
                switchToRelative = ! result.key.minor;   // préférence mineure
            SV_LOG_DEBUG (kMod, "Accord de tonique au début : "_u8 + result.key.toFrench() + " " + juce::String (here, 3)
                                + ", relatif " + juce::String (rel, 3));
            if (switchToRelative)
            {
                result.key.root = relRoot;
                result.key.minor = ! result.key.minor;
                // Choix départagé par l'accord de début : confiance modérée.
                second = relScore - 0.1f * static_cast<float> ((rel - here) / std::max (1.0e-9, std::max (here, rel)));
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
