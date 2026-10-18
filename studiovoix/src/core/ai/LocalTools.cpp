#include "LocalTools.h"

#include "../Log.h"

#include <juce_cryptography/juce_cryptography.h>

#include <thread>

#ifndef SV_EDITION_IA
 #define SV_EDITION_IA 0
#endif

namespace sv::ai::local
{
namespace
{
    constexpr const char* kMod = "OutilsIA";
    constexpr const char* kDataFolder = SV_EDITION_IA ? "StudioVoix IA" : "StudioVoix";
    constexpr juce::int64 kMaxDownload = 2000LL * 1024 * 1024;   // 2 Go : garde-fou

    juce::File& overrideFolder()
    {
        static juce::File f;
        return f;
    }

    const std::vector<ToolDef>& buildTools()
    {
        static const std::vector<ToolDef> list = []
        {
            std::vector<ToolDef> v;
            // Nettoyage de voix DeepFilterNet (Rikorose/DeepFilterNet, binaire autonome avec le modèle inclus).
            {
                ToolDef t;
                t.id = "deep-filter";
                t.name = "DeepFilterNet (nettoyage de voix)";
                t.description = "Supprime souffle, bruit de pièce et ronflement bien mieux que le débruitage classique. "
                                "Binaire autonome d'environ 50 Mo, traitement d'une prise en quelques secondes."_u8;
                t.licence = "MIT / Apache-2.0";
                t.executable = true;
#if JUCE_WINDOWS
                t.url = "https://github.com/Rikorose/DeepFilterNet/releases/download/v0.5.6/deep-filter-0.5.6-x86_64-pc-windows-msvc.exe";
                t.fileName = "deep-filter.exe";
                t.size = 26912256;   // relevé par la CI (build 53)
                t.sha256 = "75e11fa16445f560cb6b021521ddb89e89270d13b83089705d98776f58fd7915";
#elif JUCE_LINUX
                t.url = "https://github.com/Rikorose/DeepFilterNet/releases/download/v0.5.6/deep-filter-0.5.6-x86_64-unknown-linux-gnu";
                t.fileName = "deep-filter";
#else
                t.fileName = "deep-filter";
#endif
                v.push_back (t);
            }
            // whisper.cpp : binaire whisper-cli (Windows, archive avec ses DLL) ; sur Linux / macOS pas de binaire publié.
            {
                ToolDef t;
                t.id = "whisper-cli";
                t.name = "whisper.cpp (moteur de reconnaissance)";
                t.description = "Programme qui reconnaît les paroles avec un modèle Whisper, sur le processeur de ce PC. "
                                "Archive d'environ 10 Mo (binaire et bibliothèques)."_u8;
                t.licence = "MIT";
                t.executable = true;
                t.archive = true;
#if JUCE_WINDOWS
                t.url = "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.6/whisper-bin-x64.zip";
                t.fileName = "whisper-cli.exe";
                t.size = 3675974;   // archive zip (relevé CI build 58)
                t.sha256 = "0d2eca299c248f965bd0341bcb219db4b433c7f0c0ce2200d4df85765e8156a9";
#else
                t.fileName = "whisper-cli";
#endif
                v.push_back (t);
            }
            // Modèle whisper.cpp « base » (OpenAI Whisper, converti en ggml) : paroles reconnues et calées mot par mot.
            {
                ToolDef t;
                t.id = "whisper-base";
                t.name = "Whisper base (paroles et timing)"_u8;
                t.description = "Reconnaît les paroles chantées et donne la position de chaque mot (français et autres langues). "
                                "Modèle d'environ 148 Mo ; une minute de voix se transcrit en quelques secondes."_u8;
                t.licence = "MIT";
                t.url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin";
                t.fileName = "ggml-base.bin";
                t.size = 147951465;   // relevé par la CI (build 53)
                t.sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe";
                v.push_back (t);
            }
            return v;
        }();
        return list;
    }
} // namespace

const std::vector<ToolDef>& tools() { return buildTools(); }

const ToolDef* findTool (const juce::String& id)
{
    for (const auto& t : tools())
        if (t.id == id)
            return &t;
    return nullptr;
}

juce::File toolsFolder()
{
    if (overrideFolder() != juce::File())
        return overrideFolder();
    return juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory).getChildFile (kDataFolder).getChildFile ("outils");
}

void setToolsFolder (const juce::File& folder) { overrideFolder() = folder; }

