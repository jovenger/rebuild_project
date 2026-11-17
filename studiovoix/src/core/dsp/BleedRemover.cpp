#include "BleedRemover.h"

#include "../Log.h"
#include "Stft.h"

#include <juce_dsp/juce_dsp.h>

#include <algorithm>
#include <cmath>
#include <complex>
#include <vector>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Repisse";

    // Moyenne par blocs de d échantillons (décimation grossière, suffisante pour situer le pic de corrélation).
    std::vector<float> decimate (const Mono& x, size_t from, size_t count, int d)
    {
        std::vector<float> out (count / static_cast<size_t> (d), 0.0f);
        for (size_t o = 0; o < out.size(); ++o)
        {
            float s = 0.0f;
            for (int k = 0; k < d; ++k)
            {
                const size_t i = from + o * static_cast<size_t> (d) + static_cast<size_t> (k);
                s += i < x.size() ? x[i] : 0.0f;
            }
            out[o] = s / static_cast<float> (d);
        }
        return out;
    }

    // Corrélation x[i + l] · r[i] pour l dans [lo, hi], signal pleine cadence, sur [from, from + count).
    double corrAt (const Mono& x, const Mono& r, long l, size_t from, size_t count)
    {
        double s = 0.0;
        for (size_t i = from; i < from + count; ++i)
        {
            const long xi = static_cast<long> (i) + l;
            if (xi >= 0 && xi < static_cast<long> (x.size()) && i < r.size())
                s += static_cast<double> (x[static_cast<size_t> (xi)]) * r[i];
        }
        return s;
    }

    double energy (const Mono& x)
    {
        double e = 0.0;
        for (const float v : x)
            e += static_cast<double> (v) * v;
        return e;
    }

    float db10 (double ratio) { return ratio > 1.0e-12 ? static_cast<float> (10.0 * std::log10 (ratio)) : -120.0f; }

    // Part de l'instru (alignée) dans la prise : énergie de la projection par bande (|H R|²) / énergie de la prise.
    float bleedShareDb (const Mono& rec, const Mono& refAligned, double)
    {
        const int order = 11;
        Stft sx (order, static_cast<int> (rec.size())), sr (order, static_cast<int> (rec.size()));
        const int bins = sx.bins;
        std::vector<std::complex<double>> sxr (static_cast<size_t> (bins));
        std::vector<double> srr (static_cast<size_t> (bins), 0.0);
        std::vector<double> sxx (static_cast<size_t> (bins), 0.0);
        for (int f = 0; f < sx.numFrames; f += 2)
        {
            sx.forward (rec.data(), f);
            sr.forward (refAligned.data(), f);
            for (int k = 0; k < bins; ++k)
            {
                const std::complex<double> X (sx.buf[static_cast<size_t> (2 * k)], sx.buf[static_cast<size_t> (2 * k + 1)]);
                const std::complex<double> R (sr.buf[static_cast<size_t> (2 * k)], sr.buf[static_cast<size_t> (2 * k + 1)]);
                sxr[static_cast<size_t> (k)] += X * std::conj (R);
                srr[static_cast<size_t> (k)] += std::norm (R);
                sxx[static_cast<size_t> (k)] += std::norm (X);
            }
        }
        double proj = 0.0, total = 0.0;
        for (int k = 0; k < bins; ++k)
        {
            if (srr[static_cast<size_t> (k)] > 1.0e-12)
                proj += std::norm (sxr[static_cast<size_t> (k)]) / srr[static_cast<size_t> (k)];
            total += sxx[static_cast<size_t> (k)];
        }
        return db10 (total > 0.0 ? proj / total : 0.0);
    }

    Mono shifted (const Mono& ref, long lag, size_t n)
    {
        Mono out (n, 0.0f);
        for (size_t i = 0; i < n; ++i)
        {
            const long j = static_cast<long> (i) - lag;
            if (j >= 0 && j < static_cast<long> (ref.size()))
                out[i] = ref[static_cast<size_t> (j)];
        }
        return out;
    }
}

juce::String BleedReport::describe() const
{
    if (! detected)
        return "aucune musique captée par le micro (casque ?)"_u8;
    return "musique captée par le micro "_u8 + juce::String (bleedBeforeDb, 1) + " dB, retirée jusqu'à " + juce::String (bleedAfterDb, 1)
           + " dB ; décalage mesuré " + juce::String (juce::roundToInt (lagSec * 1000.0)) + " ms"_u8;
}

