#include "Leveler.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

#include <algorithm>
#include <cmath>
#include <numeric>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Niveleur";

    // ----------------------------------------------------------------------------------------------
    // Niveau court terme : RMS par fenêtre (windowMs), pas = fenêtre / 4, trame centrée.
    struct ShortTerm
    {
        std::vector<float> levelDb;   // une valeur par pas
        int hop = 1;
        int window = 1;
    };

    ShortTerm shortTermLevels (const Mono& x, double sr, float windowMs)
    {
        ShortTerm st;
        st.window = std::max (64, static_cast<int> (sr * std::max (50.0f, windowMs) * 0.001));
        st.hop = std::max (16, st.window / 4);
        const int n = static_cast<int> (x.size());
        if (n == 0)
            return st;
        const int frames = (n + st.hop - 1) / st.hop;
        st.levelDb.resize (static_cast<size_t> (frames), -120.0f);
        // Somme cumulée des carrés : chaque fenêtre en O(1).
        std::vector<double> cum (static_cast<size_t> (n) + 1, 0.0);
        for (int i = 0; i < n; ++i)
            cum[static_cast<size_t> (i) + 1] = cum[static_cast<size_t> (i)] + static_cast<double> (x[static_cast<size_t> (i)]) * x[static_cast<size_t> (i)];
        for (int f = 0; f < frames; ++f)
        {
            const int centre = f * st.hop + st.hop / 2;
            const int a = std::max (0, centre - st.window / 2), b = std::min (n, centre + st.window / 2);
            if (b <= a)
                continue;
            const double ms = (cum[static_cast<size_t> (b)] - cum[static_cast<size_t> (a)]) / static_cast<double> (b - a);
            st.levelDb[static_cast<size_t> (f)] = gainToDb (static_cast<float> (std::sqrt (std::max (0.0, ms))));
        }
        return st;
    }

    float percentile (std::vector<float> v, float q)
    {
        if (v.empty())
            return -120.0f;
        std::sort (v.begin(), v.end());
        const size_t idx = static_cast<size_t> (juce::jlimit (0.0f, 1.0f, q) * static_cast<float> (v.size() - 1));
        return v[idx];
    }

    juce::String mmss (double sec)
    {
        const int s = std::max (0, juce::roundToInt (sec));
        return juce::String (s / 60) + ":" + juce::String (s % 60).paddedLeft ('0', 2);
    }

    std::vector<LevelSurge> surgesOf (const ShortTerm& st, double sr, float aboveDb, float gateDb)
    {
        std::vector<LevelSurge> out;
        std::vector<float> active;
        for (const float l : st.levelDb)
            if (l > gateDb)
                active.push_back (l);
        if (active.size() < 8)
            return out;
        const float median = percentile (active, 0.5f);
        const double hopSec = st.hop / sr;
        LevelSurge cur;
        bool open = false;
        for (size_t f = 0; f <= st.levelDb.size(); ++f)
        {
            const bool over = f < st.levelDb.size() && st.levelDb[f] > median + aboveDb;
            if (over)
            {
                if (! open)
                {
                    cur = {};
                    cur.startSec = f * hopSec;
                    open = true;
                }
                cur.endSec = (f + 1) * hopSec;
                cur.overDb = std::max (cur.overDb, st.levelDb[f] - median);
            }
            else if (open)
            {
                open = false;
                if (cur.endSec - cur.startSec >= 0.25)   // au moins un quart de seconde : pas une simple attaque
                    out.push_back (cur);
            }
        }
        return out;
    }

    float rangeDb (const ShortTerm& st, float gateDb)
    {
        std::vector<float> active;
        for (const float l : st.levelDb)
            if (l > gateDb)
                active.push_back (l);
        if (active.size() < 4)
            return 0.0f;
        return std::max (0.0f, percentile (active, 0.9f) - percentile (active, 0.1f));
    }

    /** Courbe de gain (dB par pas) lissée ; applique sur les canaux donnés par interpolation linéaire. */
    LevelerReport levelCore (const Mono& detector, std::vector<float*> channels, int numSamples, double sr, const LevelerSettings& s)
    {
        LevelerReport rep;
        if (! s.enabled || numSamples <= 0 || detector.empty())
            return rep;
        const auto st = shortTermLevels (detector, sr, s.windowMs);
        // Seuil d'activité : au-dessus du gate absolu ET à moins de 12 dB sous le niveau médian des passages :
        // respirations, queues de notes et bruit ne sont jamais amplifiés (ils suivent le gain tenu).
        float gateDb = s.targetDb - s.gateBelowTargetDb;
        {
            std::vector<float> above;
            for (const float l : st.levelDb)
                if (l > gateDb)
                    above.push_back (l);
            if (above.size() >= 4)
                gateDb = std::max (gateDb, percentile (above, 0.5f) - 12.0f);
        }
        rep.rangeBeforeDb = rangeDb (st, gateDb);
        int activeFrames = 0;
        for (const float l : st.levelDb)
            activeFrames += l > gateDb ? 1 : 0;
        if (activeFrames < 4)
        {
            SV_LOG_INFO (kMod, "Niveleur : trop peu de passages actifs, rien à faire"_u8);
            return rep;
        }

        // Gain souhaité par pas : cible - niveau, borné ; tenu (pas de montée) sur les silences.
        // Montée brusque (plus de surgeAboveDb au-dessus du niveau médian) : baisse autorisée jusqu'à surgeCutDb.
        const size_t frames = st.levelDb.size();
        std::vector<float> desired (frames, 0.0f);
        float median = s.targetDb;
        {
            std::vector<float> act;
            for (const float l : st.levelDb)
                if (l > gateDb)
                    act.push_back (l);
            median = percentile (act, 0.5f);
        }
        rep.surges = surgesOf (st, sr, s.surgeAboveDb, gateDb);
        float held = 0.0f;
        bool seen = false;
        for (size_t f = 0; f < frames; ++f)
        {
            const float l = st.levelDb[f];
            if (l > gateDb)
            {
                const float cut = l > median + s.surgeAboveDb ? std::max (s.maxCutDb, s.surgeCutDb) : s.maxCutDb;
                held = juce::jlimit (-cut, s.maxBoostDb, s.targetDb - l);
                seen = true;
            }
            desired[f] = seen ? held : 0.0f;
        }
        // Les silences avant le premier passage actif prennent le gain du premier passage (pas de saut).
        for (size_t f = 0; f < frames; ++f)
            if (st.levelDb[f] > gateDb)
            {
                for (size_t g = 0; g < f; ++g)
                    desired[g] = desired[f];
                break;
            }

        // Lissage asymétrique : baisse rapide (attaque) quand ça monte, remontée lente (relâche).
        const double hopSec = st.hop / sr;
        const float aAtt = static_cast<float> (std::exp (-hopSec / std::max (0.01, s.attackMs * 0.001)));
        const float aRel = static_cast<float> (std::exp (-hopSec / std::max (0.01, s.releaseMs * 0.001)));
        std::vector<float> gain (frames, 0.0f);
        float g = desired.empty() ? 0.0f : desired[0];
        for (size_t f = 0; f < frames; ++f)
        {
            const float target = desired[f];
            const float a = target < g ? aAtt : aRel;
            g = a * g + (1.0f - a) * target;
            gain[f] = g;
            if (st.levelDb[f] > gateDb)
            {
                rep.maxBoostDb = std::max (rep.maxBoostDb, g);
                rep.maxCutDb = std::max (rep.maxCutDb, -g);
                if (std::abs (g) > 0.5f)
                    ++rep.framesAdjusted;
            }
        }

        // Application : interpolation linéaire entre centres de pas.
        for (int i = 0; i < numSamples; ++i)
        {
            const float pos = (static_cast<float> (i) - st.hop * 0.5f) / static_cast<float> (st.hop);
            const int f0 = juce::jlimit (0, static_cast<int> (frames) - 1, static_cast<int> (std::floor (pos)));
            const int f1 = std::min (static_cast<int> (frames) - 1, f0 + 1);
            const float t = juce::jlimit (0.0f, 1.0f, pos - static_cast<float> (f0));
            const float gDb = gain[static_cast<size_t> (f0)] * (1.0f - t) + gain[static_cast<size_t> (f1)] * t;
            const float lin = dbToGain (gDb);
            for (auto* ch : channels)
                ch[i] *= lin;
        }
        rep.applied = true;
        return rep;
    }

    // ----------------------------------------------------------------------------------------------
    // Suppresseur de résonances : STFT 2048 / pas 512, bandes de 1/6 d'octave de 100 Hz à 16 kHz.
    constexpr int kOrder = 11;
    constexpr int kFft = 1 << kOrder;
    constexpr int kHop = kFft / 4;
    constexpr int kBins = kFft / 2 + 1;
    constexpr float kBandLoHz = 100.0f;
    constexpr int kBandsPerOctave = 3;   // tiers d'octave : les harmoniques rapprochées d'une voix ne ressortent pas comme des résonances

    struct BandLayout
    {
        std::vector<float> centreHz;
        std::vector<int> binLo, binHi;   // [lo, hi) par bande
    };

    BandLayout bandLayout (double sr)
    {
        BandLayout b;
        const float nyq = static_cast<float> (sr * 0.5);
        for (int k = 0;; ++k)
        {
            const float c = kBandLoHz * std::pow (2.0f, static_cast<float> (k) / kBandsPerOctave);
            if (c > std::min (16000.0f, nyq * 0.9f))
                break;
            const float lo = c * std::pow (2.0f, -0.5f / kBandsPerOctave), hi = c * std::pow (2.0f, 0.5f / kBandsPerOctave);
            int bl = static_cast<int> (std::floor (lo / static_cast<float> (sr) * kFft)), bh = static_cast<int> (std::ceil (hi / static_cast<float> (sr) * kFft));
            bl = juce::jlimit (1, kBins - 1, bl);
            bh = juce::jlimit (bl + 1, kBins, bh);
            b.centreHz.push_back (c);
            b.binLo.push_back (bl);
            b.binHi.push_back (bh);
        }
        return b;
    }

    struct Stft
    {
        juce::dsp::FFT fft { kOrder };
        std::vector<float> window;
        std::vector<float> buf;
        int n = 0, numFrames = 0;
        explicit Stft (int numSamples) : window (static_cast<size_t> (kFft)), buf (static_cast<size_t> (2 * kFft)), n (numSamples)
        {
            for (int i = 0; i < kFft; ++i)
                window[static_cast<size_t> (i)] = std::sqrt (0.5f - 0.5f * std::cos (2.0f * juce::MathConstants<float>::pi * i / kFft));
            numFrames = (n + kHop - 1) / kHop + 3;
        }
        int frameStart (int f) const { return f * kHop - kFft; }
        void forward (const float* x, int f)
        {
            const int start = frameStart (f);
            std::fill (buf.begin(), buf.end(), 0.0f);
            for (int i = 0; i < kFft; ++i)
            {
                const int idx = start + i;
                buf[static_cast<size_t> (i)] = (idx >= 0 && idx < n) ? x[idx] * window[static_cast<size_t> (i)] : 0.0f;
            }
            fft.performRealOnlyForwardTransform (buf.data(), true);
        }
        void inverseAdd (float* out, int f)
        {
            fft.performRealOnlyInverseTransform (buf.data());
            const int start = frameStart (f);
            for (int i = 0; i < kFft; ++i)
            {
                const int idx = start + i;
                if (idx >= 0 && idx < n)
                    out[idx] += buf[static_cast<size_t> (i)] * window[static_cast<size_t> (i)] * 0.5f;   // Hann au pas 1/4 : somme = 2
            }
        }
    };

    /** Niveau (dB) de chaque bande pour le spectre courant de stft.buf. */
    void bandLevels (const Stft& stft, const BandLayout& lay, std::vector<float>& out)
    {
        out.resize (lay.centreHz.size());
        for (size_t k = 0; k < lay.centreHz.size(); ++k)
        {
            double p = 0.0;
            for (int b = lay.binLo[k]; b < lay.binHi[k]; ++b)
            {
                const float re = stft.buf[static_cast<size_t> (2 * b)], im = stft.buf[static_cast<size_t> (2 * b + 1)];
                p += static_cast<double> (re) * re + static_cast<double> (im) * im;
            }
            p /= std::max (1, lay.binHi[k] - lay.binLo[k]);
            out[k] = 10.0f * std::log10 (static_cast<float> (p) + 1e-20f);
        }
    }

    /** Dépassement de chaque bande au-dessus de la moyenne de ses voisines (±1 octave, hors ±1 bande). */
    void excessAboveNeighbours (const std::vector<float>& lv, std::vector<float>& excess)
    {
        const int nb = static_cast<int> (lv.size());
        excess.assign (lv.size(), 0.0f);
        for (int k = 0; k < nb; ++k)
        {
            double sum = 0.0;
            int cnt = 0;
            for (int j = std::max (0, k - kBandsPerOctave); j <= std::min (nb - 1, k + kBandsPerOctave); ++j)
                if (j != k)
                {
                    sum += lv[static_cast<size_t> (j)];
                    ++cnt;
                }
            excess[static_cast<size_t> (k)] = cnt > 0 ? lv[static_cast<size_t> (k)] - static_cast<float> (sum / cnt) : 0.0f;
        }
    }

    float protection (float hz, const ResonanceSettings& s)
    {
        float p = 1.0f;
        if (hz < s.protectBelowHz)
            p *= juce::jlimit (0.0f, 1.0f, (hz - s.protectBelowHz * 0.5f) / (s.protectBelowHz * 0.5f));
        if (hz > s.softAboveHz)
            p *= juce::jlimit (0.3f, 1.0f, 1.0f - 0.7f * (hz - s.softAboveHz) / std::max (1.0f, 16000.0f - s.softAboveHz));
        return p;
    }

    /** Réductions (dB, >= 0) par trame et par bande, calculées sur le signal détecteur. */
    std::vector<std::vector<float>> resonanceReductions (const Mono& det, double sr, const ResonanceSettings& s, const BandLayout& lay, ResonanceReport& rep)
    {
        Stft stft (static_cast<int> (det.size()));
        std::vector<std::vector<float>> red (static_cast<size_t> (stft.numFrames), std::vector<float> (lay.centreHz.size(), 0.0f));
        std::vector<float> lv, ex, smooth (lay.centreHz.size(), 0.0f);
        const double hopSec = kHop / sr;
        const float aAtt = static_cast<float> (std::exp (-hopSec / std::max (0.001, s.attackMs * 0.001)));
        const float aRel = static_cast<float> (std::exp (-hopSec / std::max (0.001, s.releaseMs * 0.001)));
        // Seuil d'activité : trames à plus de 40 dB sous la trame la plus forte.
        std::vector<float> frameDb (static_cast<size_t> (stft.numFrames), -120.0f);
        float maxDb = -120.0f;
        std::vector<std::vector<float>> levels (static_cast<size_t> (stft.numFrames));
        for (int f = 0; f < stft.numFrames; ++f)
        {
            stft.forward (det.data(), f);
            bandLevels (stft, lay, lv);
            levels[static_cast<size_t> (f)] = lv;
            double e = 0.0;
            for (const float l : lv)
                e += std::pow (10.0, l / 10.0);
            frameDb[static_cast<size_t> (f)] = 10.0f * std::log10 (static_cast<float> (e) + 1e-20f);
            maxDb = std::max (maxDb, frameDb[static_cast<size_t> (f)]);
        }
        // Niveau habituel de chaque bande (moyenne sur les trames actives) : une harmonique toujours présente n'est pas
        // une résonance ; seule une bande qui dépasse ses voisines ET son propre niveau habituel est rabaissée.
        std::vector<float> usual (lay.centreHz.size(), -120.0f);
        {
            std::vector<double> acc (lay.centreHz.size(), 0.0);
            int cnt = 0;
            for (int f = 0; f < stft.numFrames; ++f)
                if (frameDb[static_cast<size_t> (f)] > maxDb - 40.0f)
                {
                    for (size_t k = 0; k < acc.size(); ++k)
                        acc[k] += levels[static_cast<size_t> (f)][k];
                    ++cnt;
                }
            if (cnt > 0)
                for (size_t k = 0; k < acc.size(); ++k)
                    usual[k] = static_cast<float> (acc[k] / cnt);
        }
        double meanSum = 0.0;
        int activeFrames = 0, reducedFrames = 0;
        for (int f = 0; f < stft.numFrames; ++f)
        {
            excessAboveNeighbours (levels[static_cast<size_t> (f)], ex);
            const bool active = frameDb[static_cast<size_t> (f)] > maxDb - 40.0f;
            float frameMax = 0.0f;
            for (size_t k = 0; k < ex.size(); ++k)
            {
                const float dyn = levels[static_cast<size_t> (f)][k] - usual[k] - 1.0f;   // dépassement de son niveau habituel
                const float want = active ? juce::jlimit (0.0f, s.maxReductionDb, std::min (ex[k] - s.thresholdDb, dyn)) * protection (lay.centreHz[k], s) : 0.0f;
                const float a = want > smooth[k] ? aAtt : aRel;
                smooth[k] = a * smooth[k] + (1.0f - a) * want;
                red[static_cast<size_t> (f)][k] = smooth[k];
                frameMax = std::max (frameMax, smooth[k]);
            }
            if (active)
            {
                ++activeFrames;
                meanSum += frameMax;
                if (frameMax > 0.5f)
                    ++reducedFrames;
                rep.maxReductionDb = std::max (rep.maxReductionDb, frameMax);
            }
        }
        rep.meanReductionDb = activeFrames > 0 ? static_cast<float> (meanSum / activeFrames) : 0.0f;
        rep.activeFraction = activeFrames > 0 ? static_cast<float> (reducedFrames) / static_cast<float> (activeFrames) : 0.0f;
        return red;
    }

    /** Applique les réductions à un canal (gain par bin interpolé entre centres de bandes, en log-fréquence). */
    void applyReductions (float* x, int n, double sr, const std::vector<std::vector<float>>& red, const BandLayout& lay, float mix)
    {
        Stft stft (n);
        std::vector<float> out (static_cast<size_t> (n), 0.0f);
        std::vector<float> binGain (static_cast<size_t> (kBins), 1.0f);
        const int nb = static_cast<int> (lay.centreHz.size());
        for (int f = 0; f < stft.numFrames; ++f)
        {
            stft.forward (x, f);
            const auto& r = red[static_cast<size_t> (f)];
            int k = 0;
            for (int b = 1; b < kBins; ++b)
            {
                const float hz = static_cast<float> (b) * static_cast<float> (sr) / kFft;
                while (k + 1 < nb && lay.centreHz[static_cast<size_t> (k) + 1] <= hz)
                    ++k;
                float dB;
                if (hz <= lay.centreHz[0])
                    dB = r[0] * juce::jlimit (0.0f, 1.0f, hz / lay.centreHz[0]);
                else if (k + 1 >= nb)
                    dB = r[static_cast<size_t> (nb) - 1];
                else
                {
                    const float l0 = std::log2 (lay.centreHz[static_cast<size_t> (k)]), l1 = std::log2 (lay.centreHz[static_cast<size_t> (k) + 1]);
                    const float t = juce::jlimit (0.0f, 1.0f, (std::log2 (hz) - l0) / std::max (1e-6f, l1 - l0));
                    dB = r[static_cast<size_t> (k)] * (1.0f - t) + r[static_cast<size_t> (k) + 1] * t;
                }
                binGain[static_cast<size_t> (b)] = dbToGain (-dB);
            }
            binGain[0] = 1.0f;
            for (int b = 0; b < kBins; ++b)
            {
                stft.buf[static_cast<size_t> (2 * b)] *= binGain[static_cast<size_t> (b)];
                stft.buf[static_cast<size_t> (2 * b + 1)] *= binGain[static_cast<size_t> (b)];
            }
            stft.inverseAdd (out.data(), f);
        }
        for (int i = 0; i < n; ++i)
            x[i] = x[i] * (1.0f - mix) + out[static_cast<size_t> (i)] * mix;
    }
}

