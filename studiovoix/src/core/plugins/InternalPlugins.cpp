#include "InternalPlugins.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "../analysis/VoiceActivity.h"
#include "../dsp/Denoiser.h"
#include "../dsp/Leveler.h"
#include "../dsp/MasterChain.h"
#include "../dsp/Processors.h"

namespace sv::plugins
{
namespace
{
    constexpr const char* kMod = "EffetsIntegres";

    const std::vector<InternalPluginDef>& defs()
    {
        static const std::vector<InternalPluginDef> list = {
            { "interne:eq", "Égaliseur",
              { { "lowCut", "Coupe-bas (Hz)", 20.0f, 400.0f, 80.0f, "Hz" },
                { "lowDb", "Graves (< 200 Hz)", -12.0f, 12.0f, 0.0f, "dB" },
                { "mudDb", "Bas-médium (300 Hz)", -12.0f, 6.0f, 0.0f, "dB" },
                { "presHz", "Présence : fréquence", 1000.0f, 8000.0f, 3500.0f, "Hz" },
                { "presDb", "Présence : gain", -12.0f, 12.0f, 0.0f, "dB" },
                { "airDb", "Air (> 10 kHz)", -12.0f, 12.0f, 0.0f, "dB" },
                { "highCut", "Coupe-haut (Hz, 20000 = aucun)", 2000.0f, 20000.0f, 20000.0f, "Hz" } } },
            { "interne:comp", "Compresseur",
              { { "thr", "Seuil", -50.0f, 0.0f, -20.0f, "dB" },
                { "ratio", "Ratio", 1.0f, 20.0f, 4.0f, ":1" },
                { "att", "Attaque", 0.1f, 100.0f, 5.0f, "ms" },
                { "rel", "Relâche", 10.0f, 1000.0f, 80.0f, "ms" },
                { "makeup", "Gain de sortie", -12.0f, 24.0f, 0.0f, "dB" },
                { "mix", "Mélange (parallèle)", 0.0f, 100.0f, 100.0f, "%" } } },
            { "interne:deess", "De-esser",
              { { "freq", "Fréquence", 3000.0f, 12000.0f, 7000.0f, "Hz" },
                { "amount", "Force", 0.0f, 100.0f, 60.0f, "%" },
                { "maxDb", "Réduction max", 1.0f, 20.0f, 6.0f, "dB" } } },
            { "interne:sat", "Saturation",
              { { "drive", "Chauffe", 0.0f, 24.0f, 6.0f, "dB" },
                { "mix", "Mélange", 0.0f, 100.0f, 30.0f, "%" } } },
            { "interne:reverb", "Réverb",
              { { "send", "Niveau", 0.0f, 100.0f, 20.0f, "%" },
                { "size", "Taille", 0.0f, 100.0f, 55.0f, "%" },
                { "damp", "Amortissement", 0.0f, 100.0f, 50.0f, "%" },
                { "pre", "Pré-délai", 0.0f, 120.0f, 25.0f, "ms" } } },
            { "interne:delay", "Délai",
              { { "send", "Niveau", 0.0f, 100.0f, 15.0f, "%" },
                { "note", "Note (1 = noire, 0,5 = croche, 0,75 = croche pointée)", 0.125f, 2.0f, 0.5f, "temps" },
                { "fb", "Répétitions", 0.0f, 90.0f, 25.0f, "%" },
                { "pingpong", "Ping-pong (0 / 1)", 0.0f, 1.0f, 0.0f, "" } } },
            { "interne:gate", "Porte / débruiteur",
              { { "denoise", "Débruitage spectral", 0.0f, 30.0f, 12.0f, "dB" },
                { "gate", "Atténuation des silences", 0.0f, 40.0f, 10.0f, "dB" } } },
            { "interne:leveler", "Niveleur (fader suivi)",
              { { "target", "Niveau visé", -40.0f, -6.0f, -20.0f, "dB" },
                { "boost", "Montée max", 0.0f, 12.0f, 6.0f, "dB" },
                { "cut", "Baisse max", 0.0f, 12.0f, 6.0f, "dB" },
                { "surge", "Baisse des montées brusques", 0.0f, 18.0f, 12.0f, "dB" },
                { "speed", "Vitesse de remontée", 200.0f, 4000.0f, 1200.0f, "ms" } } },
            { "interne:reso", "Résonances (dureté)",
              { { "thr", "Seuil au-dessus du voisinage", 1.0f, 10.0f, 3.0f, "dB" },
                { "max", "Réduction max", 1.0f, 15.0f, 6.0f, "dB" },
                { "protect", "Graves protégés sous", 60.0f, 1000.0f, 500.0f, "Hz" },
                { "mix", "Mélange", 0.0f, 100.0f, 100.0f, "%" } } },
            { "interne:limiter", "Limiteur",
              { { "ceil", "Plafond (crête)", -12.0f, 0.0f, -1.0f, "dBTP" },
                { "gain", "Gain d'entrée", -12.0f, 24.0f, 0.0f, "dB" } } },
            { "interne:width", "Largeur stéréo",
              { { "width", "Largeur (100 = inchangé)", 0.0f, 200.0f, 100.0f, "%" } } },
            // Étapes de la chaîne du style sans équivalent insert : réglées par leur case dans la chaîne visible.
            { "interne:clean", "Nettoyage",
              { { "hpf", "Coupe-bas", 20.0f, 400.0f, 90.0f, "Hz" },
                { "denoise", "Débruitage spectral", 0.0f, 30.0f, 12.0f, "dB" },
                { "gate", "Atténuation des silences", 0.0f, 40.0f, 12.0f, "dB" },
                { "breath", "Respirations", 0.0f, 20.0f, 8.0f, "dB" },
                { "plosive", "Plosives p / b (0 / 1)", 0.0f, 1.0f, 1.0f, "" },
                { "declip", "Dé-écrêtage (0 / 1)", 0.0f, 1.0f, 1.0f, "" } },
              false },
            { "interne:tune", "Autotune",
              { { "amount", "Quantité", 0.0f, 100.0f, 50.0f, "%" },
                { "retune", "Vitesse (petit = effet marqué)", 1.0f, 200.0f, 30.0f, "ms" },
                { "humanize", "Naturel (variations gardées)", 0.0f, 100.0f, 50.0f, "%" } },
              false },
        };
        return list;
    }

