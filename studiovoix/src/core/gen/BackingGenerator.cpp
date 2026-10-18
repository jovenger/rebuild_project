#include "BackingGenerator.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../dsp/PitchCorrector.h"
#include "../dsp/PitchShifter.h"
#include "../dsp/Processors.h"

namespace sv::gen
{
namespace
{
    constexpr const char* kMod = "Generator";

    // Marche aléatoire lissée dans [-1, 1], un point de contrôle toutes les stepSec secondes.
    std::vector<float> smoothRandomWalk (size_t numSamples, double sr, double stepSec, juce::Random& rng)
    {
        std::vector<float> out (numSamples, 0.0f);
        const size_t step = std::max<size_t> (1, static_cast<size_t> (stepSec * sr));
        float a = rng.nextFloat() * 2.0f - 1.0f;
        for (size_t start = 0; start < numSamples; start += step)
        {
            const float b = juce::jlimit (-1.0f, 1.0f, a + (rng.nextFloat() * 2.0f - 1.0f) * 0.6f);
            for (size_t i = 0; i < step && start + i < numSamples; ++i)
            {
                const float t = static_cast<float> (i) / static_cast<float> (step);
                const float s = t * t * (3.0f - 2.0f * t);   // interpolation douce
                out[start + i] = a + (b - a) * s;
            }
            a = b;
        }
        return out;
    }

    void copySegment (const Mono& src, Mono& dst, size_t srcStart, size_t srcEnd, size_t dstStart, size_t fade, float gain)
    {
        if (srcEnd <= srcStart)
            return;
        const size_t len = srcEnd - srcStart;
        const size_t f = std::min (fade, len / 2);
        for (size_t i = 0; i < len; ++i)
        {
            const size_t s = srcStart + i, d = dstStart + i;
            if (s >= src.size() || d >= dst.size())
                break;
            float w = 1.0f;
            if (f > 0 && i < f)
                w = static_cast<float> (i) / static_cast<float> (f);
            else if (f > 0 && i >= len - f)
                w = static_cast<float> (len - i) / static_cast<float> (f);
            dst[d] += src[s] * w * gain;
        }
    }

    std::vector<Mono> loadBank (const juce::File& folder, double sr)
    {
        std::vector<Mono> bank;
        if (folder == juce::File() || ! folder.isDirectory())
            return bank;
        const auto files = folder.findChildFiles (juce::File::findFiles, false, "*.wav;*.mp3;*.flac;*.aif;*.aiff;*.ogg");
        for (const auto& f : files)
        {
            Mono m;
            juce::String err;
            if (! audio::loadMono (f, sr, m, err, 4.0))
            {
                SV_LOG_WARN (kMod, "Ad-lib ignoré ("_u8 + f.getFileName() + ") : " + err);
                continue;
            }
            if (m.size() < static_cast<size_t> (sr * 0.05))
            {
                SV_LOG_WARN (kMod, "Ad-lib ignoré (trop court) : "_u8 + f.getFileName());
                continue;
            }
            bank.push_back (std::move (m));
        }
        SV_LOG_INFO (kMod, "Banque d'ad-libs : " + juce::String ((int) bank.size()) + " sons dans " + folder.getFullPathName());
        return bank;
    }

    const char* intervalName (int steps)
    {
        switch (steps)
        {
            case 2:  return "tierce au-dessus";
            case 4:  return "quinte au-dessus";
            case -2: return "tierce en dessous";
            case -7: return "octave en dessous";
            default: return "intervalle";
        }
    }
}

juce::String ambianceId (AmbianceType t)
{
    switch (t)
    {
        case AmbianceType::NappeVoix:    return "nappe";
        case AmbianceType::ChoeurAerien: return "choeur";
        case AmbianceType::EchoLointain: return "echo";
        case AmbianceType::Count:        break;
    }
    return "nappe";
}

juce::String ambianceName (AmbianceType t)
{
    switch (t)
    {
        case AmbianceType::NappeVoix:    return "Nappe voix";
        case AmbianceType::ChoeurAerien: return juce::String (juce::CharPointer_UTF8 ("Chœur aérien"));
        case AmbianceType::EchoLointain: return "Echo lointain";
        case AmbianceType::Count:        break;
    }
    return "Nappe voix";
}

AmbianceType ambianceFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (AmbianceType::Count); ++i)
        if (ambianceId (static_cast<AmbianceType> (i)) == id)
            return static_cast<AmbianceType> (i);
    return AmbianceType::NappeVoix;
}

