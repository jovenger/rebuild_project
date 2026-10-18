#include "Processors.h"

#include "../AudioIO.h"
#include "../Log.h"

#include <juce_dsp/juce_dsp.h>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "DSP";
    constexpr float kReverbCalibration = 0.45f;   // mesuré : +6,9 dB sans correction

    struct Rbj
    {
        double cosw, sinw, alpha, A;
        Rbj (double sr, double freq, double q, double gainDb)
        {
            const double f = juce::jlimit (10.0, sr * 0.49, freq);
            const double w0 = 2.0 * juce::MathConstants<double>::pi * f / sr;
            cosw = std::cos (w0);
            sinw = std::sin (w0);
            alpha = sinw / (2.0 * std::max (0.05, q));
            A = std::pow (10.0, gainDb / 40.0);
        }
    };

    Biquad normalise (double b0, double b1, double b2, double a0, double a1, double a2)
    {
        Biquad b;
        b.b0 = b0 / a0;
        b.b1 = b1 / a0;
        b.b2 = b2 / a0;
        b.a1 = a1 / a0;
        b.a2 = a2 / a0;
        return b;
    }

    // Suiveur d'enveloppe crête (en linéaire), temps en ms.
    struct EnvFollower
    {
        float att, rel, env = 0.0f;
        EnvFollower (double sr, float attackMs, float releaseMs)
            : att (static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, attackMs) * 0.001)))),
              rel (static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, releaseMs) * 0.001))))
        {
        }
        inline float process (float x) noexcept
        {
            const float a = std::abs (x);
            env = a > env ? att * env + (1.0f - att) * a : rel * env + (1.0f - rel) * a;
            return env;
        }
    };

    // Lissage d'une réduction de gain (dB) : attaque quand la réduction augmente.
    struct GainSmoother
    {
        float att, rel, value = 0.0f;
        GainSmoother (double sr, float attackMs, float releaseMs)
            : att (static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, attackMs) * 0.001)))),
              rel (static_cast<float> (std::exp (-1.0 / (sr * std::max (0.01f, releaseMs) * 0.001))))
        {
        }
        inline float process (float target) noexcept
        {
            value = target > value ? att * value + (1.0f - att) * target : rel * value + (1.0f - rel) * target;
            return value;
        }
    };

    void linkwitzRiley (const Mono& x, double sr, double freq, Mono& low, Mono& high)
    {
        low = x;
        high = x;
        for (int stage = 0; stage < 2; ++stage)
        {
            applyBiquad (low, Biquad::lowPass (sr, freq, 0.70710678));
            applyBiquad (high, Biquad::highPass (sr, freq, 0.70710678));
        }
    }

    float rmsActiveDb (const Mono& x, double sr)
    {
        const int frame = std::max (1, static_cast<int> (sr * 0.05));
        std::vector<float> dbs;
        for (size_t s = 0; s + static_cast<size_t> (frame) <= x.size(); s += static_cast<size_t> (frame))
            dbs.push_back (gainToDb (audio::rms (x.data() + s, static_cast<size_t> (frame))));
        if (dbs.empty())
            return gainToDb (audio::rms (x.data(), x.size()));
        const float mx = *std::max_element (dbs.begin(), dbs.end());
        double e = 0.0;
        int c = 0;
        for (float d : dbs)
            if (d > mx - 40.0f && d > -90.0f)
            {
                e += std::pow (10.0, d / 10.0);
                ++c;
            }
        return c > 0 ? static_cast<float> (10.0 * std::log10 (e / c)) : -120.0f;
    }
}

// ---------------------------------------------------------------------------------------------
Biquad Biquad::highPass (double sr, double freq, double q)
{
    const Rbj r (sr, freq, q, 0.0);
    return normalise ((1 + r.cosw) / 2, -(1 + r.cosw), (1 + r.cosw) / 2, 1 + r.alpha, -2 * r.cosw, 1 - r.alpha);
}

