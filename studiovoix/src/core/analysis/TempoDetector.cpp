#include "TempoDetector.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Tempo";
    constexpr double kSr = 12000.0;
    constexpr int kOrder = 9;     // FFT 512
    constexpr int kFft = 1 << kOrder;
    constexpr int kHop = 128;

    float interpAt (const std::vector<float>& v, double pos)
    {
        const int i = static_cast<int> (std::floor (pos));
        if (i < 0 || i + 1 >= static_cast<int> (v.size()))
            return 0.0f;
        const float f = static_cast<float> (pos - i);
        return v[static_cast<size_t> (i)] * (1.0f - f) + v[static_cast<size_t> (i + 1)] * f;
    }
}

OnsetEnvelope computeOnsetEnvelope (const Mono& signal, double sampleRate)
{
    OnsetEnvelope env;
    env.frameRate = kSr / kHop;
    if (signal.empty())
        return env;

    const Mono x = audio::resample (signal, sampleRate, kSr);
    const int n = static_cast<int> (x.size());
    juce::dsp::FFT fft (kOrder);
    juce::dsp::WindowingFunction<float> window (static_cast<size_t> (kFft), juce::dsp::WindowingFunction<float>::hann, false);
    std::vector<float> buf (static_cast<size_t> (2 * kFft));
    std::vector<float> prev (static_cast<size_t> (kFft / 2), 0.0f);
    const int lowBins = static_cast<int> (150.0 * kFft / kSr);

    for (int start = 0; start < n; start += kHop)
    {
        std::fill (buf.begin(), buf.end(), 0.0f);
        for (int i = 0; i < kFft; ++i)
        {
            const int idx = start + i - kFft / 2;
            buf[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[static_cast<size_t> (idx)] : 0.0f;
        }
        window.multiplyWithWindowingTable (buf.data(), static_cast<size_t> (kFft));
        fft.performFrequencyOnlyForwardTransform (buf.data(), true);

        float flux = 0.0f, fluxLow = 0.0f;
        for (int k = 1; k < kFft / 2; ++k)
        {
            const float m = std::log1p (1000.0f * buf[static_cast<size_t> (k)]);
            const float diff = m - prev[static_cast<size_t> (k)];
            prev[static_cast<size_t> (k)] = m;
            if (diff > 0.0f)
            {
                flux += diff;
                if (k <= lowBins)
                    fluxLow += diff;
            }
        }
        env.full.push_back (flux);
        env.low.push_back (fluxLow);
    }

    // Retrait de la moyenne locale (0,5 s) et redressement.
    auto detrend = [&] (std::vector<float>& v)
    {
        const int w = std::max (1, static_cast<int> (env.frameRate * 0.25));
        std::vector<float> out (v.size(), 0.0f);
        double sum = 0.0;
        const int len = static_cast<int> (v.size());
        std::vector<double> prefix (static_cast<size_t> (len + 1), 0.0);
        for (int i = 0; i < len; ++i)
            prefix[static_cast<size_t> (i + 1)] = prefix[static_cast<size_t> (i)] + v[static_cast<size_t> (i)];
        for (int i = 0; i < len; ++i)
        {
            const int a = std::max (0, i - w), b = std::min (len, i + w + 1);
            sum = (prefix[static_cast<size_t> (b)] - prefix[static_cast<size_t> (a)]) / (b - a);
            out[static_cast<size_t> (i)] = std::max (0.0f, v[static_cast<size_t> (i)] - static_cast<float> (sum));
        }
        v.swap (out);
    };
    detrend (env.full);
    detrend (env.low);
    return env;
}

TempoInfo detectTempo (const Mono& signal, double sampleRate, double minBpm, double maxBpm)
{
    log::ScopedTimer timer (kMod, "détection de tempo"_u8);
    TempoInfo info;
    const auto env = computeOnsetEnvelope (signal, sampleRate);
    const auto& o = env.full;
    const int len = static_cast<int> (o.size());
    const double fps = env.frameRate;
    if (len < static_cast<int> (fps * 4.0))
    {
        SV_LOG_WARN (kMod, "signal trop court pour estimer le tempo (" + juce::String (len / std::max (1.0, fps), 1) + " s)");
        return info;
    }

    // Autocorrélation complète jusqu'à 4 périodes du tempo le plus lent.
    const int maxLag = std::min (len - 1, static_cast<int> (std::ceil (4.0 * 60.0 * fps / minBpm)) + 2);
    std::vector<float> ac (static_cast<size_t> (maxLag + 1), 0.0f);
    for (int lag = 1; lag <= maxLag; ++lag)
    {
        double acc = 0.0;
        for (int i = 0; i + lag < len; ++i)
            acc += static_cast<double> (o[static_cast<size_t> (i)]) * o[static_cast<size_t> (i + lag)];
        ac[static_cast<size_t> (lag)] = static_cast<float> (acc / (len - lag));
    }

    double bestBpm = 120.0, bestScore = -1.0, scoreSum = 0.0;
    int scoreCount = 0;
    for (double bpm = minBpm; bpm <= maxBpm; bpm += 0.1)
    {
        const double lag = 60.0 * fps / bpm;
        double s = 0.0;
        for (int k = 1; k <= 4; ++k)
            s += interpAt (ac, lag * k) / k;
        const double prior = std::exp (-0.5 * std::pow (std::log2 (bpm / 120.0) / 0.9, 2.0));
        s *= prior;
        scoreSum += s;
        ++scoreCount;
        if (s > bestScore)
        {
            bestScore = s;
            bestBpm = bpm;
        }
    }

    if (bestBpm < 70.0)
        bestBpm *= 2.0;
    else if (bestBpm > 180.0)
        bestBpm *= 0.5;

    // Affinage sur toute la durée (±1,5 %, pas de 0,01 BPM) : l'autocorrélation tombe sur des décalages
    // entiers de trames (140,6 au lieu de 140), et la grille dériverait de ~0,8 s sur 3 min.
    {
        double refBpm = bestBpm, refScore = -1.0;
        for (double b = bestBpm * 0.985; b <= bestBpm * 1.015; b += 0.01)
        {
            const double per = 60.0 * fps / b;
            for (double ph = 0.0; ph < per; ph += 0.5)
            {
                double sc = 0.0;
                for (double t = ph; t < len - 1; t += per)
                    sc += interpAt (o, t);
                if (sc > refScore)
                {
                    refScore = sc;
                    refBpm = b;
                }
            }
        }
        SV_LOG_DEBUG (kMod, "Tempo affiné : "_u8 + juce::String (bestBpm, 2) + " -> " + juce::String (refBpm, 2) + " BPM");
        bestBpm = refBpm;
    }

    // Phase des temps : maximise la somme du flux sur la grille.
    const double period = 60.0 * fps / bestBpm;
    double bestPhase = 0.0, bestPhaseScore = -1.0;
    for (double phase = 0.0; phase < period; phase += 0.25)
    {
        double s = 0.0;
        for (double t = phase; t < len - 1; t += period)
            s += interpAt (o, t);
        if (s > bestPhaseScore)
        {
            bestPhaseScore = s;
            bestPhase = phase;
        }
    }

    // Temps fort : celui des 4 temps candidats où la grosse caisse est la plus présente.
    int bestBeatOfBar = 0;
    double bestDown = -1.0;
    for (int j = 0; j < 4; ++j)
    {
        double s = 0.0;
        for (double t = bestPhase + j * period; t < len - 1; t += 4.0 * period)
            s += interpAt (env.low, t);   // grosse caisse seule (le flux large bande favorisait la caisse claire)
        if (s > bestDown)
        {
            bestDown = s;
            bestBeatOfBar = j;
        }
    }

    info.bpm = std::round (bestBpm * 100.0) / 100.0;   // au centième : grille juste sur un morceau entier
    info.firstBeatSec = (bestPhase + bestBeatOfBar * period) / fps;
    info.beatsPerBar = 4;
    const double meanScore = scoreCount > 0 ? scoreSum / scoreCount : 0.0;
    info.confidence = meanScore > 0.0 ? static_cast<float> (juce::jlimit (0.0, 1.0, (bestScore / meanScore - 1.0) / 3.0)) : 0.0f;

    SV_LOG_INFO (kMod, "Tempo détecté : "_u8 + juce::String (info.bpm, 1) + " BPM, premier temps fort à "_u8
                       + juce::String (info.firstBeatSec, 3) + " s (confiance " + juce::String (info.confidence, 2) + ")");
    return info;
}
} // namespace sv::analysis
