#pragma once

#include "../Types.h"

#include <juce_dsp/juce_dsp.h>

#include <cmath>
#include <vector>

// Transformée à court terme partagée (débruitage, résonances) : fenêtre racine de Hann en analyse et en synthèse
// (analyse × synthèse = Hann, dont la somme au pas N/4 vaut 2, compensée dans inverseAdd). Trame f = échantillons
// [f·hop − N, f·hop) ; les trames débordent du signal au début et à la fin (zéros), rien n'est perdu.
namespace sv::dsp
{
struct Stft
{
    const int size, hop, bins;
    juce::dsp::FFT fft;
    std::vector<float> window;
    std::vector<float> buf;   // spectre entrelacé (re, im) après forward ; signal après inverse
    const int n;
    const int numFrames;

    Stft (int fftOrder, int numSamples)
        : size (1 << fftOrder), hop ((1 << fftOrder) / 4), bins ((1 << fftOrder) / 2 + 1), fft (fftOrder),
          window (static_cast<size_t> (1 << fftOrder)), buf (static_cast<size_t> (2 * (1 << fftOrder))), n (numSamples),
          numFrames ((numSamples + (1 << fftOrder) / 4 - 1) / ((1 << fftOrder) / 4) + 3)
    {
        for (int i = 0; i < size; ++i)
            window[static_cast<size_t> (i)] = std::sqrt (0.5f - 0.5f * std::cos (2.0f * juce::MathConstants<float>::pi * static_cast<float> (i) / static_cast<float> (size)));
    }

    int frameStart (int f) const { return f * hop - size; }
    /** Instant (s) du centre de la trame. */
    double frameTimeSec (int f, double sampleRate) const { return (f * hop - size / 2) / sampleRate; }

    void forward (const float* x, int f)
    {
        const int start = frameStart (f);
        std::fill (buf.begin(), buf.end(), 0.0f);
        for (int i = 0; i < size; ++i)
        {
            const int idx = start + i;
            buf[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[idx] * window[static_cast<size_t> (i)] : 0.0f;
        }
        fft.performRealOnlyForwardTransform (buf.data(), true);
    }
    float power (int k) const
    {
        const float re = buf[static_cast<size_t> (2 * k)], im = buf[static_cast<size_t> (2 * k + 1)];
        return re * re + im * im;
    }
    void scaleBin (int k, float g)
    {
        buf[static_cast<size_t> (2 * k)] *= g;
        buf[static_cast<size_t> (2 * k + 1)] *= g;
    }
    /** Synthèse de la trame courante, ajoutée à out (recouvrement-addition normalisé). */
    void inverseAdd (float* out, int f)
    {
        fft.performRealOnlyInverseTransform (buf.data());
        const int start = frameStart (f);
        for (int i = 0; i < size; ++i)
        {
            const int idx = start + i;
            if (idx >= 0 && idx < n)
                out[idx] += buf[static_cast<size_t> (i)] * window[static_cast<size_t> (i)] * 0.5f;
        }
    }
};
} // namespace sv::dsp
