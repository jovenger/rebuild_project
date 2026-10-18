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
#include "core/dsp/MasterChain.h"
#include "core/dsp/VocalChain.h"
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
            if (i + 1 < argc && ! juce::String (argv[i + 1]).startsWith ("--"))
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
                 "  demo [--style s] -o dossier            chaine complete sur signaux de synthese\n"
                 "  master <mix> [--target t] -o sortie.wav\n"
                 "styles : rap trap pop_urbaine rnb drill afro\n"
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
    const auto instru = sv::test::synthInstru (100.0, key, 16, sr, true);
    auto phrases = sv::test::defaultPhrases (key, 100.0, 25.0f);
    auto more = phrases;
    phrases.insert (phrases.end(), more.begin(), more.end());
    const auto voice = sv::test::synthVoice (phrases, sr, 2.4);
    const auto outDir = fileArg (args.get ("out"));
    juce::String err;
    sv::audio::writeFile (outDir.getChildFile ("demo_instru.wav"), instru, sr, sv::audio::FileFormat::Wav24, err);
    sv::audio::writeMonoWavFloat (outDir.getChildFile ("demo_voix_brute.wav"), voice, sr, err);
    return runSong (instru, voice, args, outDir);
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