BleedReport findBleedLag (const Mono& rec, const Mono& ref, double sampleRate, double minLagSec, double maxLagSec)
{
    BleedReport rep;
    if (rec.size() < static_cast<size_t> (sampleRate) || ref.empty() || energy (ref) < 1.0e-9)
        return rep;
    log::ScopedTimer timer (kMod, "recherche de l'instru dans la prise"_u8);
    const int d = std::max (1, static_cast<int> (std::round (sampleRate / 12000.0)));
    const double dsr = sampleRate / d;
    const size_t win = std::min (rec.size(), static_cast<size_t> (45.0 * sampleRate));
    const auto x = decimate (rec, 0, win, d);
    const auto r = decimate (ref, 0, win, d);
    const long lo = static_cast<long> (std::floor (minLagSec * dsr)), hi = static_cast<long> (std::ceil (maxLagSec * dsr));

    // GCC-PHAT : spectre croisé blanchi -> pic net même sur une musique tonale et une voix par-dessus.
    int order = 1;
    while ((1u << order) < x.size() + r.size() + static_cast<size_t> (hi - lo))
        ++order;
    const size_t n = static_cast<size_t> (1) << order;
    juce::dsp::FFT fft (order);
    std::vector<float> fx (2 * n, 0.0f), fr (2 * n, 0.0f);
    std::copy (x.begin(), x.end(), fx.begin());
    std::copy (r.begin(), r.end(), fr.begin());
    fft.performRealOnlyForwardTransform (fx.data(), true);
    fft.performRealOnlyForwardTransform (fr.data(), true);
    for (size_t k = 0; k <= n / 2; ++k)
    {
        const std::complex<float> X (fx[2 * k], fx[2 * k + 1]), R (fr[2 * k], fr[2 * k + 1]);
        auto c = X * std::conj (R);
        const float m = std::abs (c);
        c = m > 1.0e-12f ? c / m : std::complex<float> (0.0f, 0.0f);
        fx[2 * k] = c.real();
        fx[2 * k + 1] = c.imag();
    }
    fft.performRealOnlyInverseTransform (fx.data());
    long best = 0;
    float bestV = -1.0e30f;
    double sum2 = 0.0;
    int count = 0;
    for (long l = lo; l <= hi; ++l)
    {
        const size_t idx = l >= 0 ? static_cast<size_t> (l) : n - static_cast<size_t> (-l);
        const float v = fx[idx];
        sum2 += static_cast<double> (v) * v;
        ++count;
        if (v > bestV)
        {
            bestV = v;
            best = l;
        }
    }
    const float rmsV = count > 0 ? static_cast<float> (std::sqrt (sum2 / count)) : 0.0f;
    rep.peakRatio = rmsV > 0.0f ? bestV / rmsV : 0.0f;
    rep.detected = rep.peakRatio > 8.0f;

    // Affinage à l'échantillon (pleine cadence) autour du pic.
    const long centre = best * d;
    long bestFull = centre;
    double bestC = -1.0e30;
    const size_t refineFrom = 0, refineCount = std::min (win, static_cast<size_t> (12.0 * sampleRate));
    for (long l = centre - d; l <= centre + d; ++l)
    {
        const double c = corrAt (rec, ref, l, refineFrom, refineCount);
        if (c > bestC)
        {
            bestC = c;
            bestFull = l;
        }
    }
    rep.lagSec = bestFull / sampleRate;
    SV_LOG_INFO (kMod, "Instru dans la prise : "_u8 + (rep.detected ? juce::String ("oui") : juce::String ("non")) + ", pic "
                       + juce::String (rep.peakRatio, 1) + " (seuil 8), décalage " + juce::String (rep.lagSec * 1000.0, 1) + " ms"_u8);
    return rep;
}

