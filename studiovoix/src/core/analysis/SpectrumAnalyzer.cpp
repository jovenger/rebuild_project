#include "SpectrumAnalyzer.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

namespace sv::analysis
{
namespace
{
    constexpr const char* kMod = "Spectrum";
    constexpr int kOrder = 12;   // FFT 4096
    constexpr int kFft = 1 << kOrder;
}

std::vector<float> thirdOctaveCenters()
{
    return { 25, 31.5f, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600,
             2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000 };
}

BandSpectrum averageSpectrum (const Mono& signal, double sampleRate, float gateBelowPeakDb)
{
    log::ScopedTimer timer (kMod, "spectre moyen");
    BandSpectrum result;
    result.centersHz = thirdOctaveCenters();
    const size_t numBands = result.centersHz.size();
    if (signal.size() < static_cast<size_t> (kFft))
        return result;

    juce::dsp::FFT fft (kOrder);
    juce::dsp::WindowingFunction<float> window (static_cast<size_t> (kFft), juce::dsp::WindowingFunction<float>::hann, false);
    std::vector<float> buf (static_cast<size_t> (2 * kFft));

    // Bin -> bande.
    std::vector<int> binBand (static_cast<size_t> (kFft / 2), -1);
    for (int k = 1; k < kFft / 2; ++k)
    {
        const float f = static_cast<float> (k * sampleRate / kFft);
        for (size_t b = 0; b < numBands; ++b)
        {
            const float lo = result.centersHz[b] / std::pow (2.0f, 1.0f / 6.0f);
            const float hi = result.centersHz[b] * std::pow (2.0f, 1.0f / 6.0f);
            if (f >= lo && f < hi)
            {
                binBand[static_cast<size_t> (k)] = static_cast<int> (b);
                break;
            }
        }
    }

    const float peakDb = gainToDb (audio::peak (signal.data(), signal.size()));
    const float gate = dbToGain (peakDb - gateBelowPeakDb);
    std::vector<double> acc (numBands, 0.0);
    int frames = 0;
    const int hop = kFft / 2;
    for (size_t start = 0; start + static_cast<size_t> (kFft) <= signal.size(); start += static_cast<size_t> (hop))
    {
        if (audio::rms (signal.data() + start, static_cast<size_t> (kFft)) < gate)
            continue;
        std::copy (signal.begin() + static_cast<long> (start), signal.begin() + static_cast<long> (start) + kFft, buf.begin());
        std::fill (buf.begin() + kFft, buf.end(), 0.0f);
        window.multiplyWithWindowingTable (buf.data(), static_cast<size_t> (kFft));
        fft.performFrequencyOnlyForwardTransform (buf.data(), true);
        for (int k = 1; k < kFft / 2; ++k)
        {
            const int b = binBand[static_cast<size_t> (k)];
            if (b >= 0)
                acc[static_cast<size_t> (b)] += static_cast<double> (buf[static_cast<size_t> (k)]) * buf[static_cast<size_t> (k)];
        }
        ++frames;
    }

    if (frames == 0)
        return result;

    result.levelsDb.resize (numBands);
    for (size_t b = 0; b < numBands; ++b)
        result.levelsDb[b] = static_cast<float> (10.0 * std::log10 (std::max (1.0e-20, acc[b] / frames)));
    return result;
}

std::vector<float> matchCurve (const BandSpectrum& source, const BandSpectrum& target, float maxDb,
                               float minHz, float maxHz, float strength)
{
    std::vector<float> curve;
    if (! source.valid() || ! target.valid() || source.levelsDb.size() != target.levelsDb.size())
        return curve;

    const size_t n = source.levelsDb.size();
    std::vector<float> diff (n, 0.0f);
    double mean = 0.0;
    int count = 0;
    for (size_t b = 0; b < n; ++b)
    {
        const float f = source.centersHz[b];
        if (f < minHz || f > maxHz)
            continue;
        diff[b] = target.levelsDb[b] - source.levelsDb[b];
        mean += diff[b];
        ++count;
    }
    if (count == 0)
        return std::vector<float> (n, 0.0f);
    mean /= count;

    // Centrage (seule la forme compte, pas le niveau) puis lissage sur 3 bandes.
    std::vector<float> centred (n, 0.0f);
    for (size_t b = 0; b < n; ++b)
    {
        const float f = source.centersHz[b];
        if (f >= minHz && f <= maxHz)
            centred[b] = diff[b] - static_cast<float> (mean);
    }
    curve.assign (n, 0.0f);
    for (size_t b = 0; b < n; ++b)
    {
        const float f = source.centersHz[b];
        if (f < minHz || f > maxHz)
            continue;
        float s = centred[b] * 2.0f;
        float w = 2.0f;
        if (b > 0) { s += centred[b - 1]; w += 1.0f; }
        if (b + 1 < n) { s += centred[b + 1]; w += 1.0f; }
        curve[b] = juce::jlimit (-maxDb, maxDb, strength * s / w);
    }
    return curve;
}
} // namespace sv::analysis
