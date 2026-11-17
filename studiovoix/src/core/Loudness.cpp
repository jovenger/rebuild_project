#include "Loudness.h"

namespace sv::loudness
{
namespace
{
    struct Biquad
    {
        double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
        double z1 = 0, z2 = 0;

        inline double process (double x) noexcept
        {
            const double y = b0 * x + z1;
            z1 = b1 * x - a1 * y + z2;
            z2 = b2 * x - a2 * y;
            return y;
        }
    };

    // Coefficients de pondération K pour un taux quelconque (méthode libebur128).
    void makeKWeighting (double fs, Biquad& pre, Biquad& rlb)
    {
        const double pi = juce::MathConstants<double>::pi;
        {
            const double f0 = 1681.974450955533;
            const double G = 3.999843853973347;
            const double Q = 0.7071752369554196;
            const double K = std::tan (pi * f0 / fs);
            const double Vh = std::pow (10.0, G / 20.0);
            const double Vb = std::pow (Vh, 0.4996667741545416);
            const double a0 = 1.0 + K / Q + K * K;
            pre.b0 = (Vh + Vb * K / Q + K * K) / a0;
            pre.b1 = 2.0 * (K * K - Vh) / a0;
            pre.b2 = (Vh - Vb * K / Q + K * K) / a0;
            pre.a1 = 2.0 * (K * K - 1.0) / a0;
            pre.a2 = (1.0 - K / Q + K * K) / a0;
        }
        {
            const double f0 = 38.13547087602444;
            const double Q = 0.5003270373238773;
            const double K = std::tan (pi * f0 / fs);
            const double a0 = 1.0 + K / Q + K * K;
            rlb.b0 = 1.0;
            rlb.b1 = -2.0;
            rlb.b2 = 1.0;
            rlb.a1 = 2.0 * (K * K - 1.0) / a0;
            rlb.a2 = (1.0 - K / Q + K * K) / a0;
        }
    }

    // Énergie moyenne pondérée K de chaque bloc de 400 ms (pas 100 ms), sommée sur les canaux.
    std::vector<double> blockEnergies (const std::vector<const float*>& channels, int numSamples, double fs)
    {
        const int hop = static_cast<int> (std::round (fs * 0.1));
        const int block = hop * 4;
        std::vector<double> energies;
        if (numSamples < block || hop <= 0)
        {
            // Signal court : un seul bloc sur toute la durée.
            if (numSamples <= 0)
                return energies;
        }

        std::vector<double> hopEnergy;   // énergie par tranche de 100 ms
        for (const float* ch : channels)
        {
            Biquad pre, rlb;
            makeKWeighting (fs, pre, rlb);
            int idx = 0;
            for (int start = 0; start < numSamples; start += hop, ++idx)
            {
                const int end = std::min (numSamples, start + hop);
                double acc = 0.0;
                for (int i = start; i < end; ++i)
                {
                    const double y = rlb.process (pre.process (ch[i]));
                    acc += y * y;
                }
                if (static_cast<int> (hopEnergy.size()) <= idx)
                    hopEnergy.push_back (0.0);
                hopEnergy[static_cast<size_t> (idx)] += acc;
            }
        }

        const int numHops = static_cast<int> (hopEnergy.size());
        if (numHops < 4)
        {
            double total = 0.0;
            for (double e : hopEnergy)
                total += e;
            energies.push_back (total / std::max (1, numSamples));
            return energies;
        }

        for (int h = 0; h + 4 <= numHops; ++h)
        {
            const double e = hopEnergy[static_cast<size_t> (h)] + hopEnergy[static_cast<size_t> (h + 1)]
                           + hopEnergy[static_cast<size_t> (h + 2)] + hopEnergy[static_cast<size_t> (h + 3)];
            energies.push_back (e / static_cast<double> (block));
        }
        return energies;
    }

    double energyToLufs (double e) { return e > 0.0 ? -0.691 + 10.0 * std::log10 (e) : -120.0; }

