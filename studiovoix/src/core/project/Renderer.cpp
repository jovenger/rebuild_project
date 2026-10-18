#include "Renderer.h"

#include "../Log.h"
#include "../Loudness.h"
#include "../analysis/SpectrumAnalyzer.h"
#include "../analysis/ContentClassifier.h"
#include "../dsp/ProblemAnalyzer.h"
#include "../dsp/TrackRepair.h"

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
    juce::StringArray missing;
    for (const auto& tk : t.takes)
    {
        juce::String err;
        auto data = cache.mono (p.audioDir().getChildFile (tk.file), p.sampleRate, err);
        if (data == nullptr)
        {
            SV_LOG_WARN (kMod, "Prise ignorée ("_u8 + tk.file + ") : " + err);
            missing.add (tk.file);
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
    if (! missing.isEmpty())
        summary << " | PRISE(S) MANQUANTE(S) : "_u8 << missing.joinIntoString (", ");
    return ! out.empty();
}

namespace
{
    void applyTrackPlugins (const project::Project& p, const project::Track& t, TrackRender& r)
    {
        if (t.plugins.empty() || ! r.ok())
            return;
        r.pluginNotes = plugins::applyPluginChain (r.processed, p.sampleRate, t.plugins, p.tempo.bpm);
    }
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
        if (t.isCorrection())
        {
            // Instru (fichier mixé) : défauts mesurés sur la somme mono, réparation stéréo liée (image inchangée).
            auto problems = dsp::analyzeTrackProblems (audio::toMono (r->raw), p.sampleRate, ctx.key, false);
            auto params = dsp::correctionParams (problems, false);
            const auto rep = dsp::repairStereo (r->processed, p.sampleRate, params);
            r->report.compGrDb = rep.compGrDb;
            r->report.clean.clippedRepaired = rep.clippedRepaired;
            r->report.clean.noiseReducedDb = rep.noiseReducedDb;
            r->report.leveler = rep.leveler;
            r->report.resonance = rep.resonance;
            r->problemsReport = dsp::describeProblems (problems) + "\nRéparation : "_u8 + rep.summary().replace ("\n", " ; ");
            SV_LOG_INFO (kMod, "Instru « "_u8 + t.name + " » : correction automatique — "_u8 + r->problemsReport.replace ("\n", " | "));
        }
        applyTrackPlugins (p, t, *r);
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
    if (t.raw && ! t.isGenerated())
    {
        // Brut : le son tel qu'importé, sans aucun effet ni normalisation.
        r->processed.makeCopyOf (r->raw);
        SV_LOG_INFO (kMod, "Piste « "_u8 + t.name + " » brute : aucun effet"_u8 + (t.plugins.empty() ? "" : " (sauf ses plugins)"));
        applyTrackPlugins (p, t, *r);
        return r;
    }

    style::VocalParams params;
    if (t.isCorrection())
    {
        // Correction automatique : défauts mesurés sur le son brut, réglages déduits (son propre, sans effet de style).
        const bool vocal = t.isVoice();
        auto problems = dsp::analyzeTrackProblems (raw, p.sampleRate, ctx.key, vocal);
        params = dsp::correctionParams (problems, vocal);
        r->problemsReport = dsp::describeProblems (problems);
        SV_LOG_INFO (kMod, "Piste « "_u8 + t.name + " » : correction automatique — "_u8 + r->problemsReport.replace ("\n", " | "));
    }
    else
    {
        params = style::makeParams (p.trackStyle (t), t.role, t.macros, ! t.isGenerated());
        params.timing.strength = t.timingStrength;
        params.clean.enabled = t.cleaning;
        if (! t.isGenerated() && params.pitch.enabled)
        {
            // Fichier importé polyphonique (chœurs, piano, morceau) : l'autotune ferait des vagues ; on le coupe.
            const auto content = analysis::classifyContent (audio::monoToStereo (raw), p.sampleRate);
            if (! content.voice)
            {
                params.pitch.enabled = false;
                params.timing.strength = 0.0f;
                r->problemsReport = "Son polyphonique ou musical ("_u8 + content.reason + ") : correction de justesse et recalage désactivés, "
                                    "le reste du style est appliqué."_u8;
                SV_LOG_WARN (kMod, "Piste « "_u8 + t.name + " » : " + r->problemsReport);
            }
        }
    }
    params.referenceEq = t.referenceEq;
    if (t.isGenerated())
    {
        params.pan = t.genPan;
        params.width = std::max (params.width, t.genWidth);
    }

    // Le premier temps fort est mesuré depuis le début du morceau, la prise commence à « start » :
    // la grille du recalage rythmique est exprimée dans le temps de la prise.
    auto takeCtx = ctx;
    takeCtx.tempo.firstBeatSec -= static_cast<double> (start) / p.sampleRate;
    auto result = dsp::processVocal (raw, p.sampleRate, params, takeCtx, progress);
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
    if (result.report.scaleAdapted)
        r->problemsReport << (r->problemsReport.isEmpty() ? "" : "\n") << "Gamme adaptée à la voix : autotune vers "_u8 << result.report.adaptedKey.toFrench()
                          << " (" << juce::roundToInt (result.report.outOfScaleFraction * 100.0f) << " % des notes étaient hors "_u8 << p.key.toFrench() << ")";
    else if (result.report.chromaticUsed && result.report.outOfScaleFraction >= 0.25f)
        r->problemsReport << (r->problemsReport.isEmpty() ? "" : "\n") << "Notes dispersées ("_u8 << juce::roundToInt (result.report.outOfScaleFraction * 100.0f)
                          << " % hors "_u8 << p.key.toFrench() << ") : correction note par note, sans gamme"_u8;
    if (! result.report.leveler.surges.empty())
    {
        juce::StringArray s;
        for (const auto& su : result.report.leveler.surges)
            s.add (su.describe());
        r->problemsReport << (r->problemsReport.isEmpty() ? "" : "\n") << "Montées brusques rabaissées par le niveleur : "_u8 << s.joinIntoString (", ");
        SV_LOG_WARN (kMod, "Piste « "_u8 + t.name + " » : montées brusques "_u8 + s.joinIntoString (", "));
    }
    applyTrackPlugins (p, t, *r);
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

float roleOffsetLu (style::Role role)
{
    switch (role)
    {
        case style::Role::Double:      return -6.0f;
        case style::Role::KeywordBack: return -7.0f;
        case style::Role::Harmony:     return -8.0f;
        case style::Role::AdLib:       return -9.0f;
        case style::Role::Ambiance:    return -14.0f;
        case style::Role::Instrument:  return -4.0f;
        default:                       return 0.0f;
    }
}

MixState computeAutoMix (const project::Project& p, const RenderSet& renders)
{
    MixState st;
    if (! p.autoMixEnabled)
        return st;
    const auto* instru = p.instruTrack();
    const int leadId = p.leadTrackId();
    const auto* lead = p.findTrack (leadId);
    auto okRender = [&] (int id) -> const TrackRender*
    {
        auto it = renders.find (id);
        return (it != renders.end() && it->second != nullptr && it->second->ok()) ? it->second.get() : nullptr;
    };
    const TrackRender* leadR = lead != nullptr ? okRender (leadId) : nullptr;
    if (leadR == nullptr)
        return st;   // pas de voix principale rendue : rien à équilibrer

    // 1) Orchestre : chaque piste (hors voix principale et instru) mesurée et ramenée à sa place par rapport à la voix
    //    principale selon son rôle. Une piste brute garde son son (aucun effet) mais son niveau est géré aussi.
    const double leadLufs = loudness::integratedLufs (leadR->processed, p.sampleRate);
    {
        juce::StringArray lines;
        for (const auto& t : p.tracks)
        {
            if (t.id == leadId || t.role == style::Role::Instru || t.mute)
                continue;
            const auto* r = okRender (t.id);
            if (r == nullptr || leadLufs < -90.0)
                continue;
            const double lufs = loudness::integratedLufs (r->processed, p.sampleRate);
            if (lufs < -90.0)
                continue;
            const float offset = roleOffsetLu (t.role);
            const float gain = juce::jlimit (-8.0f, 6.0f, static_cast<float> (leadLufs + offset - lufs));
            if (std::abs (gain) >= 0.3f)
                st.trackGainDb[t.id] = gain;
            lines.add (t.name + " : " + juce::String (lufs - leadLufs, 1) + " LU sous la voix, place "_u8 + juce::String (offset, 0) + " LU -> gain "
                       + (gain >= 0.0f ? "+" : "") + juce::String (gain, 1) + " dB");
        }
        st.balanceReport = lines.joinIntoString ("\n");
        if (! lines.isEmpty())
            SV_LOG_INFO (kMod, "Orchestre : " + lines.joinIntoString (" | "));
    }

    // 2) Voix / instru : sonie de la voix par rapport à l'instru, creux de l'instru sous la voix.
    const TrackRender* instruR = instru != nullptr ? okRender (instru->id) : nullptr;
    if (instruR != nullptr)
    {
        const auto& instruBuf = instruR->processed;
        const int n = instruBuf.getNumSamples();
        auto place = [&] (const TrackRender& r, Stereo& dst, float gain)
        {
            const long offset = r.startSample - instruR->startSample;
            for (int c = 0; c < 2; ++c)
                for (int i = 0; i < r.processed.getNumSamples(); ++i)
                {
                    const long d = offset + i;
                    if (d >= 0 && d < n)
                        dst.addSample (c, static_cast<int> (d), r.processed.getSample (c, i) * gain);
                }
        };
        Stereo all = makeStereo (n);
        for (const auto& t : p.tracks)
        {
            if (! t.isVoice() || t.mute)   // un instrument enregistré ne creuse pas l'instru
                continue;
            if (const auto* r = okRender (t.id))
                place (*r, all, dbToGain (t.volumeDb + st.autoTrackGain (t.id)));
        }
        mix::AutoMixSettings s;
        s.enabled = true;
        s.duckingDb = instru->raw ? 0.0f : p.duckingDb;   // instru brute : pas de creux sous la voix
        s.vocalOverInstruLu = style::masterTone (p.style).vocalOverInstruLu;
        // Sonie de la voix mesurée sur toute la voix (pas seulement là où elle recouvre l'instru).
        st.autoMix = mix::autoMix (instruBuf, leadR->processed, all, p.sampleRate, s);
        st.autoMixApplied = true;
    }

    // 3) Sonie du mixage obtenu (affichée dans la barre du haut).
    st.mixLufs = loudness::integratedLufs (mixdown (p, renders, st), p.sampleRate);
    SV_LOG_INFO (kMod, "Mixage : " + juce::String (st.mixLufs, 1) + " LUFS avant mastering");
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
        if (t.role == style::Role::Instru && ! t.raw && mixState.autoMixApplied && mixState.autoMix.duckedInstru.getNumSamples() > 0)
            src = &mixState.autoMix.duckedInstru;

        float gl, gr;
        balanceGains (t.pan, gl, gr);
        const float vocalGain = t.isVoice() && mixState.autoMixApplied ? mixState.autoMix.vocalGainDb : 0.0f;
        const float g = dbToGain (t.volumeDb + vocalGain + mixState.autoTrackGain (t.id));
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
