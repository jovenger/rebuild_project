#include "Denoiser.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

#include <cmath>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Débruitage";
    constexpr int kOrder = 10;          // FFT 1024 (21 ms à 48 kHz)
    constexpr int kFft = 1 << kOrder;
    constexpr int kHop = kFft / 4;
    constexpr int kBins = kFft / 2 + 1;

    float levelDbOfInactive (const Mono& x, double sr, const analysis::VoiceActivity& va)
    {
        double e = 0.0;
        size_t n = 0;
        const size_t frame = static_cast<size_t> (std::max (1.0, va.frameSec * sr));
        for (size_t f = 0; f < va.active.size(); ++f)
        {
            if (va.active[f])
                continue;
            const size_t a = f * frame, b = std::min (x.size(), a + frame);
            for (size_t i = a; i < b; ++i)
                e += static_cast<double> (x[i]) * x[i];
            n += b > a ? b - a : 0;
        }
        return n > 0 ? gainToDb (static_cast<float> (std::sqrt (e / static_cast<double> (n)))) : -120.0f;
    }
}

DenoiseReport spectralDenoise (Mono& x, double sr, const analysis::VoiceActivity& va, float maxReductionDb)
{
    log::ScopedTimer timer (kMod, "débruitage spectral"_u8);
    DenoiseReport rep;
    const int n = static_cast<int> (x.size());
    if (n < kFft * 2 || maxReductionDb <= 0.0f)
        return rep;
    rep.noiseBeforeDb = levelDbOfInactive (x, sr, va);

    juce::dsp::FFT fft (kOrder);
    std::vector<float> window (static_cast<size_t> (kFft));
    for (int i = 0; i < kFft; ++i)
        window[static_cast<size_t> (i)] = std::sqrt (0.5f - 0.5f * std::cos (2.0f * juce::MathConstants<float>::pi * i / kFft));   // racine de Hann : analyse × synthèse = Hann, somme constante au pas 1/4

    const int numFrames = (n + kHop - 1) / kHop + 3;
    std::vector<float> buf (static_cast<size_t> (2 * kFft));
    std::vector<float> power (static_cast<size_t> (kBins));

    // 1) Profil de bruit : moyenne des spectres de puissance des trames inactives (sinon les 10 % les plus calmes).
    std::vector<double> noise (static_cast<size_t> (kBins), 0.0);
    std::vector<std::pair<float, int>> frameEnergy;
    frameEnergy.reserve (static_cast<size_t> (numFrames));
    auto analyse = [&] (int frameIndex)
    {
        const int start = frameIndex * kHop - kFft;
        std::fill (buf.begin(), buf.end(), 0.0f);
        for (int i = 0; i < kFft; ++i)
        {
            const int idx = start + i;
            buf[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[static_cast<size_t> (idx)] * window[static_cast<size_t> (i)] : 0.0f;
        }
        fft.performRealOnlyForwardTransform (buf.data(), true);
        for (int k = 0; k < kBins; ++k)
        {
            const float re = buf[static_cast<size_t> (2 * k)], im = buf[static_cast<size_t> (2 * k + 1)];
            power[static_cast<size_t> (k)] = re * re + im * im;
        }
    };
    int inactiveCount = 0;
    for (int f = 0; f < numFrames; ++f)
    {
        const double tSec = (f * kHop - kFft / 2) / sr;
        const bool inactive = tSec >= 0.0 && tSec < va.active.size() * va.frameSec && ! va.isActiveAt (tSec);
        analyse (f);
        double e = 0.0;
        for (int k = 0; k < kBins; ++k)
            e += power[static_cast<size_t> (k)];
        frameEnergy.emplace_back (static_cast<float> (e), f);
        if (inactive)
        {
            for (int k = 0; k < kBins; ++k)
                noise[static_cast<size_t> (k)] += power[static_cast<size_t> (k)];
            ++inactiveCount;
        }
    }
    if (inactiveCount < 10)
    {
        // Pas assez de silence : les 10 % de trames les plus calmes servent de profil.
        std::sort (frameEnergy.begin(), frameEnergy.end());
        std::fill (noise.begin(), noise.end(), 0.0);
        inactiveCount = 0;
        for (size_t i = 0; i < std::max<size_t> (10, frameEnergy.size() / 10) && i < frameEnergy.size(); ++i)
        {
            analyse (frameEnergy[i].second);
            for (int k = 0; k < kBins; ++k)
                noise[static_cast<size_t> (k)] += power[static_cast<size_t> (k)];
            ++inactiveCount;
        }
    }
    rep.noiseFrames = inactiveCount;
    if (inactiveCount == 0)
        return rep;
    for (auto& v : noise)
        v /= inactiveCount;

    // 2) Gain par bande : Wiener avec sur-soustraction, plancher = -maxReductionDb, lissé (temps : montée rapide,
    //    descente lente ; fréquence : 3 bandes) pour ne pas créer de bruit « musical ».
    const float floorGain = dbToGain (-maxReductionDb);
    const float over = 2.0f;
    std::vector<float> gain (static_cast<size_t> (kBins), 1.0f), gainPrev (static_cast<size_t> (kBins), 1.0f);
    Mono out (static_cast<size_t> (n), 0.0f);
    for (int f = 0; f < numFrames; ++f)
    {
        const int start = f * kHop - kFft;
        analyse (f);
        for (int k = 0; k < kBins; ++k)
        {
            const double p = power[static_cast<size_t> (k)];
            const double nz = noise[static_cast<size_t> (k)] * over;
            // Soustraction spectrale de puissance : gain d'amplitude = racine (la voix au-dessus du bruit est à peine touchée).
            const float g = p > 1.0e-20 ? static_cast<float> (std::sqrt (std::max (0.0, 1.0 - nz / p))) : 0.0f;
            gain[static_cast<size_t> (k)] = std::max (floorGain, g);
        }
        // Lissage en fréquence.
        for (int k = 1; k + 1 < kBins; ++k)
            gain[static_cast<size_t> (k)] = 0.25f * gain[static_cast<size_t> (k - 1)] + 0.5f * gain[static_cast<size_t> (k)] + 0.25f * gain[static_cast<size_t> (k + 1)];
        // Lissage en temps : une bande qui s'ouvre (voix) suit vite, une bande qui se ferme descend doucement.
        for (int k = 0; k < kBins; ++k)
        {
            auto& gp = gainPrev[static_cast<size_t> (k)];
            const float g = gain[static_cast<size_t> (k)];
            gp = g > gp ? 0.6f * g + 0.4f * gp : 0.25f * g + 0.75f * gp;
            gain[static_cast<size_t> (k)] = gp;
        }
        // Spectre complexe de la trame (nouvelle analyse pour les parties réelle / imaginaire).
        std::fill (buf.begin(), buf.end(), 0.0f);
        for (int i = 0; i < kFft; ++i)
        {
            const int idx = start + i;
            buf[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[static_cast<size_t> (idx)] * window[static_cast<size_t> (i)] : 0.0f;
        }
        fft.performRealOnlyForwardTransform (buf.data(), true);
        for (int k = 0; k < kBins; ++k)
        {
            buf[static_cast<size_t> (2 * k)] *= gain[static_cast<size_t> (k)];
            buf[static_cast<size_t> (2 * k + 1)] *= gain[static_cast<size_t> (k)];
        }
        fft.performRealOnlyInverseTransform (buf.data());
        for (int i = 0; i < kFft; ++i)
        {
            const int idx = start + i;
            if (idx >= 0 && idx < n)
                out[static_cast<size_t> (idx)] += buf[static_cast<size_t> (i)] * window[static_cast<size_t> (i)];
        }
    }
    // Normalisation : analyse × synthèse = Hann, dont la somme au pas 1/4 vaut 2.
    const float norm = 0.5f;
    for (int i = 0; i < n; ++i)
        x[static_cast<size_t> (i)] = out[static_cast<size_t> (i)] * norm;
    rep.noiseAfterDb = levelDbOfInactive (x, sr, va);
    SV_LOG_INFO (kMod, "Bruit dans les silences : " + juce::String (rep.noiseBeforeDb, 1) + " -> " + juce::String (rep.noiseAfterDb, 1)
                       + " dBFS (" + juce::String (rep.noiseFrames) + " trames de profil, max -" + juce::String (maxReductionDb, 0) + " dB)");
    return rep;
}

int declip (Mono& x, float threshold)
{
    const int n = static_cast<int> (x.size());
    int repaired = 0;
    for (int i = 0; i < n;)
    {
        if (std::abs (x[static_cast<size_t> (i)]) < threshold)
        {
            ++i;
            continue;
        }
        int j = i;
        while (j < n && std::abs (x[static_cast<size_t> (j)]) >= threshold && (x[static_cast<size_t> (j)] > 0.0f) == (x[static_cast<size_t> (i)] > 0.0f))
            ++j;
        // Zone [i, j) écrêtée : interpolation cubique (Hermite) entre les points sains de part et d'autre, avec leurs pentes.
        const int len = j - i;
        if (len >= 2 && i >= 2 && j + 1 < n && len < 4096)
        {
            const float p0 = x[static_cast<size_t> (i - 1)], p1 = x[static_cast<size_t> (j)];
            const float m0 = (x[static_cast<size_t> (i - 1)] - x[static_cast<size_t> (i - 2)]) * (len + 1);
            const float m1 = (x[static_cast<size_t> (j + 1)] - x[static_cast<size_t> (j)]) * (len + 1);
            for (int k = 0; k < len; ++k)
            {
                const float t = static_cast<float> (k + 1) / static_cast<float> (len + 1);
                const float t2 = t * t, t3 = t2 * t;
                const float h00 = 2 * t3 - 3 * t2 + 1, h10 = t3 - 2 * t2 + t, h01 = -2 * t3 + 3 * t2, h11 = t3 - t2;
                const float v = h00 * p0 + h10 * m0 + h01 * p1 + h11 * m1;
                const float sign = x[static_cast<size_t> (i)] > 0.0f ? 1.0f : -1.0f;
                // Jamais en dessous du niveau écrêté (on reconstruit la bosse), borné à +6 dB.
                x[static_cast<size_t> (i + k)] = sign * juce::jlimit (threshold, 2.0f, std::abs (v));
            }
            repaired += len;
        }
        i = j;
    }
    return repaired;
}
} // namespace sv::dsp
