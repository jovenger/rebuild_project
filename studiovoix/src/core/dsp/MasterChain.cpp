#include "MasterChain.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../Loudness.h"
#include "Processors.h"

#include <deque>

namespace sv::dsp
{
namespace
{
    constexpr const char* kMod = "Master";
}

TargetInfo targetInfo (LoudnessTarget t)
{
    switch (t)
    {
        case LoudnessTarget::Spotify:    return { "spotify", "Spotify (-14 LUFS)", -14.0f, -1.0f };
        case LoudnessTarget::YouTube:    return { "youtube", "YouTube (-14 LUFS)", -14.0f, -1.0f };
        case LoudnessTarget::AppleMusic: return { "apple", "Apple Music (-16 LUFS)", -16.0f, -1.0f };
        case LoudnessTarget::TikTok:     return { "tiktok", "TikTok / Instagram (-14 LUFS)", -14.0f, -1.0f };
        case LoudnessTarget::Fort:       return { "fort", juce::String (juce::CharPointer_UTF8 ("Fort / club (-9 LUFS)")), -9.0f, -1.0f };
        case LoudnessTarget::Reference:  return { "reference", juce::String (juce::CharPointer_UTF8 ("Comme le morceau de référence")), -14.0f, -1.0f };
        case LoudnessTarget::None:
        case LoudnessTarget::Count:      return { "none", "Sans normalisation (limiteur seul)", 0.0f, -1.0f };
    }
    return {};
}

LoudnessTarget targetFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (LoudnessTarget::Count); ++i)
        if (targetInfo (static_cast<LoudnessTarget> (i)).id == id)
            return static_cast<LoudnessTarget> (i);
    return LoudnessTarget::Spotify;
}

float limitStereo (Stereo& buffer, double sampleRate, float ceilingDb, float lookaheadMs, float releaseMs, int* hardClipped)
{
    const int n = buffer.getNumSamples();
    if (n == 0)
        return 0.0f;
    const float ceiling = dbToGain (ceilingDb);
    const int L = std::max (1, static_cast<int> (sampleRate * lookaheadMs * 0.001));
    float* chL = buffer.getWritePointer (0);
    float* chR = buffer.getNumChannels() > 1 ? buffer.getWritePointer (1) : chL;

    std::vector<float> req (static_cast<size_t> (n));
    for (int i = 0; i < n; ++i)
    {
        const float pk = std::max (std::abs (chL[i]), std::abs (chR[i]));
        req[static_cast<size_t> (i)] = pk > ceiling ? ceiling / pk : 1.0f;
    }

    // m[j] = min(req[j .. j+L]) par fenêtre glissante (file monotone).
    std::vector<float> m (static_cast<size_t> (n));
    std::deque<int> dq;
    for (int i = n - 1; i >= 0; --i)
    {
        while (! dq.empty() && req[static_cast<size_t> (dq.back())] >= req[static_cast<size_t> (i)])
            dq.pop_back();
        dq.push_back (i);
        while (dq.front() > i + L)
            dq.pop_front();
        m[static_cast<size_t> (i)] = req[static_cast<size_t> (dq.front())];
    }

    // g[n] = moyenne de m sur [n-L, n] : rampe douce terminée au moment de la crête.
    std::vector<float> g (static_cast<size_t> (n));
    double sum = 0.0;
    for (int i = 0; i < n; ++i)
    {
        sum += m[static_cast<size_t> (i)];
        if (i - L - 1 >= 0)
            sum -= m[static_cast<size_t> (i - L - 1)];
        const int count = std::min (i + 1, L + 1);
        g[static_cast<size_t> (i)] = static_cast<float> (sum / count);
    }

    // Relâchement lent (jamais au-dessus de g : la sécurité est conservée).
    const float relCoef = static_cast<float> (1.0 - std::exp (-1.0 / (sampleRate * releaseMs * 0.001)));
    float state = 1.0f;
    float maxGr = 0.0f;
    int clipped = 0;
    for (int i = 0; i < n; ++i)
    {
        const float released = state + (1.0f - state) * relCoef;
        state = std::min (g[static_cast<size_t> (i)], released);
        maxGr = std::max (maxGr, -gainToDb (state));
        chL[i] *= state;
        if (chR != chL)
            chR[i] *= state;
        for (float* c : { chL, chR })
        {
            if (std::abs (c[i]) > ceiling)
            {
                c[i] = std::copysign (ceiling, c[i]);
                ++clipped;
            }
        }
    }
    if (hardClipped != nullptr)
        *hardClipped = clipped;
    return maxGr;
}