juce::File toolFile (const ToolDef& t)
{
    if (! t.archive)
        return toolsFolder().getChildFile (t.fileName);
    // Archive extraite dans outils/<id>/ : le binaire peut être dans un sous-dossier (Release/…).
    const auto dir = toolsFolder().getChildFile (t.id);
    juce::Array<juce::File> found;
    dir.findChildFiles (found, juce::File::findFiles, true, t.fileName);
    return found.isEmpty() ? dir.getChildFile (t.fileName) : found.getReference (0);
}

bool isInstalled (const ToolDef& t)
{
    const auto f = toolFile (t);
    // La taille épinglée est celle du téléchargement : pour une archive, c'est le zip, pas le binaire extrait.
    return f.existsAsFile() && (t.archive || t.size <= 0 || f.getSize() == t.size);
}

juce::String sha256Of (const juce::File& f)
{
    if (! f.existsAsFile())
        return {};
    return juce::SHA256 (f).toHexString().toLowerCase();
}

namespace
{
    struct ProgressListener final : public juce::URL::DownloadTaskListener
    {
        explicit ProgressListener (Progress& p) : target (p) {}
        void finished (juce::URL::DownloadTask*, bool) override {}
        void progress (juce::URL::DownloadTask*, juce::int64 downloaded, juce::int64 total) override
        {
            target.downloaded.store (downloaded);
            if (total > 0)
                target.fraction.store (juce::jlimit (0.0f, 1.0f, static_cast<float> (static_cast<double> (downloaded) / static_cast<double> (total))));
        }
        Progress& target;
    };
} // namespace