// --------------------------------------------------------------------------------------------------
LevelerReport autoLevel (Mono& x, double sr, const LevelerSettings& s)
{
    log::ScopedTimer timer (kMod, "niveleur");
    auto rep = levelCore (x, { x.data() }, static_cast<int> (x.size()), sr, s);
    if (rep.applied)
    {
        rep.rangeAfterDb = rangeDb (shortTermLevels (x, sr, s.windowMs), s.targetDb - s.gateBelowTargetDb);
        SV_LOG_INFO (kMod, "Niveleur : étendue "_u8 + juce::String (rep.rangeBeforeDb, 1) + " -> " + juce::String (rep.rangeAfterDb, 1) + " dB, +"
                           + juce::String (rep.maxBoostDb, 1) + " / -" + juce::String (rep.maxCutDb, 1) + " dB max");
    }
    return rep;
}

LevelerReport autoLevelStereo (Stereo& x, double sr, const LevelerSettings& s)
{
    log::ScopedTimer timer (kMod, "niveleur stéréo"_u8);
    if (x.getNumChannels() < 1 || x.getNumSamples() == 0)
        return {};
    const Mono det = audio::toMono (x);
    std::vector<float*> chans;
    for (int c = 0; c < x.getNumChannels(); ++c)
        chans.push_back (x.getWritePointer (c));
    auto rep = levelCore (det, chans, x.getNumSamples(), sr, s);
    if (rep.applied)
    {
        rep.rangeAfterDb = rangeDb (shortTermLevels (audio::toMono (x), sr, s.windowMs), s.targetDb - s.gateBelowTargetDb);
        SV_LOG_INFO (kMod, "Niveleur stéréo : étendue "_u8 + juce::String (rep.rangeBeforeDb, 1) + " -> " + juce::String (rep.rangeAfterDb, 1) + " dB, +"
                           + juce::String (rep.maxBoostDb, 1) + " / -" + juce::String (rep.maxCutDb, 1) + " dB max");
    }
    return rep;
}