GenerationOptions GenerationOptions::fromDefaults (const style::GenerationDefaults& d)
{
    GenerationOptions o;
    o.doubles = d.doubles;
    o.harmonies = d.harmonies;
    o.keywordBacks = d.keywordBacks;
    o.keywordSyllables = d.keywordSyllables;
    o.adLibs = d.adLibs;
    o.adLibDensity = d.adLibDensity;
    o.ambiance = d.ambiance;
    return o;
}

GeneratedTrack makeDouble (const LeadAnalysis& lead, double sr, int index, int total, juce::Random& rng)
{
    log::ScopedTimer timer (kMod, "doublage " + juce::String (index + 1));
    GeneratedTrack t;
    t.role = style::Role::Double;
    t.name = "Doublage " + juce::String (index + 1);
    if (total == 1)
        t.pan = 0.0f;
    else if (total == 2)
        t.pan = index == 0 ? -0.75f : 0.75f;
    else
        t.pan = index == 0 ? 0.0f : (index % 2 == 1 ? -0.8f : 0.8f);

    // Désaccord léger et variable (± quelques cents), alterné d'une piste à l'autre.
    const float baseCents = (index % 2 == 0 ? 1.0f : -1.0f) * (6.0f + 3.0f * static_cast<float> (index));
    const auto walkPitch = smoothRandomWalk (lead.track.frames.size(), 1.0 / lead.track.hopSec, 0.4, rng);
    std::vector<float> ratios (lead.track.frames.size());
    for (size_t i = 0; i < ratios.size(); ++i)
        ratios[i] = std::pow (2.0f, (baseCents + 3.0f * walkPitch[i]) / 1200.0f);
    Mono shifted = dsp::psolaShift (lead.prepared, sr, lead.track, ratios);

    // Retard variable (14 à 30 ms) : imite un second passage humain.
    const auto walkDelay = smoothRandomWalk (shifted.size(), sr, 0.08, rng);
    std::vector<float> delays (shifted.size());
    const float baseMs = 14.0f + 8.0f * static_cast<float> (index);
    for (size_t i = 0; i < delays.size(); ++i)
        delays[i] = static_cast<float> ((baseMs + 5.0f * walkDelay[i]) * 0.001 * sr);
    t.audio = dsp::variableDelay (shifted, delays);

    // Légère variation de niveau (±1 dB).
    const auto walkGain = smoothRandomWalk (t.audio.size(), sr, 0.3, rng);
    for (size_t i = 0; i < t.audio.size(); ++i)
        t.audio[i] *= dbToGain (walkGain[i]);

    t.detail = "retard " + juce::String (juce::roundToInt (baseMs)) + " ms, " + juce::String (juce::roundToInt (baseCents)) + " cents";
    return t;
}

GeneratedTrack makeHarmony (const LeadAnalysis& lead, double sr, int index)
{
    log::ScopedTimer timer (kMod, "harmonie " + juce::String (index + 1));
    static constexpr int kSteps[] = { 2, 4, -7 };
    const int steps = kSteps[juce::jlimit (0, 2, index)];

    GeneratedTrack t;
    t.role = style::Role::Harmony;
    t.name = "Harmonie " + juce::String (index + 1);
    t.detail = intervalName (steps);
    t.pan = index == 0 ? -0.45f : (index == 1 ? 0.45f : 0.0f);

    std::vector<float> ratios (lead.track.frames.size(), 1.0f);
    for (size_t i = 0; i < ratios.size(); ++i)
    {
        const auto& f = lead.track.frames[i];
        if (! f.voiced)
            continue;
        const float midi = analysis::hzToMidi (f.f0);
        const float anchor = dsp::nearestScaleMidi (midi, lead.key, false);
        const float target = dsp::diatonicShift (midi, lead.key, steps);
        ratios[i] = std::pow (2.0f, (target - anchor) / 12.0f);   // conserve les inflexions de la voix
    }
    dsp::PsolaOptions opt;
    opt.unvoicedGain = 0.3f;   // consonnes atténuées : évite les "s" en double
    Mono shifted = dsp::psolaShift (lead.prepared, sr, lead.track, ratios, opt);

    std::vector<float> delays (shifted.size(), static_cast<float> ((8.0 + 4.0 * index) * 0.001 * sr));
    t.audio = dsp::variableDelay (shifted, delays);
    return t;
}

