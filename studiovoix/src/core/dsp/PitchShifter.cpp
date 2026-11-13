#include "PitchShifter.h"

#include "../Log.h"

#include <algorithm>
#include <cmath>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "PSOLA";

    float ratioAt (const analysis::PitchTrack& track, const std::vector<float>& ratios, double timeSec)
    {
        if (ratios.empty())
            return 1.0f;
        const double pos = timeSec / track.hopSec;
        const int i0 = static_cast<int> (std::floor (pos));
        const int n = static_cast<int> (ratios.size());
        if (i0 < 0)
            return ratios.front();
        if (i0 + 1 >= n)
            return ratios.back();
        const float f = static_cast<float> (pos - i0);
        return ratios[static_cast<size_t> (i0)] * (1.0f - f) + ratios[static_cast<size_t> (i0 + 1)] * f;
    }

    // Interpolation à position fractionnaire : sinc fenêtré (Kaiser, 16 points). x(i + phi) = somme h[k] x[i + k - 7].
    // Pourquoi : des grains posés à l'échantillon entier près font une gigue de ±0,5 échantillon d'une période à
    // l'autre, soit un bruit non harmonique mesuré à -25 dB au-dessus de 2 kHz sur une note tenue (« ça crépite dans
    // les aigus »). À position fractionnaire, la sortie d'une note tenue est exactement périodique.
    constexpr int kTaps = 16;
    constexpr int kTapCentre = 7;

    double bessel0 (double x)
    {
        double s = 1.0, t = 1.0;
        for (int k = 1; k < 40; ++k)
        {
            t *= (x / (2.0 * k)) * (x / (2.0 * k));
            s += t;
            if (t < 1.0e-12 * s)
                break;
        }
        return s;
    }

    void sincTaps (double phi, float* h)
    {
        if (phi < 1.0e-9)
        {
            for (int k = 0; k < kTaps; ++k)
                h[k] = k == kTapCentre ? 1.0f : 0.0f;
            return;
        }
        static const double i0b = bessel0 (8.0);
        double sum = 0.0;
        double v[kTaps];
        for (int k = 0; k < kTaps; ++k)
        {
            const double t = (k - kTapCentre) - phi;
            const double u = t / (kTaps / 2);
            const double w = std::abs (u) < 1.0 ? bessel0 (8.0 * std::sqrt (1.0 - u * u)) / i0b : 0.0;
            const double a = juce::MathConstants<double>::pi * t;
            v[k] = (std::abs (a) < 1.0e-9 ? 1.0 : std::sin (a) / a) * w;
            sum += v[k];
        }
        for (int k = 0; k < kTaps; ++k)
            h[k] = static_cast<float> (v[k] / sum);
    }

    struct Region
    {
        int a = 0, b = 0;   // échantillons [a, b) où la hauteur est réellement changée
    };
}