float shortTermRangeDb (const Mono& x, double sr, float windowMs, float gateDb)
{
    return rangeDb (shortTermLevels (x, sr, windowMs), gateDb);
}

std::vector<LevelSurge> levelSurges (const Mono& x, double sr, float aboveDb, float windowMs, float gateDb)
{
    return surgesOf (shortTermLevels (x, sr, windowMs), sr, aboveDb, gateDb);
}

juce::String LevelSurge::describe() const
{
    return "à "_u8 + mmss (startSec) + " (+" + juce::String (juce::roundToInt (overDb)) + " dB pendant " + juce::String (endSec - startSec, 1) + " s)";
}

ResonanceReport suppressResonances (Mono& x, double sr, const ResonanceSettings& s)
{
    log::ScopedTimer timer (kMod, "résonances"_u8);
    ResonanceReport rep;
    if (! s.enabled || static_cast<int> (x.size()) < kFft * 2 || s.maxReductionDb <= 0.0f || sr < 8000.0)
        return rep;
    const auto lay = bandLayout (sr);
    const auto red = resonanceReductions (x, sr, s, lay, rep);
    applyReductions (x.data(), static_cast<int> (x.size()), sr, red, lay, juce::jlimit (0.0f, 1.0f, s.mix));
    rep.applied = true;
    SV_LOG_INFO (kMod, "Résonances : réduction moyenne "_u8 + juce::String (rep.meanReductionDb, 1) + " dB, max " + juce::String (rep.maxReductionDb, 1)
                       + " dB sur " + juce::String (juce::roundToInt (rep.activeFraction * 100.0f)) + " % des trames actives");
    return rep;
}

