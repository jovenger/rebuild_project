#include "TestSignals.h"

#include "core/analysis/PitchDetector.h"
#include "core/dsp/Processors.h"

#include <algorithm>

namespace sv::test
{
namespace
{
    float formantGain (double f)
    {
        // Voyelle "a" : F1 730 Hz, F2 1090 Hz, F3 2440 Hz.
        auto peak = [] (double f, double fc, double bw) { return 1.0 / (1.0 + std::pow ((f - fc) / (bw * 0.5), 2.0)); };
        return static_cast<float> (0.03 + peak (f, 730, 160) + 0.5 * peak (f, 1090, 180) + 0.25 * peak (f, 2440, 250));
    }
}

Mono sine (double freqHz, double seconds, double sampleRate, float amplitude)
{
    Mono m (static_cast<size_t> (seconds * sampleRate));
    for (size_t i = 0; i < m.size(); ++i)
        m[i] = amplitude * static_cast<float> (std::sin (2.0 * juce::MathConstants<double>::pi * freqHz * static_cast<double> (i) / sampleRate));
    return m;
}

Mono synthVoice (const std::vector<VoicePhrase>& phrases, double sr, double leadInSec, float vibratoCents, juce::int64 seed)
{
    juce::Random rng (seed);
    double total = leadInSec;
    for (const auto& p : phrases)
    {
        for (const auto& n : p.notes)
            total += n.seconds;
        total += p.gapAfterSec + (p.sibilantAtEnd ? 0.15 : 0.0);
    }
    Mono out (static_cast<size_t> ((total + 0.5) * sr), 0.0f);
    // Bruit de fond très faible (micro réel).
    for (auto& v : out)
        v = (rng.nextFloat() * 2.0f - 1.0f) * 0.0003f;

    const double twoPi = 2.0 * juce::MathConstants<double>::pi;
    double t = leadInSec;
    for (const auto& phrase : phrases)
    {
        if (phrase.breathBefore)
        {
            // Respiration : bruit filtré 300 ms, faible, juste avant la phrase.
            const size_t a = static_cast<size_t> (std::max (0.0, t - 0.4) * sr);
            const size_t len = static_cast<size_t> (0.3 * sr);
            Mono br (len);
            for (auto& v : br)
                v = (rng.nextFloat() * 2.0f - 1.0f);
            dsp::lowPass (br, sr, 2500.0, 2);
            dsp::highPass (br, sr, 400.0, 2);
            for (size_t i = 0; i < len && a + i < out.size(); ++i)
            {
                const float env = std::sin (juce::MathConstants<float>::pi * static_cast<float> (i) / static_cast<float> (len));
                out[a + i] += br[i] * 0.03f * env;
            }
        }

        std::vector<double> phases (40, 0.0);
        for (size_t ni = 0; ni < phrase.notes.size(); ++ni)
        {
            const auto& note = phrase.notes[ni];
            const size_t a = static_cast<size_t> (t * sr);
            const size_t len = static_cast<size_t> (note.seconds * sr);
            const double baseHz = 440.0 * std::pow (2.0, (note.midi + note.centsOffset / 100.0 - 69.0) / 12.0);
            for (size_t i = 0; i < len && a + i < out.size(); ++i)
            {
                const double tt = static_cast<double> (i) / sr;
                const double vib = tt > 0.15 ? vibratoCents * std::sin (twoPi * 5.5 * tt) : 0.0;
                const double f0 = baseHz * std::pow (2.0, vib / 1200.0);
                double s = 0.0;
                for (int k = 1; k < 40; ++k)
                {
                    const double fk = f0 * k;
                    if (fk > 7000.0)
                        break;
                    phases[static_cast<size_t> (k)] += twoPi * fk / sr;
                    s += formantGain (fk) / std::pow (static_cast<double> (k), 0.7) * std::sin (phases[static_cast<size_t> (k)]);
                }
                // Enveloppe de syllabe : attaque 15 ms, creux entre syllabes.
                const double att = std::min (1.0, tt / 0.015);
                const double rel = std::min (1.0, (note.seconds - tt) / 0.04);
                const double env = att * std::max (0.25, rel);
                out[a + i] += static_cast<float> (s * 0.12 * env);
            }
            // Consonne d'attaque : petit bruit aigu.
            Mono cons (static_cast<size_t> (0.02 * sr));
            for (auto& v : cons)
                v = rng.nextFloat() * 2.0f - 1.0f;
            dsp::highPass (cons, sr, 2000.0, 2);
            for (size_t i = 0; i < cons.size() && a + i < out.size(); ++i)
                out[a + i] += cons[i] * 0.02f;
            t += note.seconds;
        }

        if (phrase.sibilantAtEnd)
        {
            const size_t a = static_cast<size_t> (t * sr);
            const size_t len = static_cast<size_t> (0.12 * sr);
            Mono s (len);
            for (auto& v : s)
                v = rng.nextFloat() * 2.0f - 1.0f;
            dsp::highPass (s, sr, 5000.0, 4);
            for (size_t i = 0; i < len && a + i < out.size(); ++i)
            {
                const float env = std::sin (juce::MathConstants<float>::pi * static_cast<float> (i) / static_cast<float> (len));
                out[a + i] += s[i] * 0.25f * env;
            }
            t += 0.15;
        }
        t += phrase.gapAfterSec;
    }
    return out;
}

Stereo synthInstru (double bpm, const MusicalKey& key, int bars, double sr, bool chorusEnergy, juce::int64 seed)
{
    juce::Random rng (seed);
    const double beat = 60.0 / bpm;
    const double total = bars * 4 * beat + 1.0;
    const int n = static_cast<int> (total * sr);
    Stereo out = makeStereo (n);
    const double twoPi = 2.0 * juce::MathConstants<double>::pi;
    const auto scale = key.scale();
    const int degrees[4] = { 0, key.minor ? 5 : 4, key.minor ? 2 : 5, key.minor ? 6 : 3 };

    auto add = [&] (int ch, long idx, float v)
    {
        if (idx >= 0 && idx < n)
            out.addSample (ch, static_cast<int> (idx), v);
    };

    for (int bar = 0; bar < bars; ++bar)
    {
        // Refrain : mesures 8-15 et 24-31 (sur un motif de 16 mesures).
        const bool chorus = chorusEnergy && (bar % 16) >= 8;
        const double barStart = bar * 4 * beat;
        const int degree = degrees[bar % 4];

        for (int b = 0; b < 4; ++b)
        {
            const long s = static_cast<long> ((barStart + b * beat) * sr);
            if (b == 0 || b == 2)
            {
                // Grosse caisse.
                double ph = 0.0;
                for (int i = 0; i < static_cast<int> (0.25 * sr); ++i)
                {
                    const double tt = i / sr;
                    const double f = 50.0 + 70.0 * std::exp (-tt / 0.03);
                    ph += twoPi * f / sr;
                    const float v = static_cast<float> (0.8 * std::sin (ph) * std::exp (-tt / 0.15));
                    add (0, s + i, v);
                    add (1, s + i, v);
                }
            }
            else
            {
                // Caisse claire.
                for (int i = 0; i < static_cast<int> (0.2 * sr); ++i)
                {
                    const double tt = i / sr;
                    const float noise = (rng.nextFloat() * 2.0f - 1.0f);
                    const float v = static_cast<float> ((0.35 * noise + 0.2 * std::sin (twoPi * 190.0 * tt)) * std::exp (-tt / 0.07));
                    add (0, s + i, v * (chorus ? 1.2f : 1.0f));
                    add (1, s + i, v * (chorus ? 1.2f : 1.0f));
                }
            }
            // Charleston (croches, doubles croches au refrain).
            const int subdiv = chorus ? 4 : 2;
            for (int h = 0; h < subdiv; ++h)
            {
                const long hs = s + static_cast<long> (h * beat / subdiv * sr);
                float prev = 0.0f;
                for (int i = 0; i < static_cast<int> (0.04 * sr); ++i)
                {
                    const float noise = rng.nextFloat() * 2.0f - 1.0f;
                    const float hp = noise - prev;   // passe-haut grossier
                    prev = noise;
                    const float v = 0.06f * hp * static_cast<float> (std::exp (-(i / sr) / 0.012));
                    add (0, hs + i, v);
                    add (1, hs + i, v * 0.8f);
                }
            }
        }

        // Basse et accord.
        const int rootPc = scale[static_cast<size_t> (degree)];
        const double bassHz = 440.0 * std::pow (2.0, ((36 + rootPc) - 69.0) / 12.0);
        std::array<double, 3> chordHz {};
        for (int c = 0; c < 3; ++c)
        {
            const int d = (degree + 2 * c) % 7;
            const int midi = 60 + scale[static_cast<size_t> (d)];   // Do 4 à Si 4 (renversements)
            chordHz[static_cast<size_t> (c)] = 440.0 * std::pow (2.0, (midi - 69.0) / 12.0);
        }
        const long bs = static_cast<long> (barStart * sr);
        const int barLen = static_cast<int> (4 * beat * sr);
        const float padGain = chorus ? 0.07f : 0.045f;
        for (int i = 0; i < barLen; ++i)
        {
            const double tt = i / sr;
            const double env = std::min (1.0, tt / 0.05) * std::min (1.0, (4 * beat - tt) / 0.05);
            const float bass = static_cast<float> (0.35 * env * (std::sin (twoPi * bassHz * tt) + 0.3 * std::sin (twoPi * 2 * bassHz * tt)));
            float padL = 0.0f, padR = 0.0f;
            for (double f : chordHz)
            {
                for (int h = 1; h <= 3; ++h)
                {
                    padL += static_cast<float> (std::sin (twoPi * f * h * 1.002 * tt) / h);
                    padR += static_cast<float> (std::sin (twoPi * f * h * 0.998 * tt) / h);
                }
                if (chorus)
                {
                    padL += 0.5f * static_cast<float> (std::sin (twoPi * f * 2.0 * tt));
                    padR += 0.5f * static_cast<float> (std::sin (twoPi * f * 2.0 * tt));
                }
            }
            add (0, bs + i, bass + padGain * static_cast<float> (env) * padL);
            add (1, bs + i, bass + padGain * static_cast<float> (env) * padR);
        }
    }

    const float pk = std::max (out.getMagnitude (0, 0, n), out.getMagnitude (1, 0, n));
    if (pk > 0.0f)
        out.applyGain (0.7f / pk);
    return out;
}

std::vector<VoicePhrase> defaultPhrases (const MusicalKey& key, double bpm, float detuneCents)
{
    const auto scale = key.scale();
    const double beat = 60.0 / bpm;
    // Tonique à l'octave 3 (La 3 = 57 pour La).
    auto noteOf = [&] (int degree)
    {
        const int d = ((degree % 7) + 7) % 7;
        const int oct = degree >= 7 ? 12 : 0;
        int midi = 48 + scale[static_cast<size_t> (d)] + oct;
        if (scale[static_cast<size_t> (d)] < key.root)
            midi += 12;
        return static_cast<float> (midi);
    };
    const int patterns[4][4] = { { 0, 2, 4, 2 }, { 4, 5, 4, 2 }, { 0, 1, 2, 0 }, { 2, 4, 5, 4 } };
    std::vector<VoicePhrase> phrases;
    for (int p = 0; p < 4; ++p)
    {
        VoicePhrase ph;
        for (int k = 0; k < 4; ++k)
            ph.notes.push_back ({ noteOf (patterns[p][k]), beat, detuneCents });
        ph.gapAfterSec = 0.7;
        ph.sibilantAtEnd = (p == 1);
        ph.breathBefore = (p == 2);
        phrases.push_back (ph);
    }
    return phrases;
}

float medianF0 (const Mono& x, double sampleRate, double fromSec, double toSec)
{
    const auto track = analysis::detectPitch (x, sampleRate);
    std::vector<float> f;
    for (size_t i = 0; i < track.frames.size(); ++i)
    {
        const double t = static_cast<double> (i) * track.hopSec;
        if (t < fromSec || t > toSec || ! track.frames[i].voiced)
            continue;
        f.push_back (track.frames[i].f0);
    }
    if (f.empty())
        return 0.0f;
    std::nth_element (f.begin(), f.begin() + static_cast<long> (f.size() / 2), f.end());
    return f[f.size() / 2];
}
} // namespace sv::test
