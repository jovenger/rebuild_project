#include "PluginChain.h"

#include "../AudioIO.h"
#include "../Log.h"
#include "InternalPlugins.h"

namespace sv::plugins
{
namespace
{
    constexpr const char* kMod = "Plugins";
    constexpr int kBlock = 1024;

    InstanceFactory& factoryRef()
    {
        static InstanceFactory f;
        return f;
    }
}

juce::var PluginSlot::toVar() const
{
    auto* o = new juce::DynamicObject();
    o->setProperty ("id", identifier);
    o->setProperty ("name", name);
    o->setProperty ("state", state.toBase64Encoding());
    o->setProperty ("bypass", bypass);
    return juce::var (o);
}

PluginSlot PluginSlot::fromVar (const juce::var& v)
{
    PluginSlot s;
    s.identifier = v.getProperty ("id", {}).toString();
    s.name = v.getProperty ("name", {}).toString();
    if (! s.state.fromBase64Encoding (v.getProperty ("state", {}).toString()))
        s.state.reset();
    s.bypass = static_cast<bool> (v.getProperty ("bypass", false));
    return s;
}

void setInstanceFactory (InstanceFactory factory) { factoryRef() = std::move (factory); }
bool hasInstanceFactory() { return static_cast<bool> (factoryRef()); }

juce::StringArray applyPluginChain (Stereo& audio, double sr, const std::vector<PluginSlot>& slots, double bpm)
{
    juce::StringArray notes;
    if (slots.empty() || audio.getNumSamples() == 0)
        return notes;
    for (const auto& slot : slots)
    {
        if (slot.bypass)
        {
            notes.add (slot.name + " : contourné"_u8);
            continue;
        }
        if (isInternal (slot.identifier))
        {
            notes.add (applyInternal (audio, sr, bpm, slot));
            continue;
        }
        if (! hasInstanceFactory())
        {
            notes.add (slot.name + " : ignoré (aucun hôte de plugins VST3)"_u8);
            SV_LOG_WARN (kMod, notes[notes.size() - 1]);
            continue;
        }
        const auto t0 = juce::Time::getMillisecondCounterHiRes();
        juce::String err;
        auto instance = factoryRef() (slot, sr, kBlock, err);
        if (instance == nullptr)
        {
            notes.add (slot.name + " : non chargé ("_u8 + err + ")");
            SV_LOG_ERROR (kMod, "Plugin « "_u8 + slot.name + " » non chargé : "_u8 + err);
            continue;
        }
        instance->setNonRealtime (true);
        instance->setPlayConfigDetails (2, 2, sr, kBlock);
        instance->prepareToPlay (sr, kBlock);
        if (slot.state.getSize() > 0)
            instance->setStateInformation (slot.state.getData(), static_cast<int> (slot.state.getSize()));
        const int latency = std::max (0, instance->getLatencySamples());
        const int n = audio.getNumSamples();
        const int ins = instance->getTotalNumInputChannels(), outs = instance->getTotalNumOutputChannels();
        const int chans = std::max ({ 2, ins, outs });
        juce::AudioBuffer<float> block (chans, kBlock);
        juce::MidiBuffer midi;
        Stereo out (2, n);
        out.clear();
        // La latence est compensée en lisant « latency » échantillons de plus (queue silencieuse) et en décalant.
        for (int pos = 0; pos < n + latency; pos += kBlock)
        {
            const int len = std::min (kBlock, n + latency - pos);
            block.clear();
            for (int c = 0; c < 2; ++c)
                for (int i = 0; i < len; ++i)
                    if (pos + i < n)
                        block.setSample (c % std::max (1, ins > 0 ? ins : 2), i, audio.getSample (c, pos + i));
            juce::AudioBuffer<float> view (block.getArrayOfWritePointers(), chans, len);
            midi.clear();
            instance->processBlock (view, midi);
            for (int c = 0; c < 2; ++c)
            {
                const int src = outs > 0 ? c % outs : c;
                for (int i = 0; i < len; ++i)
                {
                    const int dst = pos + i - latency;
                    if (dst >= 0 && dst < n)
                        out.setSample (c, dst, view.getSample (src, i));
                }
            }
        }
        instance->releaseResources();
        const auto fixed = audio::sanitize (out.getWritePointer (0), static_cast<size_t> (n)) + audio::sanitize (out.getWritePointer (1), static_cast<size_t> (n));
        if (fixed > 0)
            SV_LOG_WARN (kMod, "Plugin « "_u8 + slot.name + " » : "_u8 + juce::String (static_cast<juce::int64> (fixed)) + " échantillons non finis corrigés"_u8);
        audio = std::move (out);
        const auto ms = juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0);
        notes.add (slot.name + (latency > 0 ? " (latence " + juce::String (latency) + " éch. compensée)"_u8 : juce::String()));
        SV_LOG_INFO (kMod, "Plugin « "_u8 + slot.name + " » appliqué en "_u8 + juce::String (ms) + " ms, latence " + juce::String (latency) + " échantillons"_u8);
    }
    return notes;
}
} // namespace sv::plugins
