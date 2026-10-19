#pragma once

#include <juce_core/juce_core.h>

#include "../Text.h"

// Clients HTTP des services d'IA facultatifs (aucun audio n'est envoyé, uniquement du texte).
//  - Claude (Anthropic, API Messages) : réponses texte ou JSON structuré (output_config.format).
//  - ElevenLabs Music : génération d'une instru à partir d'une description.
// Appels bloquants : à lancer hors du thread UI.
namespace sv::ai
{
constexpr const char* kDefaultClaudeModel = "claude-opus-5-5";

struct HttpResult
{
    int status = 0;
    juce::MemoryBlock body;
    juce::StringPairArray headers;
    juce::String error;   // erreur réseau (pas de réponse, délai dépassé, téléchargement incomplet)
};

HttpResult postJson (const juce::String& url, const juce::String& headers, const juce::String& body, int timeoutMs);
/** postJson + 2 nouveaux essais (attente croissante, en-tête retry-after respecté) sur 429 / 5xx / 529. */
HttpResult postJsonWithRetry (const juce::String& url, const juce::String& headers, const juce::String& body, int timeoutMs);
/** Message lisible d'une erreur ElevenLabs (detail texte, objet {message} ou tableau [{msg}]). */
juce::String musicErrorMessage (const juce::var& responseJson);

// --- Claude ----------------------------------------------------------------------------------
struct ClaudeRequest
{
    juce::String apiKey;
    juce::String model = kDefaultClaudeModel;
    juce::String system;
    juce::String user;
    juce::var schema;                 // si défini : réponse JSON validée par l'API
    juce::String effort = "medium";   // low / medium / high
    int maxTokens = 16000;
    int timeoutMs = 180000;
};

struct ClaudeResponse
{
    bool ok = false;
    juce::String text;
    juce::var json;
    juce::String error;       // message lisible en français
    juce::String stopReason;
    juce::String model;
    int httpStatus = 0;
    int inputTokens = 0;
    int outputTokens = 0;
};

juce::String buildClaudeBody (const ClaudeRequest& request);
ClaudeResponse parseClaudeResponse (int httpStatus, const juce::String& body, bool expectJson);
ClaudeResponse askClaude (const ClaudeRequest& request);

/** Message d'erreur lisible pour un code HTTP (401 clé invalide, 429 limite…). */
juce::String describeHttpError (int status, const juce::String& serverMessage);

// --- ElevenLabs Music ------------------------------------------------------------------------
struct MusicRequest
{
    juce::String apiKey;
    juce::String prompt;
    int lengthMs = 120000;
    bool instrumental = true;
    juce::String modelId = "music_v1";
    int timeoutMs = 600000;
};

struct MusicResponse
{
    bool ok = false;
    juce::File file;
    juce::String error;
};

/** Écrit l'audio reçu dans outFileWithoutExtension + extension détectée (.mp3 / .wav). */
MusicResponse composeMusic (const MusicRequest& request, const juce::File& outFileWithoutExtension);
} // namespace sv::ai
