#pragma once

#include <juce_audio_devices/juce_audio_devices.h>
#include <juce_audio_formats/juce_audio_formats.h>

#include "core/Types.h"

#include <memory>
#include <mutex>

// Moteur temps réel : lecture du mix (tampons déjà calculés), enregistrement de la voix sur disque
// pendant la prise (sans perte en cas de plantage), clics de métronome / compte à rebours, vu-mètres.
// Aucun traitement lourd dans le thread audio : les effets sont calculés hors temps réel après la prise.
namespace sv::app
{
class AudioEngine final : public juce::AudioIODeviceCallback
{
public:
    struct PlayTrack
    {
        std::shared_ptr<const Stereo> buffer;
        long start = 0;
        float gainL = 1.0f;
        float gainR = 1.0f;
        std::shared_ptr<std::atomic<float>> peak;   // crête jouée (après gain), lue et remise à zéro par l'interface
    };

    struct PlayState
    {
        std::vector<PlayTrack> tracks;
        long length = 0;
    };

    struct RecordRequest
    {
        juce::File file;          // WAV 32 bits flottants mono
        long recordStart = 0;     // position timeline où la prise commence (avant recalage)
        long prerollSamples = 0;  // compte à rebours avant recordStart
        bool punch = false;
        long punchIn = 0;
        long punchOut = 0;
    };

    struct RecordedTake
    {
        bool ok = false;
        juce::String error;
        juce::File file;
        long firstWrittenPosition = 0;   // position timeline (callback) du premier échantillon écrit
        long numSamples = 0;
        int inputLatency = 0;
        int outputLatency = 0;
        bool clipped = false;
        float peakDb = -120.0f;
        double sampleRate = kProjectSampleRate;   // fréquence de la carte pendant la prise (celle du WAV)
        long droppedSamples = 0;                  // perdus faute de place dans la file d'écriture disque
        juce::String warning;                     // prise gardée mais à vérifier (disque, silence, carte perdue)
        RecordRequest request;
    };

    AudioEngine();
    ~AudioEngine() override;

    juce::AudioDeviceManager& deviceManager() { return devices; }

    /** Ouvre la carte son : WASAPI exclusif en priorité sous Windows, puis repli. Retourne un message d'erreur ou vide. */
    juce::String openDevice (const juce::XmlElement* savedState);
    juce::String describeDevice() const;
    /** Identifiant du matériel courant (type | entrée | sortie) auquel le calibrage est rattaché. */
    juce::String deviceKey() const;
    /** Longueur réelle (échantillons) d'un WAV, -1 s'il est illisible. */
    static long wavFileLength (const juce::File& file);

    /** Appelés sur le thread UI (fixés une fois par la session). */
    std::function<void()> onDeviceLostWhileRecording;
    std::function<void (double oldRate, double newRate)> onSampleRateChanged;
    double sampleRate() const { return currentSampleRate.load(); }
    int inputLatency() const;
    int outputLatency() const;

    // Transport (thread UI)
    void setPlayState (std::shared_ptr<const PlayState> state);
    void play();
    void stop();
    bool isPlaying() const { return playing.load(); }
    void setPosition (long samples);
    long getPosition() const { return position.load(); }
    void setLoop (bool enabled, long start, long end);
    void setTempo (double bpm, double firstBeatSec);
    void setMetronome (bool on) { metronomeOn.store (on); }
    void setMonitoring (bool on, float gain = 1.0f) { monitorOn.store (on); monitorGain.store (gain); }
    void setInputChannelMode (int mode) { inputMode.store (mode); }
    void setInputTrimDb (float db) { inputTrim.store (dbToGain (db)); }

    // Enregistrement
    bool startRecording (const RecordRequest& request, juce::String& error);
    RecordedTake stopRecording();
    bool isRecording() const { return recording.load(); }
    bool isInCountdown() const { return recording.load() && position.load() < recordStartPos.load(); }