Biquad Biquad::lowPass (double sr, double freq, double q)
{
    const Rbj r (sr, freq, q, 0.0);
    return normalise ((1 - r.cosw) / 2, 1 - r.cosw, (1 - r.cosw) / 2, 1 + r.alpha, -2 * r.cosw, 1 - r.alpha);
}

Biquad Biquad::peak (double sr, double freq, double q, double gainDb)
{
    const Rbj r (sr, freq, q, gainDb);
    return normalise (1 + r.alpha * r.A, -2 * r.cosw, 1 - r.alpha * r.A, 1 + r.alpha / r.A, -2 * r.cosw, 1 - r.alpha / r.A);
}

Biquad Biquad::lowShelf (double sr, double freq, double q, double gainDb)
{
    const Rbj r (sr, freq, q, gainDb);
    const double A = r.A, c = r.cosw, sa = 2 * std::sqrt (A) * r.alpha;
    return normalise (A * ((A + 1) - (A - 1) * c + sa), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sa),
                      (A + 1) + (A - 1) * c + sa, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sa);
}

Biquad Biquad::highShelf (double sr, double freq, double q, double gainDb)
{
    const Rbj r (sr, freq, q, gainDb);
    const double A = r.A, c = r.cosw, sa = 2 * std::sqrt (A) * r.alpha;
    return normalise (A * ((A + 1) + (A - 1) * c + sa), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sa),
                      (A + 1) - (A - 1) * c + sa, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sa);
}

Biquad Biquad::bandPass (double sr, double freq, double q)
{
    const Rbj r (sr, freq, q, 0.0);
    return normalise (r.alpha, 0.0, -r.alpha, 1 + r.alpha, -2 * r.cosw, 1 - r.alpha);
}

void applyBiquad (Mono& x, Biquad f)
{
    f.reset();
    for (auto& v : x)
        v = f.process (v);
}

void highPass (Mono& x, double sr, double freq, int order)
{
    if (freq <= 0.0)
        return;
    if (order >= 4)
    {
        applyBiquad (x, Biquad::highPass (sr, freq, 0.54119610));
        applyBiquad (x, Biquad::highPass (sr, freq, 1.30656296));
    }
    else
    {
        applyBiquad (x, Biquad::highPass (sr, freq, 0.70710678));
    }
}

void lowPass (Mono& x, double sr, double freq, int order)
{
    if (freq <= 0.0 || freq >= sr * 0.49)
        return;
    if (order >= 4)
    {
        applyBiquad (x, Biquad::lowPass (sr, freq, 0.54119610));
        applyBiquad (x, Biquad::lowPass (sr, freq, 1.30656296));
    }
    else
    {
        applyBiquad (x, Biquad::lowPass (sr, freq, 0.70710678));
    }
}

// ---------------------------------------------------------------------------------------------
void applyEq (Mono& x, double sr, const EqSettings& eq)
{
    highPass (x, sr, eq.lowCutHz, 4);
    if (std::abs (eq.lowShelfDb) > 0.05f)
        applyBiquad (x, Biquad::lowShelf (sr, eq.lowShelfHz, 0.707, eq.lowShelfDb));
    if (std::abs (eq.mudDb) > 0.05f)
        applyBiquad (x, Biquad::peak (sr, eq.mudHz, eq.mudQ, eq.mudDb));
    if (std::abs (eq.presenceDb) > 0.05f)
        applyBiquad (x, Biquad::peak (sr, eq.presenceHz, eq.presenceQ, eq.presenceDb));
    if (std::abs (eq.airDb) > 0.05f)
        applyBiquad (x, Biquad::highShelf (sr, eq.airHz, 0.707, eq.airDb));
    if (eq.highCutHz > 0.0f)
        lowPass (x, sr, eq.highCutHz, 2);
}

