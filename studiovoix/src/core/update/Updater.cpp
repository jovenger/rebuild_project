#include "Updater.h"

#include "../Log.h"

#include <juce_cryptography/juce_cryptography.h>

#ifndef SV_BUILD_NUMBER
 #define SV_BUILD_NUMBER 0
#endif

namespace sv::update
{
namespace
{
    constexpr const char* kMod = "MiseAJour";
    constexpr juce::int64 kMinSize = 100 * 1024;           // un installateur fait plusieurs Mo
    constexpr juce::int64 kMaxSize = 500 * 1024 * 1024;

    juce::String baseHeaders (const juce::String& token, const char* accept)
    {
        juce::String h;
        h << "Accept: " << accept << "\r\n"
          << "X-GitHub-Api-Version: 2026-03-10\r\n"
          << "User-Agent: StudioVoix-build" << currentBuild() << "\r\n";
        if (token.trim().isNotEmpty())
            h << "Authorization: Bearer " << token.trim() << "\r\n";
        return h;
    }

    bool isHex64 (const juce::String& s)
    {
        return s.length() == 64 && s.containsOnly ("0123456789abcdef");
    }
}

int currentBuild() { return SV_BUILD_NUMBER; }

int buildFromName (const juce::String& name)
{
    const auto lower = name.toLowerCase();
    for (int from = 0;;)
    {
        const int i = lower.indexOf (from, "build");
        if (i < 0)
            return 0;
        const auto digits = lower.substring (i + 5).initialSectionContainingOnly ("0123456789");
        if (digits.isNotEmpty() && digits.length() <= 9)
            return digits.getIntValue();
        from = i + 5;
    }
}

ReleaseInfo parseRelease (const juce::String& json)
{
    ReleaseInfo r;
    juce::var v;
    if (juce::JSON::parse (json, v).failed() || ! v.isObject() || v.isArray())
    {
        r.error = "Réponse GitHub illisible"_u8;
        return r;
    }
    r.tag = v.getProperty ("tag_name", {}).toString();
    r.title = v.getProperty ("name", {}).toString();
    r.notes = v.getProperty ("body", {}).toString();
    if (static_cast<bool> (v.getProperty ("draft", false)))
    {
        r.error = "Version en brouillon ignorée"_u8;
        return r;
    }
    const auto* assets = v.getProperty ("assets", {}).getArray();
    if (assets != nullptr)
        for (const auto& a : *assets)
        {
            const auto name = a.getProperty ("name", {}).toString();
            if (! (name.startsWithIgnoreCase ("StudioVoix-Setup") && name.endsWithIgnoreCase (".exe")))
                continue;
            r.assetName = name;
            r.assetApiUrl = a.getProperty ("url", {}).toString();
            r.downloadUrl = a.getProperty ("browser_download_url", {}).toString();
            r.size = static_cast<juce::int64> (a.getProperty ("size", 0));
            const auto digest = a.getProperty ("digest", {}).toString().trim().toLowerCase();
            if (digest.startsWith ("sha256:") && isHex64 (digest.substring (7)))
                r.sha256 = digest.substring (7);
            break;
        }
    if (r.assetName.isEmpty())
    {
        r.error = "La dernière version publiée ne contient pas d'installateur"_u8;
        return r;
    }
    // Téléchargement uniquement depuis l'API GitHub (pas d'adresse arbitraire venant de la réponse).
    if (! r.assetApiUrl.startsWith ("https://api.github.com/repos/"))
    {
        r.error = "Adresse de téléchargement inattendue : "_u8 + r.assetApiUrl;
        return r;
    }
    if (r.size < kMinSize || r.size > kMaxSize)
    {
        r.error = "Taille d'installateur invalide ("_u8 + juce::String (r.size) + " octets)";
        return r;
    }
    r.build = buildFromName (r.assetName);
    if (r.build <= 0)
        r.build = buildFromName (r.tag);
    if (r.build <= 0)
    {
        r.error = "Numéro de build introuvable dans « "_u8 + r.assetName + " »"_u8;
        return r;
    }
    r.ok = true;
    return r;
}

juce::String describeHttpError (int status, bool hasToken)
{
    if (status <= 0)
        return "Pas de connexion à GitHub (internet ?)"_u8;
    if (status == 401)
        return "Jeton GitHub refusé (expiré ou mal copié) : vérifie-le dans Paramètres"_u8;
    if (status == 403 || status == 429)
        return "Limite de requêtes GitHub atteinte : réessaie dans un moment"_u8;
    if (status == 404)
        return hasToken ? juce::String ("Aucune version publiée trouvée, ou le jeton n'a pas accès au dépôt "_u8 + kRepo)
                        : juce::String ("Dépôt privé : colle un jeton GitHub (lecture seule) dans Paramètres > Mises à jour, ou rends le dépôt public"_u8);
    return "Erreur GitHub (HTTP "_u8 + juce::String (status) + ")";
}

ReleaseInfo fetchLatest (const juce::String& token, int timeoutMs)
{
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    const juce::String url = "https://api.github.com/repos/" + juce::String (kRepo) + "/releases/latest";
    juce::WebInputStream stream (juce::URL (url), false);
    stream.withExtraHeaders (baseHeaders (token, "application/vnd.github+json")).withConnectionTimeout (timeoutMs).withNumRedirectsToFollow (3);
    const bool connected = stream.connect (nullptr);
    const int status = stream.getStatusCode();
    juce::MemoryOutputStream body;
    if (connected)
        body.writeFromInputStream (stream, 4 * 1024 * 1024);
    ReleaseInfo r;
    if (status == 200)
        r = parseRelease (body.toString());
    else
        r.error = describeHttpError (status, token.trim().isNotEmpty());
    r.httpStatus = status;
    const auto ms = juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0);
    if (r.ok)
        SV_LOG_INFO (kMod, "Dernière version : build " + juce::String (r.build) + " (" + r.assetName + ", " + juce::String (r.size)
                           + " octets" + (r.sha256.isNotEmpty() ? ", SHA-256 connu" : ", SHA-256 inconnu") + ") ; ce programme : build "
                           + juce::String (currentBuild()) + " — " + juce::String (ms) + " ms");
    else
        SV_LOG_WARN (kMod, "Vérification impossible (HTTP "_u8 + juce::String (status) + ", " + juce::String (ms) + " ms) : " + r.error);
    return r;
}