bool install (const ToolDef& t, Progress& progress, juce::String& error)
{
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    if (t.url.isEmpty())
    {
        error = t.name + " : indisponible sur ce système"_u8;
        SV_LOG_WARN (kMod, error);
        return false;
    }
    if (! t.url.startsWith ("https://"))
    {
        error = "Adresse non sécurisée refusée : "_u8 + t.url;
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    const auto folder = toolsFolder();
    if (! folder.createDirectory())
    {
        error = "Dossier des outils impossible à créer : "_u8 + folder.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    const auto temp = folder.getChildFile (t.fileName + ".partiel");
    temp.deleteFile();
    SV_LOG_INFO (kMod, "Téléchargement de "_u8 + t.name + " : " + t.url);
    ProgressListener listener (progress);
    juce::URL::DownloadTaskOptions options;
    options.listener = &listener;
    options.extraHeaders = "User-Agent: StudioVoix\r\n";
    auto task = juce::URL (t.url).downloadToFile (temp, options);
    if (task == nullptr)
    {
        error = "Téléchargement impossible (connexion refusée) : "_u8 + t.url;
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    while (! task->isFinished())
    {
        if (progress.cancel.load())
        {
            task.reset();
            temp.deleteFile();
            error = "Téléchargement annulé"_u8;
            SV_LOG_INFO (kMod, t.name + " : " + error);
            return false;
        }
        if (task->getLengthDownloaded() > kMaxDownload)
        {
            task.reset();
            temp.deleteFile();
            error = "Fichier anormalement gros, téléchargement arrêté"_u8;
            SV_LOG_ERROR (kMod, t.name + " : " + error);
            return false;
        }
        juce::Thread::sleep (100);
    }
    if (task->hadError())
    {
        temp.deleteFile();
        error = "Téléchargement échoué (réseau, proxy ou adresse introuvable) : "_u8 + t.url;
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    task.reset();
    const auto size = temp.getSize();
    if (size <= 0 || (t.size > 0 && size != t.size))
    {
        error = "Taille inattendue : "_u8 + juce::String (size) + " octets (attendu " + juce::String (t.size) + ")";
        SV_LOG_ERROR (kMod, t.name + " : " + error);
        temp.deleteFile();
        return false;
    }
    const auto digest = sha256Of (temp);
    progress.downloadSize = size;
    progress.downloadSha256 = digest;
    if (t.sha256.isNotEmpty())
    {
        if (digest != t.sha256.toLowerCase())
        {
            error = "Empreinte SHA-256 différente de celle attendue : fichier refusé"_u8;
            SV_LOG_ERROR (kMod, t.name + " : " + error + " (" + digest + ")");
            temp.deleteFile();
            return false;
        }
    }
    else
        SV_LOG_WARN (kMod, t.name + " : empreinte non encore relevée, fichier accepté sans vérification (SHA-256 "_u8 + digest + ", " + juce::String (size) + " octets)");
    if (t.archive)
    {
        const auto dir = toolsFolder().getChildFile (t.id);
        dir.deleteRecursively();
        juce::ZipFile zip (temp);
        const auto result = zip.uncompressTo (dir, true);
        temp.deleteFile();
        if (result.failed() || zip.getNumEntries() == 0)
        {
            error = "Archive illisible : "_u8 + result.getErrorMessage();
            SV_LOG_ERROR (kMod, t.name + " : " + error);
            dir.deleteRecursively();
            return false;
        }
        const auto exe = toolFile (t);
        if (! exe.existsAsFile())
        {
            error = "Archive sans "_u8 + t.fileName;
            SV_LOG_ERROR (kMod, t.name + " : " + error);
            dir.deleteRecursively();
            return false;
        }
        exe.setExecutePermission (true);
        progress.fraction.store (1.0f);
        SV_LOG_INFO (kMod, t.name + " installé : "_u8 + exe.getFullPathName() + " (" + juce::String (zip.getNumEntries()) + " fichiers, "
                           + juce::String (juce::roundToInt ((juce::Time::getMillisecondCounterHiRes() - t0) / 1000.0)) + " s)");
        return true;
    }
    const auto dest = toolFile (t);
    dest.deleteFile();
    if (! temp.moveFileTo (dest))
    {
        error = "Impossible de placer le fichier dans "_u8 + dest.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        temp.deleteFile();
        return false;
    }
    if (t.executable)
        dest.setExecutePermission (true);
    progress.fraction.store (1.0f);
    SV_LOG_INFO (kMod, t.name + " installé : "_u8 + dest.getFullPathName() + " (" + juce::String (size / 1024 / 1024) + " Mo, "
                       + juce::String (juce::roundToInt ((juce::Time::getMillisecondCounterHiRes() - t0) / 1000.0)) + " s)");
    return true;
}

bool remove (const ToolDef& t)
{
    if (t.archive)
    {
        const auto dir = toolsFolder().getChildFile (t.id);
        if (! dir.isDirectory())
            return false;
        const bool okDir = dir.deleteRecursively();
        SV_LOG_INFO (kMod, t.name + (okDir ? " supprimé"_u8 : " : suppression impossible"_u8));
        return okDir;
    }
    const auto f = toolFile (t);
    if (! f.existsAsFile())
        return false;
    const bool ok = f.deleteFile();
    SV_LOG_INFO (kMod, t.name + (ok ? " supprimé"_u8 : " : suppression impossible"_u8));
    return ok;
}

bool run (const ToolDef& t, const juce::StringArray& args, juce::String& output, int& exitCode, int timeoutMs)
{
    exitCode = -1;
    output.clear();
    const auto exe = toolFile (t);
    if (! t.executable || ! exe.existsAsFile())
    {
        output = t.name + " : outil absent (à installer dans IA locale)"_u8;
        SV_LOG_WARN (kMod, output);
        return false;
    }
    juce::StringArray cmd;
    cmd.add (exe.getFullPathName());
    cmd.addArray (args);
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    juce::ChildProcess process;
    if (! process.start (cmd))
    {
        output = "Lancement impossible : "_u8 + exe.getFullPathName();
        SV_LOG_ERROR (kMod, output);
        return false;
    }
    // La sortie se lit pendant que le processus tourne (après sa fin, JUCE ne la rend plus) : lecture bloquante dans
    // un fil à part, garde-fou de délai ici.
    juce::String captured;
    std::thread reader ([&process, &captured] { captured = process.readAllProcessOutput(); });
    const bool finished = process.waitForProcessToFinish (timeoutMs);
    if (! finished)
        process.kill();
    reader.join();
    if (! finished)
    {
        output = t.name + " : délai dépassé ("_u8 + juce::String (timeoutMs / 1000) + " s), processus arrêté"_u8;
        SV_LOG_ERROR (kMod, output + (captured.isEmpty() ? juce::String() : " — sortie : " + captured.trim().substring (0, 300)));
        return false;
    }
    output = captured;
    exitCode = static_cast<int> (process.getExitCode());
    SV_LOG_INFO (kMod, t.name + " : code " + juce::String (exitCode) + " en " + juce::String (juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0)) + " ms");
    return true;
}

juce::String describe (const ToolDef& t)
{
    if (t.url.isEmpty())
        return t.name + " : indisponible sur ce système"_u8;
    if (isInstalled (t))
        return t.name + " : installé ("_u8 + juce::String (toolFile (t).getSize() / 1024 / 1024) + " Mo)";
    return t.name + " : non installé"_u8 + (t.size > 0 ? " (" + juce::String (t.size / 1024 / 1024) + " Mo à télécharger)"_u8 : juce::String());
}
} // namespace sv::ai::local
