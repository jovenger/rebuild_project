#include "CommandParser.h"

#include "../Log.h"

namespace sv::assistant
{
namespace
{
    constexpr const char* kMod = "Assistant";

    enum class Target { Autotune, Presence, Space, Reverb, Delay, Energy, Level };

    struct Keyword
    {
        const char* word;
        Target target;
        int inherentSign;   // sens propre du mot ("sombre" = moins de présence)
    };

    // Mots sans accents (le texte est normalisé avant comparaison).
    const Keyword kKeywords[] = {
        { "autotune", Target::Autotune, +1 }, { "auto-tune", Target::Autotune, +1 }, { "auto tune", Target::Autotune, +1 },
        { "justesse", Target::Autotune, +1 }, { "correction", Target::Autotune, +1 }, { "robot", Target::Autotune, +1 },
        { "naturel", Target::Autotune, -1 }, { "naturelle", Target::Autotune, -1 },
        { "presence", Target::Presence, +1 }, { "brillant", Target::Presence, +1 }, { "brillante", Target::Presence, +1 },
        { "clair", Target::Presence, +1 }, { "claire", Target::Presence, +1 }, { "aigu", Target::Presence, +1 },
        { "aigus", Target::Presence, +1 }, { "air", Target::Presence, +1 }, { "devant", Target::Presence, +1 },
        { "sombre", Target::Presence, -1 }, { "chaud", Target::Presence, -1 }, { "chaude", Target::Presence, -1 },
        { "mat", Target::Presence, -1 }, { "etouffe", Target::Presence, -1 }, { "grave", Target::Presence, -1 },
        { "reverb", Target::Reverb, +1 }, { "reverbe", Target::Reverb, +1 }, { "reverberation", Target::Reverb, +1 },
        { "salle", Target::Reverb, +1 },
        { "delai", Target::Delay, +1 }, { "delay", Target::Delay, +1 }, { "echo", Target::Delay, +1 },
        { "espace", Target::Space, +1 }, { "ambiance", Target::Space, +1 }, { "aere", Target::Space, +1 },
        { "aeree", Target::Space, +1 }, { "large", Target::Space, +1 }, { "sec", Target::Space, -1 }, { "seche", Target::Space, -1 },
        { "energie", Target::Energy, +1 }, { "agressif", Target::Energy, +1 }, { "agressive", Target::Energy, +1 },
        { "punch", Target::Energy, +1 }, { "patate", Target::Energy, +1 }, { "compression", Target::Energy, +1 },
        { "compresse", Target::Energy, +1 }, { "sature", Target::Energy, +1 }, { "saturation", Target::Energy, +1 },
        { "doux", Target::Energy, -1 }, { "douce", Target::Energy, -1 }, { "calme", Target::Energy, -1 },
        { "fort", Target::Level, +1 }, { "forte", Target::Level, +1 }, { "volume", Target::Level, +1 },
        { "faible", Target::Level, -1 },
    };

    const char* targetName (Target t)
    {
        switch (t)
        {
            case Target::Autotune: return "autotune";
            case Target::Presence: return "presence";
            case Target::Space:    return "espace";
            case Target::Reverb:   return "reverb";
            case Target::Delay:    return "delai";
            case Target::Energy:   return "energie";
            case Target::Level:    return "volume";
        }
        return "?";
    }

    float& field (style::Macros& m, Target t)
    {
        switch (t)
        {
            case Target::Autotune: return m.autotune;
            case Target::Presence: return m.presence;
            case Target::Space:    return m.space;
            case Target::Reverb:   return m.reverbTrim;
            case Target::Delay:    return m.delayTrim;
            case Target::Energy:   return m.energy;
            case Target::Level:    return m.level;
        }
        return m.level;
    }

    bool containsWord (const juce::String& text, const juce::String& word)
    {
        int idx = text.indexOf (word);
        while (idx >= 0)
        {
            const bool startOk = idx == 0 || ! juce::CharacterFunctions::isLetter (text[idx - 1]);
            const int end = idx + word.length();
            const bool endOk = end >= text.length() || ! juce::CharacterFunctions::isLetter (text[end]);
            if (startOk && endOk)
                return true;
            idx = text.indexOf (idx + 1, word);
        }
        return false;
    }
}

juce::String normalise (const juce::String& text)
{
    // Correspondance par point de code (plus fiable qu'une suite de String::replace sur des
    // séquences UTF-8 de plusieurs octets).
    juce::String out;
    const juce::String lower = text.toLowerCase();   // doit vivre pendant tout le parcours (pas de temporaire)
    for (auto p = lower.getCharPointer(); ! p.isEmpty();)
    {
        const juce::juce_wchar c = p.getAndAdvance();
        switch (c)
        {
            case 0xE0: case 0xE2: case 0xE4: out << 'a'; break;
            case 0xE9: case 0xE8: case 0xEA: case 0xEB: out << 'e'; break;
            case 0xEE: case 0xEF: out << 'i'; break;
            case 0xF4: case 0xF6: out << 'o'; break;
            case 0xF9: case 0xFB: case 0xFC: out << 'u'; break;
            case 0xE7: out << 'c'; break;
            case 0x153: out << "oe"; break;
            case 0x2019: case 0x2018: out << '\''; break;
            default: out << juce::String::charToString (c); break;
        }
    }
    return out.replace ("d'", "de ").replace ("l'", "le ");
}

CommandResult apply (const juce::String& text, const style::Macros& current)
{
    CommandResult res;
    res.macros = current;
    const auto t = normalise (text);
    if (t.trim().isEmpty())
        return res;

    // Sens global : "moins", "baisse", "enleve"... sinon "plus".
    int direction = +1;
    for (const char* neg : { "moins", "baisse", "diminue", "enleve", "retire", "reduis", "reduit", "sans", "pas assez" })
        if (containsWord (t, neg))
            direction = -1;
    if (containsWord (t, "pas assez"))
        direction = +1;
    for (const char* pos : { "plus", "augmente", "monte", "ajoute", "rajoute", "davantage" })
        if (containsWord (t, pos) && ! containsWord (t, "moins"))
            direction = +1;
    if (containsWord (t, "trop"))
        direction = -1;   // "trop de réverb" = en enlever

    float amount = 0.15f;
    for (const char* big : { "beaucoup", "vraiment", "tres", "carrement", "a fond", "max" })
        if (containsWord (t, big))
            amount = 0.3f;
    for (const char* small : { "un peu", "legerement", "leger", "petit", "chouia" })
        if (containsWord (t, small))
            amount = 0.07f;

    std::vector<Target> done;
    for (const auto& kw : kKeywords)
    {
        if (! containsWord (t, kw.word))
            continue;
        if (std::find (done.begin(), done.end(), kw.target) != done.end())
            continue;
        done.push_back (kw.target);

        float& f = field (res.macros, kw.target);
        const float before = f;
        f = juce::jlimit (0.0f, 1.0f, f + static_cast<float> (direction * kw.inherentSign) * amount);
        res.understood = true;
        res.changes.add (juce::String (targetName (kw.target)) + " : " + juce::String (before, 2) + " -> " + juce::String (f, 2));
    }

    SV_LOG_INFO (kMod, "Demande \"" + text + "\" -> " + (res.understood ? res.changes.joinIntoString ("; ") : juce::String ("non comprise")));
    return res;
}
} // namespace sv::assistant