    juce::var parse (const juce::MemoryBlock& state)
    {
        juce::var v;
        if (state.getSize() > 0)
            juce::JSON::parse (state.toString(), v);
        return v;
    }

    juce::MemoryBlock serialise (const juce::var& v)
    {
        juce::MemoryBlock b;
        const auto s = juce::JSON::toString (v, true);
        b.append (s.toRawUTF8(), s.getNumBytesAsUTF8());
        return b;
    }

    using audio::channel;
    using audio::setChannel;
}

const std::vector<InternalPluginDef>& internalPlugins() { return defs(); }

const InternalPluginDef* findInternal (const juce::String& identifier)
{
    for (const auto& d : defs())
        if (identifier == d.identifier)
            return &d;
    return nullptr;
}

bool isInternal (const juce::String& identifier) { return identifier.startsWith ("interne:"); }

juce::MemoryBlock defaultInternalState (const InternalPluginDef& def)
{
    auto* o = new juce::DynamicObject();
    for (const auto& p : def.params)
        o->setProperty (p.id, p.def);
    return serialise (juce::var (o));
}

float internalParam (const InternalPluginDef& def, const juce::MemoryBlock& state, const juce::String& id)
{
    const auto v = parse (state);
    for (const auto& p : def.params)
        if (id == p.id)
        {
            const auto x = v.getProperty (p.id, p.def);
            const float f = static_cast<float> (static_cast<double> (x));
            return std::isfinite (f) ? juce::jlimit (p.min, p.max, f) : p.def;
        }
    return 0.0f;
}

juce::MemoryBlock withInternalParam (const InternalPluginDef& def, const juce::MemoryBlock& state, const juce::String& id, float value)
{
    auto v = parse (state);
    if (! v.isObject())
        v = parse (defaultInternalState (def));
    if (auto* o = v.getDynamicObject())
        o->setProperty (juce::Identifier (id), value);
    return serialise (v);
}

juce::String applyInternal (Stereo& audio, double sr, double bpm, const PluginSlot& slot)
{
    const auto* def = findInternal (slot.identifier);
    if (def == nullptr)
        return slot.name + " : effet intégré inconnu"_u8;
    if (! def->insertable)
    {
        SV_LOG_WARN (kMod, slot.name + " : règle une étape de la chaîne du style, pas un insert (ignoré)"_u8);
        return slot.name + " : pas un insert (ignoré)"_u8;
    }
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    auto P = [&] (const char* id) { return internalParam (*def, slot.state, id); };
    const juce::String id (slot.identifier);
    const int n = audio.getNumSamples();
    juce::String note = def->name;

    if (id == "interne:eq")
    {
        dsp::EqSettings eq;
        eq.lowCutHz = P ("lowCut");
        eq.lowShelfDb = P ("lowDb");
        eq.mudDb = P ("mudDb");
        eq.presenceHz = P ("presHz");
        eq.presenceDb = P ("presDb");
        eq.airDb = P ("airDb");
        eq.highCutHz = P ("highCut") >= 19999.0f ? 0.0f : P ("highCut");
        for (int c = 0; c < 2; ++c)
        {
            auto m = channel (audio, c);
            dsp::applyEq (m, sr, eq);
            setChannel (audio, c, m);
        }
    }
    else if (id == "interne:comp")
    {
        dsp::CompressorSettings cs { P ("thr"), P ("ratio"), 6.0f, P ("att"), P ("rel"), P ("makeup"), P ("mix") / 100.0f, false };
        const float gr = dsp::compressLinked (audio, sr, cs);   // canaux liés : l'image stéréo ne bouge pas
        note << " (" << juce::String (gr, 1) << " dB de réduction)"_u8;
    }
    else if (id == "interne:deess")
    {
        dsp::DeEsserSettings d { P ("freq"), P ("amount") / 100.0f, P ("maxDb"), -8.0f };
        for (int c = 0; c < 2; ++c)
        {
            auto m = channel (audio, c);
            dsp::deEss (m, sr, d);
            setChannel (audio, c, m);
        }
    }
    else if (id == "interne:sat")
    {
        dsp::SaturationSettings s { P ("drive"), P ("mix") / 100.0f, 0.15f };
        for (int c = 0; c < 2; ++c)
        {
            auto m = channel (audio, c);
            dsp::saturate (m, sr, s);
            setChannel (audio, c, m);
        }
    }
    else if (id == "interne:reverb" || id == "interne:delay")
    {
        // Retour d'effet calculé sur la somme mono, ajouté au signal (la traîne est tronquée à la longueur de la piste).
        Mono mono = audio::toMono (audio);
        Stereo ret;
        if (id == "interne:reverb")
        {
            dsp::ReverbSettings r;
            r.send = P ("send") / 100.0f;
            r.roomSize = P ("size") / 100.0f;
            r.damping = P ("damp") / 100.0f;
            r.preDelayMs = P ("pre");
            ret = dsp::reverbReturn (mono, sr, r);
        }
        else
        {
            dsp::DelaySettings d;
            d.send = P ("send") / 100.0f;
            d.noteBeats = P ("note");
            d.feedback = P ("fb") / 100.0f;
            d.pingPong = P ("pingpong") >= 0.5f;
            ret = dsp::delayReturn (mono, sr, bpm > 0.0 ? bpm : 120.0, d);
        }
        for (int c = 0; c < 2; ++c)
            for (int i = 0; i < n && i < ret.getNumSamples(); ++i)
                audio.addSample (c, i, ret.getSample (std::min (c, ret.getNumChannels() - 1), i));
    }
    else if (id == "interne:gate")
    {
        Mono mono = audio::toMono (audio);
        const auto va = analysis::analyzeVoice (mono, sr);
        float reduced = 0.0f;
        for (int c = 0; c < 2; ++c)
        {
            auto m = channel (audio, c);
            if (P ("denoise") > 0.0f)
                reduced = dsp::spectralDenoise (m, sr, va, P ("denoise")).reductionDb();
            if (P ("gate") > 0.0f)
            {
                dsp::CleanSettings cs;
                cs.hpfHz = 20.0f;
                cs.dePlosive = false;
                cs.breathReductionDb = 0.0f;
                cs.denoiseDb = 0.0f;
                cs.declip = false;
                cs.gateRangeDb = P ("gate");
                analysis::PitchTrack empty;
                dsp::clean (m, sr, cs, empty, va);
            }
            setChannel (audio, c, m);
        }
        note << " (bruit -" << juce::String (reduced, 1) << " dB)";
    }
    else if (id == "interne:leveler")
    {
        dsp::LevelerSettings ls;
        ls.enabled = true;
        ls.targetDb = P ("target");
        ls.maxBoostDb = P ("boost");
        ls.maxCutDb = P ("cut");
        ls.surgeCutDb = P ("surge");
        ls.releaseMs = P ("speed");
        ls.attackMs = std::max (100.0f, P ("speed") * 0.2f);
        const auto rep = dsp::autoLevelStereo (audio, sr, ls);
        note << " (étendue "_u8 << juce::String (rep.rangeBeforeDb, 1) << " -> " << juce::String (rep.rangeAfterDb, 1) << " dB"
             << (rep.surges.empty() ? juce::String() : ", " + juce::String (static_cast<int> (rep.surges.size())) + " montée(s) brusque(s)"_u8) << ")";
    }
    else if (id == "interne:reso")
    {
        dsp::ResonanceSettings rs;
        rs.enabled = true;
        rs.thresholdDb = P ("thr");
        rs.maxReductionDb = P ("max");
        rs.protectBelowHz = P ("protect");
        rs.mix = P ("mix") / 100.0f;
        const auto rep = dsp::suppressResonancesStereo (audio, sr, rs);
        note << " (" << juce::String (rep.meanReductionDb, 1) << " dB en moyenne, max " << juce::String (rep.maxReductionDb, 1) << " dB)";
    }
    else if (id == "interne:limiter")
    {
        audio.applyGain (dbToGain (P ("gain")));
        const float gr = dsp::limitStereo (audio, sr, P ("ceil"));
        note << " (" << juce::String (gr, 1) << " dB de limitation)";
    }
    else if (id == "interne:width")
    {
        const float w = P ("width") / 100.0f;
        for (int i = 0; i < n; ++i)
        {
            const float l = audio.getSample (0, i), r = audio.getSample (1, i);
            const float mid = 0.5f * (l + r), side = 0.5f * (l - r) * w;
            audio.setSample (0, i, mid + side);
            audio.setSample (1, i, mid - side);
        }
    }
    SV_LOG_INFO (kMod, note + " en " + juce::String (juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0)) + " ms");
    return note;
}
} // namespace sv::plugins
