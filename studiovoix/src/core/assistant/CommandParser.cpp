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
            // Minuscules et majuscules accentuées (toLowerCase ne traite que l'ASCII selon la locale).
            case 0xE0: case 0xE2: case 0xE4: case 0xC0: case 0xC2: case 0xC4: out << 'a'; break;
            case 0xE9: case 0xE8: case 0xEA: case 0xEB: case 0xC9: case 0xC8: case 0xCA: case 0xCB: out << 'e'; break;
            case 0xEE: case 0xEF: case 0xCE: case 0xCF: out << 'i'; break;
            case 0xF4: case 0xF6: case 0xD4: case 0xD6: out << 'o'; break;
            case 0xF9: case 0xFB: case 0xFC: case 0xD9: case 0xDB: case 0xDC: out << 'u'; break;
            case 0xE7: case 0xC7: out << 'c'; break;
            case 0x153: case 0x152: out << "oe"; break;
            case 0x2019: case 0x2018: out << '\''; break;
            default: out << juce::String::charToString (c); break;
        }
    }
    return out.replace ("d'", "de ").replace ("l'", "le ");
}

namespace
{
    // Valeur absolue demandée dans la proposition : « à 30 % », « 30 % », « à 0,5 », « à zéro ». -1 sinon.
    float absoluteValue (const juce::String& clause)
    {
        if (containsWord (clause, "a zero") || containsWord (clause, "zero"))
            return 0.0f;
        juce::StringArray tokens;
        tokens.addTokens (clause.replace ("%", " % "), " ", "");
        tokens.removeEmptyStrings();
        for (int i = 0; i < tokens.size(); ++i)
        {
            const auto tok = tokens[i].replace ("#", ".");
            if (! tok.containsOnly ("0123456789.") || ! tok.containsAnyOf ("0123456789"))
                continue;
            const bool percent = i + 1 < tokens.size() && (tokens[i + 1] == "%" || tokens[i + 1] == "pourcent" || tokens[i + 1] == "pourcents");
            const bool afterA = i > 0 && tokens[i - 1] == "a";
            if (! percent && ! afterA)
                continue;   // « de 10 % » relatif, ou nombre sans rapport
            if (! percent && i > 0 && tokens[i - 1] == "de")
                continue;
            const float v = tok.getFloatValue();
            return juce::jlimit (0.0f, 1.0f, percent || v > 1.0f ? v / 100.0f : v);
        }
        return -1.0f;
    }
}

CommandResult apply (const juce::String& text, const style::Macros& current)
{
    CommandResult res;
    res.macros = current;
    const auto t = normalise (text);
    if (t.trim().isEmpty())
        return res;

    // Une demande peut mêler plusieurs consignes : « plus de reverb et moins d'autotune ».
    // Chaque proposition a son propre sens.
    // Les décimales (« 0,5 », « 0.5 ») sont protégées avant le découpage sur la ponctuation.
    juce::String protectedText;
    for (int i = 0; i < t.length(); ++i)
    {
        const auto ch = t[i];
        const bool decimal = (ch == ',' || ch == '.') && i > 0 && i + 1 < t.length()
                             && juce::CharacterFunctions::isDigit (t[i - 1]) && juce::CharacterFunctions::isDigit (t[i + 1]);
        protectedText << juce::String::charToString (decimal ? juce::juce_wchar ('#') : ch);
    }
    juce::StringArray clauses;
    clauses.addTokens (protectedText.replace (" et ", ",").replace (" mais ", ",").replace (" puis ", ",").replace (";", ",").replace (".", ","), ",", "");
    clauses.trim();
    clauses.removeEmptyStrings();

    for (const auto& c : clauses)
    {
        // Sens : relatif (+1 / -1) ou mise à zéro (« pas de », « aucune », « coupe »…).
        int direction = +1;
        bool toZero = false;
        if (containsWord (c, "pas assez") || containsWord (c, "trop peu"))
            direction = +1;
        else if (containsWord (c, "trop"))
            direction = -1;   // « trop de réverb », « pas trop de réverb » = en enlever
        else
        {
            for (const char* strong : { "pas de", "pas le", "aucun", "aucune", "sans", "coupe", "supprime", "arrete", "stop", "ne", "zero" })
                if (containsWord (c, strong))
                    toZero = true;
            if (! toZero)
            {
                for (const char* neg : { "moins", "baisse", "diminue", "enleve", "retire", "reduis", "reduit" })
                    if (containsWord (c, neg))
                        direction = -1;
                for (const char* pos : { "plus", "augmente", "monte", "ajoute", "rajoute", "davantage" })
                    if (containsWord (c, pos) && ! containsWord (c, "moins"))
                        direction = +1;
            }
        }

        float amount = 0.15f;
        for (const char* big : { "beaucoup", "vraiment", "tres", "carrement", "a fond", "max" })
            if (containsWord (c, big))
                amount = 0.3f;
        for (const char* small : { "un peu", "legerement", "leger", "petit", "chouia" })
            if (containsWord (c, small))
                amount = 0.07f;
        const float absolute = absoluteValue (c);

        std::vector<Target> done;
        for (const auto& kw : kKeywords)
        {
            if (! containsWord (c, kw.word))
                continue;
            if (std::find (done.begin(), done.end(), kw.target) != done.end())
                continue;
            done.push_back (kw.target);

            float& f = field (res.macros, kw.target);
            const float before = f;
            if (absolute >= 0.0f && kw.inherentSign > 0)
                f = absolute;
            else if (toZero && kw.inherentSign > 0)
                f = 0.0f;
            else
                f = juce::jlimit (0.0f, 1.0f, f + static_cast<float> ((toZero ? -1 : direction) * kw.inherentSign) * amount);
            res.understood = true;
            res.changes.add (juce::String (targetName (kw.target)) + " : " + juce::String (before, 2) + " -> " + juce::String (f, 2));
        }
    }

    SV_LOG_INFO (kMod, "Demande \"" + text + "\" -> " + (res.understood ? res.changes.joinIntoString ("; ") : juce::String ("non comprise")));
    return res;
}
} // namespace sv::assistant
