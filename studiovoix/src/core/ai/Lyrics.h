#pragma once

#include "../Types.h"

#include <juce_core/juce_core.h>

#include <vector>

// Paroles reconnues et calées mot par mot (édition StudioVoix IA) : whisper.cpp (outil « whisper-cli » + modèle ggml)
// lancé en sous-processus sur la voix principale ; chaque mot reçoit sa position sur la timeline. Sert au prompteur
// (karaoké), à l'affichage sous les blocs et, plus tard, au recalage rythmique mot par mot.
namespace sv::ai::local
{
/** Lecture de la sortie JSON de whisper-cli (-oj, un segment par mot avec -ml 1 -sow) ; offsetSec = position du début
    de l'audio analysé sur la timeline. Les segments vides sont ignorés, les mots triés par temps. */
std::vector<LyricWord> parseWhisperJson (const juce::String& json, double offsetSec);

/** Regroupe les mots en lignes de paroles : nouvelle ligne quand le silence entre deux mots dépasse gapSec. */
juce::String wordsToLyrics (const std::vector<LyricWord>& words, double gapSec = 0.7);

/** Vrai si whisper-cli et le modèle sont installés. */
bool whisperAvailable();

/** Transcrit `audio` (mono, sampleRate) : WAV 16 kHz 16 bits dans workDir, whisper-cli, lecture du JSON. offsetSec est
    ajouté aux temps. Bloquant (quelques secondes par minute de voix). Vide + error renseignée en cas d'échec. */
std::vector<LyricWord> transcribeWithWhisper (const Mono& audio, double sampleRate, const juce::File& workDir, double offsetSec,
                                              juce::String& error, double& seconds);
} // namespace sv::ai::local