ResonanceReport suppressResonancesStereo (Stereo& x, double sr, const ResonanceSettings& s)
{
    log::ScopedTimer timer (kMod, "résonances stéréo"_u8);
    ResonanceReport rep;
    const int n = x.getNumSamples();
    if (! s.enabled || n < kFft * 2 || s.maxReductionDb <= 0.0f || sr < 8000.0 || x.getNumChannels() < 1)
        return rep;
    const Mono det = audio::toMono (x);
    const auto lay = bandLayout (sr);
    const auto red = resonanceReductions (det, sr, s, lay, rep);
    for (int c = 0; c < x.getNumChannels(); ++c)
        applyReductions (x.getWritePointer (c), n, sr, red, lay, juce::jlimit (0.0f, 1.0f, s.mix));
    rep.applied = true;
    SV_LOG_INFO (kMod, "Résonances stéréo : réduction moyenne "_u8 + juce::String (rep.meanReductionDb, 1) + " dB, max " + juce::String (rep.maxReductionDb, 1) + " dB");
    return rep;
}

float resonanceExcessDb (const Mono& x, double sr)
{
    if (static_cast<int> (x.size()) < kFft * 2 || sr < 8000.0)
        return 0.0f;
    const auto lay = bandLayout (sr);
    ResonanceSettings s;
    s.enabled = true;
    s.thresholdDb = 0.0f;
    s.maxReductionDb = 40.0f;
    s.attackMs = 0.001f;
    s.releaseMs = 0.001f;
    s.protectBelowHz = 0.0f;
    s.softAboveHz = 20000.0f;
    ResonanceReport rep;
    resonanceReductions (x, sr, s, lay, rep);
    return rep.meanReductionDb;   // = dépassement moyen de la bande la plus saillante
}
} // namespace sv::dsp