Mono psolaShift (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                 const std::vector<float>& ratioPerFrame, const PsolaOptions& options)
{
    log::ScopedTimer timer (kMod, "transposition PSOLA (" + juce::String (input.size() / sampleRate, 1) + " s)");
    const int n = static_cast<int> (input.size());
    if (n == 0)
        return {};

    const double defaultPeriod = sampleRate / options.defaultUnvoicedHz;
    auto periodAt = [&] (double sample) -> double
    {
        const float f0 = track.f0At (sample / sampleRate);
        return f0 > 0.0f ? sampleRate / f0 : defaultPeriod;
    };
    const auto& frames = track.frames;
    const int nf = static_cast<int> (frames.size());
    const double hopSamples = track.hopSec * sampleRate;

    // 1) Où la hauteur change-t-elle vraiment ? Une trame est « active » si elle est voisée et que son rapport s'écarte
    //    de 1 de plus de 2 cents. Un passage voisé entier est traité dès qu'une de ses trames est active (les bords des
    //    zones traitées tombent ainsi sur des consonnes ou des silences, jamais au milieu d'une note). Partout ailleurs
    //    (consonnes, souffle, silences, notes déjà justes), le son d'origine passe tel quel, à l'échantillon près.
    std::vector<char> active (static_cast<size_t> (nf), 0);
    for (int i = 0; i < nf;)
    {
        if (! frames[static_cast<size_t> (i)].voiced)
        {
            ++i;
            continue;
        }
        int j = i;
        bool any = false;
        for (; j < nf && frames[static_cast<size_t> (j)].voiced; ++j)
            any = any || (static_cast<size_t> (j) < ratioPerFrame.size() && std::abs (ratioPerFrame[static_cast<size_t> (j)] - 1.0f) > 0.0012f);
        if (any)
            std::fill (active.begin() + i, active.begin() + j, static_cast<char> (1));
        i = j;
    }
    // Zones en échantillons ; deux zones séparées par moins de 40 ms n'en font qu'une.
    std::vector<Region> regions;
    const int mergeGap = static_cast<int> (0.040 * sampleRate);
    for (int i = 0; i < nf;)
    {
        if (! active[static_cast<size_t> (i)])
        {
            ++i;
            continue;
        }
        int j = i;
        while (j < nf && active[static_cast<size_t> (j)])
            ++j;
        Region r;
        r.a = juce::jlimit (0, n, static_cast<int> (std::floor ((i - 0.5) * hopSamples)));
        r.b = juce::jlimit (0, n, static_cast<int> (std::ceil ((j - 0.5) * hopSamples)));
        if (! regions.empty() && r.a - regions.back().b < mergeGap)
            regions.back().b = r.b;
        else if (r.b > r.a)
            regions.push_back (r);
        i = j;
    }

    // 2) Base : le son d'origine (parties non voisées au gain demandé, fondu de 3 ms aux changements).
    Mono out (input);
    if (std::abs (options.unvoicedGain - 1.0f) > 1.0e-4f)
    {
        const float step = 1.0f / std::max (1.0f, static_cast<float> (0.003 * sampleRate));
        float g = track.voicedAt (0.0) ? 1.0f : options.unvoicedGain;
        for (int i = 0; i < n; ++i)
        {
            const float target = track.voicedAt (i / sampleRate) ? 1.0f : options.unvoicedGain;
            g += juce::jlimit (-step, step, target - g);
            out[static_cast<size_t> (i)] = input[static_cast<size_t> (i)] * g;
        }
    }
    if (regions.empty())
    {
        SV_LOG_INFO (kMod, "aucune hauteur à changer : son d'origine conservé tel quel"_u8);
        return out;
    }

    // Signal lissé (1 ms) pour caler la première marque d'un passage voisé sur une impulsion glottique.
    const int smoothLen = std::max (1, static_cast<int> (sampleRate * 0.001));
    std::vector<float> smooth (static_cast<size_t> (n));
    {
        double acc = 0.0;
        for (int i = 0; i < n; ++i)
        {
            acc += input[static_cast<size_t> (i)];
            if (i >= smoothLen)
                acc -= input[static_cast<size_t> (i - smoothLen)];
            smooth[static_cast<size_t> (i)] = static_cast<float> (acc / smoothLen);
        }
    }
    auto peakNear = [&] (int from, int to)
    {
        from = juce::jlimit (0, n - 1, from);
        to = juce::jlimit (from, n - 1, to);
        int best = from;
        for (int k = from; k <= to; ++k)
            if (smooth[static_cast<size_t> (k)] > smooth[static_cast<size_t> (best)])
                best = k;
        return best;
    };
    // Ressemblance de la forme d'onde autour de deux positions (corrélation normalisée), pas de 'stride' échantillons.
    auto similarity = [&] (int ref, int cand, int half, int stride)
    {
        double s = 0.0, e0 = 0.0, e1 = 0.0;
        for (int j = -half; j <= half; j += stride)
        {
            const double a = input[static_cast<size_t> (ref + j)], b = input[static_cast<size_t> (cand + j)];
            s += a * b;
            e0 += a * a;
            e1 += b * b;
        }
        return s / std::sqrt (e0 * e1 + 1.0e-20);
    };

    const int fade = std::max (8, static_cast<int> (0.005 * sampleRate));
    size_t totalMarks = 0;
    long processed = 0;
    std::vector<double> marks;
    std::vector<char> markVoiced;
    std::vector<double> acc, wsum;

    for (const auto& region : regions)
    {
        const int margin = fade + static_cast<int> (2.5 * std::max (periodAt (region.a), periodAt (region.b)));
        const int ea = std::max (0, region.a - margin), eb = std::min (n, region.b + margin);
        const int len = eb - ea;
        if (len <= 0)
            continue;
        processed += region.b - region.a;

        // 3) Marques d'analyse à position fractionnaire. La première se cale sur une crête ; les suivantes sont
        //    cherchées une période plus loin, là où la forme d'onde ressemble le plus à celle de la marque précédente
        //    (corrélation normalisée, sommet affiné par parabole) : la phase reste la même d'une marque à l'autre même
        //    quand la forme d'onde a deux crêtes voisines, ce qui évitait mal l'ancien calage sur le maximum.
        marks.clear();
        markVoiced.clear();
        double m = ea;
        if (track.voicedAt (ea / sampleRate))
            m = peakNear (ea, ea + static_cast<int> (periodAt (ea)));
        while (m < eb + 2.0 * defaultPeriod && m < n)
        {
            const bool v = track.voicedAt (m / sampleRate);
            marks.push_back (m);
            markVoiced.push_back (v ? 1 : 0);
            const double p = periodAt (m);
            double next = m + p;
            const bool nextVoiced = track.voicedAt (next / sampleRate);
            if (v && nextVoiced)
            {
                const int rp = static_cast<int> (std::lround (m)), c0 = static_cast<int> (std::lround (next));
                const int half = std::max (8, static_cast<int> (p * 0.5)), radius = std::max (2, static_cast<int> (p * 0.2));
                if (rp - half >= 0 && c0 + radius + 1 + half < n && c0 - radius - 1 - half >= 0)
                {
                    int best = c0;
                    double bestSim = -2.0;
                    for (int c = c0 - radius; c <= c0 + radius; ++c)
                    {
                        const double s = similarity (rp, c, half, 2);
                        if (s > bestSim)
                        {
                            bestSim = s;
                            best = c;
                        }
                    }
                    if (bestSim > 0.5)
                    {
                        const double s0 = similarity (rp, best - 1, half, 1), s1 = similarity (rp, best, half, 1), s2 = similarity (rp, best + 1, half, 1);
                        const double den = s0 - 2.0 * s1 + s2;
                        const double d = den < -1.0e-12 ? juce::jlimit (-0.5, 0.5, 0.5 * (s0 - s2) / den) : 0.0;
                        next = m + (best + d - rp);
                    }
                }
            }
            else if (! v && nextVoiced)
                next = peakNear (static_cast<int> (next - 0.5 * p), static_cast<int> (next + 0.5 * p));   // attaque d'un passage voisé
            m = std::max (m + 1.0, next);
        }
        totalMarks += marks.size();
        if (marks.size() < 2)
            continue;

        // 4) Synthèse : chaque grain (fenêtre de ±1 période autour d'une marque) est reposé à l'instant de synthèse ts,
        //    à position fractionnaire. ts avance de l'écart entre marques divisé par le rapport : à rapport 1 la sortie
        //    suit exactement l'entrée, et la gigue naturelle de la voix est conservée, ni plus ni moins.
        acc.assign (static_cast<size_t> (len), 0.0);
        wsum.assign (static_cast<size_t> (len), 0.0);
        double ts = marks.front();
        size_t nearest = 0;
        float h[kTaps];
        while (ts < eb && ts < n)
        {
            const double tSec = ts / sampleRate;
            const bool voiced = track.voicedAt (tSec);
            const float ratio = voiced ? std::max (0.25f, std::min (4.0f, ratioAt (track, ratioPerFrame, tSec))) : 1.0f;
            while (nearest + 1 < marks.size() && std::abs (marks[nearest + 1] - ts) <= std::abs (marks[nearest] - ts))
                ++nearest;
            while (nearest > 0 && std::abs (marks[nearest - 1] - ts) < std::abs (marks[nearest] - ts))
                --nearest;
            const double mk = marks[nearest];
            const double pa = nearest + 1 < marks.size() ? marks[nearest + 1] - mk : mk - marks[nearest - 1];
            const double half = std::max (2.0, pa);
            const float gain = markVoiced[nearest] ? 1.0f : options.unvoicedGain;
            const double shift = mk - ts;                       // la source est lue à dst + shift
            const double shiftFloor = std::floor (shift);
            const int si = static_cast<int> (shiftFloor);
            sincTaps (shift - shiftFloor, h);
            const bool direct = h[kTapCentre] == 1.0f;
            const int d0 = std::max (ea, static_cast<int> (std::ceil (ts - half))), d1 = std::min (eb - 1, static_cast<int> (std::floor (ts + half)));
            for (int dst = d0; dst <= d1; ++dst)
            {
                const double w = 0.5 + 0.5 * std::cos (juce::MathConstants<double>::pi * (dst - ts) / half);
                const int src = dst + si;
                double v = 0.0;
                if (direct)
                    v = src >= 0 && src < n ? input[static_cast<size_t> (src)] : 0.0f;
                else if (src - kTapCentre >= 0 && src - kTapCentre + kTaps <= n)
                {
                    const float* x = input.data() + (src - kTapCentre);
                    float s = 0.0f;
                    for (int k = 0; k < kTaps; ++k)
                        s += h[k] * x[k];
                    v = s;
                }
                else
                    for (int k = 0; k < kTaps; ++k)
                    {
                        const int idx = src - kTapCentre + k;
                        if (idx >= 0 && idx < n)
                            v += h[k] * input[static_cast<size_t> (idx)];
                    }
                acc[static_cast<size_t> (dst - ea)] += w * v * gain;
                wsum[static_cast<size_t> (dst - ea)] += w;
            }
            ts += std::max (1.0, pa / ratio);
        }

        // 5) Fondu de 5 ms entre le son d'origine et le son transposé aux bords de la zone.
        for (int i = ea; i < eb; ++i)
        {
            float g = 1.0f;
            if (i < region.a)
                g = region.a - i >= fade ? 0.0f : 1.0f - static_cast<float> (region.a - i) / static_cast<float> (fade);
            else if (i >= region.b)
                g = i - region.b >= fade ? 0.0f : 1.0f - static_cast<float> (i - region.b) / static_cast<float> (fade);
            if (g <= 0.0f)
                continue;
            const float y = static_cast<float> (acc[static_cast<size_t> (i - ea)] / std::max (0.6, wsum[static_cast<size_t> (i - ea)]));
            out[static_cast<size_t> (i)] = g * y + (1.0f - g) * out[static_cast<size_t> (i)];
        }
    }
    SV_LOG_INFO (kMod, juce::String (static_cast<int> (regions.size())) + " zone(s) transposée(s), "_u8
                       + juce::String (juce::roundToInt (100.0 * static_cast<double> (processed) / n)) + " % de la durée, "_u8
                       + juce::String (static_cast<int> (totalMarks)) + " marques ; le reste passe tel quel"_u8);
    return out;
}

Mono psolaShiftSemitones (const Mono& input, double sampleRate, const analysis::PitchTrack& track,
                          float semitones, const PsolaOptions& options)
{
    const float r = std::pow (2.0f, semitones / 12.0f);
    std::vector<float> ratios (track.frames.size(), r);
    return psolaShift (input, sampleRate, track, ratios, options);
}
} // namespace sv::dsp