BleedReport removeBleed (Mono& rec, const Mono& ref, double sampleRate, double minLagSec, double maxLagSec)
{
    auto rep = findBleedLag (rec, ref, sampleRate, minLagSec, maxLagSec);
    if (! rep.detected)
        return rep;
    log::ScopedTimer timer (kMod, "retrait de l'instru captée par le micro"_u8);
    const long lag = static_cast<long> (std::llround (rep.lagSec * sampleRate));
    const Mono r = shifted (ref, lag, rec.size());
    rep.bleedBeforeDb = bleedShareDb (rec, r, sampleRate);

    // 1) Fonction de transfert pièce + micro par bande : H = Σ X R* / Σ |R|² (la voix, sans lien avec l'instru,
    //    s'annule en moyenne). Estimée par tranches de 3 s (interpolées d'une tranche à l'autre) pour suivre une
    //    horloge micro / sortie qui dérive (appareils séparés : micro USB, enceinte Bluetooth) ; chaque tranche est
    //    tirée vers l'estimation globale quand l'instru y est faible (régularisation).
    const int order = 11;
    Stft sx (order, static_cast<int> (rec.size())), sr (order, static_cast<int> (rec.size()));
    const int bins = sx.bins;
    const int framesPerBlock = std::max (8, static_cast<int> (3.0 * sampleRate / sx.hop));
    const int blocks = sx.numFrames / framesPerBlock + 1;
    std::vector<std::complex<double>> sxr (static_cast<size_t> (bins * blocks));
    std::vector<double> srr (static_cast<size_t> (bins * blocks), 0.0);
    std::vector<std::complex<double>> gxr (static_cast<size_t> (bins));
    std::vector<double> grr (static_cast<size_t> (bins), 0.0);
    for (int f = 0; f < sx.numFrames; ++f)
    {
        sx.forward (rec.data(), f);
        sr.forward (r.data(), f);
        const size_t base = static_cast<size_t> ((f / framesPerBlock) * bins);
        for (int k = 0; k < bins; ++k)
        {
            const std::complex<double> X (sx.buf[static_cast<size_t> (2 * k)], sx.buf[static_cast<size_t> (2 * k + 1)]);
            const std::complex<double> R (sr.buf[static_cast<size_t> (2 * k)], sr.buf[static_cast<size_t> (2 * k + 1)]);
            const auto xr = X * std::conj (R);
            const double rr = std::norm (R);
            sxr[base + static_cast<size_t> (k)] += xr;
            srr[base + static_cast<size_t> (k)] += rr;
            gxr[static_cast<size_t> (k)] += xr;
            grr[static_cast<size_t> (k)] += rr;
        }
    }
    std::vector<std::complex<float>> hb (static_cast<size_t> (bins * blocks));
    for (int b = 0; b < blocks; ++b)
        for (int k = 0; k < bins; ++k)
        {
            const size_t i = static_cast<size_t> (b * bins + k), ki = static_cast<size_t> (k);
            const double reg = 0.05 * grr[ki] / blocks;   // poids de l'estimation globale
            const double den = srr[i] + reg + 1.0e-12;
            hb[i] = std::complex<float> ((sxr[i] + gxr[ki] * (reg / (grr[ki] + 1.0e-12))) / den);
        }
    std::vector<std::complex<float>> h (static_cast<size_t> (bins));
    const auto hFor = [&] (int f)
    {
        // Interpolation linéaire entre les centres de tranche.
        const double pos = (f + 0.5) / framesPerBlock - 0.5;
        const int b0 = juce::jlimit (0, blocks - 1, static_cast<int> (std::floor (pos)));
        const int b1 = std::min (blocks - 1, b0 + 1);
        const float t = static_cast<float> (juce::jlimit (0.0, 1.0, pos - b0));
        for (int k = 0; k < bins; ++k)
            h[static_cast<size_t> (k)] = hb[static_cast<size_t> (b0 * bins + k)] * (1.0f - t) + hb[static_cast<size_t> (b1 * bins + k)] * t;
    };

    // 2) Soustraction de l'instru estimée, puis suppression douce de ce qui reste (réverbération longue, variations) :
    //    gain = 1 - 1,5 × (reste estimé / signal), plancher -14 dB, relâché lentement pour éviter le bruit « musical ».
    Mono out (rec.size(), 0.0f);
    std::vector<float> gPrev (static_cast<size_t> (bins), 1.0f);
    constexpr float kResidual = 0.15f, kOver = 1.5f, kFloor = 0.2f;
    for (int f = 0; f < sx.numFrames; ++f)
    {
        sx.forward (rec.data(), f);
        sr.forward (r.data(), f);
        hFor (f);
        for (int k = 0; k < bins; ++k)
        {
            const size_t ki = static_cast<size_t> (k);
            std::complex<float> X (sx.buf[2 * ki], sx.buf[2 * ki + 1]);
            const std::complex<float> R (sr.buf[2 * ki], sr.buf[2 * ki + 1]);
            const std::complex<float> b = h[ki] * R;
            const std::complex<float> y = X - b;
            const float py = std::norm (y);
            const float residual = kResidual * std::norm (b);
            float g = py > 1.0e-20f ? 1.0f - kOver * residual / py : 1.0f;
            g = juce::jlimit (kFloor, 1.0f, g);
            g = std::max (g, gPrev[ki] * 0.6f + 0.4f * g);   // remontée immédiate, descente lissée
            gPrev[ki] = g;
            sx.buf[2 * ki] = y.real() * g;
            sx.buf[2 * ki + 1] = y.imag() * g;
        }
        sx.inverseAdd (out.data(), f);
    }
    rec.swap (out);
    rep.bleedAfterDb = bleedShareDb (rec, r, sampleRate);
    SV_LOG_INFO (kMod, rep.describe());
    return rep;
}
} // namespace sv::dsp