GeneratedTrack makeKeywordBacks (const LeadAnalysis& lead, double sr, int syllables)
{
    log::ScopedTimer timer (kMod, "backs mots clés"_u8);
    GeneratedTrack t;
    t.role = style::Role::KeywordBack;
    t.name = juce::String (juce::CharPointer_UTF8 ("Backs mots clés"));
    t.width = 0.6f;
    t.audio.assign (lead.prepared.size(), 0.0f);

    // Copie légèrement désaccordée (+7 cents) pour ne pas sonner comme un simple écho de la voix.
    const Mono source = dsp::psolaShiftSemitones (lead.prepared, sr, lead.track, 0.07f);
    const size_t fade = static_cast<size_t> (sr * 0.01);
    int count = 0;
    for (const auto& p : lead.va.phrases)
    {
        if (p.syllableOnsets.empty())
            continue;
        const int k = std::min (std::max (1, syllables), static_cast<int> (p.syllableOnsets.size()));
        double start = p.syllableOnsets[p.syllableOnsets.size() - static_cast<size_t> (k)];
        if (p.endSec - start > 0.9)
            start = p.endSec - 0.9;
        if (p.endSec - start < 0.2)
            start = std::max (p.startSec, p.endSec - 0.25);
        const size_t a = static_cast<size_t> (std::max (0.0, start - 0.01) * sr);
        const size_t b = std::min (source.size(), static_cast<size_t> ((p.endSec + 0.04) * sr));
        copySegment (source, t.audio, a, b, a, fade, 1.0f);
        ++count;
    }
    t.detail = juce::String (count) + " fins de phrases, " + juce::String (syllables) + " syllabe(s)";
    return t;
}

GeneratedTrack makeAdLibs (const LeadAnalysis& lead, double sr, const GenerationOptions& options, juce::Random& rng,
                           int& placedCount)
{
    log::ScopedTimer timer (kMod, "ad-libs");
    GeneratedTrack t;
    t.role = style::Role::AdLib;
    t.name = "Ad-libs";
    t.audio.assign (lead.prepared.size(), 0.0f);
    placedCount = 0;

    const auto bank = loadBank (options.adLibFolder, sr);
    const size_t fade = static_cast<size_t> (sr * 0.02);
    const double total = static_cast<double> (lead.prepared.size()) / sr;
    const auto& phrases = lead.va.phrases;

    for (size_t i = 0; i < phrases.size(); ++i)
    {
        const double gapStart = phrases[i].endSec + 0.06;
        const double gapEnd = (i + 1 < phrases.size() ? phrases[i + 1].startSec : total) - 0.05;
        if (gapEnd - gapStart < 0.35 || rng.nextFloat() > options.adLibDensity)
            continue;

        const size_t dst = static_cast<size_t> (gapStart * sr);
        const size_t maxLen = static_cast<size_t> ((gapEnd - gapStart) * sr);

        if (! bank.empty())
        {
            const auto& clip = bank[static_cast<size_t> (rng.nextInt (static_cast<int> (bank.size())))];
            copySegment (clip, t.audio, 0, std::min (clip.size(), maxLen), dst, fade, 1.0f);
        }
        else
        {
            // Sans banque : écho du dernier mot, une octave au-dessus.
            const auto& p = phrases[i];
            if (p.syllableOnsets.empty())
                continue;
            const double s = std::max (p.syllableOnsets.back(), p.endSec - 0.6);
            const size_t a = static_cast<size_t> (s * sr);
            const size_t b = std::min (lead.prepared.size(), static_cast<size_t> (p.endSec * sr));
            if (b <= a + static_cast<size_t> (sr * 0.05))
                continue;
            Mono word (lead.prepared.begin() + static_cast<long> (a), lead.prepared.begin() + static_cast<long> (b));
            analysis::PitchTrack wordTrack = analysis::detectPitch (word, sr);
            Mono up = dsp::psolaShiftSemitones (word, sr, wordTrack, 12.0f);
            copySegment (up, t.audio, 0, std::min (up.size(), maxLen), dst, fade, 0.8f);
        }
        ++placedCount;
    }
    t.detail = bank.empty() ? juce::String (placedCount) + juce::String (juce::CharPointer_UTF8 (" échos du dernier mot (banque d'ad-libs vide)"))
                            : juce::String (placedCount) + " ad-libs de ta banque (" + juce::String ((int) bank.size()) + " sons)";
    t.pan = 0.0f;
    t.width = 0.5f;
    return t;
}

