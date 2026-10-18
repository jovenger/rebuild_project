#include "StyleProfiles.h"

namespace sv::style
{
namespace
{
    struct StyleInfo
    {
        const char* id;
        const char* name;
    };

    constexpr StyleInfo kStyles[] = {
        { "rap", "Rap / Hip-hop" },
        { "trap", "Trap" },
        { "pop_urbaine", "Pop urbaine" },
        { "rnb", "R&B" },
        { "drill", "Drill" },
        { "afro", "Afro" },
    };

    constexpr StyleInfo kRoles[] = {
        { "instru", "Instru" },
        { "lead", "Voix principale" },
        { "double", "Doublage" },
        { "harmony", "Harmonie" },
        { "keyword_back", "Backs mots clés" },
        { "adlib", "Ad-libs" },
        { "ambiance", "Ambiance" },
        { "manual_back", "Back enregistré" },
    };

    float lerp (float a, float b, float t) { return a + (b - a) * t; }

    VocalParams leadBase (Style s)
    {
        VocalParams p;
        p.clean.enabled = true;
        p.clean.dePlosive = true;
        p.clean.gateRangeDb = 12.0f;
        p.clean.breathReductionDb = 8.0f;
        p.comp2.ratio = 1.0f;   // désactivé par défaut
        p.reverb.hpfHz = 300.0f;
        p.reverb.lpfHz = 9000.0f;
        p.delay.hpfHz = 350.0f;
        p.delay.lpfHz = 6000.0f;

        switch (s)
        {
            case Style::Rap:
                p.pitch = { true, 0.15f, 80.0f, 0.8f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 4000.0f, 3.0f, 0.9f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 5.0f, 80.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 20.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 6500.0f, 0.6f, 10.0f, -8.0f };
                p.sat = { 3.0f, 0.3f, 0.1f };
                p.reverb.send = 0.08f; p.reverb.roomSize = 0.35f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.10f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.2f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Trap:
                p.pitch = { true, 1.0f, 5.0f, 0.0f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -22.0f, 6.0f, 6.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 6500.0f, 0.7f, 10.0f, -8.0f };
                p.sat = { 6.0f, 0.4f, 0.15f };
                p.reverb.send = 0.15f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.20f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::PopUrbaine:
                p.pitch = { true, 0.7f, 20.0f, 0.4f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3000.0f, 2.5f, 0.8f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 6500.0f, 0.7f, 10.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.20f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.12f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.25f;
                p.outputDb = -14.0f;
                break;
            case Style::RnB:
                p.pitch = { true, 0.5f, 40.0f, 0.7f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.5f, 350.0f, -1.5f, 1.0f, 3000.0f, 1.5f, 0.8f, 11000.0f, 3.0f, 0.0f };
                p.comp = { -22.0f, 3.0f, 8.0f, 15.0f, 150.0f, 0.0f, 0.85f, true };
                p.comp2 = { -28.0f, 1.8f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 6000.0f, 0.8f, 10.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.30f; p.reverb.roomSize = 0.75f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 40.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.3f;
                p.outputDb = -14.0f;
                break;
            case Style::Drill:
                p.pitch = { true, 0.6f, 15.0f, 0.2f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 2500.0f, 4.0f, 1.0f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -20.0f, 6.0f, 4.0f, 2.0f, 50.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 6500.0f, 0.6f, 10.0f, -8.0f };
                p.sat = { 7.0f, 0.45f, 0.2f };
                p.reverb.send = 0.08f; p.reverb.roomSize = 0.3f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 15.0f;
                p.delay.send = 0.10f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.25f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Afro:
            case Style::Count:
                p.pitch = { true, 0.8f, 15.0f, 0.3f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 6500.0f, 0.7f, 10.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.25f; p.reverb.roomSize = 0.65f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.20f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.35f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
        }
        return p;
    }

    void applyRole (VocalParams& p, Role r)
    {
        switch (r)
        {
            case Role::Lead:
            case Role::Instru:
            case Role::Count:
                break;
            case Role::Double:
                p.outputDb -= 7.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 14.0f;
                p.eq.lowCutHz = 150.0f;
                p.eq.presenceDb -= 2.0f;
                p.eq.airDb -= 1.0f;
                p.comp.ratio += 2.0f;
                p.deEss.amount = std::min (1.0f, p.deEss.amount + 0.2f);
                p.sat.mix *= 0.7f;
                p.reverb.send *= 0.6f;
                p.delay.send = 0.0f;
                p.timing.strength = 0.0f;
                break;
            case Role::Harmony:
                p.outputDb -= 11.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 14.0f;
                p.eq.lowCutHz = 200.0f;
                p.eq.presenceDb -= 3.0f;
                p.eq.airDb += 1.0f;
                p.comp.ratio += 2.0f;
                p.comp.thresholdDb -= 3.0f;
                p.deEss.amount = std::min (1.0f, p.deEss.amount + 0.3f);
                p.sat.mix *= 0.5f;
                p.reverb.send = p.reverb.send * 1.5f + 0.05f;
                p.delay.send *= 0.5f;
                break;
            case Role::KeywordBack:
                p.outputDb -= 6.0f;
                p.pitch.enabled = false;
                p.clean.gateRangeDb = 20.0f;
                p.eq.lowCutHz = 180.0f;
                p.eq.mudDb -= 1.0f;
                p.eq.presenceDb += 1.0f;
                p.sat.driveDb += 4.0f;
                p.sat.mix = std::min (0.8f, p.sat.mix + 0.15f);
                p.reverb.send *= 0.5f;
                p.delay.send = 0.0f;
                p.width = 0.6f;
                break;
            case Role::AdLib:
                p.outputDb -= 9.0f;
                p.pitch.enabled = false;
                p.eq.lowCutHz = 220.0f;
                p.eq.highCutHz = 9000.0f;
                p.sat.driveDb += 6.0f;
                p.sat.mix = std::min (0.8f, p.sat.mix + 0.25f);
                p.delay.send = std::max (0.25f, p.delay.send);
                p.delay.throwsOnly = false;
                p.delay.feedback = 0.35f;
                p.reverb.send *= 1.3f;
                break;
            case Role::Ambiance:
                p.outputDb -= 18.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 20.0f;
                p.eq.lowCutHz = 250.0f;
                p.eq.highCutHz = 6000.0f;
                p.dryGain = 0.15f;
                p.reverb.send = 1.0f;
                p.reverb.roomSize = 0.95f;
                p.reverb.damping = 0.6f;
                p.reverb.width = 1.0f;
                p.reverb.preDelayMs = 60.0f;
                p.delay.send = 0.2f;
                p.delay.noteBeats = 2.0f;
                p.delay.feedback = 0.4f;
                p.delay.throwsOnly = false;
                p.comp.ratio = 2.0f;
                p.comp2.ratio = 1.0f;
                p.sat.mix = 0.0f;
                p.width = 1.0f;
                p.deEss.amount = 0.9f;
                break;
            case Role::ManualBack:
                p.outputDb -= 6.0f;
                p.eq.lowCutHz = 160.0f;
                p.eq.presenceDb += 1.0f;
                p.sat.driveDb += 3.0f;
                p.reverb.send *= 0.7f;
                p.delay.send *= 0.5f;
                p.width = 0.4f;
                break;
        }
    }

    void applyMacros (VocalParams& p, const Macros& m)
    {
        // Autotune
        const float a = juce::jlimit (0.0f, 1.0f, m.autotune);
        if (a <= 0.5f)
        {
            p.pitch.amount *= a / 0.5f;
        }
        else
        {
            const float t = (a - 0.5f) / 0.5f;
            p.pitch.amount = lerp (p.pitch.amount, 1.0f, t);
            p.pitch.retuneMs = lerp (p.pitch.retuneMs, 2.0f, t);
            p.pitch.humanize = lerp (p.pitch.humanize, 0.0f, t);
        }
        if (p.pitch.amount < 0.02f)
            p.pitch.enabled = false;

        // Présence
        const float pr = (juce::jlimit (0.0f, 1.0f, m.presence) - 0.5f) * 2.0f;
        p.eq.presenceDb += pr * 5.0f;
        p.eq.airDb += pr * 4.0f;
        p.eq.mudDb -= pr * 1.5f;

        // Espace
        const float sp = juce::jlimit (0.0f, 1.0f, m.space) * 2.0f;
        const float rt = juce::jlimit (0.0f, 1.0f, m.reverbTrim) * 2.0f;
        const float dt = juce::jlimit (0.0f, 1.0f, m.delayTrim) * 2.0f;
        p.reverb.send = juce::jlimit (0.0f, 1.5f, p.reverb.send * sp * rt);
        p.delay.send = juce::jlimit (0.0f, 1.0f, p.delay.send * sp * dt);

        // Énergie
        const float en = (juce::jlimit (0.0f, 1.0f, m.energy) - 0.5f) * 2.0f;
        if (p.comp.ratio > 1.0f)
        {
            p.comp.ratio = std::max (1.5f, p.comp.ratio * (1.0f + 0.5f * en));
            p.comp.thresholdDb -= en * 6.0f;
        }
        p.sat.driveDb = std::max (0.0f, p.sat.driveDb + en * 6.0f);
        if (p.sat.mix > 0.0f || en > 0.0f)
            p.sat.mix = juce::jlimit (0.0f, 0.8f, p.sat.mix + en * 0.2f);

        // Volume
        p.outputDb += (juce::jlimit (0.0f, 1.0f, m.level) - 0.5f) * 24.0f;
    }
}

juce::String styleId (Style s) { return kStyles[juce::jlimit (0, 5, static_cast<int> (s))].id; }
juce::String styleName (Style s) { return juce::String (juce::CharPointer_UTF8 (kStyles[juce::jlimit (0, 5, static_cast<int> (s))].name)); }

Style styleFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (Style::Count); ++i)
        if (id == kStyles[i].id)
            return static_cast<Style> (i);
    return Style::Rap;
}

juce::String roleId (Role r) { return kRoles[juce::jlimit (0, 7, static_cast<int> (r))].id; }
juce::String roleName (Role r) { return juce::String (juce::CharPointer_UTF8 (kRoles[juce::jlimit (0, 7, static_cast<int> (r))].name)); }

Role roleFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (Role::Count); ++i)
        if (id == kRoles[i].id)
            return static_cast<Role> (i);
    return Role::Lead;
}

