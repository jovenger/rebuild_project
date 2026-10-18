#include "TakeComper.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/VoiceActivity.h"
#include "../dsp/PitchCorrector.h"

#include <map>

namespace sv::gen
{
namespace
{
    constexpr const char* kMod = "Comping";

    float sampleAt (const TakeInput& t, long pos)
    {
        if (pos < t.regionStart || pos >= t.regionEnd)
            return 0.0f;
        const long idx = pos - t.startSample;
        if (idx < 0 || idx >= static_cast<long> (t.audio->size()))
            return 0.0f;
        return (*t.audio)[static_cast<size_t> (idx)];
    }

    bool validTake (const TakeInput& t)
    {
        return t.audio != nullptr && ! t.audio->empty() && t.regionEnd > t.regionStart;
    }

    void span (const std::vector<TakeInput>& takes, long& a, long& b)
    {
        a = std::numeric_limits<long>::max();
        b = std::numeric_limits<long>::min();
        for (const auto& t : takes)
        {
            if (! validTake (t))
                continue;
            a = std::min (a, t.regionStart);
            b = std::max (b, t.regionEnd);
        }
        if (a > b)
            a = b = 0;
    }

    Mono extract (const TakeInput& t, long from, long to)
    {
        Mono m (static_cast<size_t> (std::max (0L, to - from)));
        for (long p = from; p < to; ++p)
            m[static_cast<size_t> (p - from)] = sampleAt (t, p);
        return m;
    }
}

CompResult compLatest (const std::vector<TakeInput>& takes, double sampleRate)
{
    CompResult res;
    long a, b;
    span (takes, a, b);
    res.startSample = a;
    res.audio.assign (static_cast<size_t> (std::max (0L, b - a)), 0.0f);
    const long fade = static_cast<long> (sampleRate * 0.015);

    for (size_t k = 0; k < takes.size(); ++k)
    {
        const auto& t = takes[k];
        if (! validTake (t))
            continue;
        for (long p = t.regionStart; p < t.regionEnd; ++p)
        {
            float w = 1.0f;
            if (k > 0)
            {
                if (p < t.regionStart + fade)
                    w = static_cast<float> (p - t.regionStart) / static_cast<float> (fade);
                else if (p >= t.regionEnd - fade)
                    w = static_cast<float> (t.regionEnd - p) / static_cast<float> (fade);
            }
            auto& dst = res.audio[static_cast<size_t> (p - a)];
            dst = dst * (1.0f - w) + sampleAt (t, p) * w;
        }
        res.segments.push_back ({ t.regionStart, t.regionEnd, static_cast<int> (k), 0.0f });
    }
    res.summary = juce::String ((int) takes.size()) + juce::String (juce::CharPointer_UTF8 (" prise(s), la plus récente gagne sur sa zone"));
    return res;
}

CompResult compBest (const std::vector<TakeInput>& takes, double sampleRate, const MusicalKey& key,
                     const TempoInfo& tempo, style::Style style)
{
    log::ScopedTimer timer (kMod, "meilleure prise automatique");
    int valid = 0;
    for (const auto& t : takes)
        valid += validTake (t) ? 1 : 0;
    if (valid <= 1)
        return compLatest (takes, sampleRate);

    long a, b;
    span (takes, a, b);
    const double sr = sampleRate;

    // Analyse de chaque prise sur toute l'étendue.
    struct TakeAnalysis
    {
        Mono audio;
        analysis::VoiceActivity va;
        analysis::PitchTrack track;
    };
    std::vector<TakeAnalysis> an (takes.size());
    for (size_t k = 0; k < takes.size(); ++k)
    {
        if (! validTake (takes[k]))
            continue;
        an[k].audio = extract (takes[k], a, b);
        an[k].va = analysis::analyzeVoice (an[k].audio, sr);
        an[k].track = analysis::detectPitch (an[k].audio, sr);
    }

    // Créneaux : union des phrases de toutes les prises.
    std::vector<std::pair<double, double>> intervals;
    for (const auto& x : an)
        for (const auto& p : x.va.phrases)
            intervals.push_back ({ p.startSec, p.endSec });
    std::sort (intervals.begin(), intervals.end());
    std::vector<std::pair<double, double>> slots;
    for (const auto& iv : intervals)
    {
        if (! slots.empty() && iv.first <= slots.back().second + 0.05)
            slots.back().second = std::max (slots.back().second, iv.second);
        else
            slots.push_back (iv);
    }
    if (slots.empty())
        return compLatest (takes, sampleRate);

    const bool rhythmic = style == style::Style::Rap || style == style::Style::Drill || style == style::Style::Trap;
    const float pitchWeight = style == style::Style::Rap || style == style::Style::Drill ? 0.3f : 1.0f;
    const float timingWeight = rhythmic ? 1.5f : 0.8f;
    const double grid = tempo.beatSec() / 4.0;

    CompResult res;
    res.startSample = a;
    res.audio.assign (static_cast<size_t> (b - a), 0.0f);
    std::map<int, int> wins;

    // Bornes : milieux des silences entre créneaux.
    std::vector<double> bounds { 0.0 };
    for (size_t s = 0; s + 1 < slots.size(); ++s)
        bounds.push_back (0.5 * (slots[s].second + slots[s + 1].first));
    bounds.push_back (static_cast<double> (b - a) / sr);

    const long fade = static_cast<long> (sr * 0.02);
    for (size_t s = 0; s < slots.size(); ++s)
    {
        const double s0 = slots[s].first, s1 = slots[s].second;
        const long segA = static_cast<long> (bounds[s] * sr);
        const long segB = static_cast<long> (bounds[s + 1] * sr);

        // Durée voisée par prise et niveaux.
        std::vector<double> voicedDur (takes.size(), 0.0);
        std::vector<float> levels (takes.size(), -120.0f);
        double maxVoiced = 0.0;
        for (size_t k = 0; k < takes.size(); ++k)
        {
            if (! validTake (takes[k]))
                continue;
            // la prise doit couvrir le créneau
            const long absA = a + static_cast<long> (s0 * sr), absB = a + static_cast<long> (s1 * sr);
            if (takes[k].regionStart > absA + static_cast<long> (0.1 * sr) || takes[k].regionEnd < absB - static_cast<long> (0.1 * sr))
                continue;
            double vd = 0.0;
            for (double t = s0; t < s1; t += an[k].track.hopSec)
                vd += an[k].va.isActiveAt (t) ? an[k].track.hopSec : 0.0;
            voicedDur[k] = vd;
            maxVoiced = std::max (maxVoiced, vd);
            const size_t ia = static_cast<size_t> (s0 * sr), ib = std::min (an[k].audio.size(), static_cast<size_t> (s1 * sr));
            levels[k] = ib > ia ? gainToDb (audio::rms (an[k].audio.data() + ia, ib - ia)) : -120.0f;
        }
        std::vector<float> lv;
        for (float l : levels)
            if (l > -100.0f)
                lv.push_back (l);
        std::sort (lv.begin(), lv.end());
        float medianLevel = -120.0f;
        if (! lv.empty())
            medianLevel = lv.size() % 2 == 1 ? lv[lv.size() / 2] : 0.5f * (lv[lv.size() / 2 - 1] + lv[lv.size() / 2]);

        int best = -1;
        float bestScore = 1.0e9f;
        for (size_t k = 0; k < takes.size(); ++k)
        {
            if (voicedDur[k] <= 0.0)
                continue;
            float score = 0.0f;
            score += static_cast<float> (1.0 - voicedDur[k] / std::max (1.0e-6, maxVoiced)) * 3.0f;

            // Justesse : écart moyen à la gamme.
            double cents = 0.0;
            int nv = 0;
            for (double t = s0; t < s1; t += an[k].track.hopSec)
            {
                const float f0 = an[k].track.f0At (t);
                if (f0 <= 0.0f)
                    continue;
                const float m = analysis::hzToMidi (f0);
                cents += std::abs (m - dsp::nearestScaleMidi (m, key, false)) * 100.0;
                ++nv;
            }
            if (nv > 0)
                score += pitchWeight * static_cast<float> (cents / nv / 50.0);

            // Rythme : écart des attaques à la grille.
            double dev = 0.0;
            int no = 0;
            for (const auto& p : an[k].va.phrases)
                for (double o : p.syllableOnsets)
                    if (o >= s0 - 0.05 && o <= s1)
                    {
                        const double g = tempo.firstBeatSec + std::round ((o + static_cast<double> (a) / sr - tempo.firstBeatSec) / grid) * grid
                                         - static_cast<double> (a) / sr;
                        dev += std::abs (o - g) * 1000.0;
                        ++no;
                    }
            if (no > 0)
                score += timingWeight * static_cast<float> (dev / no / 40.0);

            // Saturation numérique.
            int clipped = 0;
            const size_t ia = static_cast<size_t> (s0 * sr), ib = std::min (an[k].audio.size(), static_cast<size_t> (s1 * sr));
            for (size_t i = ia; i < ib; ++i)
                clipped += std::abs (an[k].audio[i]) >= 0.99f ? 1 : 0;
            // L'écrêtage est un défaut rédhibitoire : il doit dominer les autres critères.
            if (clipped > 5)
                score += 2.0f + std::min (4.0f, static_cast<float> (clipped) / 100.0f);

            // Bruit de fond (rapport signal / bruit).
            const float snr = levels[k] - an[k].va.noiseFloorDb;
            if (snr < 20.0f)
                score += (20.0f - snr) / 10.0f;

            // Régularité de niveau.
            score += std::min (1.5f, std::abs (levels[k] - medianLevel) / 6.0f);

            if (score < bestScore)
            {
                bestScore = score;
                best = static_cast<int> (k);
            }
        }
        if (best < 0)
            continue;
        ++wins[best];
        res.segments.push_back ({ a + segA, a + segB, best, bestScore });

        const auto& src = an[static_cast<size_t> (best)].audio;
        for (long p = std::max (0L, segA - fade); p < std::min (b - a, segB + fade); ++p)
        {
            float w = 1.0f;
            if (p < segA + fade)
                w = static_cast<float> (p - (segA - fade)) / static_cast<float> (2 * fade);
            else if (p >= segB - fade)
                w = static_cast<float> ((segB + fade) - p) / static_cast<float> (2 * fade);
            w = juce::jlimit (0.0f, 1.0f, w);
            res.audio[static_cast<size_t> (p)] += src[static_cast<size_t> (p)] * w;
        }
    }

    juce::StringArray parts;
    for (const auto& [k, c] : wins)
        parts.add ("prise " + juce::String (takes[static_cast<size_t> (k)].id) + " : " + juce::String (c) + " phrase(s)");
    res.summary = juce::String (juce::CharPointer_UTF8 ("Meilleure prise par phrase — ")) + parts.joinIntoString (", ");
    SV_LOG_INFO (kMod, res.summary);
    return res;
}
} // namespace sv::gen
