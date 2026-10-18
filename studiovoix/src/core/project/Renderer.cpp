#include "Renderer.h"

#include "../Log.h"
#include "../Loudness.h"
#include "../analysis/SpectrumAnalyzer.h"

namespace sv::render
{
namespace
{
    constexpr const char* kMod = "Renderer";

    void balanceGains (float pan, float& gl, float& gr)
    {
        const float p = juce::jlimit (-1.0f, 1.0f, pan);
        gl = p <= 0.0f ? 1.0f : 1.0f - p;
        gr = p >= 0.0f ? 1.0f : 1.0f + p;
    }

    bool anySolo (const project::Project& p)
    {
        for (const auto& t : p.tracks)
            if (t.solo)
                return true;
        return false;
    }
}

// ---------------------------------------------------------------------------------------------
std::shared_ptr<const Mono> AudioCache::mono (const juce::File& file, double sampleRate, juce::String& error)
{
    const auto key = file.getFullPathName() + "@" + juce::String (sampleRate);
    {
        std::lock_guard<std::mutex> lock (mutex);
        if (auto it = monoCache.find (key); it != monoCache.end())
            return it->second;
    }
    Mono m;
    if (! audio::loadMono (file, sampleRate, m, error))
        return nullptr;
    auto ptr = std::make_shared<const Mono> (std::move (m));
    std::lock_guard<std::mutex> lock (mutex);
    monoCache[key] = ptr;
    return ptr;
}

std::shared_ptr<const Stereo> AudioCache::stereo (const juce::File& file, double sampleRate, juce::String& error)
{
    const auto key = file.getFullPathName() + "@" + juce::String (sampleRate);
    {
        std::lock_guard<std::mutex> lock (mutex);
        if (auto it = stereoCache.find (key); it != stereoCache.end())
            return it->second;
    }
    auto res = audio::loadStereo (file, sampleRate);
    if (! res.ok())
    {
        error = res.error;
        return nullptr;
    }
    auto ptr = std::make_shared<const Stereo> (std::move (res.buffer));
    std::lock_guard<std::mutex> lock (mutex);
    stereoCache[key] = ptr;
    return ptr;
}

void AudioCache::put (const juce::File& file, Mono data)
{
    std::lock_guard<std::mutex> lock (mutex);
    const auto key = file.getFullPathName() + "@" + juce::String (kProjectSampleRate);
    monoCache[key] = std::make_shared<const Mono> (std::move (data));
}

void AudioCache::clear()
{
    std::lock_guard<std::mutex> lock (mutex);
    monoCache.clear();
    stereoCache.clear();
}

// ---------------------------------------------------------------------------------------------
dsp::AnalysisContext makeContext (const project::Project& p, AudioCache& cache)
{
    dsp::AnalysisContext ctx;
    ctx.key = p.key;
    ctx.tempo = p.tempo;
    if (p.referenceFile.isNotEmpty())
    {
        juce::String err;
        const juce::File ref (p.referenceFile);
        if (auto st = cache.stereo (ref, p.sampleRate, err))
            ctx.reference = analysis::averageSpectrum (audio::toMono (*st), p.sampleRate);
        else
            SV_LOG_WARN (kMod, "Morceau de référence illisible : "_u8 + err);
    }
    return ctx;
}

bool compositeRaw (const project::Project& p, const project::Track& t, AudioCache& cache, Mono& out, long& start,
                   juce::String& summary, juce::String& error)
{
    out.clear();
    start = 0;

    if (t.isGenerated() || (t.takes.empty() && t.sourceFile.isNotEmpty()))
    {
        auto data = cache.mono (p.audioDir().getChildFile (t.sourceFile), p.sampleRate, error);
        if (data == nullptr)
            return false;
        out = *data;
        start = t.sourceStart;
        summary = t.detail;
        return true;
    }

    if (t.takes.empty())
    {
        error = "La piste " + t.name + " n'a aucune prise";
        return false;
    }

    std::vector<std::shared_ptr<const Mono>> holders;
    std::vector<gen::TakeInput> inputs;
    for (const auto& tk : t.takes)
    {
        juce::String err;
        auto data = cache.mono (p.audioDir().getChildFile (tk.file), p.sampleRate, err);
        if (data == nullptr)
        {
            SV_LOG_WARN (kMod, "Prise ignorée ("_u8 + tk.file + ") : " + err);
            continue;
        }
        holders.push_back (data);
        gen::TakeInput in;
        in.audio = data.get();
        in.startSample = tk.startSample;
        in.regionStart = tk.regionStart;
        in.regionEnd = tk.regionEnd;
        in.id = tk.id;
        inputs.push_back (in);
    }
    if (inputs.empty())
    {
        error = "Aucune prise lisible pour " + t.name;
        return false;
    }

    const auto res = t.comp == project::CompMode::Best && inputs.size() > 1
                       ? gen::compBest (inputs, p.sampleRate, p.key, p.tempo, p.style)
                       : gen::compLatest (inputs, p.sampleRate);
    out = res.audio;
    start = res.startSample;
    summary = res.summary;
    return ! out.empty();
}

std::shared_ptr<TrackRender> renderTrack (const project::Project& p, const project::Track& t, AudioCache& cache,
                                          const dsp::AnalysisContext& ctx, const ProgressFn& progress)
{
    log::ScopedTimer timer (kMod, "rendu de la piste " + t.name);
    auto r = std::make_shared<TrackRender>();
    r->trackId = t.id;

    if (t.role == style::Role::Instru)
    {
        juce::String err;
        auto st = cache.stereo (p.audioDir().getChildFile (t.sourceFile), p.sampleRate, err);
        if (st == nullptr)
        {
            r->error = "Instru illisible : " + err;
            SV_LOG_ERROR (kMod, r->error);
            return r;
        }
        r->processed.makeCopyOf (*st);
        r->raw.makeCopyOf (*st);
        r->startSample = t.sourceStart;
        return r;
    }

    Mono raw;
    long start = 0;
    juce::String err;
    if (! compositeRaw (p, t, cache, raw, start, r->compSummary, err))
    {
        r->error = err;
        SV_LOG_ERROR (kMod, err);
        return r;
    }
    r->startSample = start;
    r->raw = audio::monoToStereo (raw);

    auto params = style::makeParams (p.style, t.role, t.macros);
    params.timing.strength = t.timingStrength;
    params.clean.enabled = t.cleaning;
    params.referenceEq = t.referenceEq;
    if (t.isGenerated())
    {
        params.pan = t.genPan;
        params.width = std::max (params.width, t.genWidth);
    }

    auto result = dsp::processVocal (raw, p.sampleRate, params, ctx, progress);
    if (result.cancelled)
    {
        r->error = "Rendu annulé"_u8;
        return r;
    }
    r->processed = std::move (result.audio);
    r->prepared = std::move (result.prepared);
    r->track = std::move (result.track);
    r->va = std::move (result.va);
    r->report = result.report;
    return r;
}

std::vector<int> generateBackingTracks (project::Project& p, int leadTrackId, const TrackRender& leadRender,
                                        const gen::GenerationOptions& options, juce::String& error, const ProgressFn& progress)
{
    std::vector<int> ids;
    const auto* lead = p.findTrack (leadTrackId);
    if (lead == nullptr || leadRender.prepared.empty())
    {
        error = "Voix principale introuvable ou pas encore traitée"_u8;
        SV_LOG_ERROR (kMod, error);
        return ids;
    }
    const juce::String leadName = lead->name;
    const style::Macros leadMacros = lead->macros;

    gen::LeadAnalysis la;
    la.prepared = leadRender.prepared;
    la.track = leadRender.track;
    la.va = leadRender.va;
    la.key = p.key;
    la.tempo = p.tempo;

    const auto generated = gen::generate (la, p.sampleRate, options, progress);

    // Les anciennes pistes générées depuis cette voix sont remplacées.
    std::vector<int> old;
    for (const auto& t : p.tracks)
        if (t.generatedFrom == leadTrackId)
            old.push_back (t.id);
    for (int id : old)
        p.removeTrack (id);

    for (const auto& g : generated)
    {
        auto& t = p.addTrack (g.role, g.name);
        t.generatedFrom = leadTrackId;
        t.detail = g.detail;
        t.genPan = g.pan;
        t.genWidth = g.width;
        t.sourceStart = leadRender.startSample;
        t.macros = leadMacros;
        t.macros.level = 0.5f;
        t.sourceFile = "gen_" + juce::String (leadTrackId) + "_" + juce::String (t.id) + "_"
                     + juce::String (juce::Time::currentTimeMillis()) + ".wav";
        juce::String err;
        if (! audio::writeMonoWavFloat (p.audioDir().getChildFile (t.sourceFile), g.audio, p.sampleRate, err))
        {
            error = "Écriture de "_u8 + g.name + " impossible : " + err;
            SV_LOG_ERROR (kMod, error);
            p.removeTrack (t.id);
            continue;
        }
        ids.push_back (t.id);
    }
    SV_LOG_INFO (kMod, juce::String ((int) ids.size()) + " pistes générées depuis "_u8 + leadName);
    return ids;
}

MixState computeAutoMix (const project::Project& p, const RenderSet& renders)
{
    MixState st;
    if (! p.autoMixEnabled)
        return st;
    const auto* instru = p.instruTrack();
    const int leadId = p.leadTrackId();
    if (instru == nullptr || leadId < 0)
        return st;
    auto itI = renders.find (instru->id);
    auto itL = renders.find (leadId);
    if (itI == renders.end() || itL == renders.end() || itI->second == nullptr || itL->second == nullptr
        || ! itI->second->ok() || ! itL->second->ok())
        return st;

    // Voix placées sur la timeline de l'instru.
    const auto& instruBuf = itI->second->processed;
    const int n = instruBuf.getNumSamples();
    auto place = [&] (const TrackRender& r, Stereo& dst, float gain)
    {
        const long offset = r.startSample - itI->second->startSample;
        for (int c = 0; c < 2; ++c)
            for (int i = 0; i < r.processed.getNumSamples(); ++i)
            {
                const long d = offset + i;
                if (d >= 0 && d < n)
                    dst.addSample (c, static_cast<int> (d), r.processed.getSample (c, i) * gain);
            }
    };
    Stereo lead = makeStereo (n), all = makeStereo (n);
    place (*itL->second, lead, 1.0f);
    for (const auto& t : p.tracks)
    {
        if (! t.isVocal() || t.mute)
            continue;
        if (auto it = renders.find (t.id); it != renders.end() && it->second != nullptr && it->second->ok())
            place (*it->second, all, dbToGain (t.volumeDb));
    }

    mix::AutoMixSettings s;
    s.enabled = true;
    s.duckingDb = p.duckingDb;
    s.vocalOverInstruLu = style::masterTone (p.style).vocalOverInstruLu;
    st.autoMix = mix::autoMix (instruBuf, lead, all, p.sampleRate, s);
    st.autoMixApplied = true;
    return st;
}

Stereo mixdown (const project::Project& p, const RenderSet& renders, const MixState& mixState, bool useRaw)
{
    log::ScopedTimer timer (kMod, "mixage");
    const juce::ScopedNoDenormals noDenormals;
    long end = 0;
    for (const auto& t : p.tracks)
        if (auto it = renders.find (t.id); it != renders.end() && it->second != nullptr && it->second->ok())
            end = std::max (end, it->second->startSample + it->second->processed.getNumSamples());

    Stereo mixBuf = makeStereo (static_cast<int> (std::max (0L, end)));
    const bool solo = anySolo (p);
    for (const auto& t : p.tracks)
    {
        if (t.mute || (solo && ! t.solo))
            continue;
        auto it = renders.find (t.id);
        if (it == renders.end() || it->second == nullptr || ! it->second->ok())
            continue;
        const auto& r = *it->second;
        const Stereo* src = (useRaw || ! t.processingEnabled) && t.isVocal() ? &r.raw : &r.processed;
        if (t.role == style::Role::Instru && mixState.autoMixApplied && mixState.autoMix.duckedInstru.getNumSamples() > 0)
            src = &mixState.autoMix.duckedInstru;

        float gl, gr;
        balanceGains (t.pan, gl, gr);
        const float vocalGain = t.isVocal() && mixState.autoMixApplied ? mixState.autoMix.vocalGainDb : 0.0f;
        const float g = dbToGain (t.volumeDb + vocalGain);
        for (int i = 0; i < src->getNumSamples(); ++i)
        {
            const long d = r.startSample + i;
            if (d < 0 || d >= end)
                continue;
            mixBuf.addSample (0, static_cast<int> (d), src->getSample (0, i) * g * gl);
            mixBuf.addSample (1, static_cast<int> (d), src->getSample (1, i) * g * gr);
        }
    }
    return mixBuf;
}

ExportReport exportProject (const project::Project& p, const RenderSet& renders, const ExportOptions& options,
                            const ProgressFn& progress)
{
    log::ScopedTimer timer (kMod, "export");
    ExportReport rep;
    const auto ext = audio::extensionFor (options.format);
    const auto mixState = computeAutoMix (p, renders);
    rep.vocalGainDb = mixState.autoMix.vocalGainDb;
    if (progress && ! progress (0.2f))
    {
        rep.error = "Export annulé"_u8;
        return rep;
    }

    Stereo mixBuf = mixdown (p, renders, mixState);
    if (mixBuf.getNumSamples() == 0)
    {
        rep.error = "Rien à exporter (aucune piste rendue)"_u8;
        SV_LOG_ERROR (kMod, rep.error);
        return rep;
    }

    dsp::MasterSettings ms;
    ms.enabled = options.master && p.masterEnabled;
    ms.target = p.target;
    const auto tone = style::masterTone (p.style);
    ms.lowShelfDb = tone.lowShelfDb;
    ms.highShelfDb = tone.highShelfDb;
    // MP3 : l'encodage ajoute des crêtes, on vise -2 dBTP au lieu de -1.
    ms.extraHeadroomDb = options.format == audio::FileFormat::Mp3_320 ? 1.0f : 0.0f;
    Stereo mastered = dsp::master (mixBuf, p.sampleRate, ms, rep.master);
    if (! ms.enabled)
    {
        // Sans mastering : simple protection contre l'écrêtage, puis mesures du fichier réellement écrit.
        const float ceilingTp = -1.0f - ms.extraHeadroomDb;
        dsp::limitStereo (mastered, p.sampleRate, ceilingTp - 0.3f);
        rep.master.truePeakDb = loudness::truePeakDb (mastered);
        if (rep.master.truePeakDb > ceilingTp)
        {
            mastered.applyGain (dbToGain (static_cast<float> (ceilingTp - 0.05 - rep.master.truePeakDb)));
            rep.master.truePeakDb = loudness::truePeakDb (mastered);
        }
        rep.master.outputLufs = loudness::integratedLufs (mastered, p.sampleRate);
    }
    if (progress && ! progress (0.6f))
    {
        rep.error = "Export annulé"_u8;
        return rep;
    }

    // Jamais d'écrasement : un export existant du même nom donne « nom (2) », « nom (3) »…
    rep.mixFile = options.outDir.getChildFile (audio::safeFileName (options.baseName, "mix") + ext);
    if (rep.mixFile.exists())
        rep.mixFile = rep.mixFile.getNonexistentSibling (true);
    juce::String err;
    if (! audio::writeFile (rep.mixFile, mastered, p.sampleRate, options.format, err))
    {
        rep.error = err;
        return rep;
    }

    if (options.stems)
    {
        // Pistes séparées : chacune traitée, avec son volume, sans mastering, alignées sur 0.
        auto stemsDir = options.outDir.getChildFile (rep.mixFile.getFileNameWithoutExtension() + "_pistes");
        if (stemsDir.exists())
            stemsDir = stemsDir.getNonexistentSibling (true);
        int idx = 1, failed = 0, limited = 0;
        for (const auto& t : p.tracks)
        {
            auto it = renders.find (t.id);
            if (it == renders.end() || it->second == nullptr || ! it->second->ok())
                continue;
            project::Project solo = p;
            for (auto& st : solo.tracks)
            {
                st.solo = st.id == t.id;
                st.mute = false;
            }
            Stereo stem = mixdown (solo, renders, mixState);
            // Une piste qui dépasserait 0 dBFS serait écrêtée net dans le fichier : limiteur de sécurité.
            if (std::max (stem.getMagnitude (0, 0, stem.getNumSamples()), stem.getMagnitude (1, 0, stem.getNumSamples())) > 0.999f)
            {
                dsp::limitStereo (stem, p.sampleRate, -0.3f);
                ++limited;
                SV_LOG_WARN (kMod, "Piste séparée au-dessus de 0 dBFS, limitée : "_u8 + t.name);
            }
            const auto file = stemsDir.getChildFile (juce::String (idx++).paddedLeft ('0', 2) + "_"
                                                     + audio::safeFileName (t.name, "piste") + ext);
            if (audio::writeFile (file, stem, p.sampleRate, options.format, err))
            {
                rep.stemFiles.add (file.getFullPathName());
            }
            else
            {
                ++failed;
                SV_LOG_ERROR (kMod, "Piste séparée non écrite ("_u8 + t.name + ") : " + err);
            }
        }
        juce::StringArray warnings;
        if (failed > 0)
            warnings.add (juce::String (failed) + " piste(s) séparée(s) non écrite(s) : "_u8 + err);
        if (limited > 0)
            warnings.add (juce::String (limited) + " piste(s) séparée(s) trop forte(s), limitée(s) sous 0 dBFS"_u8);
        rep.warning = warnings.joinIntoString (" ; ");
    }

    if (progress)
        progress (1.0f);
    rep.ok = true;
    SV_LOG_INFO (kMod, "Export terminé : "_u8 + rep.mixFile.getFullPathName() + " + " + juce::String (rep.stemFiles.size()) + " pistes séparées"_u8
                       + (rep.warning.isNotEmpty() ? " — à vérifier : "_u8 + rep.warning : juce::String()));
    return rep;
}

int copySectionToSimilar (project::Project& p, int trackId, int sectionIndex, AudioCache& cache, juce::String& error)
{
    auto* t = p.findTrack (trackId);
    if (t == nullptr || sectionIndex < 0 || sectionIndex >= static_cast<int> (p.sections.size()))
    {
        error = "Piste ou section invalide";
        return 0;
    }
    const auto src = p.sections[static_cast<size_t> (sectionIndex)];
    const long a = static_cast<long> (src.startSec * p.sampleRate);
    const long b = static_cast<long> (src.endSec * p.sampleRate);

    Mono raw;
    long start = 0;
    juce::String summary;
    if (! compositeRaw (p, *t, cache, raw, start, summary, error))
        return 0;

    Mono part (static_cast<size_t> (std::max (0L, b - a)), 0.0f);
    for (long s = a; s < b; ++s)
    {
        const long idx = s - start;
        if (idx >= 0 && idx < static_cast<long> (raw.size()))
            part[static_cast<size_t> (s - a)] = raw[static_cast<size_t> (idx)];
    }
    if (audio::rms (part.data(), part.size()) < 1.0e-5f)
    {
        error = "La section \"" + src.label + "\" ne contient pas de voix sur cette piste";
        return 0;
    }

    int copies = 0, failed = 0;
    for (size_t i = 0; i < p.sections.size(); ++i)
    {
        const auto& dst = p.sections[i];
        if (static_cast<int> (i) == sectionIndex || dst.group != src.group)
            continue;
        project::Take tk;
        tk.id = p.nextTakeId++;
        tk.file = "copie_" + juce::String (tk.id) + "_" + juce::String (juce::Time::currentTimeMillis()) + ".wav";
        tk.startSample = static_cast<long> (dst.startSec * p.sampleRate);
        tk.regionStart = tk.startSample;
        tk.regionEnd = tk.startSample + std::min (static_cast<long> (part.size()), static_cast<long> ((dst.endSec - dst.startSec) * p.sampleRate));
        tk.createdMs = juce::Time::currentTimeMillis();
        juce::String err;
        if (! audio::writeMonoWavFloat (p.audioDir().getChildFile (tk.file), part, p.sampleRate, err))
        {
            ++failed;
            error = juce::String (failed) + " copie(s) impossible(s) : " + err;
            SV_LOG_ERROR (kMod, "Copie de section vers \"" + dst.label + "\" impossible : " + err);
            continue;
        }
        t->takes.push_back (tk);
        ++copies;
    }
    SV_LOG_INFO (kMod, "Section " + src.label + " copiée "_u8 + juce::String (copies) + " fois sur la piste " + t->name);
    return copies;
}
} // namespace sv::render