juce::var Macros::toVar() const
{
    auto* o = new juce::DynamicObject();
    o->setProperty ("autotune", autotune);
    o->setProperty ("presence", presence);
    o->setProperty ("space", space);
    o->setProperty ("energy", energy);
    o->setProperty ("level", level);
    o->setProperty ("reverbTrim", reverbTrim);
    o->setProperty ("delayTrim", delayTrim);
    return juce::var (o);
}

Macros Macros::fromVar (const juce::var& v)
{
    Macros m;
    auto get = [&] (const char* key, float def)
    {
        const auto x = v.getProperty (key, def);
        const float f = static_cast<float> (static_cast<double> (x));
        return std::isfinite (f) ? juce::jlimit (0.0f, 1.0f, f) : def;
    };
    m.autotune = get ("autotune", 0.5f);
    m.presence = get ("presence", 0.5f);
    m.space = get ("space", 0.5f);
    m.energy = get ("energy", 0.5f);
    m.level = get ("level", 0.5f);
    m.reverbTrim = get ("reverbTrim", 0.5f);
    m.delayTrim = get ("delayTrim", 0.5f);
    return m;
}

VocalParams makeParams (Style s, Role r, const Macros& macros)
{
    VocalParams p = leadBase (s);
    applyRole (p, r);
    applyMacros (p, macros);
    return p;
}

