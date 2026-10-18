// studiovoix_cli : traitement hors ligne et tests.
//
//   studiovoix_cli test
//   studiovoix_cli analyze <instru>
//   studiovoix_cli remix <voix> [--instru <instru>] [--style trap] [--role lead] -o <sortie.wav>
//   studiovoix_cli song <instru> <voix> [--style trap] [--target spotify] [--stems] -o <dossier>
//   studiovoix_cli demo [--style trap] -o <dossier>          (instru + voix de synthèse)
//   studiovoix_cli master <mix> [--target spotify] -o <sortie.wav>

#include "core/AudioIO.h"
#include "core/Log.h"
#include "core/Loudness.h"
#include "core/analysis/KeyDetector.h"
#include "core/analysis/StructureDetector.h"
#include "core/analysis/TempoDetector.h"
#include "core/assistant/CommandParser.h"
#include "core/dsp/MasterChain.h"
#include "core/dsp/VocalChain.h"
#include "core/dsp/PitchCorrector.h"
#include "core/dsp/ProblemAnalyzer.h"
#include "core/analysis/VoiceActivity.h"
#include "core/analysis/PitchDetector.h"
#include "core/project/Project.h"
#include "core/project/Renderer.h"
#include "tests/TestSignals.h"

#include <iostream>

namespace sv::test
{
int runAllTests();
}