void applyCurveEq (Mono& x, double sr, const std::vector<float>& centersHz, const std::vector<float>& gainsDb)
{
    if (centersHz.size() != gainsDb.size())
        return;
    static const float octaves[] = { 31.5f, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 };
    int applied = 0;
    for (float oc : octaves)
    {
        // gain de la bande en tiers d'octave la plus proche
        size_t best = 0;
        float bestDist = 1.0e9f;
        for (size_t i = 0; i < centersHz.size(); ++i)
        {
            const float d = std::abs (std::log2 (centersHz[i] / oc));
            if (d < bestDist)
            {
                bestDist = d;
                best = i;
            }
        }
        const float g = gainsDb[best];
        if (std::abs (g) > 0.2f && oc < sr * 0.45)
        {
            applyBiquad (x, Biquad::peak (sr, oc, 1.41, g));
            ++applied;
        }
    }
    SV_LOG_DEBUG (kMod, "EQ de référence : "_u8 + juce::String (applied) + " bandes appliquées"_u8);
}

// ---------------------------------------------------------------------------------------------
float compress (Mono& x, double sr, const CompressorSettings& c)
{
    if (c.ratio <= 1.0f || x.empty())
        return 0.0f;

    const float T = c.thresholdDb, R = c.ratio, W = std::max (0.0f, c.kneeDb);
    GainSmoother smoother (sr, c.attackMs, c.releaseMs);
    const float makeup = dbToGain (c.makeupDb);
    const int rmsLen = std::max (1, static_cast<int> (sr * 0.01));
    double sq = 0.0;
    double grSum = 0.0;
    long grCount = 0;
    // Le détecteur lit une copie non modifiée : la fenêtre RMS ne doit jamais contenir
    // des échantillons déjà compressés (sinon l'estimation de niveau dérive).
    const Mono dry = x;

    for (size_t i = 0; i < x.size(); ++i)
    {
        float levelDb;
        if (c.rmsDetector)
        {
            sq += static_cast<double> (dry[i]) * dry[i];
            if (i >= static_cast<size_t> (rmsLen))
                sq -= static_cast<double> (dry[i - static_cast<size_t> (rmsLen)]) * dry[i - static_cast<size_t> (rmsLen)];
            levelDb = gainToDb (static_cast<float> (std::sqrt (std::max (0.0, sq) / rmsLen)));
        }
        else
        {
            levelDb = gainToDb (std::abs (dry[i]));
        }

        float outDb;
        const float over = levelDb - T;
        if (2.0f * over < -W)
            outDb = levelDb;
        else if (2.0f * std::abs (over) <= W && W > 0.0f)
            outDb = levelDb + (1.0f / R - 1.0f) * std::pow (over + W * 0.5f, 2.0f) / (2.0f * W);
        else
            outDb = T + over / R;

        const float gr = smoother.process (std::max (0.0f, levelDb - outDb));
        x[i] *= dbToGain (-gr) * makeup;
        if (levelDb > T - 20.0f)
        {
            grSum += gr;
            ++grCount;
        }
    }

    if (c.mix < 0.999f)
        for (size_t i = 0; i < x.size(); ++i)
            x[i] = dry[i] * (1.0f - c.mix) + x[i] * c.mix;

    return grCount > 0 ? static_cast<float> (grSum / grCount) : 0.0f;
}

// ---------------------------------------------------------------------------------------------
float deEss (Mono& x, double sr, const DeEsserSettings& d)
{
    if (d.amount <= 0.0f || x.empty() || d.freqHz >= sr * 0.45)
        return 0.0f;

    Mono low, high;
    linkwitzRiley (x, sr, d.freqHz, low, high);
    EnvFollower fullEnv (sr, 0.5f, 30.0f), highEnv (sr, 0.5f, 30.0f);
    GainSmoother smoother (sr, 1.0f, 40.0f);
    double grSum = 0.0;
    long grCount = 0;

    for (size_t i = 0; i < x.size(); ++i)
    {
        const float fe = gainToDb (fullEnv.process (x[i]));
        const float he = gainToDb (highEnv.process (high[i]));
        const float excess = he - (fe + d.offsetDb);
        const float target = juce::jlimit (0.0f, d.maxReductionDb, excess * d.amount * 1.5f);
        const float gr = smoother.process (target);
        x[i] = low[i] + high[i] * dbToGain (-gr);
        if (gr > 0.5f)
        {
            grSum += gr;
            ++grCount;
        }
    }
    return grCount > 0 ? static_cast<float> (grSum / grCount) : 0.0f;
}