GenerationDefaults generationDefaults (Style s)
{
    GenerationDefaults g;
    switch (s)
    {
        case Style::Rap:        g = { 1, 0, true, true, true, 0.3f, 2, 0.45f }; break;
        case Style::Trap:       g = { 2, 1, true, true, true, 0.3f, 2, 0.6f }; break;
        case Style::PopUrbaine: g = { 1, 1, true, false, true, 0.5f, 2, 0.3f }; break;
        case Style::RnB:        g = { 1, 2, false, true, true, 0.8f, 1, 0.25f }; break;
        case Style::Drill:      g = { 1, 0, true, true, false, 0.0f, 1, 0.5f }; break;
        case Style::Afro:
        case Style::Count:      g = { 1, 2, false, true, true, 0.6f, 2, 0.5f }; break;
    }
    return g;
}

MasterTone masterTone (Style s)
{
    switch (s)
    {
        case Style::Rap:        return { 1.0f, 0.5f, 1.5f };
        case Style::Trap:       return { 1.5f, 1.0f, 0.5f };
        case Style::PopUrbaine: return { 0.5f, 1.5f, 1.5f };
        case Style::RnB:        return { 1.0f, 1.0f, 1.0f };
        case Style::Drill:      return { 1.5f, 0.5f, 0.5f };
        case Style::Afro:
        case Style::Count:      return { 1.0f, 1.0f, 1.0f };
    }
    return {};
}
} // namespace sv::style