namespace
{
constexpr const char* kMod = "CLI";

struct Args
{
    juce::StringArray positional;
    juce::StringPairArray options;
    bool has (const juce::String& k) const { return options.containsKey (k); }
    juce::String get (const juce::String& k, const juce::String& def = {}) const { return has (k) ? options[k] : def; }
};

Args parse (int argc, char* argv[])
{
    Args a;
    for (int i = 2; i < argc; ++i)
    {
        const juce::String s = juce::String::fromUTF8 (argv[i]);
        if (s.startsWith ("--") || s == "-o")
        {
            const auto key = s == "-o" ? juce::String ("out") : s.substring (2);
            if (i + 1 < argc && ! juce::String (argv[i + 1]).startsWith ("-"))
                a.options.set (key, juce::String::fromUTF8 (argv[++i]));
            else
                a.options.set (key, "1");
        }
        else
        {
            a.positional.add (s);
        }
    }
    return a;
}

juce::File fileArg (const juce::String& p)
{
    return juce::File::getCurrentWorkingDirectory().getChildFile (p);
}

void usage()
{
    std::cout << "studiovoix_cli <commande>\n"
                 "  test                                   lance les tests automatiques\n"
                 "  analyze <instru>                       tonalite, tempo, structure\n"
                 "  remix <voix> [--instru f] [--style s] [--role r] -o sortie.wav\n"
                 "  song <instru> <voix> [--style s] [--target t] [--stems] -o dossier\n"
                 "  demo [--style s] [--bars N] -o dossier chaine complete sur signaux de synthese\n"
                 "  master <mix> [--target t] -o sortie.wav\n"
                 "  assistant <phrase>                     teste l'assistant texte\n"
                 "  presets                                effets pre-regles de chaque style (Markdown)\n"
                 "styles : rap trap pop_urbaine rnb drill afro rock latino rap_melodique boom_bap pop\n"
                 "         variete dancehall zouk amapiano gospel electro acoustique rap_conscient\n"
                 "         rap_hardcore cloud_rap rage plugg emo_rap afro_trap lofi phonk jersey_club\n"
                 "         rai bouyon funk_bresilien afro_house country\n"
                 "cibles : spotify youtube apple tiktok fort none\n";
}

struct InstruAnalysis
{
    sv::MusicalKey key;
    sv::TempoInfo tempo;
    std::vector<sv::analysis::Section> sections;
};

InstruAnalysis analyseInstru (const sv::Mono& mono, double sr)
{
    InstruAnalysis a;
    a.key = sv::analysis::detectKey (mono, sr).key;
    a.tempo = sv::analysis::detectTempo (mono, sr);
    a.sections = sv::analysis::detectStructure (mono, sr, a.tempo);
    return a;
}

int cmdAnalyze (const Args& args)
{
    if (args.positional.isEmpty())
    {
        usage();
        return 2;
    }
    auto res = sv::audio::loadStereo (fileArg (args.positional[0]), sv::kProjectSampleRate);
    if (! res.ok())
    {
        std::cerr << res.error << std::endl;
        return 1;
    }
    const auto a = analyseInstru (sv::audio::toMono (res.buffer), sv::kProjectSampleRate);
    std::cout << "Tonalite : " << a.key.toFrench() << " (confiance " << a.key.confidence << ")\n"
              << "Tempo : " << a.tempo.bpm << " BPM, premier temps fort " << a.tempo.firstBeatSec << " s\n";
    for (const auto& s : a.sections)
        std::cout << "  " << s.label << " : " << s.startSec << " -> " << s.endSec << " s\n";
    std::cout << "Sonie : " << sv::loudness::integratedLufs (res.buffer, sv::kProjectSampleRate) << " LUFS\n";
    return 0;
}

int cmdRemix (const Args& args)
{
    if (args.positional.isEmpty() || ! args.has ("out"))
    {
        usage();
        return 2;
    }
    const double sr = sv::kProjectSampleRate;
    sv::Mono voice;
    juce::String err;
    if (! sv::audio::loadMono (fileArg (args.positional[0]), sr, voice, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    sv::dsp::AnalysisContext ctx;
    if (args.has ("instru"))
    {
        auto ins = sv::audio::loadStereo (fileArg (args.get ("instru")), sr);
        if (! ins.ok())
        {
            std::cerr << ins.error << std::endl;
            return 1;
        }
        const auto a = analyseInstru (sv::audio::toMono (ins.buffer), sr);
        ctx.key = a.key;
        ctx.tempo = a.tempo;
    }
    else
    {
        ctx.key = sv::analysis::detectKey (voice, sr).key;
    }
    const auto st = sv::style::styleFromId (args.get ("style", "rap"));
    const auto role = sv::style::roleFromId (args.get ("role", "lead"));
    const auto params = sv::style::makeParams (st, role, {});
    const auto res = sv::dsp::processVocal (voice, sr, params, ctx);
    if (! sv::audio::writeFile (fileArg (args.get ("out")), res.audio, sr, sv::audio::FileFormat::Wav24, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    std::cout << "Ecrit : " << fileArg (args.get ("out")).getFullPathName() << "\n";
    return 0;
}

int runSong (const sv::Stereo& instru, const sv::Mono& voice, const Args& args, const juce::File& outDir)
{
    const double sr = sv::kProjectSampleRate;
    juce::String err;
    const auto folder = sv::project::createProjectFolder (outDir, "projet", err);
    if (folder == juce::File())
    {
        std::cerr << err << std::endl;
        return 1;
    }

    sv::project::Project p;
    p.folder = folder;
    p.name = "Morceau";
    p.style = sv::style::styleFromId (args.get ("style", "trap"));
    p.target = sv::dsp::targetFromId (args.get ("target", "spotify"));

    const auto a = analyseInstru (sv::audio::toMono (instru), sr);
    p.key = a.key;
    p.tempo = a.tempo;
    p.sections = a.sections;

    if (! sv::audio::writeFile (p.audioDir().getChildFile ("instru.wav"), instru, sr, sv::audio::FileFormat::Wav24, err)
        || ! sv::audio::writeMonoWavFloat (p.audioDir().getChildFile ("prise_1.wav"), voice, sr, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    auto& ins = p.addTrack (sv::style::Role::Instru, "Instru");
    ins.sourceFile = "instru.wav";
    auto& lead = p.addTrack (sv::style::Role::Lead, "Voix principale");
    sv::project::Take tk;
    tk.id = p.nextTakeId++;
    tk.file = "prise_1.wav";
    tk.regionEnd = static_cast<long> (voice.size());
    lead.takes.push_back (tk);
    const int leadId = lead.id;

    sv::render::AudioCache cache;
    const auto ctx = sv::render::makeContext (p, cache);
    sv::render::RenderSet set;
    for (const auto& t : p.tracks)
    {
        auto r = sv::render::renderTrack (p, t, cache, ctx);
        if (! r->ok())
        {
            std::cerr << r->error << std::endl;
            return 1;
        }
        set[t.id] = r;
    }

    auto opts = sv::gen::GenerationOptions::fromDefaults (sv::style::generationDefaults (p.style));
    if (args.has ("adlibs"))
        opts.adLibFolder = fileArg (args.get ("adlibs"));
    const auto ids = sv::render::generateBackingTracks (p, leadId, *set[leadId], opts, err);
    for (int id : ids)
        set[id] = sv::render::renderTrack (p, *p.findTrack (id), cache, ctx);

    if (! p.save (err))
        std::cerr << "Avertissement : " << err << std::endl;

    sv::render::ExportOptions eo;
    eo.outDir = outDir;
    eo.baseName = "mix_" + sv::style::styleId (p.style);
    eo.stems = args.has ("stems");
    const auto rep = sv::render::exportProject (p, set, eo);
    if (! rep.ok)
    {
        std::cerr << rep.error << std::endl;
        return 1;
    }
    std::cout << "Tonalite " << p.key.toFrench() << ", " << p.tempo.bpm << " BPM\n"
              << "Pistes : " << p.tracks.size() << " (dont " << ids.size() << " generees)\n"
              << "Mix : " << rep.mixFile.getFullPathName() << "\n"
              << "Sonie " << rep.master.outputLufs << " LUFS, crete vraie " << rep.master.truePeakDb << " dBTP\n";
    return 0;
}

int cmdSong (const Args& args)
{
    if (args.positional.size() < 2 || ! args.has ("out"))
    {
        usage();
        return 2;
    }
    const double sr = sv::kProjectSampleRate;
    auto ins = sv::audio::loadStereo (fileArg (args.positional[0]), sr);
    if (! ins.ok())
    {
        std::cerr << ins.error << std::endl;
        return 1;
    }
    sv::Mono voice;
    juce::String err;
    if (! sv::audio::loadMono (fileArg (args.positional[1]), sr, voice, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    return runSong (ins.buffer, voice, args, fileArg (args.get ("out")));
}

int cmdDemo (const Args& args)
{
    if (! args.has ("out"))
    {
        usage();
        return 2;
    }
    const double sr = sv::kProjectSampleRate;
    sv::MusicalKey key;
    key.root = 9;
    key.minor = true;
    // --bars N : longueur de l'instru (16 par défaut, 72 ~ 3 minutes à 100 BPM).
    const int bars = juce::jlimit (8, 200, args.get ("bars", "16").getIntValue());
    const auto instru = sv::test::synthInstru (100.0, key, bars, sr, true);
    auto phrases = sv::test::defaultPhrases (key, 100.0, 25.0f);
    const auto base = phrases;
    const int repeats = std::max (2, bars / 8);
    for (int i = 1; i < repeats; ++i)
        phrases.insert (phrases.end(), base.begin(), base.end());
    const auto voice = sv::test::synthVoice (phrases, sr, 2.4);
    const auto outDir = fileArg (args.get ("out"));
    juce::String err;
    sv::audio::writeFile (outDir.getChildFile ("demo_instru.wav"), instru, sr, sv::audio::FileFormat::Wav24, err);
    sv::audio::writeMonoWavFloat (outDir.getChildFile ("demo_voix_brute.wav"), voice, sr, err);
    return runSong (instru, voice, args, outDir);
}

// Diagnostic : niveau de la première attaque par rapport au niveau médian, étape par étape.
int cmdPresets()
{
    // Sortie Markdown reprise telle quelle dans le README (valeurs lues dans le code, pas recopiées à la main).
    for (const auto& group : sv::style::styleGroups())
    for (const auto st : group.styles)
    {
        if (st == group.styles.front())
            std::cout << "**Famille " << juce::String (juce::CharPointer_UTF8 (group.name)) << "**\n\n";
        std::cout << "### " << sv::style::styleName (st) << "\n\n";
        for (const auto& line : juce::StringArray::fromLines (sv::dsp::describeChain (sv::style::makeParams (st, sv::style::Role::Lead, {}))))
            std::cout << "- " << line << "\n";
        const auto g = sv::style::generationDefaults (st);
        juce::StringArray gen;
        if (g.doubles > 0)    gen.add (juce::String (g.doubles) + (g.doubles > 1 ? " doublages" : " doublage"));
        if (g.harmonies > 0)  gen.add (juce::String (g.harmonies) + (g.harmonies > 1 ? " harmonies" : " harmonie"));
        if (g.keywordBacks)   gen.add ("backs sur les mots clés"_u8);
        if (g.adLibs)         gen.add ("ad-libs");
        if (g.ambiance)       gen.add ("ambiance");
        std::cout << "- Pistes générées cochées par défaut : "_u8 << gen.joinIntoString (", ") << "\n\n";
    }
    return 0;
}

int cmdDebugChain (const Args& args)
{
    const double sr = sv::kProjectSampleRate;
    sv::Mono x;
    juce::String err;
    if (args.positional.isEmpty() || ! sv::audio::loadMono (fileArg (args.positional[0]), sr, x, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    const auto p = sv::style::makeParams (sv::style::styleFromId (args.get ("style", "trap")), sv::style::Role::Lead, {});
    auto va = sv::analysis::analyzeVoice (x, sr);
    if (va.phrases.empty())
        return 1;
    const double onset = va.phrases[0].startSec;
    auto report = [&] (const char* stage, const sv::Mono& y)
    {
        auto rmsAt = [&] (double a, double b)
        {
            const size_t ia = static_cast<size_t> (a * sr), ib = std::min (y.size(), static_cast<size_t> (b * sr));
            return sv::gainToDb (sv::audio::rms (y.data() + ia, ib - ia));
        };
        std::vector<float> lv;
        for (const auto& ph : va.phrases)
            lv.push_back (rmsAt (ph.startSec + 0.3, ph.endSec - 0.05));
        std::sort (lv.begin(), lv.end());
        std::cout << stage << " : attaque " << rmsAt (onset, onset + 0.1) - lv[lv.size() / 2] << " dB / phrase, crête "
                  << sv::gainToDb (sv::audio::peak (y.data(), y.size())) << " dBFS\n";
    };
    report ("brut", x);
    const float g = sv::dsp::gainForActiveRms (x, sr, p.inputTargetDb);
    for (auto& v : x) v *= g;
    report ("normalisé", x);
    auto track = sv::analysis::detectPitch (x, sr);
    sv::dsp::clean (x, sr, p.clean, track, va);
    report ("nettoyé", x);
    sv::dsp::PitchCorrectionParams pc;
    pc.key = sv::analysis::detectKey (x, sr).key;
    pc.amount = p.pitch.amount; pc.retuneMs = p.pitch.retuneMs; pc.humanize = p.pitch.humanize;
    x = sv::dsp::correctPitch (x, sr, pc, &track).audio;
    report ("autotune", x);
    sv::dsp::applyEq (x, sr, p.eq);
    report ("EQ", x);
    std::cout << "  GR comp1 " << sv::dsp::compress (x, sr, p.comp) << " dB\n";
    report ("comp1", x);
    std::cout << "  GR comp2 " << sv::dsp::compress (x, sr, p.comp2) << " dB\n";
    report ("comp2", x);
    sv::dsp::deEss (x, sr, p.deEss);
    report ("de-esser", x);
    sv::dsp::saturate (x, sr, p.sat);
    report ("saturation", x);
    return 0;
}

// ---------------------------------------------------------------------------------------------
// Détecteur d'artefacts : compare l'enveloppe d'entrée et de sortie dans les passages chantés.
// Trou = gain qui plonge de plus de 6 dB sous son voisinage pendant 30 à 500 ms alors que l'entrée est stable ;
// oscillation = modulation du gain entre 3 et 12 Hz ; saut = variation de plus de 4 dB d'une trame (10 ms) à l'autre.
struct ArtefactMetrics
{
    int holes = 0;
    float worstHoleDb = 0.0f;
    double worstHoleSec = 0.0;
    float oscillationDb = 0.0f;   // RMS de la modulation 3-12 Hz du gain (dB)
    int jumps = 0;
    float maxJumpDb = 0.0f;
    int validFrames = 0;
    // Un saut de 4-5 dB à une frontière voyelle / sifflante vient de l'EQ (présence) : normal. Seuls les sauts
    // nombreux ou très grands comptent comme artefact.
    bool bad() const { return holes > 0 || oscillationDb > 1.5f || jumps > 6 || maxJumpDb > 7.0f; }
    juce::String str() const
    {
        return juce::String (holes) + " trou(s)" + (holes > 0 ? " (pire -" + juce::String (worstHoleDb, 1) + " dB à "_u8 + juce::String (worstHoleSec, 2) + " s)" : juce::String())
               + ", oscillation " + juce::String (oscillationDb, 2) + " dB, " + juce::String (jumps) + " saut(s)" + (jumps > 0 ? " (max " + juce::String (maxJumpDb, 1) + " dB)" : juce::String());
    }
};

ArtefactMetrics measureArtefacts (const sv::Mono& in, const sv::Mono& out, double sr, const sv::analysis::VoiceActivity& va, const sv::analysis::PitchTrack& track)
{
    ArtefactMetrics m;
    const int hop = static_cast<int> (sr * 0.01), win = static_cast<int> (sr * 0.02);
    const int n = static_cast<int> (std::min (in.size(), out.size()));
    const int frames = n / hop;
    if (frames < 10)
        return m;
    std::vector<float> envIn (frames), envOut (frames), g (frames, 0.0f);
    std::vector<char> valid (frames, 0);
    for (int f = 0; f < frames; ++f)
    {
        const int a = f * hop, b = std::min (n, a + win);
        envIn[f] = sv::gainToDb (sv::audio::rms (in.data() + a, static_cast<size_t> (b - a)));
        envOut[f] = sv::gainToDb (sv::audio::rms (out.data() + a, static_cast<size_t> (b - a)));
        const double t = (a + win * 0.5) / sr;
        valid[f] = va.isActiveAt (t) && track.voicedAt (t) && envIn[f] > va.noiseFloorDb + 15.0f;
        g[f] = envOut[f] - envIn[f];
        m.validFrames += valid[f];
    }
    auto localMedian = [&] (const std::vector<float>& v, int f, int radius)
    {
        std::vector<float> w;
        for (int k = std::max (0, f - radius); k <= std::min (frames - 1, f + radius); ++k)
            if (valid[k])
                w.push_back (v[k]);
        if (w.empty())
            return v[f];
        std::sort (w.begin(), w.end());
        return w[w.size() / 2];
    };
    // Trous.
    int run = 0;
    float runDepth = 0.0f;
    for (int f = 0; f <= frames; ++f)
    {
        bool cand = false;
        float depth = 0.0f;
        if (f < frames && valid[f])
        {
            const float gm = localMedian (g, f, 30), im = localMedian (envIn, f, 30);
            depth = gm - g[f];
            cand = depth > 6.0f && std::abs (envIn[f] - im) < 3.0f;
        }
        if (cand)
        {
            ++run;
            runDepth = std::max (runDepth, depth);
        }
        else
        {
            if (run >= 3 && run <= 50)
            {
                ++m.holes;
                if (runDepth > m.worstHoleDb)
                {
                    m.worstHoleDb = runDepth;
                    m.worstHoleSec = (f - run) * hop / sr;
                }
            }
            run = 0;
            runDepth = 0.0f;
        }
    }
    // Sauts.
    for (int f = 1; f < frames; ++f)
        if (valid[f] && valid[f - 1])
        {
            const float d = std::abs (g[f] - g[f - 1]);
            if (d > 4.0f)
            {
                ++m.jumps;
                m.maxJumpDb = std::max (m.maxJumpDb, d);
            }
        }
    // Oscillation 3-12 Hz : passe-haut (moyenne glissante ±170 ms retirée) puis passe-bas (±40 ms), segments chantés >= 600 ms.
    auto movavg = [&] (const std::vector<float>& v, int f, int radius)
    {
        double s = 0.0;
        int c = 0;
        for (int k = std::max (0, f - radius); k <= std::min (frames - 1, f + radius); ++k)
            if (valid[k])
            {
                s += v[k];
                ++c;
            }
        return c > 0 ? static_cast<float> (s / c) : 0.0f;
    };
    std::vector<float> hp (frames, 0.0f);
    for (int f = 0; f < frames; ++f)
        if (valid[f])
            hp[f] = g[f] - movavg (g, f, 17);
    double sq = 0.0;
    int cnt = 0;
    for (int f = 0; f < frames;)
    {
        if (! valid[f])
        {
            ++f;
            continue;
        }
        int e = f;
        while (e < frames && valid[e])
            ++e;
        if (e - f >= 60)
            for (int k = f + 10; k < e - 10; ++k)
            {
                const float lp = movavg (hp, k, 4);
                sq += static_cast<double> (lp) * lp;
                ++cnt;
            }
        f = e;
    }
    m.oscillationDb = cnt > 0 ? static_cast<float> (std::sqrt (sq / cnt)) : 0.0f;
    return m;
}

int cmdArtefacts (const Args& args)
{
    const double sr = sv::kProjectSampleRate;
    sv::Mono x;
    juce::String err;
    if (args.positional.isEmpty() || ! sv::audio::loadMono (fileArg (args.positional[0]), sr, x, err))
    {
        std::cerr << "artefacts <voix.wav> [--instru=fichier] [--style=id|all] [--attribuer]\n" << err << std::endl;
        return 2;
    }
    sv::dsp::AnalysisContext ctx;
    ctx.tempo.bpm = 100.0;
    if (args.has ("instru"))
    {
        sv::Mono inst;
        if (sv::audio::loadMono (fileArg (args.get ("instru", "")), sr, inst, err))
            ctx.key = sv::analysis::detectKey (inst, sr).key;
    }
    else
        ctx.key = sv::analysis::detectKey (x, sr).key;
    const auto va = sv::analysis::analyzeVoice (x, sr);
    const auto track = sv::analysis::detectPitch (x, sr);
    std::vector<juce::String> styles;
    const auto styleArg = args.get ("style", "all");
    if (styleArg == "all")
        for (int i = 0; i < static_cast<int> (sv::style::Style::Count); ++i)
            styles.push_back (sv::style::styleId (static_cast<sv::style::Style> (i)));
    else
        styles.push_back (styleArg);
    styles.push_back (sv::dsp::kCorrectionStyleId);

    auto run = [&] (sv::style::VocalParams p, const juce::String& label) -> ArtefactMetrics
    {
        p.timing.strength = 0.0f;   // le recalage déplace des syllabes : la comparaison d'enveloppes n'aurait plus de sens
        auto res = sv::dsp::processVocal (x, sr, p, ctx);
        const auto out = sv::audio::toMono (res.audio);
        const auto m = measureArtefacts (x, out, sr, va, track);
        std::cout << "  " << label << " : " << m.str() << "\n";
        return m;
    };
    int bad = 0;
    for (const auto& id : styles)
    {
        sv::style::VocalParams p;
        if (id == sv::dsp::kCorrectionStyleId)
        {
            auto problems = sv::dsp::analyzeTrackProblems (x, sr, ctx.key, true);
            p = sv::dsp::correctionParams (problems, true);
        }
        else
            p = sv::style::makeParams (sv::style::styleFromId (id), sv::style::Role::Lead, {});
        if (args.has ("sanscomp"))
        {
            p.comp.ratio = 1.0f;   // base sans compresseurs : ils masquent les creux des autres étages
            p.comp2.ratio = 1.0f;
        }
        std::cout << id << "\n";
        const auto m = run (p, "chaîne complète");
        if (m.bad())
        {
            ++bad;
            if (args.has ("attribuer"))
            {
                // Chaque étage coupé à son tour : celui dont la coupure fait disparaître l'artefact est le coupable.
                auto v = p;
                v.clean.enabled = false; v.leveler.enabled = false; v.pitch.enabled = false; v.resonance.enabled = false;
                v.comp.ratio = 1.0f; v.comp2.ratio = 1.0f; v.deEss.amount = 0.0f; v.sat.mix = 0.0f; v.reverb.send = 0.0f; v.delay.send = 0.0f;
                v.eq = {}; v.eq.lowCutHz = 0.0f;
                run (v, "tout coupé (référence de la mesure)"_u8);
                v = p; v.clean.enabled = false;                         run (v, "sans nettoyage");
                v = p; v.clean.gateRangeDb = 0.0f;                      run (v, "sans porte");
                v = p; v.clean.denoiseDb = 0.0f;                        run (v, "sans débruitage"_u8);
                v = p; v.clean.breathReductionDb = 0.0f;                run (v, "sans respirations");
                v = p; v.clean.dePlosive = false;                       run (v, "sans anti-plosives");
                v = p; v.leveler.enabled = false;                       run (v, "sans niveleur");
                v = p; v.pitch.enabled = false;                         run (v, "sans autotune");
                v = p; v.resonance.enabled = false;                     run (v, "sans résonances"_u8);
                v = p; v.comp.ratio = 1.0f; v.comp2.ratio = 1.0f;       run (v, "sans compresseurs");
                v = p; v.deEss.amount = 0.0f;                           run (v, "sans de-esser");
                v = p; v.sat.mix = 0.0f;                                run (v, "sans saturation");
                v = p; v.eq = {}; v.eq.lowCutHz = 20.0f;                run (v, "sans EQ (coupe-bas 20 Hz)");
            }
        }
    }
    std::cout << (bad == 0 ? "Aucun artefact détecté." : juce::String (bad) + " chaîne(s) avec artefacts.") << "\n";
    return bad == 0 ? 0 : 1;
}

int cmdMaster (const Args& args)
{
    if (args.positional.isEmpty() || ! args.has ("out"))
    {
        usage();
        return 2;
    }
    const double sr = sv::kProjectSampleRate;
    auto mixRes = sv::audio::loadStereo (fileArg (args.positional[0]), sr);
    if (! mixRes.ok())
    {
        std::cerr << mixRes.error << std::endl;
        return 1;
    }
    sv::dsp::MasterSettings ms;
    ms.target = sv::dsp::targetFromId (args.get ("target", "spotify"));
    sv::dsp::MasterReport rep;
    const auto out = sv::dsp::master (mixRes.buffer, sr, ms, rep);
    juce::String err;
    if (! sv::audio::writeFile (fileArg (args.get ("out")), out, sr, sv::audio::FileFormat::Wav24, err))
    {
        std::cerr << err << std::endl;
        return 1;
    }
    std::cout << rep.inputLufs << " -> " << rep.outputLufs << " LUFS, " << rep.truePeakDb << " dBTP\n";
    return 0;
}
} // namespace

int main (int argc, char* argv[])
{
    const auto logFile = juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory)
                             .getChildFile ("StudioVoix").getChildFile ("logs").getChildFile ("cli.log");
    sv::log::init (logFile, sv::log::Level::Debug, true);

    if (argc < 2)
    {
        usage();
        return 2;
    }

    const juce::String cmd (argv[1]);
    const auto args = parse (argc, argv);
    SV_LOG_INFO (kMod, "Commande : " + cmd + " " + args.positional.joinIntoString (" "));

    int code = 2;
    try
    {
        if (cmd == "test")         code = sv::test::runAllTests();
        else if (cmd == "analyze") code = cmdAnalyze (args);
        else if (cmd == "remix")   code = cmdRemix (args);
        else if (cmd == "song")    code = cmdSong (args);
        else if (cmd == "demo")    code = cmdDemo (args);
        else if (cmd == "master")  code = cmdMaster (args);
        else if (cmd == "debugchain") code = cmdDebugChain (args);
        else if (cmd == "artefacts") code = cmdArtefacts (args);
        else if (cmd == "presets") code = cmdPresets();
        else if (cmd == "assistant")
        {
            const auto text = args.positional.joinIntoString (" ");
            const auto r = sv::assistant::apply (text, {});
            std::cout << "normalise : [" << sv::assistant::normalise (text) << "]\n" << (r.understood ? r.changes.joinIntoString ("\n") : juce::String ("non comprise")) << "\n";
            code = r.understood ? 0 : 1;
        }
        else                       usage();
    }
    catch (const std::exception& e)
    {
        SV_LOG_ERROR (kMod, juce::String ("Exception : ") + e.what());
        code = 1;
    }

    SV_LOG_INFO (kMod, "Fin (code " + juce::String (code) + ")");
    sv::log::shutdown();
    return code;
}