bool verifyInstaller (const juce::File& file, const ReleaseInfo& release, juce::String& error)
{
    const auto size = file.getSize();
    if (release.size > 0 && size != release.size)
    {
        error = "Téléchargement incomplet ("_u8 + juce::String (size) + "/" + juce::String (release.size) + " octets)";
        return false;
    }
    {
        juce::FileInputStream in (file);
        char mz[2] = {};
        if (! in.openedOk() || in.read (mz, 2) != 2 || mz[0] != 'M' || mz[1] != 'Z')
        {
            error = "Le fichier téléchargé n'est pas un programme Windows"_u8;
            return false;
        }
    }
    if (release.sha256.isNotEmpty())
    {
        const auto actual = juce::SHA256 (file).toHexString().toLowerCase();
        if (actual != release.sha256)
        {
            error = "Empreinte SHA-256 différente de celle publiée : fichier corrompu ou modifié"_u8;
            SV_LOG_ERROR (kMod, "SHA-256 attendu " + release.sha256 + ", obtenu " + actual);
            return false;
        }
    }
    else
    {
        SV_LOG_WARN (kMod, "GitHub ne fournit pas de SHA-256 pour ce fichier : vérification limitée à la taille et à l'en-tête"_u8);
    }
    return true;
}

bool download (const ReleaseInfo& release, const juce::String& token, const juce::File& dest,
               const ProgressFn& progress, juce::String& error)
{
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    SV_LOG_INFO (kMod, "Téléchargement de "_u8 + release.assetName + " vers " + dest.getFullPathName());
    if (! release.ok)
    {
        error = "Aucune version à télécharger"_u8;
        return false;
    }
    if (! dest.getParentDirectory().createDirectory())
    {
        error = "Dossier temporaire inaccessible : "_u8 + dest.getParentDirectory().getFullPathName();
        return false;
    }

    // 1) API GitHub (avec le jeton) : redirection 302 vers une adresse signée, ou contenu direct (200).
    //    La redirection est suivie à la main pour ne pas renvoyer le jeton à l'hébergeur du fichier.
    auto first = std::make_unique<juce::WebInputStream> (juce::URL (release.assetApiUrl), false);
    first->withExtraHeaders (baseHeaders (token, "application/octet-stream")).withConnectionTimeout (20000).withNumRedirectsToFollow (0);
    first->connect (nullptr);
    int status = first->getStatusCode();
    std::unique_ptr<juce::WebInputStream> stream;
    if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308)
    {
        const auto location = first->getResponseHeaders().getValue ("Location", {}).trim();
        if (! location.startsWithIgnoreCase ("https://"))
        {
            error = "Redirection de téléchargement invalide"_u8;
            SV_LOG_ERROR (kMod, error + " : « "_u8 + location + " »"_u8);
            return false;
        }
        SV_LOG_INFO (kMod, "Redirection vers " + juce::URL (location).getDomain());
        first.reset();
        stream = std::make_unique<juce::WebInputStream> (juce::URL (location), false);
        stream->withExtraHeaders ("User-Agent: StudioVoix-build" + juce::String (currentBuild()) + "\r\n")
            .withConnectionTimeout (20000).withNumRedirectsToFollow (3);
        stream->connect (nullptr);
        status = stream->getStatusCode();
    }
    else
    {
        stream = std::move (first);
    }
    if (status != 200)
    {
        error = describeHttpError (status, token.trim().isNotEmpty());
        SV_LOG_ERROR (kMod, "Téléchargement refusé (HTTP "_u8 + juce::String (status) + ") : " + error);
        return false;
    }

    const auto part = dest.withFileExtension (".part");
    part.deleteFile();
    {
        juce::FileOutputStream out (part);
        if (! out.openedOk())
        {
            error = "Écriture impossible : "_u8 + part.getFullPathName();
            return false;
        }
        juce::HeapBlock<char> buffer (64 * 1024);
        juce::int64 total = 0;
        const juce::int64 expected = release.size > 0 ? release.size : stream->getTotalLength();
        while (! stream->isExhausted())
        {
            const int n = stream->read (buffer.getData(), 64 * 1024);
            if (n < 0)
                break;
            if (n == 0)
            {
                if (stream->isExhausted() || stream->isError())
                    break;
                continue;
            }
            if (! out.write (buffer.getData(), static_cast<size_t> (n)))
            {
                error = "Disque plein ou écriture refusée"_u8;
                break;
            }
            total += n;
            if (total > kMaxSize)
            {
                error = "Fichier plus gros qu'annoncé : téléchargement arrêté"_u8;
                break;
            }
            if (progress && expected > 0 && ! progress (static_cast<double> (total) / static_cast<double> (expected)))
            {
                error = "Téléchargement annulé"_u8;
                break;
            }
        }
        out.flush();
        if (error.isEmpty() && out.getStatus().failed())
            error = "Écriture du fichier : "_u8 + out.getStatus().getErrorMessage();
        SV_LOG_INFO (kMod, juce::String (total) + " octets reçus en " + juce::String (juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0)) + " ms");
    }
    if (error.isEmpty() && ! verifyInstaller (part, release, error))
        SV_LOG_ERROR (kMod, "Vérification de l'installateur : "_u8 + error);
    if (error.isNotEmpty())
    {
        part.deleteFile();
        return false;
    }
    dest.deleteFile();
    if (! part.moveFileTo (dest))
    {
        error = "Impossible de finaliser le fichier : "_u8 + dest.getFullPathName();
        part.deleteFile();
        return false;
    }
    SV_LOG_INFO (kMod, "Installateur prêt et vérifié : "_u8 + dest.getFullPathName());
    return true;
}

juce::String installerArguments (const juce::File& logFile)
{
    // /RELANCER=1 : l'installateur attend la fermeture du programme puis le relance (voir StudioVoix.iss).
    return "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /CLOSEAPPLICATIONS /RELANCER=1 /LOG=\"" + logFile.getFullPathName() + "\"";
}
} // namespace sv::update
