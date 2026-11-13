#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

// Nettoyage de voix par IA locale (DeepFilterNet via l'outil « deep-filter ») : la prise brute passe dans le réseau
// avant la chaîne du style. Résultat mis en cache dans le projet (empreinte du contenu) : un rendu suivant ne relance
// pas l'outil. Sans outil installé, rien n'est modifié et la raison est donnée.
namespace sv::ai::local
{
struct AiCleanResult
{
    bool applied = false;     // audio remplacé par la version nettoyée
    bool fromCache = false;
    juce::String note;        // ligne lisible pour le rapport de piste (toujours remplie)
    double seconds = 0.0;     // durée de l'outil (0 si cache ou non lancé)
};

/** Clé de cache : empreinte du contenu audio et de la fréquence (16 caractères hexadécimaux). */
juce::String aiCleanKey (const Mono& audio, double sampleRate);

/** Nettoie `audio` en place avec deep-filter (48 kHz exigé par l'outil ; sinon rien). cacheDir reçoit l'entrée et la
    sortie (ia_nettoyage_<clé>.wav). Bloquant : à appeler depuis le fil de rendu. */
AiCleanResult cleanWithDeepFilter (Mono& audio, double sampleRate, const juce::File& cacheDir);

/** Vrai si l'outil deep-filter est installé (le nettoyage IA peut être proposé). */
bool deepFilterAvailable();
} // namespace sv::ai::local