// ---------------------------------------------------------------------------------------------
void saturate (Mono& x, double sr, const SaturationSettings& s)
{
    juce::ignoreUnused (sr);
    if (s.mix <= 0.001f || x.empty())
        return;

    const float drive = dbToGain (s.driveDb);
    const float bias = s.asymmetry * 0.3f;
    const float biasOut = std::tanh (bias);
    const float dryRms = audio::rms (x.data(), x.size());

    juce::dsp::Oversampling<float> os (1, 1, juce::dsp::Oversampling<float>::filterHalfBandFIREquiripple, true, true);
    constexpr int block = 512;
    os.initProcessing (block);
    const int latency = static_cast<int> (std::round (os.getLatencyInSamples()));

    const size_t n = x.size();
    Mono padded (n + static_cast<size_t> (latency + block), 0.0f);
    std::copy (x.begin(), x.end(), padded.begin());
    Mono wet (padded.size(), 0.0f);

    for (size_t start = 0; start < padded.size(); start += block)
    {
        const size_t len = std::min (static_cast<size_t> (block), padded.size() - start);
        std::copy (padded.begin() + static_cast<long> (start), padded.begin() + static_cast<long> (start + len),
                   wet.begin() + static_cast<long> (start));
        float* chans[1] = { wet.data() + start };
        juce::dsp::AudioBlock<float> blk (chans, 1, len);
        auto up = os.processSamplesUp (juce::dsp::AudioBlock<const float> (blk));
        float* u = up.getChannelPointer (0);
        for (size_t i = 0; i < up.getNumSamples(); ++i)
            u[i] = std::tanh (drive * u[i] + bias) - biasOut;
        os.processSamplesDown (blk);
    }

    // Compensation de latence et de niveau.
    Mono shaped (n);
    for (size_t i = 0; i < n; ++i)
        shaped[i] = wet[i + static_cast<size_t> (latency)];
    const float wetRms = audio::rms (shaped.data(), n);
    const float comp = wetRms > 1.0e-9f ? dryRms / wetRms : 1.0f;

    // Retrait du continu introduit par l'asymétrie.
    Biquad dc = Biquad::highPass (sr, 15.0, 0.707);
    for (size_t i = 0; i < n; ++i)
    {
        const float w = dc.process (shaped[i] * comp);
        x[i] = x[i] * (1.0f - s.mix) + w * s.mix;
    }
}