    // Calibrage de latence : joue des clics et capte l'entrée en mémoire.
    bool startCalibration (juce::String& error);
    bool isCalibrating() const { return calibrating.load(); }
    /** Résultat : décalage mesuré (échantillons) entre émission et réception, -1 si échec. */
    int finishCalibration (juce::String& report);

    // Vu-mètres (lecture depuis l'UI)
    float inputPeak() const { return inPeak.load(); }
    float outputPeakL() const { return outPeakL.load(); }
    float outputPeakR() const { return outPeakR.load(); }
    bool consumeClipFlag() { return clipFlag.exchange (false); }
    void resetMeters();
    /** Crête maintenue jusqu'à resetHoldPeak() (test du niveau du micro). */
    float holdPeak() const { return heldPeak.load(); }
    void resetHoldPeak() { heldPeak.store (0.0f); }

    // AudioIODeviceCallback
    void audioDeviceIOCallbackWithContext (const float* const* inputChannelData, int numInputChannels,
                                           float* const* outputChannelData, int numOutputChannels, int numSamples,
                                           const juce::AudioIODeviceCallbackContext& context) override;
    void audioDeviceAboutToStart (juce::AudioIODevice* device) override;
    void audioDeviceStopped() override;
    void audioDeviceError (const juce::String& errorMessage) override;

private:
    void renderClicks (float* const* out, int numOutputChannels, int numSamples, long blockStart, bool countdownOnly);

    juce::AudioDeviceManager devices;
    juce::TimeSliceThread writerThread { "Enregistrement disque" };

    juce::SpinLock stateLock;
    std::shared_ptr<const PlayState> state;
    std::vector<std::shared_ptr<const PlayState>> retired;   // libérés sur le thread UI

    std::atomic<bool> playing { false };
    std::atomic<long> position { 0 };
    std::atomic<bool> loopOn { false };
    std::atomic<long> loopStart { 0 }, loopEnd { 0 };
    std::atomic<double> bpm { 120.0 };
    std::atomic<double> firstBeat { 0.0 };
    std::atomic<bool> metronomeOn { false };
    std::atomic<bool> monitorOn { false };
    std::atomic<float> monitorGain { 1.0f };
    std::atomic<int> inputMode { 0 };
    std::atomic<float> inputTrim { 1.0f };
    std::atomic<double> currentSampleRate { kProjectSampleRate };

    // Enregistrement
    juce::CriticalSection writerLock;
    std::unique_ptr<juce::AudioFormatWriter::ThreadedWriter> writer;
    std::atomic<bool> recording { false };
    std::atomic<long> recordStartPos { 0 };
    std::atomic<long> firstWritten { -1 };
    std::atomic<long> writtenSamples { 0 };
    std::atomic<float> recPeak { 0.0f };
    std::atomic<bool> recClipped { false };
    std::atomic<bool> writeOverflow { false };
    std::atomic<bool> firstWrittenSet { false };
    std::atomic<long> droppedSamples { 0 };
    std::atomic<bool> recordingSuspended { false };   // carte arrêtée pendant la prise : plus rien n'est écrit
    RecordRequest currentRequest;
    bool loopWasOn = false;
    double recSampleRate = kProjectSampleRate;
    int recInputLatency = 0, recOutputLatency = 0;

    // Clics
    std::atomic<bool> clickReset { false };   // demandé par l'UI, appliqué par le thread audio
    int clickRemaining = 0;
    double clickPhase = 0.0;
    double clickFreq = 1500.0;

    // Calibrage
    std::atomic<bool> calibrating { false };
    std::vector<float> calibBuffer;
    std::atomic<long> calibPos { 0 };
    std::vector<long> calibClickTimes;

    // Mesures
    std::atomic<float> inPeak { 0.0f }, outPeakL { 0.0f }, outPeakR { 0.0f }, heldPeak { 0.0f };
    std::atomic<bool> clipFlag { false };
    std::vector<float> inputScratch;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AudioEngine)
};
} // namespace sv::app
