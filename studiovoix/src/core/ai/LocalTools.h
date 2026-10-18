#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

#include <atomic>
#include <vector>

// Outils d'IA locaux et gratuits (édition « StudioVoix IA ») : binaires et modèles libres téléchargés à la demande
// dans le dossier « outils » du programme, vérifiés par taille et empreinte SHA-256, puis lancés en sous-processus.
// Rien n'est embarqué dans l'installateur. Les empreintes sont relevées par la CI (`studiovoix_cli outils-empreintes`)
// et épinglées ici ; une empreinte vide = pas encore relevée (téléchargement accepté avec avertissement dans le journal).
namespace sv::ai::local
{
struct ToolDef
{
    juce::String id;            // "deep-filter", "whisper-base"…
    juce::String name;          // nom affiché
    juce::String description;   // à quoi ça sert, poids, durée
    juce::String url;           // adresse pour ce système (vide = indisponible sur ce système)
    juce::String fileName;      // nom du fichier dans le dossier outils
    juce::int64 size = 0;       // taille attendue en octets (0 = inconnue)
    juce::String sha256;        // empreinte attendue (hexadécimal minuscule, vide = non relevée)
    bool executable = false;    // binaire à lancer (sinon modèle lu par le programme)
    juce::String licence;
};

/** Outils connus, dans l'ordre d'affichage. */
const std::vector<ToolDef>& tools();
const ToolDef* findTool (const juce::String& id);

/** Dossier des outils (%APPDATA%\StudioVoix IA\outils) ; modifiable pour les tests. */
juce::File toolsFolder();
void setToolsFolder (const juce::File& folder);
juce::File toolFile (const ToolDef& t);
bool isInstalled (const ToolDef& t);

struct Progress
{
    std::atomic<float> fraction { 0.0f };          // 0..1 (0 si la taille totale est inconnue)
    std::atomic<juce::int64> downloaded { 0 };
    std::atomic<bool> cancel { false };
};

/** Télécharge dans un fichier temporaire, vérifie taille et SHA-256, installe. Bloquant : hors du fil d'interface. */
bool install (const ToolDef& t, Progress& progress, juce::String& error);
bool remove (const ToolDef& t);

/** Lance un outil installé avec ses arguments ; sortie (stdout + stderr) et code de retour ; false si absent,
    échec de lancement ou délai dépassé (le processus est alors tué). */
bool run (const ToolDef& t, const juce::StringArray& args, juce::String& output, int& exitCode, int timeoutMs);

/** Empreinte SHA-256 (hexadécimal minuscule) d'un fichier ; vide s'il est illisible. */
juce::String sha256Of (const juce::File& f);

/** Ligne lisible : nom, état (installé / absent / indisponible), taille. */
juce::String describe (const ToolDef& t);
} // namespace sv::ai::local