// ---------------------------------------------------------------------------------------------
CleanReport clean (Mono& x, double sr, const CleanSettings& s, const analysis::PitchTrack& track,
                   const analysis::VoiceActivity& va)
{
    CleanReport report;
    report.noiseFloorDb = va.noiseFloorDb;
    if (! s.enabled || x.empty())
        return report;
    log::ScopedTimer timer (kMod, "nettoyage voix");

    highPass (x, sr, s.hpfHz, 4);

    // 1) Anti-plosives : réduction dynamique de la bande < 150 Hz pendant les bouffées.
    if (s.dePlosive)
    {
        Mono low, high;
        linkwitzRiley (x, sr, 150.0, low, high);
        EnvFollower lowEnv (sr, 1.0f, 20.0f), slowEnv (sr, 200.0f, 200.0f), fullEnv (sr, 1.0f, 20.0f);
        GainSmoother smoother (sr, 1.0f, 60.0f);
        bool inPlosive = false;
        for (size_t i = 0; i < x.size(); ++i)
        {
            const float le = gainToDb (lowEnv.process (low[i]));
            const float se = gainToDb (slowEnv.process (low[i]));
            const float fe = gainToDb (fullEnv.process (x[i]));
            const bool burst = le > se + 9.0f && le > fe - 6.0f && le > va.thresholdDb;
            const float target = burst ? std::min (18.0f, le - se) : 0.0f;
            if (burst && ! inPlosive)
                ++report.plosivesTreated;
            inPlosive = burst;
            const float gr = smoother.process (target);
            x[i] = low[i] * dbToGain (-gr) + high[i];
        }
    }

    // 2) Respirations : zones non voisées, assez fortes pour être entendues, peu d'aigus (pas un "s").
    if (s.breathReductionDb > 0.0f && ! va.envDb.empty())
    {
        Mono highBand = x;
        highPass (highBand, sr, 4000.0, 2);
        const int frame = std::max (1, static_cast<int> (sr * va.frameSec));
        const int nf = static_cast<int> (va.envDb.size());
        float phraseLevel = -30.0f;
        if (! va.phrases.empty())
        {
            double e = 0.0;
            for (const auto& p : va.phrases)
                e += std::pow (10.0, p.levelDb / 10.0);
            phraseLevel = static_cast<float> (10.0 * std::log10 (e / va.phrases.size()));
        }
        const float g = dbToGain (-s.breathReductionDb);
        for (int f = 0; f < nf;)
        {
            const float db = va.envDb[static_cast<size_t> (f)];
            const bool candidate = ! track.voicedAt ((f + 0.5) * va.frameSec)
                                   && db > va.noiseFloorDb + 6.0f && db < phraseLevel - 10.0f;
            if (! candidate)
            {
                ++f;
                continue;
            }
            int e = f;
            while (e < nf && ! track.voicedAt ((e + 0.5) * va.frameSec)
                   && va.envDb[static_cast<size_t> (e)] > va.noiseFloorDb + 6.0f
                   && va.envDb[static_cast<size_t> (e)] < phraseLevel - 10.0f)
                ++e;
            const double dur = (e - f) * va.frameSec;
            const size_t a = static_cast<size_t> (f) * static_cast<size_t> (frame);
            const size_t b = std::min (x.size(), static_cast<size_t> (e) * static_cast<size_t> (frame));
            if (dur >= 0.15 && dur <= 0.9 && b > a)
            {
                const float total = audio::rms (x.data() + a, b - a);
                const float hi = audio::rms (highBand.data() + a, b - a);
                const float highRatio = total > 1.0e-9f ? (hi * hi) / (total * total) : 1.0f;
                if (highRatio < 0.35f)
                {
                    const size_t fade = std::min ((b - a) / 4, static_cast<size_t> (sr * 0.01));
                    for (size_t i = a; i < b; ++i)
                    {
                        float w = 1.0f;
                        if (i < a + fade)
                            w = static_cast<float> (i - a) / static_cast<float> (fade);
                        else if (i >= b - fade)
                            w = static_cast<float> (b - i) / static_cast<float> (fade);
                        x[i] *= 1.0f - (1.0f - g) * w;
                    }
                    ++report.breathsTreated;
                }
            }
            f = std::max (e, f + 1);
        }
    }

    // 3) Porte douce (expandeur 2:1) sous le seuil d'activité.
    if (s.gateRangeDb > 0.0f)
    {
        const float thr = va.thresholdDb - 6.0f;
        EnvFollower env (sr, 1.0f, 50.0f);
        GainSmoother smoother (sr, 1.0f, 80.0f);
        const int holdSamples = static_cast<int> (sr * 0.05);
        int hold = 0;
        for (size_t i = 0; i < x.size(); ++i)
        {
            const float e = gainToDb (env.process (x[i]));
            float target = 0.0f;
            if (e < thr)
            {
                if (hold > 0)
                    --hold;
                else
                    target = std::min (s.gateRangeDb, thr - e);
            }
            else
            {
                hold = holdSamples;
            }
            x[i] *= dbToGain (-smoother.process (target));
        }
    }

    SV_LOG_INFO (kMod, "Nettoyage : " + juce::String (report.plosivesTreated) + " plosives, "
                       + juce::String (report.breathsTreated) + " respirations atténuées, bruit de fond "_u8
                       + juce::String (report.noiseFloorDb, 1) + " dB");
    return report;
}