GeneratedTrack makeAmbiance (const LeadAnalysis& lead, double sr, AmbianceType type)
{
    log::ScopedTimer timer (kMod, "ambiance");
    GeneratedTrack t;
    t.role = style::Role::Ambiance;
    t.name = "Ambiance (" + ambianceName (type) + ")";
    t.width = 1.0f;
    const size_t n = lead.prepared.size();
    t.audio.assign (n, 0.0f);

    auto addShift = [&] (int diatonicSteps, float semis, float gain)
    {
        std::vector<float> ratios (lead.track.frames.size(), 1.0f);
        for (size_t i = 0; i < ratios.size(); ++i)
        {
            const auto& f = lead.track.frames[i];
            if (! f.voiced)
                continue;
            const float midi = analysis::hzToMidi (f.f0);
            const float anchor = dsp::nearestScaleMidi (midi, lead.key, false);
            const float target = diatonicSteps != 0 ? dsp::diatonicShift (midi, lead.key, diatonicSteps) : anchor + semis;
            ratios[i] = std::pow (2.0f, (target - anchor) / 12.0f);
        }
        dsp::PsolaOptions opt;
        opt.unvoicedGain = 0.1f;
        const Mono s = dsp::psolaShift (lead.prepared, sr, lead.track, ratios, opt);
        for (size_t i = 0; i < n && i < s.size(); ++i)
            t.audio[i] += s[i] * gain;
    };

    switch (type)
    {
        case AmbianceType::NappeVoix:
            addShift (0, -12.0f, 0.6f);
            addShift (4, 0.0f, 0.5f);
            t.detail = "octave en dessous + quinte";
            break;
        case AmbianceType::ChoeurAerien:
            addShift (0, 12.0f, 0.5f);
            addShift (2, 0.0f, 0.5f);
            t.detail = "octave au-dessus + tierce";
            break;
        case AmbianceType::EchoLointain:
        case AmbianceType::Count:
        {
            const size_t d = static_cast<size_t> (lead.tempo.beatSec() * 2.0 * sr);
            for (size_t i = d; i < n; ++i)
                t.audio[i] = lead.prepared[i - d] * 0.7f;
            dsp::lowPass (t.audio, sr, 3000.0, 2);
            dsp::highPass (t.audio, sr, 400.0, 2);
            t.detail = "écho 2 temps filtré"_u8;
            break;
        }
    }

    // Attaques adoucies (rendu de nappe) : gain = enveloppe lente / enveloppe rapide.
    const float slowAtt = static_cast<float> (std::exp (-1.0 / (sr * 0.15)));
    const float fastAtt = static_cast<float> (std::exp (-1.0 / (sr * 0.001)));
    const float rel = static_cast<float> (std::exp (-1.0 / (sr * 0.3)));
    float slow = 0.0f, fast = 0.0f;
    for (auto& v : t.audio)
    {
        const float a = std::abs (v);
        slow = a > slow ? slowAtt * slow + (1.0f - slowAtt) * a : rel * slow + (1.0f - rel) * a;
        fast = a > fast ? fastAtt * fast + (1.0f - fastAtt) * a : rel * fast + (1.0f - rel) * a;
        v *= fast > 1.0e-9f ? std::min (1.0f, slow / fast) : 0.0f;
    }
    return t;
}

std::vector<GeneratedTrack> generate (const LeadAnalysis& lead, double sampleRate, const GenerationOptions& options,
                                      const ProgressFn& progress)
{
    log::ScopedTimer timer (kMod, "génération complète"_u8);
    std::vector<GeneratedTrack> out;
    if (lead.prepared.empty())
    {
        SV_LOG_WARN (kMod, "voix principale vide : rien à générer"_u8);
        return out;
    }

    juce::Random rng (options.seed);
    const int steps = juce::jlimit (0, 3, options.doubles) + juce::jlimit (0, 3, options.harmonies)
                    + (options.keywordBacks ? 1 : 0) + (options.adLibs ? 1 : 0) + (options.ambiance ? 1 : 0);
    int done = 0;
    auto tick = [&]
    {
        ++done;
        return ! progress || progress (steps > 0 ? static_cast<float> (done) / steps : 1.0f);
    };

    for (int i = 0; i < juce::jlimit (0, 3, options.doubles); ++i)
    {
        out.push_back (makeDouble (lead, sampleRate, i, juce::jlimit (1, 3, options.doubles), rng));
        if (! tick()) return out;
    }
    for (int i = 0; i < juce::jlimit (0, 3, options.harmonies); ++i)
    {
        out.push_back (makeHarmony (lead, sampleRate, i));
        if (! tick()) return out;
    }
    if (options.keywordBacks)
    {
        out.push_back (makeKeywordBacks (lead, sampleRate, options.keywordSyllables));
        if (! tick()) return out;
    }
    if (options.adLibs)
    {
        int placed = 0;
        auto t = makeAdLibs (lead, sampleRate, options, rng, placed);
        if (placed > 0)
            out.push_back (std::move (t));
        else
            SV_LOG_INFO (kMod, "Aucun silence assez long pour placer un ad-lib");
        if (! tick()) return out;
    }
    if (options.ambiance)
    {
        out.push_back (makeAmbiance (lead, sampleRate, options.ambianceType));
        tick();
    }

    for (const auto& t : out)
        SV_LOG_INFO (kMod, "Piste générée : "_u8 + t.name + " (" + t.detail + ")");
    return out;
}
} // namespace sv::gen
