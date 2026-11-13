#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

// Séparation d'instru par Demucs (demucs.cpp, modèle Hybrid Transformer 4 sources) : batterie, basse, autres,
// voix. Édition « StudioVoix IA » : outil « demucs » (binaire demucs_mt compilé par la CI) et modèle
// « demucs-htdemucs », tous deux installés depuis l'onglet IA locale. Lourd : plusieurs minutes sur le processeur.
namespace sv::ai::local
{
struct StemSet
{
    Mono drums, bass, other, vocals;   // au taux demandé, mono (les prises du projet sont mono)
    bool ok = false;
    juce::String note;                 // raison de l'échec ou résumé
    double seconds = 0.0;              // durée du calcul
};

/** Outil et modèle installés ? */
bool demucsAvailable();

/** Lit les quatre WAV écrits par demucs.cpp dans outDir (target_0_drums.wav … target_3_vocals.wav) ;
    rééchantillonne au taux demandé. Public pour les tests. */
bool readDemucsOutputs (const juce::File& outDir, double sampleRate, StemSet& out, juce::String& error);

/** Écrit le mixage en WAV 44,1 kHz dans workDir, lance demucs_mt (délai : 15 min + 6 s par seconde d'audio),
    relit les quatre parties. Bloquant : hors du fil d'interface. */
StemSet separateWithDemucs (const Stereo& mix, double sampleRate, const juce::File& workDir);
} // namespace sv::ai::local