// ---------------------------------------------------------------------------------------------
Stereo reverbReturn (const Mono& x, double sr, const ReverbSettings& r)
{
    Stereo out = makeStereo (static_cast<int> (x.size()));
    if (r.send <= 0.0001f || x.empty())
        return out;

    const size_t pre = static_cast<size_t> (std::max (0.0f, r.preDelayMs) * 0.001 * sr);
    Mono in (x.size(), 0.0f);
    for (size_t i = pre; i < x.size(); ++i)
        in[i] = x[i - pre];
    highPass (in, sr, r.hpfHz, 2);
    lowPass (in, sr, r.lpfHz, 2);

    juce::Reverb reverb;
    reverb.setSampleRate (sr);
    juce::Reverb::Parameters p;
    p.roomSize = juce::jlimit (0.0f, 1.0f, r.roomSize);
    p.damping = juce::jlimit (0.0f, 1.0f, r.damping);
    p.width = juce::jlimit (0.0f, 1.0f, r.width);
    p.wetLevel = 1.0f;
    p.dryLevel = 0.0f;
    p.freezeMode = 0.0f;
    reverb.setParameters (p);

    float* L = out.getWritePointer (0);
    float* R = out.getWritePointer (1);
    std::copy (in.begin(), in.end(), L);
    std::copy (in.begin(), in.end(), R);
    constexpr int block = 1024;
    for (int s = 0; s < out.getNumSamples(); s += block)
        reverb.processStereo (L + s, R + s, std::min (block, out.getNumSamples() - s));

    // Facteur de calibrage du Freeverb JUCE (vérifié par test : retour ≈ niveau d'entrée pour send = 1).
    out.applyGain (r.send * kReverbCalibration);
    return out;
}

Stereo delayReturn (const Mono& x, double sr, double bpm, const DelaySettings& d, const std::vector<float>& sendEnvelope)
{
    const int n = static_cast<int> (x.size());
    Stereo out = makeStereo (n);
    if (d.send <= 0.0001f || n == 0)
        return out;

    const double beatSec = 60.0 / juce::jlimit (40.0, 240.0, bpm);
    const int delayL = std::max (1, static_cast<int> (std::round (beatSec * d.noteBeats * sr)));
    const int delayR = d.pingPong ? delayL : std::max (1, static_cast<int> (std::round (delayL * 1.015)));
    const float fb = juce::jlimit (0.0f, 0.9f, d.feedback);

    std::vector<float> bufL (static_cast<size_t> (delayL), 0.0f), bufR (static_cast<size_t> (delayR), 0.0f);
    int posL = 0, posR = 0;
    Biquad hpL = Biquad::highPass (sr, d.hpfHz, 0.707), hpR = hpL;
    Biquad lpL = Biquad::lowPass (sr, d.lpfHz, 0.707), lpR = lpL;
    float* L = out.getWritePointer (0);
    float* R = out.getWritePointer (1);

    for (int i = 0; i < n; ++i)
    {
        const float env = sendEnvelope.empty() ? 1.0f : sendEnvelope[static_cast<size_t> (std::min (i, static_cast<int> (sendEnvelope.size()) - 1))];
        const float in = x[static_cast<size_t> (i)] * env;
        const float outL = bufL[static_cast<size_t> (posL)];
        const float outR = bufR[static_cast<size_t> (posR)];
        L[i] = outL;
        R[i] = outR;

        float newL, newR;
        if (d.pingPong)
        {
            newL = in + lpL.process (hpL.process (outR)) * fb;
            newR = lpR.process (hpR.process (outL)) * fb;
        }
        else
        {
            newL = in + lpL.process (hpL.process (outL)) * fb;
            newR = in + lpR.process (hpR.process (outR)) * fb;
        }
        bufL[static_cast<size_t> (posL)] = newL;
        bufR[static_cast<size_t> (posR)] = newR;
        posL = (posL + 1) % delayL;
        posR = (posR + 1) % delayR;
    }
    out.applyGain (d.send);
    return out;
}

