#pragma once

#include "Types.h"

#include <juce_audio_formats/juce_audio_formats.h>

namespace sv::audio
{
struct LoadResult
{
    Stereo buffer;                 // toujours 2 canaux, au taux demandé
    double sampleRate = 0.0;
    double originalSampleRate = 0.0;
    int originalChannels = 0;
    juce::String error;

    bool ok() const { return error.isEmpty(); }
};

/** Charge WAV / AIFF / FLAC / OGG / MP3 et convertit en stéréo au taux demandé.
    Valide : existence, taille, durée max, nombre de canaux. */
LoadResult loadStereo (const juce::File& file, double targetSampleRate, double maxSeconds = 1800.0);

/** Charge et convertit en mono (moyenne des canaux). */
bool loadMono (const juce::File& file, double targetSampleRate, Mono& out, juce::String& error,
               double maxSeconds = 1800.0);

enum class FileFormat { Wav24, Wav32Float, Flac24, Mp3_320 };

juce::String extensionFor (FileFormat format);

/** Nom de fichier sûr sous Windows : caractères interdits et de contrôle retirés, noms réservés
    (CON, NUL, COM1…) préfixés, point/espace final retiré ; fallback si le résultat est vide. */
juce::String safeFileName (const juce::String& name, const juce::String& fallback);

/** Écrit un fichier. Le MP3 exige lame.exe (à côté de l'appli ou dans le PATH). */
bool writeFile (const juce::File& file, const Stereo& buffer, double sampleRate, FileFormat format,
                juce::String& error);

bool writeMonoWavFloat (const juce::File& file, const Mono& data, double sampleRate, juce::String& error);

Mono toMono (const Stereo& buffer);
Stereo monoToStereo (const Mono& mono);

Stereo resample (const Stereo& in, double fromSr, double toSr);
Mono resample (const Mono& in, double fromSr, double toSr);

float peak (const float* data, size_t n);
float rms (const float* data, size_t n);
bool hasNonFinite (const float* data, size_t n);
/** Remplace NaN/Inf par 0. Retourne le nombre de valeurs corrigées. */
size_t sanitize (float* data, size_t n);

/** Fondu linéaire en place (entrée ou sortie) sur [start, start+len). */
void applyFade (float* data, size_t size, size_t start, size_t len, bool fadeIn);

/** Cherche lame (encodeur MP3) à côté de l'exécutable puis dans le PATH. */
juce::File findLameExecutable();

/** Décalage temporel (ms) de b par rapport à a, par corrélation des enveloppes (5 ms, pas 1 ms) sur ±maxMs.
    > 0 = b est en retard. Sert à vérifier qu'un traitement ne décale pas une piste. */
double envelopeLagMs (const Mono& a, const Mono& b, double sampleRate, int maxMs = 500);
} // namespace sv::audio
