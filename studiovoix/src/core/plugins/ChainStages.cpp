#include "ChainStages.h"

#include "../Log.h"

namespace sv::plugins
{
namespace
{
    constexpr const char* kMod = "ChaineVisible";

    const std::vector<ChainStage>& stages()
    {
        static const std::vector<ChainStage> list = {
            { "clean", "Nettoyage", "interne:clean" },
            { "leveler", "Niveleur", "interne:leveler" },
            { "tune", "Autotune", "interne:tune" },
            { "eq", "EQ", "interne:eq" },
            { "reso", "Résonances", "interne:reso" },
            { "comp", "Compresseur", "interne:comp" },
            { "deess", "De-esser", "interne:deess" },
            { "comp2", "Compresseur 2", "interne:comp" },
            { "sat", "Saturation", "interne:sat" },
            { "reverb", "Réverb", "interne:reverb" },
            { "delay", "Délai", "interne:delay" },
        };
        return list;
    }

    juce::String num (float v)
    {
        const auto t = juce::String (v, 1);
        return t.endsWith (".0") ? t.dropLastCharacters (2) : t;
    }
    juce::String db (float v) { return (v > 0.0f ? "+" : "") + num (v) + " dB"; }
    juce::String hz (float f) { return f >= 1000.0f ? num (f / 1000.0f) + " kHz" : juce::String (juce::roundToInt (f)) + " Hz"; }
    juce::String pct (float v) { return juce::String (juce::roundToInt (v * 100.0f)) + " %"; }
} // namespace

const std::vector<ChainStage>& chainStages() { return stages(); }

const ChainStage* findStage (const juce::String& id)
{
    for (const auto& s : stages())
        if (id == s.id)
            return &s;
    return nullptr;
}

juce::MemoryBlock stageState (const ChainStage& s, const style::VocalParams& p)
{
    const auto* def = findInternal (s.pluginId);
    if (def == nullptr)
        return {};
    auto state = defaultInternalState (*def);
    auto set = [&] (const char* id, float v) { state = withInternalParam (*def, state, id, v); };
    const juce::String id (s.id);
    if (id == "clean")
    {
        set ("hpf", p.clean.hpfHz);
        set ("denoise", p.clean.denoiseDb);
        set ("gate", p.clean.gateRangeDb);
        set ("breath", p.clean.breathReductionDb);
        set ("plosive", p.clean.dePlosive ? 1.0f : 0.0f);
        set ("declip", p.clean.declip ? 1.0f : 0.0f);
    }
    else if (id == "leveler")
    {
        set ("target", p.leveler.targetDb);
        set ("boost", p.leveler.maxBoostDb);
        set ("cut", p.leveler.maxCutDb);
        set ("surge", p.leveler.surgeCutDb);
        set ("speed", p.leveler.releaseMs);
    }
    else if (id == "tune")
    {
        set ("amount", p.pitch.amount * 100.0f);
        set ("retune", p.pitch.retuneMs);
        set ("humanize", p.pitch.humanize * 100.0f);
    }
    else if (id == "eq")
    {
        set ("lowCut", p.eq.lowCutHz);
        set ("lowDb", p.eq.lowShelfDb);
        set ("mudDb", p.eq.mudDb);
        set ("presHz", p.eq.presenceHz);
        set ("presDb", p.eq.presenceDb);
        set ("airDb", p.eq.airDb);
        set ("highCut", p.eq.highCutHz <= 0.0f ? 20000.0f : p.eq.highCutHz);
    }
    else if (id == "reso")
    {
        set ("thr", p.resonance.thresholdDb);
        set ("max", p.resonance.maxReductionDb);
        set ("protect", p.resonance.protectBelowHz);
        set ("mix", p.resonance.mix * 100.0f);
    }
    else if (id == "comp" || id == "comp2")
    {
        const auto& c = id == "comp" ? p.comp : p.comp2;
        set ("thr", c.thresholdDb);
        set ("ratio", c.ratio);
        set ("att", c.attackMs);
        set ("rel", c.releaseMs);
        set ("makeup", c.makeupDb);
        set ("mix", c.mix * 100.0f);
    }
    else if (id == "deess")
    {
        set ("freq", p.deEss.freqHz);
        set ("amount", p.deEss.amount * 100.0f);
        set ("maxDb", p.deEss.maxReductionDb);
    }
    else if (id == "sat")
    {
        set ("drive", p.sat.driveDb);
        set ("mix", p.sat.mix * 100.0f);
    }
    else if (id == "reverb")
    {
        set ("send", p.reverb.send * 100.0f);
        set ("size", p.reverb.roomSize * 100.0f);
        set ("damp", p.reverb.damping * 100.0f);
        set ("pre", p.reverb.preDelayMs);
    }
    else if (id == "delay")
    {
        set ("send", p.delay.send * 100.0f);
        set ("note", p.delay.noteBeats);
        set ("fb", p.delay.feedback * 100.0f);
        set ("pingpong", p.delay.pingPong ? 1.0f : 0.0f);
    }
    return state;
}

void applyStageState (const ChainStage& s, const juce::MemoryBlock& state, style::VocalParams& p)
{
    const auto* def = findInternal (s.pluginId);
    if (def == nullptr || state.getSize() == 0)
        return;
    auto P = [&] (const char* id) { return internalParam (*def, state, id); };
    const juce::String id (s.id);
    if (id == "clean")
    {
        p.clean.enabled = true;
        p.clean.hpfHz = std::max (20.0f, P ("hpf"));
        p.clean.denoiseDb = P ("denoise");
        p.clean.gateRangeDb = P ("gate");
        p.clean.breathReductionDb = P ("breath");
        p.clean.dePlosive = P ("plosive") >= 0.5f;
        p.clean.declip = P ("declip") >= 0.5f;
    }
    else if (id == "leveler")
    {
        p.leveler.enabled = true;
        p.leveler.targetDb = P ("target");
        p.leveler.maxBoostDb = P ("boost");
        p.leveler.maxCutDb = P ("cut");
        p.leveler.surgeCutDb = P ("surge");
        p.leveler.releaseMs = P ("speed");
        p.leveler.attackMs = std::max (100.0f, P ("speed") * 0.2f);
    }
    else if (id == "tune")
    {
        p.pitch.amount = P ("amount") / 100.0f;
        p.pitch.enabled = p.pitch.amount > 0.001f;
        p.pitch.retuneMs = P ("retune");
        p.pitch.humanize = P ("humanize") / 100.0f;
    }
    else if (id == "eq")
    {
        p.eq.lowCutHz = std::max (20.0f, P ("lowCut"));
        p.eq.lowShelfDb = P ("lowDb");
        p.eq.mudDb = P ("mudDb");
        p.eq.presenceHz = P ("presHz");
        p.eq.presenceDb = P ("presDb");
        p.eq.airDb = P ("airDb");
        p.eq.highCutHz = P ("highCut") >= 19999.0f ? 0.0f : P ("highCut");
    }
    else if (id == "reso")
    {
        p.resonance.enabled = true;
        p.resonance.thresholdDb = P ("thr");
        p.resonance.maxReductionDb = P ("max");
        p.resonance.protectBelowHz = P ("protect");
        p.resonance.mix = P ("mix") / 100.0f;
    }
    else if (id == "comp" || id == "comp2")
    {
        auto& c = id == "comp" ? p.comp : p.comp2;
        c.thresholdDb = P ("thr");
        c.ratio = P ("ratio");
        c.attackMs = P ("att");
        c.releaseMs = P ("rel");
        c.makeupDb = P ("makeup");
        c.mix = P ("mix") / 100.0f;
    }
    else if (id == "deess")
    {
        p.deEss.freqHz = P ("freq");
        p.deEss.amount = P ("amount") / 100.0f;
        p.deEss.maxReductionDb = P ("maxDb");
    }
    else if (id == "sat")
    {
        p.sat.driveDb = P ("drive");
        p.sat.mix = P ("mix") / 100.0f;
    }
    else if (id == "reverb")
    {
        p.reverb.send = P ("send") / 100.0f;
        p.reverb.roomSize = P ("size") / 100.0f;
        p.reverb.damping = P ("damp") / 100.0f;
        p.reverb.preDelayMs = P ("pre");
    }
    else if (id == "delay")
    {
        p.delay.send = P ("send") / 100.0f;
        p.delay.noteBeats = P ("note");
        p.delay.feedback = P ("fb") / 100.0f;
        p.delay.pingPong = P ("pingpong") >= 0.5f;
    }
}

void bypassStage (const ChainStage& s, style::VocalParams& p)
{
    const juce::String id (s.id);
    if (id == "clean")        p.clean.enabled = false;
    else if (id == "leveler") p.leveler.enabled = false;
    else if (id == "tune")    p.pitch.enabled = false;
    else if (id == "eq")
    {
        p.eq.lowCutHz = 20.0f;   // 20 Hz : inaudible (jamais 0 Hz, le filtre ne converge pas)
        p.eq.lowShelfDb = p.eq.mudDb = p.eq.presenceDb = p.eq.airDb = 0.0f;
        p.eq.highCutHz = 0.0f;
    }
    else if (id == "reso")    p.resonance.enabled = false;
    else if (id == "comp")    p.comp.ratio = 1.0f;
    else if (id == "deess")   p.deEss.amount = 0.0f;
    else if (id == "comp2")   p.comp2.ratio = 1.0f;
    else if (id == "sat")     p.sat.mix = 0.0f;
    else if (id == "reverb")  p.reverb.send = 0.0f;
    else if (id == "delay")   p.delay.send = 0.0f;
}

bool stageActive (const ChainStage& s, const style::VocalParams& p)
{
    const juce::String id (s.id);
    if (id == "clean")   return p.clean.enabled;
    if (id == "leveler") return p.leveler.enabled;
    if (id == "tune")    return p.pitch.enabled && p.pitch.amount > 0.01f;
    if (id == "eq")
        return p.eq.lowCutHz > 30.0f || p.eq.highCutHz > 0.0f || std::abs (p.eq.lowShelfDb) > 0.05f || std::abs (p.eq.mudDb) > 0.05f
               || std::abs (p.eq.presenceDb) > 0.05f || std::abs (p.eq.airDb) > 0.05f;
    if (id == "reso")    return p.resonance.enabled;
    if (id == "comp")    return p.comp.ratio > 1.01f;
    if (id == "deess")   return p.deEss.amount > 0.001f;
    if (id == "comp2")   return p.comp2.ratio > 1.01f;
    if (id == "sat")     return p.sat.mix > 0.001f;
    if (id == "reverb")  return p.reverb.send > 0.001f;
    if (id == "delay")   return p.delay.send > 0.001f;
    return false;
}

juce::String stageSummary (const ChainStage& s, const style::VocalParams& p)
{
    if (! stageActive (s, p))
        return "off";
    const juce::String id (s.id);
    if (id == "clean")   return hz (p.clean.hpfHz) + ", -" + num (p.clean.denoiseDb) + " dB";
    if (id == "leveler") return db (p.leveler.targetDb) + " +" + num (p.leveler.maxBoostDb) + "/-" + num (p.leveler.maxCutDb);
    if (id == "tune")    return pct (p.pitch.amount) + ", " + juce::String (juce::roundToInt (p.pitch.retuneMs)) + " ms";
    if (id == "eq")
    {
        juce::StringArray parts;
        if (p.eq.lowCutHz > 30.0f) parts.add ("CB " + hz (p.eq.lowCutHz));
        if (std::abs (p.eq.mudDb) > 0.05f) parts.add (db (p.eq.mudDb) + " " + hz (p.eq.mudHz));
        if (std::abs (p.eq.presenceDb) > 0.05f) parts.add (db (p.eq.presenceDb) + " " + hz (p.eq.presenceHz));
        if (std::abs (p.eq.airDb) > 0.05f) parts.add (db (p.eq.airDb) + " air");
        // Case étroite : trois éléments au plus (le détail complet est dans l'info-bulle et le rapport).
        while (parts.size() > 3)
            parts.remove (parts.size() - 1);
        return parts.joinIntoString (", ");
    }
    if (id == "reso")    return num (p.resonance.thresholdDb) + " dB, max " + num (p.resonance.maxReductionDb);
    if (id == "comp")    return num (p.comp.ratio) + ":1 " + db (p.comp.thresholdDb);
    if (id == "deess")   return hz (p.deEss.freqHz) + " " + pct (p.deEss.amount);
    if (id == "comp2")   return num (p.comp2.ratio) + ":1 " + db (p.comp2.thresholdDb);
    if (id == "sat")     return db (p.sat.driveDb) + " " + pct (p.sat.mix);
    if (id == "reverb")  return pct (p.reverb.send) + ", " + juce::String (juce::roundToInt (p.reverb.preDelayMs)) + " ms";
    if (id == "delay")   return pct (p.delay.send) + ", " + num (p.delay.noteBeats) + " temps";
    return {};
}

juce::String applyStageOverrides (const std::map<juce::String, StageOverride>& overrides, style::VocalParams& p)
{
    juce::StringArray lines;
    for (const auto& [id, ov] : overrides)
    {
        const auto* s = findStage (id);
        if (s == nullptr)
        {
            SV_LOG_WARN (kMod, "Étape inconnue ignorée : "_u8 + id);
            continue;
        }
        const juce::String name (juce::CharPointer_UTF8 (s->name));
        if (ov.bypass)
        {
            bypassStage (*s, p);
            lines.add (name + " : contourné"_u8);
        }
        else if (ov.state.getSize() > 0)
        {
            applyStageState (*s, ov.state, p);
            lines.add (name + " : " + stageSummary (*s, p) + " (réglé à la main)"_u8);
        }
    }
    return lines.joinIntoString (" ; ");
}
} // namespace sv::plugins