std::vector<float> phraseEndThrowEnvelope (size_t numSamples, double sr, const analysis::VoiceActivity& va, double tailSec)
{
    std::vector<float> env (numSamples, 0.0f);
    const size_t fade = static_cast<size_t> (sr * 0.02);
    for (const auto& p : va.phrases)
    {
        const size_t a = static_cast<size_t> (std::max (p.startSec, p.endSec - tailSec) * sr);
        const size_t b = std::min (numSamples, static_cast<size_t> ((p.endSec + 0.05) * sr));
        for (size_t i = a; i < b; ++i)
        {
            float w = 1.0f;
            if (i < a + fade)
                w = static_cast<float> (i - a) / static_cast<float> (fade);
            else if (b > fade && i >= b - fade)
                w = static_cast<float> (b - i) / static_cast<float> (fade);
            env[i] = std::max (env[i], w);
        }
    }
    return env;
}

// ---------------------------------------------------------------------------------------------
Stereo placeStereo (const Mono& x, double sr, float pan, float width, float gain)
{
    const int n = static_cast<int> (x.size());
    Stereo out = makeStereo (n);
    float gl, gr;
    panGains (pan, gl, gr);
    // Compensation : le centre vaut 0 dB (au lieu de -3 dB) pour garder les niveaux intuitifs.
    gl *= juce::MathConstants<float>::sqrt2;
    gr *= juce::MathConstants<float>::sqrt2;
    const int haas = static_cast<int> (juce::jlimit (0.0f, 1.0f, width) * 0.015 * sr);
    float* L = out.getWritePointer (0);
    float* R = out.getWritePointer (1);
    for (int i = 0; i < n; ++i)
    {
        L[i] = x[static_cast<size_t> (i)] * gl * gain;
        const int j = i - haas;
        R[i] = (j >= 0 ? x[static_cast<size_t> (j)] : 0.0f) * gr * gain;
    }
    return out;
}

float gainForActiveRms (const Mono& x, double sr, float targetDb)
{
    const float current = rmsActiveDb (x, sr);
    if (current < -90.0f)
        return 1.0f;
    return dbToGain (juce::jlimit (-30.0f, 30.0f, targetDb - current));
}

Mono variableDelay (const Mono& x, const std::vector<float>& delaySamples)
{
    const int n = static_cast<int> (x.size());
    Mono out (x.size(), 0.0f);
    auto at = [&] (int i) { return (i >= 0 && i < n) ? x[static_cast<size_t> (i)] : 0.0f; };
    for (int i = 0; i < n; ++i)
    {
        const float d = delaySamples.empty() ? 0.0f : delaySamples[static_cast<size_t> (std::min (i, static_cast<int> (delaySamples.size()) - 1))];
        const double pos = i - static_cast<double> (d);
        const int i1 = static_cast<int> (std::floor (pos));
        const float t = static_cast<float> (pos - i1);
        const float y0 = at (i1 - 1), y1 = at (i1), y2 = at (i1 + 1), y3 = at (i1 + 2);
        // Interpolation d'Hermite (4 points).
        const float c0 = y1;
        const float c1 = 0.5f * (y2 - y0);
        const float c2 = y0 - 2.5f * y1 + 2.0f * y2 - 0.5f * y3;
        const float c3 = 0.5f * (y3 - y0) + 1.5f * (y1 - y2);
        out[static_cast<size_t> (i)] = ((c3 * t + c2) * t + c1) * t + c0;
    }
    return out;
}
} // namespace sv::dsp
