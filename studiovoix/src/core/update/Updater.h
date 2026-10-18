#pragma once

#include <juce_core/juce_core.h>

#include "../Text.h"

#include <functional>

// Mises à jour automatiques : la CI publie à chaque compilation une « release » GitHub contenant
// l'installateur (StudioVoix-Setup-<version>-build<N>.exe). Le programme compare le numéro de build
// de la dernière release au sien, télécharge l'installateur, le vérifie (taille, SHA-256, en-tête
// Windows), puis le lance en mode silencieux ; l'installateur attend la fermeture du programme,
// remplace les fichiers et le relance.
// Appels réseau bloquants : à lancer hors du thread UI.
namespace sv::update
{
constexpr const char* kRepo = "jovenger/rebuild_project";

/** Numéro de build de ce programme (SV_BUILD_NUMBER, 0 = compilation locale). */
int currentBuild();

/** Numéro de build lu dans un nom ("…-build23.exe", "studiovoix-build23") ; 0 si absent. */
int buildFromName (const juce::String& name);

struct ReleaseInfo
{
    bool ok = false;
    int build = 0;
    juce::String tag, title, notes;
    juce::String assetName, assetApiUrl, downloadUrl;
    juce::String sha256;      // minuscules, vide si GitHub ne le fournit pas
    juce::int64 size = 0;
    int httpStatus = 0;
    juce::String error;       // message lisible en français
};

/** Lit la réponse JSON de l'API GitHub « release ». */
ReleaseInfo parseRelease (const juce::String& json);

/** Message lisible pour un échec HTTP de la vérification (dépôt privé sans jeton, jeton refusé…). */
juce::String describeHttpError (int status, bool hasToken);

/** Interroge GitHub (dernière release). token : jeton GitHub facultatif (dépôt privé). */
ReleaseInfo fetchLatest (const juce::String& token, int timeoutMs = 15000);

/** progress (0..1) ; renvoie false pour annuler. */
using ProgressFn = std::function<bool (double)>;

/** Télécharge l'installateur de la release dans dest puis le vérifie. */
bool download (const ReleaseInfo& release, const juce::String& token, const juce::File& dest,
               const ProgressFn& progress, juce::String& error);

/** Taille annoncée, SHA-256 (si connu) et en-tête « MZ » d'un exécutable Windows. */
bool verifyInstaller (const juce::File& file, const ReleaseInfo& release, juce::String& error);

/** Arguments de l'installateur pour une mise à jour silencieuse avec relance du programme. */
juce::String installerArguments (const juce::File& logFile);
} // namespace sv::update