Stereo master (const Stereo& mix, double sampleRate, const MasterSettings& settings, MasterReport& report)
{
    log::ScopedTimer timer (kMod, "mastering");
    const juce::ScopedNoDenormals noDenormals;
    Stereo out (mix);
    const int n = out.getNumSamples();
    report = {};
    if (n == 0)
        return out;

    report.inputLufs = loudness::integratedLufs (out, sampleRate);
    if (! settings.enabled)
    {
        report.outputLufs = report.inputLufs;
        report.truePeakDb = loudness::truePeakDb (out);
        return out;
    }

    // 1) Compression de cohésion (stéréo liée, détection RMS 20 ms).
    if (settings.glueRatio > 1.0f && report.inputLufs > -70.0)
    {
        const float threshold = static_cast<float> (report.inputLufs) + 4.0f;
        const int rmsLen = std::max (1, static_cast<int> (sampleRate * 0.02));
        const float att = static_cast<float> (std::exp (-1.0 / (sampleRate * 0.030)));
        const float rel = static_cast<float> (std::exp (-1.0 / (sampleRate * 0.200)));
        double sq = 0.0;
        float gr = 0.0f;
        double grSum = 0.0;
        float* L = out.getWritePointer (0);
        float* R = out.getWritePointer (1);
        const float* dL = mix.getReadPointer (0);   // détection sur le signal non compressé
        const float* dR = mix.getReadPointer (mix.getNumChannels() > 1 ? 1 : 0);
        for (int i = 0; i < n; ++i)
        {
            const double s = 0.5 * (static_cast<double> (dL[i]) * dL[i] + static_cast<double> (dR[i]) * dR[i]);
            sq += s;
            if (i >= rmsLen)
                sq -= 0.5 * (static_cast<double> (dL[i - rmsLen]) * dL[i - rmsLen] + static_cast<double> (dR[i - rmsLen]) * dR[i - rmsLen]);
            const float lvl = gainToDb (static_cast<float> (std::sqrt (std::max (0.0, sq / rmsLen))));
            const float target = lvl > threshold ? (lvl - threshold) * (1.0f - 1.0f / settings.glueRatio) : 0.0f;
            gr = target > gr ? att * gr + (1.0f - att) * target : rel * gr + (1.0f - rel) * target;
            const float g = dbToGain (-gr);
            L[i] *= g;
            R[i] *= g;
            grSum += gr;
        }
        report.glueGrDb = static_cast<float> (grSum / n);
    }

    // 2) Couleur du style.
    for (int c = 0; c < 2; ++c)
    {
        Mono ch (out.getReadPointer (c), out.getReadPointer (c) + n);
        if (std::abs (settings.lowShelfDb) > 0.05f)
            applyBiquad (ch, Biquad::lowShelf (sampleRate, 100.0, 0.707, settings.lowShelfDb));
        if (std::abs (settings.highShelfDb) > 0.05f)
            applyBiquad (ch, Biquad::highShelf (sampleRate, 10000.0, 0.707, settings.highShelfDb));
        std::copy (ch.begin(), ch.end(), out.getWritePointer (c));
    }

    // 2 bis) Mastering par référence : spectre du mixage rapproché de celui du morceau de référence (tiers d'octave,
    //        5 dB max par bande, graves sous 60 Hz et aigus au-dessus de 16 kHz laissés tels quels).
    if (settings.referenceStrength > 0.001f && settings.reference.valid())
    {
        const auto mine = analysis::averageSpectrum (audio::toMono (out), sampleRate);
        const auto curve = analysis::matchCurve (mine, settings.reference, 5.0f, 60.0f, 16000.0f, settings.referenceStrength);
        float maxAbs = 0.0f;
        for (const float g : curve)
            maxAbs = std::max (maxAbs, std::abs (g));
        if (maxAbs > 0.1f && curve.size() == mine.centersHz.size())
        {
            for (int c = 0; c < 2; ++c)
            {
                Mono ch (out.getReadPointer (c), out.getReadPointer (c) + n);
                applyCurveEq (ch, sampleRate, mine.centersHz, curve);
                std::copy (ch.begin(), ch.end(), out.getWritePointer (c));
            }
            report.referenceEqMaxDb = maxAbs;
        }
        SV_LOG_INFO (kMod, "Mastering par référence : correction max "_u8 + juce::String (maxAbs, 1) + " dB par bande (force "
                           + juce::String (settings.referenceStrength, 2) + ")");
    }

    // 3) Normalisation + limiteur, itératif (la limitation réduit la sonie).
    auto info = targetInfo (settings.target);
    if (settings.target == LoudnessTarget::Reference)
    {
        // Sonie du morceau de référence (bornée : un morceau mal mesuré ne doit pas écraser ni éteindre le mix).
        info.lufs = settings.referenceLufs > -60.0 ? juce::jlimit (-24.0f, -6.0f, static_cast<float> (settings.referenceLufs)) : -14.0f;
        SV_LOG_INFO (kMod, "Sonie visée = morceau de référence : "_u8 + juce::String (info.lufs, 1) + " LUFS");
    }
    const bool normalise = settings.target != LoudnessTarget::None;
    const double pre = loudness::integratedLufs (out, sampleRate);
    double gainDb = normalise && pre > -70.0 ? info.lufs - pre : 0.0;
    const float ceilingTp = info.ceilingDbTp - std::max (0.0f, settings.extraHeadroomDb);
    float ceiling = ceilingTp - 0.3f;   // marge : la crête vraie dépasse la crête échantillon
    Stereo result (out);

    for (int it = 0; it < 5; ++it)
    {
        result.makeCopyOf (out);
        result.applyGain (dbToGain (static_cast<float> (gainDb)));
        int clipped = 0;
        report.limiterMaxGrDb = limitStereo (result, sampleRate, ceiling, 5.0f, 120.0f, &clipped);
        report.hardClippedSamples = clipped;
        report.outputLufs = loudness::integratedLufs (result, sampleRate);
        report.truePeakDb = loudness::truePeakDb (result);
        report.iterations = it + 1;

        bool done = true;
        if (report.truePeakDb > ceilingTp + 0.05)
        {
            ceiling -= static_cast<float> (report.truePeakDb - ceilingTp) + 0.1f;
            done = false;
        }
        // Mix quasi silencieux : pas de normalisation (sinon +30 dB de souffle).
        if (normalise && pre > -70.0 && std::abs (report.outputLufs - info.lufs) > 0.3)
        {
            gainDb += info.lufs - report.outputLufs;
            gainDb = juce::jlimit (-40.0, 30.0, gainDb);
            done = false;
        }
        if (done)
            break;
    }

    // Garantie finale : jamais au-dessus du plafond, même si les itérations n'ont pas convergé.
    if (report.truePeakDb > ceilingTp + 0.05)
    {
        const float fix = static_cast<float> (ceilingTp - 0.05 - report.truePeakDb);
        result.applyGain (dbToGain (fix));
        report.truePeakDb = loudness::truePeakDb (result);
        report.outputLufs = loudness::integratedLufs (result, sampleRate);
        SV_LOG_WARN (kMod, "Crête vraie encore au-dessus du plafond après les itérations : gain "_u8 + juce::String (fix, 2)
                           + " dB appliqué (sonie "_u8 + juce::String (report.outputLufs, 1) + " LUFS)");
    }

    SV_LOG_INFO (kMod, "Master " + info.name + " : " + juce::String (report.inputLufs, 1) + " -> "
                       + juce::String (report.outputLufs, 1) + " LUFS, crête vraie "_u8 + juce::String (report.truePeakDb, 2)
                       + " dBTP, limiteur max " + juce::String (report.limiterMaxGrDb, 1) + " dB, cohésion "_u8
                       + juce::String (report.glueGrDb, 1) + " dB, " + juce::String (report.iterations) + " itérations"_u8);
    if (report.limiterMaxGrDb > 8.0f)
        SV_LOG_WARN (kMod, "Limiteur très sollicité ("_u8 + juce::String (report.limiterMaxGrDb, 1) + " dB) : la cible est peut-être trop forte pour ce mix"_u8);
    return result;
}
} // namespace sv::dsp
