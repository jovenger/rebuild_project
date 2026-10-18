#pragma once

#include "../Types.h"
#include "../analysis/PitchDetector.h"
#include "../analysis/VoiceActivity.h"

// Briques de traitement hors temps réel (voix et master). Toutes travaillent sur des tampons complets.
namespace sv::dsp
{
// ---------------------------------------------------------------------------------------------
// Filtres biquad (formules RBJ), double précision.
struct Biquad
{
    double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
    double z1 = 0, z2 = 0;

    inline float process (float xf) noexcept
    {
        const double x = xf;
        const double y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        return static_cast<float> (y);
    }
    void reset() noexcept { z1 = z2 = 0.0; }

    static Biquad highPass (double sr, double freq, double q);
    static Biquad lowPass (double sr, double freq, double q);
    static Biquad peak (double sr, double freq, double q, double gainDb);
    static Biquad lowShelf (double sr, double freq, double q, double gainDb);
    static Biquad highShelf (double sr, double freq, double q, double gainDb);
    static Biquad bandPass (double sr, double freq, double q);   // gain 0 dB au centre
};

void applyBiquad (Mono& x, Biquad f);
/** Passe-haut / passe-bas Butterworth d'ordre 2 ou 4. */
void highPass (Mono& x, double sr, double freq, int order = 4);
void lowPass (Mono& x, double sr, double freq, int order = 2);

// ---------------------------------------------------------------------------------------------
struct EqSettings
{
    float lowCutHz = 80.0f;
    float lowShelfHz = 200.0f, lowShelfDb = 0.0f;
    float mudHz = 300.0f, mudDb = 0.0f, mudQ = 1.0f;
    float presenceHz = 3500.0f, presenceDb = 0.0f, presenceQ = 0.9f;
    float airHz = 12000.0f, airDb = 0.0f;
    float highCutHz = 0.0f;   // 0 = désactivé
};
void applyEq (Mono& x, double sr, const EqSettings& eq);

/** EQ correctif par bandes d'octave d'après une courbe en tiers d'octave (centres + gains dB). */
void applyCurveEq (Mono& x, double sr, const std::vector<float>& centersHz, const std::vector<float>& gainsDb);

// ---------------------------------------------------------------------------------------------
struct CompressorSettings
{
    float thresholdDb = -20.0f;
    float ratio = 4.0f;
    float kneeDb = 6.0f;
    float attackMs = 5.0f;
    float releaseMs = 80.0f;
    float makeupDb = 0.0f;    // NaN interdit ; 0 = aucun
    float mix = 1.0f;         // 1 = série, <1 = compression parallèle
    bool rmsDetector = false;
};
/** Retourne la réduction de gain moyenne (dB, positive) pendant les passages actifs. */
float compress (Mono& x, double sr, const CompressorSettings& c);
/** Même compresseur sur plusieurs canaux liés (détecteur = canal le plus fort) : l'image stéréo ne bouge pas. */
float compressLinked (Stereo& audio, double sr, const CompressorSettings& c);

/** Compresseur « colle » du bus voix : toutes les voix (principale, doublages, backs, ad-libs, harmonies, ambiance)
    passent ensemble dans un même compresseur RMS lié (seuil -20 dB, 2:1, genou 6 dB, attaque 30 ms, relâche 200 ms)
    pour sonner comme un seul ensemble, puis un rattrapage de gain fixe. L'état est conservé d'un bloc à l'autre :
    la même classe sert au rendu (un seul bloc) et à la lecture temps réel (blocs de la carte son). */
class BusGlue
{
public:
    static CompressorSettings settings();
    void prepare (double sampleRate);
    void setMakeupDb (float db) noexcept { makeup = dbToGain (db); }
    /** Compresse en place numChannels canaux liés. Retourne la réduction de gain moyenne du bloc (dB, positive) sur les
        passages actifs (niveau au-dessus de seuil - 20 dB). */
    float process (float* const* channels, int numChannels, int numSamples) noexcept;
    float process (Stereo& audio) noexcept;

private:
    float att = 0.0f, rel = 0.0f, rmsCoef = 0.0f, makeup = 1.0f;
    float gr = 0.0f;   // réduction lissée (dB)
    float sq = 0.0f;   // puissance RMS lissée (fenêtre ~10 ms)
};

// ---------------------------------------------------------------------------------------------
struct DeEsserSettings
{
    float freqHz = 6500.0f;
    float amount = 0.6f;      // 0..1
    float maxReductionDb = 10.0f;
    float offsetDb = -8.0f;   // seuil relatif à l'enveloppe large bande
};
float deEss (Mono& x, double sr, const DeEsserSettings& d);

// ---------------------------------------------------------------------------------------------
struct SaturationSettings
{
    float driveDb = 0.0f;
    float mix = 0.0f;         // 0 = désactivé
    float asymmetry = 0.1f;   // harmoniques paires
};
void saturate (Mono& x, double sr, const SaturationSettings& s);

// ---------------------------------------------------------------------------------------------
struct CleanSettings
{
    bool enabled = true;
    float hpfHz = 90.0f;
    bool dePlosive = true;
    float gateRangeDb = 12.0f;        // atténuation max sous le seuil (0 = pas de porte)
    float breathReductionDb = 8.0f;   // 0 = respirations intactes
    float denoiseDb = 12.0f;          // débruitage spectral (souffle, ronflement, bruit de pièce) ; 0 = désactivé
    bool declip = true;               // reconstruction des passages écrêtés
};
struct CleanReport
{
    int plosivesTreated = 0;
    int breathsTreated = 0;
    float noiseFloorDb = -120.0f;
    float noiseReducedDb = 0.0f;      // baisse du bruit dans les silences (débruitage spectral)
    int clippedRepaired = 0;          // échantillons écrêtés reconstruits
};
CleanReport clean (Mono& x, double sr, const CleanSettings& s, const analysis::PitchTrack& track,
                   const analysis::VoiceActivity& va);

// ---------------------------------------------------------------------------------------------
struct ReverbSettings
{
    float send = 0.0f;        // 0..1, niveau du retour
    float roomSize = 0.5f;
    float damping = 0.5f;
    float width = 1.0f;
    float preDelayMs = 20.0f;
    float hpfHz = 250.0f;
    float lpfHz = 9000.0f;
};
/** Retour de réverbération stéréo (100 % mouillé) multiplié par send. */
Stereo reverbReturn (const Mono& x, double sr, const ReverbSettings& r);

struct DelaySettings
{
    float send = 0.0f;
    float noteBeats = 0.5f;   // 0.5 = croche, 1 = noire, 0.75 = croche pointée
    float feedback = 0.25f;
    float hpfHz = 300.0f;
    float lpfHz = 6000.0f;
    bool pingPong = false;
    bool throwsOnly = false;  // envoi seulement sur les fins de phrases
};
/** sendEnvelope : gain d'envoi par échantillon (vide = constant). */
Stereo delayReturn (const Mono& x, double sr, double bpm, const DelaySettings& d,
                    const std::vector<float>& sendEnvelope = {});

/** Enveloppe d'envoi qui ne s'ouvre que sur les derniers mots de chaque phrase. */
std::vector<float> phraseEndThrowEnvelope (size_t numSamples, double sr, const analysis::VoiceActivity& va,
                                           double tailSec = 0.35);

// ---------------------------------------------------------------------------------------------
/** Place un signal mono dans l'image stéréo : panoramique + élargissement Haas (width 0..1). */
Stereo placeStereo (const Mono& x, double sr, float pan, float width, float gain);

/** Gain qui amène le RMS des passages actifs à targetDb. */
float gainForActiveRms (const Mono& x, double sr, float targetDb);
/** Niveau RMS (dBFS) des passages actifs (-120 si silence). */
float activeLevelDb (const Mono& x, double sr);

/** Délai fractionnaire variable (doublages) : delaySamples par échantillon. */
Mono variableDelay (const Mono& x, const std::vector<float>& delaySamples);
} // namespace sv::dsp
