#include "AiClient.h"

#include "../Log.h"

namespace sv::ai
{
namespace
{
    constexpr const char* kMod = "AI";
    constexpr const char* kClaudeUrl = "https://api.anthropic.com/v1/messages";
    constexpr const char* kMusicUrl = "https://api.elevenlabs.io/v1/music";

    juce::String maskKey (const juce::String& key)
    {
        return key.length() > 8 ? key.substring (0, 4) + "…"_u8 + key.getLastCharacters (4) : juce::String ("(courte)");
    }
}

HttpResult postJson (const juce::String& url, const juce::String& headers, const juce::String& body, int timeoutMs)
{
    HttpResult r;
    const auto t0 = juce::Time::getMillisecondCounterHiRes();
    juce::WebInputStream stream (juce::URL (url).withPOSTData (body), true);
    stream.withExtraHeaders (headers).withConnectionTimeout (timeoutMs).withNumRedirectsToFollow (3);
    if (! stream.connect (nullptr))
    {
        r.status = stream.getStatusCode();
        const double elapsed = juce::Time::getMillisecondCounterHiRes() - t0;
        if (r.status <= 0)
            r.error = elapsed >= timeoutMs * 0.95
                          ? "Délai dépassé ("_u8 + juce::String (juce::roundToInt (elapsed / 1000.0)) + " s) : le service n'a pas répondu à temps"_u8
                          : juce::String ("Pas de réponse du serveur (connexion internet ?)"_u8);
    }
    r.status = stream.getStatusCode();
    r.headers = stream.getResponseHeaders();
    const auto expected = stream.getTotalLength();
    juce::MemoryOutputStream out (r.body, false);
    out.writeFromInputStream (stream, 200 * 1024 * 1024);
    out.flush();
    if (r.error.isEmpty() && expected > 0 && static_cast<juce::int64> (r.body.getSize()) != expected)
        r.error = "Téléchargement incomplet ("_u8 + juce::String (static_cast<juce::int64> (r.body.getSize())) + "/" + juce::String (expected)
                  + " octets) : connexion coupée ?"_u8;
    const auto requestId = r.headers.getValue ("request-id", {});
    SV_LOG_INFO (kMod, "HTTP " + juce::String (r.status) + " en " + juce::String (juce::roundToInt (juce::Time::getMillisecondCounterHiRes() - t0))
                       + " ms, " + juce::String (static_cast<juce::int64> (r.body.getSize())) + " octets" + (requestId.isNotEmpty() ? ", request-id " + requestId : juce::String())
                       + (r.error.isNotEmpty() ? " — "_u8 + r.error : juce::String()));
    return r;
}

HttpResult postJsonWithRetry (const juce::String& url, const juce::String& headers, const juce::String& body, int timeoutMs)
{
    HttpResult r;
    for (int attempt = 0;; ++attempt)
    {
        r = postJson (url, headers, body, timeoutMs);
        const bool transient = r.status == 429 || r.status == 529 || (r.status >= 500 && r.status <= 504);
        if (! transient || attempt >= 2)
            return r;
        int waitMs = 2000 << attempt;   // 2 s puis 4 s
        const auto retryAfter = r.headers.getValue ("retry-after", {}).trim();
        if (retryAfter.containsOnly ("0123456789") && retryAfter.isNotEmpty())
            waitMs = juce::jlimit (1000, 30000, retryAfter.getIntValue() * 1000);
        SV_LOG_WARN (kMod, "HTTP " + juce::String (r.status) + " (service saturé ou limite) : nouvel essai dans "_u8
                           + juce::String (waitMs / 1000.0, 1) + " s (" + juce::String (attempt + 1) + "/2)");
        juce::Thread::sleep (waitMs);
    }
}

juce::String musicErrorMessage (const juce::var& v)
{
    const auto detail = v.getProperty ("detail", {});
    // Le tableau d'abord : pour JUCE, un tableau est aussi un « objet ».
    if (const auto* arr = detail.getArray(); arr != nullptr)
        return arr->isEmpty() ? juce::String() : (*arr)[0].getProperty ("msg", {}).toString();
    if (detail.isObject())
        return detail.getProperty ("message", {}).toString();
    return detail.isString() ? detail.toString() : juce::String();
}

juce::String describeHttpError (int status, const juce::String& serverMessage)
{
    juce::String m;
    switch (status)
    {
        case 400: m = "Requête refusée par le service"_u8; break;
        case 401: m = "Clé API invalide ou manquante"_u8; break;
        case 402: m = "Crédit insuffisant sur le compte du service"_u8; break;
        case 403: m = "Accès refusé avec cette clé"_u8; break;
        case 404: m = "Service ou modèle introuvable (nom du modèle ?)"_u8; break;
        case 413: m = "Demande trop longue"_u8; break;
        case 429: m = "Limite d'utilisation atteinte, réessaie dans un moment"_u8; break;
        case 500: case 502: case 503: case 504: case 529: m = "Service momentanément indisponible, réessaie plus tard"_u8; break;
        default:  m = "Erreur du service (HTTP "_u8 + juce::String (status) + ")"; break;
    }
    if (serverMessage.isNotEmpty())
        m << " — "_u8 << serverMessage.substring (0, 300);
    return m;
}

// ---------------------------------------------------------------------------------------------
juce::String buildClaudeBody (const ClaudeRequest& rq)
{
    auto* root = new juce::DynamicObject();
    root->setProperty ("model", rq.model.isNotEmpty() ? rq.model : juce::String (kDefaultClaudeModel));
    root->setProperty ("max_tokens", rq.maxTokens);
    if (rq.system.isNotEmpty())
        root->setProperty ("system", rq.system);

    auto* msg = new juce::DynamicObject();
    msg->setProperty ("role", "user");
    msg->setProperty ("content", rq.user);
    juce::Array<juce::var> messages;
    messages.add (juce::var (msg));
    root->setProperty ("messages", messages);

    // Réflexion adaptative toujours active sur ce modèle : on règle seulement l'effort.
    auto* oc = new juce::DynamicObject();
    oc->setProperty ("effort", rq.effort);
    if (! rq.schema.isVoid())
    {
        auto* fmt = new juce::DynamicObject();
        fmt->setProperty ("type", "json_schema");
        fmt->setProperty ("schema", rq.schema);
        oc->setProperty ("format", juce::var (fmt));
    }
    root->setProperty ("output_config", juce::var (oc));

    // En cas de refus par les filtres de sécurité, l'API relance sur le modèle de repli recommandé.
    root->setProperty ("fallbacks", "default");
    return juce::JSON::toString (juce::var (root), true);
}

ClaudeResponse parseClaudeResponse (int httpStatus, const juce::String& body, bool expectJson)
{
    ClaudeResponse res;
    res.httpStatus = httpStatus;
    juce::var v;
    const auto parsed = juce::JSON::parse (body, v);

    if (httpStatus != 200)
    {
        juce::String serverMsg;
        if (parsed.wasOk())
            serverMsg = v.getProperty ("error", {}).getProperty ("message", {}).toString();
        res.error = describeHttpError (httpStatus, serverMsg);
        return res;
    }
    if (parsed.failed() || ! v.isObject())
    {
        res.error = "Réponse illisible du service d'IA"_u8;
        return res;
    }

    res.model = v.getProperty ("model", {}).toString();
    res.stopReason = v.getProperty ("stop_reason", {}).toString();
    const auto usage = v.getProperty ("usage", {});
    res.inputTokens = static_cast<int> (usage.getProperty ("input_tokens", 0));
    res.outputTokens = static_cast<int> (usage.getProperty ("output_tokens", 0));

    if (res.stopReason == "refusal")
    {
        res.error = "L'IA a refusé cette demande"_u8;
        return res;
    }

    if (const auto* content = v.getProperty ("content", {}).getArray())
        for (const auto& block : *content)
            if (block.getProperty ("type", {}).toString() == "text")
                res.text << block.getProperty ("text", {}).toString();

    if (res.stopReason == "max_tokens")
    {
        SV_LOG_WARN (kMod, "Réponse tronquée (max_tokens atteint)"_u8);
        if (expectJson)
        {
            res.error = "Réponse de l'IA tronquée (limite de longueur atteinte) : réessaie avec une demande plus courte"_u8;
            return res;
        }
    }

    if (expectJson)
    {
        if (juce::JSON::parse (res.text, res.json).failed() || ! res.json.isObject())
        {
            res.error = "L'IA n'a pas renvoyé de JSON valide"_u8;
            return res;
        }
    }
    res.ok = res.text.isNotEmpty();
    if (! res.ok)
        res.error = "Réponse vide"_u8;
    return res;
}

ClaudeResponse askClaude (const ClaudeRequest& rq)
{
    log::ScopedTimer timer (kMod, "requête Claude"_u8);
    if (rq.apiKey.trim().isEmpty())
    {
        ClaudeResponse r;
        r.error = "Aucune clé API IA (Paramètres > IA connectée)"_u8;
        return r;
    }
    juce::String headers;
    headers << "Content-Type: application/json\r\n"
            << "x-api-key: " << rq.apiKey.trim() << "\r\n"
            << "anthropic-version: 2023-06-01\r\n"
            << "anthropic-beta: server-side-fallback-2026-07-01\r\n";
    SV_LOG_INFO (kMod, "Claude : modèle "_u8 + rq.model + ", effort " + rq.effort + ", clé "_u8 + maskKey (rq.apiKey.trim())
                       + ", " + juce::String (rq.user.length()) + " caractères envoyés"_u8);

    const auto http = postJsonWithRetry (kClaudeUrl, headers, buildClaudeBody (rq), rq.timeoutMs);
    if (http.error.isNotEmpty() && (http.status == 0 || http.status == 200))
    {
        ClaudeResponse r;
        r.error = http.error;
        SV_LOG_ERROR (kMod, r.error);
        return r;
    }
    auto res = parseClaudeResponse (http.status, http.body.toString(), ! rq.schema.isVoid());
    if (res.ok)
        SV_LOG_INFO (kMod, "Réponse de "_u8 + res.model + " : " + juce::String (res.inputTokens) + " jetons en entrée, "_u8
                           + juce::String (res.outputTokens) + " en sortie");
    else
        SV_LOG_ERROR (kMod, "Claude : " + res.error);
    return res;
}

// ---------------------------------------------------------------------------------------------
MusicResponse composeMusic (const MusicRequest& rq, const juce::File& outFileWithoutExtension)
{
    log::ScopedTimer timer (kMod, "génération musicale"_u8);
    MusicResponse res;
    if (rq.apiKey.trim().isEmpty())
    {
        res.error = "Aucune clé de génération musicale (Paramètres > IA connectée)"_u8;
        return res;
    }
    if (rq.prompt.trim().isEmpty())
    {
        res.error = "Description de l'instru vide";
        return res;
    }

    auto* root = new juce::DynamicObject();
    root->setProperty ("prompt", rq.prompt.substring (0, 4000));
    root->setProperty ("music_length_ms", juce::jlimit (3000, 600000, rq.lengthMs));
    root->setProperty ("model_id", rq.modelId);
    root->setProperty ("force_instrumental", rq.instrumental);
    juce::String headers;
    headers << "Content-Type: application/json\r\n"
            << "xi-api-key: " << rq.apiKey.trim() << "\r\n";
    SV_LOG_INFO (kMod, "Génération d'instru : "_u8 + juce::String (rq.lengthMs / 1000) + " s, modèle "_u8 + rq.modelId + ", clé "_u8 + maskKey (rq.apiKey.trim()));

    const auto http = postJsonWithRetry (kMusicUrl, headers, juce::JSON::toString (juce::var (root), true), rq.timeoutMs);
    if (http.status != 200)
    {
        juce::String serverMsg;
        juce::var v;
        if (juce::JSON::parse (http.body.toString(), v).wasOk())
            serverMsg = musicErrorMessage (v);
        res.error = http.status == 0 ? http.error : describeHttpError (http.status, serverMsg);
        SV_LOG_ERROR (kMod, "Génération musicale : "_u8 + res.error);
        return res;
    }
    if (http.error.isNotEmpty())
    {
        res.error = http.error;   // téléchargement incomplet : ne pas importer un morceau tronqué
        SV_LOG_ERROR (kMod, "Génération musicale : "_u8 + res.error);
        return res;
    }
    if (http.body.getSize() < 1024)
    {
        res.error = "Fichier audio reçu trop petit ("_u8 + juce::String ((int) http.body.getSize()) + " octets)";
        SV_LOG_ERROR (kMod, res.error);
        return res;
    }

    // Format d'après les premiers octets : "RIFF" = WAV, sinon MP3 (ID3 ou trame 0xFFEx).
    const auto* b = static_cast<const unsigned char*> (http.body.getData());
    const bool wav = b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F';
    res.file = outFileWithoutExtension.withFileExtension (wav ? ".wav" : ".mp3");
    if (! res.file.getParentDirectory().createDirectory() || ! res.file.replaceWithData (http.body.getData(), http.body.getSize()))
    {
        res.error = "Écriture du fichier impossible : "_u8 + res.file.getFullPathName();
        SV_LOG_ERROR (kMod, res.error);
        return res;
    }
    res.ok = true;
    SV_LOG_INFO (kMod, "Instru générée : "_u8 + res.file.getFullPathName() + " (" + juce::String ((int) (http.body.getSize() / 1024)) + " Ko)");
    return res;
}
} // namespace sv::ai