    double gatedIntegrated (const std::vector<double>& energies)
    {
        // Porte absolue -70 LUFS puis porte relative -10 LU.
        double sum = 0.0;
        int count = 0;
        for (double e : energies)
            if (energyToLufs (e) > -70.0)
            {
                sum += e;
                ++count;
            }
        if (count == 0)
            return -120.0;

        const double relGate = energyToLufs (sum / count) - 10.0;
        double sum2 = 0.0;
        int count2 = 0;
        for (double e : energies)
            if (energyToLufs (e) > -70.0 && energyToLufs (e) > relGate)
            {
                sum2 += e;
                ++count2;
            }
        return count2 > 0 ? energyToLufs (sum2 / count2) : -120.0;
    }
}

double integratedLufs (const Stereo& buffer, double sampleRate)
{
    std::vector<const float*> chans;
    for (int c = 0; c < buffer.getNumChannels(); ++c)
        chans.push_back (buffer.getReadPointer (c));
    return gatedIntegrated (blockEnergies (chans, buffer.getNumSamples(), sampleRate));
}

double integratedLufs (const Mono& mono, double sampleRate)
{
    // Un signal mono est compté comme un canal unique (convention BS.1770).
    std::vector<const float*> chans { mono.data() };
    return gatedIntegrated (blockEnergies (chans, static_cast<int> (mono.size()), sampleRate));
}

std::vector<float> momentaryCurve (const Mono& mono, double sampleRate)
{
    std::vector<const float*> chans { mono.data() };
    const auto energies = blockEnergies (chans, static_cast<int> (mono.size()), sampleRate);
    std::vector<float> curve;
    curve.reserve (energies.size());
    for (double e : energies)
        curve.push_back (static_cast<float> (energyToLufs (e)));
    return curve;
}

double truePeakDb (const Stereo& buffer)
{
    // Interpolation x4 par sinc fenêtré (Hann, 8 points de chaque côté) : approximation de la crête vraie.
    constexpr int over = 4;
    constexpr int half = 8;
    const double pi = juce::MathConstants<double>::pi;
    double coeffs[over][2 * half];
    for (int p = 0; p < over; ++p)
    {
        const double frac = static_cast<double> (p) / over;
        for (int k = 0; k < 2 * half; ++k)
        {
            const double x = (k - half + 1) - frac;
            const double sinc = std::abs (x) < 1.0e-9 ? 1.0 : std::sin (pi * x) / (pi * x);
            const double w = 0.5 + 0.5 * std::cos (pi * x / half);
            coeffs[p][k] = sinc * w;
        }
    }

    double maxPeak = 0.0;
    for (int c = 0; c < buffer.getNumChannels(); ++c)
    {
        const float* d = buffer.getReadPointer (c);
        const int n = buffer.getNumSamples();
        for (int i = 0; i < n; ++i)
        {
            maxPeak = std::max (maxPeak, static_cast<double> (std::abs (d[i])));
            for (int p = 1; p < over; ++p)
            {
                double acc = 0.0;
                for (int k = 0; k < 2 * half; ++k)
                {
                    const int idx = i + k - half + 1;
                    if (idx >= 0 && idx < n)
                        acc += coeffs[p][k] * d[idx];
                }
                maxPeak = std::max (maxPeak, std::abs (acc));
            }
        }
    }
    return maxPeak > 0.0 ? 20.0 * std::log10 (maxPeak) : -120.0;
}

Report measure (const Stereo& buffer, double sampleRate)
{
    Report r;
    r.integratedLufs = integratedLufs (buffer, sampleRate);
    r.truePeakDb = truePeakDb (buffer);
    float sp = 0.0f;
    for (int c = 0; c < buffer.getNumChannels(); ++c)
        sp = std::max (sp, buffer.getMagnitude (c, 0, buffer.getNumSamples()));
    r.samplePeakDb = gainToDb (sp);
    return r;
}
} // namespace sv::loudness
