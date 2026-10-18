#include "AudioEngine.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "AudioEngine";

   #if JUCE_WINDOWS
    // Nom du matériel entre parenthèses : "Microphone (USB Audio Device)" -> "USB Audio Device".
    juce::String hardwareName (const juce::String& deviceName)
    {
        if (! deviceName.contains ("("))
            return deviceName.trim();
        return deviceName.fromFirstOccurrenceOf ("(", false, false).upToLastOccurrenceOf (")", false, false).trim();
    }
   #endif
}

AudioEngine::AudioEngine()
{
    writerThread.startThread();
}

AudioEngine::~AudioEngine()
{
    devices.removeAudioCallback (this);
    {
        const juce::ScopedLock sl (writerLock);
        writer.reset();
    }
    writerThread.stopThread (2000);
    devices.closeAudioDevice();
}

juce::String AudioEngine::openDevice (const juce::XmlElement* savedState)
{
    log::ScopedTimer timer (kMod, "ouverture de la carte son");
    juce::AudioDeviceManager::AudioDeviceSetup preferred;
    preferred.sampleRate = kProjectSampleRate;
    preferred.bufferSize = 128;

    juce::String err = devices.initialise (2, 2, savedState, true, {}, &preferred);
    if (err.isNotEmpty())
        SV_LOG_WARN (kMod, "Initialisation : " + err);

   #if JUCE_WINDOWS
    if (savedState == nullptr)
    {
        // Priorité au mode exclusif (latence minimale), puis repli progressif.
        for (const char* type : { "Windows Audio (Exclusive Mode)", "Windows Audio (Low Latency Mode)", "Windows Audio" })
        {
            devices.setCurrentAudioDeviceType (type, true);
            auto* t = devices.getCurrentDeviceTypeObject();
            if (t == nullptr)
                continue;
            t->scanForDevices();
            auto setup = devices.getAudioDeviceSetup();
            // Premier lancement : entrée par défaut de Windows, et sortie sur le même appareil si elle existe
            // (casque branché sur le micro USB ou sur l'interface : une seule horloge, latence minimale).
            // Le choix réel de l'utilisateur se fait ensuite dans Paramètres et est mémorisé.
            const auto inputs = t->getDeviceNames (true);
            const auto outputs = t->getDeviceNames (false);
            if (setup.inputDeviceName.isEmpty() && ! inputs.isEmpty())
                setup.inputDeviceName = inputs[juce::jmax (0, t->getDefaultDeviceIndex (true))];
            const auto hw = hardwareName (setup.inputDeviceName);
            if (hw.isNotEmpty())
            {
                for (const auto& o : outputs)
                {
                    if (hardwareName (o).equalsIgnoreCase (hw))
                    {
                        setup.outputDeviceName = o;
                        SV_LOG_INFO (kMod, "Entrée et sortie sur le même appareil : "_u8 + hw);
                        break;
                    }
                }
            }
            setup.sampleRate = kProjectSampleRate;
            setup.bufferSize = juce::String (type).contains ("Exclusive") ? 128 : 256;
            setup.useDefaultInputChannels = true;
            setup.useDefaultOutputChannels = true;
            err = devices.setAudioDeviceSetup (setup, true);
            if (err.isEmpty() && devices.getCurrentAudioDevice() != nullptr)
            {
                SV_LOG_INFO (kMod, juce::String ("Mode audio retenu : ") + type);
                break;
            }
            SV_LOG_WARN (kMod, juce::String ("Mode ") + type + " indisponible : " + err);
        }
    }
   #endif

    devices.addAudioCallback (this);
    if (devices.getCurrentAudioDevice() == nullptr)
    {
        const auto msg = "Aucune carte son ouverte"_u8 + (err.isNotEmpty() ? " : " + err : juce::String());
        SV_LOG_ERROR (kMod, msg);
        return msg;
    }
    SV_LOG_INFO (kMod, describeDevice());
    return {};
}

juce::String AudioEngine::describeDevice() const
{
    auto* d = devices.getCurrentAudioDevice();
    if (d == nullptr)
        return "Aucune carte son";
    const double sr = d->getCurrentSampleRate();
    return devices.getCurrentAudioDeviceType() + " | " + d->getName() + " | " + juce::String (sr, 0) + " Hz | tampon "
         + juce::String (d->getCurrentBufferSizeSamples()) + " | latence entrée "_u8 + juce::String (d->getInputLatencyInSamples() * 1000.0 / sr, 1)
         + " ms, sortie " + juce::String (d->getOutputLatencyInSamples() * 1000.0 / sr, 1) + " ms";
}

int AudioEngine::inputLatency() const
{
    auto* d = devices.getCurrentAudioDevice();
    return d != nullptr ? d->getInputLatencyInSamples() : 0;
}

int AudioEngine::outputLatency() const
{
    auto* d = devices.getCurrentAudioDevice();
    return d != nullptr ? d->getOutputLatencyInSamples() : 0;
}

void AudioEngine::setPlayState (std::shared_ptr<const PlayState> newState)
{
    {
        const juce::SpinLock::ScopedLockType sl (stateLock);
        std::swap (state, newState);
    }
    // L'ancien état (newState) est libéré ici, sur le thread UI : le thread audio ne l'utilise
    // que sous le verrou, il ne peut donc plus y accéder.
}

void AudioEngine::play()
{
    playing.store (true);
}

void AudioEngine::stop()
{
    playing.store (false);
    clickRemaining = 0;
}

void AudioEngine::setPosition (long samples)
{
    position.store (std::max (0L, samples));
}

void AudioEngine::setLoop (bool enabled, long start, long end)
{
    loopStart.store (std::max (0L, start));
    loopEnd.store (std::max (start + 1, end));
    loopOn.store (enabled && end > start);
}

void AudioEngine::setTempo (double newBpm, double firstBeatSec)
{
    bpm.store (juce::jlimit (40.0, 240.0, newBpm));
    firstBeat.store (firstBeatSec);
}

void AudioEngine::resetMeters()
{
    inPeak.store (0.0f);
    outPeakL.store (0.0f);
    outPeakR.store (0.0f);
}

bool AudioEngine::startRecording (const RecordRequest& request, juce::String& error)
{
    if (recording.load())
    {
        error = "Un enregistrement est déjà en cours"_u8;
        return false;
    }
    if (devices.getCurrentAudioDevice() == nullptr)
    {
        error = "Aucune carte son : vérifie les paramètres audio"_u8;
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    const auto dir = request.file.getParentDirectory().createDirectory();
    if (dir.failed())
    {
        error = "Dossier de prise impossible à créer : "_u8 + dir.getErrorMessage();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    std::unique_ptr<juce::OutputStream> stream = std::make_unique<juce::FileOutputStream> (request.file);
    if (static_cast<juce::FileOutputStream*> (stream.get())->failedToOpen())
    {
        error = "Fichier de prise impossible à ouvrir : "_u8 + request.file.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    juce::WavAudioFormat wav;
    auto options = juce::AudioFormatWriterOptions{}
                       .withSampleRate (currentSampleRate.load())
                       .withNumChannels (1)
                       .withBitsPerSample (32)
                       .withSampleFormat (juce::AudioFormatWriterOptions::SampleFormat::floatingPoint);
    auto w = wav.createWriterFor (stream, options);
    if (w == nullptr)
    {
        error = "Encodeur WAV indisponible";
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    {
        const juce::ScopedLock sl (writerLock);
        writer = std::make_unique<juce::AudioFormatWriter::ThreadedWriter> (w.release(), writerThread, 1 << 17);
    }

    currentRequest = request;
    firstWritten.store (-1);
    writtenSamples.store (0);
    recPeak.store (0.0f);
    recClipped.store (false);
    writeOverflow.store (false);
    recordStartPos.store (request.recordStart);
    loopOn.store (false);
    position.store (request.recordStart - std::max (0L, request.prerollSamples));
    recording.store (true);
    playing.store (true);

    SV_LOG_INFO (kMod, "Enregistrement démarré : "_u8 + request.file.getFileName() + ", départ "_u8
                       + juce::String (request.recordStart / currentSampleRate.load(), 3) + " s, compte à rebours "_u8
                       + juce::String (request.prerollSamples / currentSampleRate.load(), 2) + " s"
                       + (request.punch ? ", punch " + juce::String (request.punchIn / currentSampleRate.load(), 2) + "-"
                                              + juce::String (request.punchOut / currentSampleRate.load(), 2) + " s"
                                        : juce::String()));
    return true;
}

AudioEngine::RecordedTake AudioEngine::stopRecording()
{
    RecordedTake take;
    take.request = currentRequest;
    if (! recording.load())
    {
        take.error = "Aucun enregistrement en cours";
        return take;
    }
    recording.store (false);
    playing.store (false);
    {
        const juce::ScopedLock sl (writerLock);
        writer.reset();   // vide la file et ferme le fichier
    }

    take.file = currentRequest.file;
    take.firstWrittenPosition = firstWritten.load();
    take.numSamples = writtenSamples.load();
    take.inputLatency = inputLatency();
    take.outputLatency = outputLatency();
    take.clipped = recClipped.load();
    take.peakDb = gainToDb (recPeak.load());
    take.ok = take.numSamples > 0 && take.firstWrittenPosition >= 0;
    if (! take.ok)
        take.error = "Prise vide (arrêtée pendant le compte à rebours ?)"_u8;
    if (writeOverflow.load())
        SV_LOG_ERROR (kMod, "Le disque n'a pas suivi : des échantillons ont pu être perdus dans "_u8 + take.file.getFileName());

    SV_LOG_INFO (kMod, "Enregistrement arrêté : "_u8 + juce::String (take.numSamples / currentSampleRate.load(), 2) + " s, crête "_u8
                       + juce::String (take.peakDb, 1) + " dBFS" + (take.clipped ? " (SATURATION détectée)"_u8 : juce::String())
                       + ", latences entrée/sortie "_u8 + juce::String (take.inputLatency) + "/" + juce::String (take.outputLatency) + " échantillons"_u8);
    return take;
}

bool AudioEngine::startCalibration (juce::String& error)
{
    if (recording.load() || devices.getCurrentAudioDevice() == nullptr)
    {
        error = "Calibrage impossible (enregistrement en cours ou pas de carte son)";
        return false;
    }
    const double sr = currentSampleRate.load();
    playing.store (false);
    calibBuffer.assign (static_cast<size_t> (sr * 3.2), 0.0f);
    calibClickTimes.clear();
    for (int k = 1; k <= 5; ++k)
        calibClickTimes.push_back (static_cast<long> (k * 0.5 * sr));
    calibPos.store (0);
    calibrating.store (true);
    SV_LOG_INFO (kMod, "Calibrage de latence démarré"_u8);
    return true;
}

int AudioEngine::finishCalibration (juce::String& report)
{
    calibrating.store (false);
    const double sr = currentSampleRate.load();
    if (calibBuffer.empty())
    {
        report = "Pas de données de calibrage"_u8;
        return -1;
    }
    // Bruit de fond : début du tampon, avant le premier clic.
    double noise = 0.0;
    const size_t noiseLen = static_cast<size_t> (0.4 * sr);
    for (size_t i = 0; i < noiseLen && i < calibBuffer.size(); ++i)
        noise += calibBuffer[i] * calibBuffer[i];
    noise = std::sqrt (noise / std::max<size_t> (1, noiseLen));
    float pk = 0.0f;
    for (float v : calibBuffer)
        pk = std::max (pk, std::abs (v));
    const float threshold = std::max (static_cast<float> (noise * 6.0), pk * 0.25f);

    std::vector<long> offsets;
    for (long c : calibClickTimes)
    {
        const long end = std::min (static_cast<long> (calibBuffer.size()), c + static_cast<long> (0.4 * sr));
        for (long i = c; i < end; ++i)
            if (std::abs (calibBuffer[static_cast<size_t> (i)]) > threshold)
            {
                offsets.push_back (i - c);
                break;
            }
    }

    if (offsets.size() < 3 || pk < 0.01f)
    {
        report = "Clics non captés par le micro ("_u8 + juce::String ((int) offsets.size()) + "/5). Approche le casque du micro, monte le volume et recommence."_u8;
        SV_LOG_WARN (kMod, report);
        return -1;
    }
    std::sort (offsets.begin(), offsets.end());
    const long median = offsets[offsets.size() / 2];
    const long spread = offsets.back() - offsets.front();
    report = "Latence aller-retour mesurée : "_u8 + juce::String (median * 1000.0 / sr, 1) + " ms (" + juce::String ((int) offsets.size())
           + "/5 clics, écart "_u8 + juce::String (spread * 1000.0 / sr, 1) + " ms ; annoncée par le pilote : "_u8
           + juce::String ((inputLatency() + outputLatency()) * 1000.0 / sr, 1) + " ms)";
    SV_LOG_INFO (kMod, report);
    return static_cast<int> (median);
}

void AudioEngine::renderClicks (float* const* out, int numOutputChannels, int numSamples, long blockStart, bool countdownOnly)
{
    const double sr = currentSampleRate.load();
    const double period = sr * 60.0 / bpm.load();
    const double first = firstBeat.load() * sr;
    const long recStart = recordStartPos.load();
    const int clickLen = static_cast<int> (0.03 * sr);

    double nextBeat = first + std::ceil ((blockStart - first) / period) * period;
    for (int i = 0; i < numSamples; ++i)
    {
        const long t = blockStart + i;
        if (static_cast<double> (t) >= nextBeat)
        {
            const bool allowed = ! countdownOnly || t < recStart;
            if (allowed)
            {
                const long beatIndex = static_cast<long> (std::llround ((nextBeat - first) / period));
                clickFreq = (beatIndex % 4 == 0) ? 2000.0 : 1500.0;
                clickRemaining = clickLen;
                clickPhase = 0.0;
            }
            nextBeat += period;
        }
        if (clickRemaining > 0)
        {
            const float env = static_cast<float> (clickRemaining) / static_cast<float> (clickLen);
            const float v = 0.25f * env * env * static_cast<float> (std::sin (clickPhase));
            clickPhase += 2.0 * juce::MathConstants<double>::pi * clickFreq / sr;
            --clickRemaining;
            for (int c = 0; c < std::min (2, numOutputChannels); ++c)
                if (out[c] != nullptr)
                    out[c][i] += v;
        }
    }
}

void AudioEngine::audioDeviceIOCallbackWithContext (const float* const* in, int numIn, float* const* out, int numOut,
                                                    int numSamples, const juce::AudioIODeviceCallbackContext&)
{
    for (int c = 0; c < numOut; ++c)
        if (out[c] != nullptr)
            juce::FloatVectorOperations::clear (out[c], numSamples);

    // Entrée mono (moyenne ou canal choisi) avec ajustement de gain.
    const int n = std::min (numSamples, static_cast<int> (inputScratch.size()));
    float* mono = inputScratch.data();
    juce::FloatVectorOperations::clear (mono, n);
    const int mode = inputMode.load();
    if (mode == 1 && numIn >= 1 && in[0] != nullptr)
        juce::FloatVectorOperations::copy (mono, in[0], n);
    else if (mode == 2 && numIn >= 2 && in[1] != nullptr)
        juce::FloatVectorOperations::copy (mono, in[1], n);
    else
    {
        int active = 0;
        for (int c = 0; c < numIn; ++c)
            if (in[c] != nullptr)
            {
                juce::FloatVectorOperations::add (mono, in[c], n);
                ++active;
            }
        if (active > 1)
            juce::FloatVectorOperations::multiply (mono, 1.0f / static_cast<float> (active), n);
    }
    juce::FloatVectorOperations::multiply (mono, inputTrim.load(), n);

    float peak = 0.0f;
    for (int i = 0; i < n; ++i)
        peak = std::max (peak, std::abs (mono[i]));
    if (peak > inPeak.load())
        inPeak.store (peak);
    if (peak > heldPeak.load())
        heldPeak.store (peak);
    if (peak >= 0.98f)
        clipFlag.store (true);

    // Calibrage : clics + capture.
    if (calibrating.load())
    {
        const double sr = currentSampleRate.load();
        const int clickLen = static_cast<int> (0.01 * sr);
        long p = calibPos.load();
        for (int i = 0; i < n && p < static_cast<long> (calibBuffer.size()); ++i, ++p)
        {
            calibBuffer[static_cast<size_t> (p)] = mono[i];
            for (long c : calibClickTimes)
                if (p >= c && p < c + clickLen)
                {
                    const float v = 0.7f * static_cast<float> (std::sin (2.0 * juce::MathConstants<double>::pi * 1000.0 * (p - c) / sr));
                    for (int ch = 0; ch < std::min (2, numOut); ++ch)
                        if (out[ch] != nullptr)
                            out[ch][i] += v;
                }
        }
        calibPos.store (p);
        if (p >= static_cast<long> (calibBuffer.size()))
            calibrating.store (false);
        return;
    }

    if (playing.load())
    {
        long pos = position.load();
        const bool isRec = recording.load();
        int done = 0;
        while (done < numSamples)
        {
            int chunk = numSamples - done;
            const bool looping = loopOn.load() && ! isRec;
            if (looping && pos + chunk > loopEnd.load())
                chunk = static_cast<int> (std::max (1L, loopEnd.load() - pos));

            {
                const juce::SpinLock::ScopedTryLockType tl (stateLock);
                if (tl.isLocked() && state != nullptr)
                {
                    for (const auto& t : state->tracks)
                    {
                        if (t.buffer == nullptr)
                            continue;
                        const long len = t.buffer->getNumSamples();
                        const long a = std::max (pos, t.start);
                        const long b = std::min (pos + chunk, t.start + len);
                        if (b <= a)
                            continue;
                        const int srcOff = static_cast<int> (a - t.start);
                        const int dstOff = done + static_cast<int> (a - pos);
                        const int cnt = static_cast<int> (b - a);
                        if (numOut > 0 && out[0] != nullptr)
                            juce::FloatVectorOperations::addWithMultiply (out[0] + dstOff, t.buffer->getReadPointer (0) + srcOff, t.gainL, cnt);
                        if (numOut > 1 && out[1] != nullptr)
                            juce::FloatVectorOperations::addWithMultiply (out[1] + dstOff, t.buffer->getReadPointer (1) + srcOff, t.gainR, cnt);
                    }
                }
            }

            float* shifted[2] = { numOut > 0 && out[0] != nullptr ? out[0] + done : nullptr,
                                  numOut > 1 && out[1] != nullptr ? out[1] + done : nullptr };
            if (metronomeOn.load() || isRec)
                renderClicks (shifted, std::min (2, numOut), chunk, pos, ! metronomeOn.load());

            pos += chunk;
            done += chunk;
            if (looping && pos >= loopEnd.load())
                pos = loopStart.load();
        }

        // Écriture de la prise (uniquement à partir du point de départ, après le compte à rebours).
        if (isRec)
        {
            const long blockStart = pos - numSamples;   // pas de boucle pendant l'enregistrement
            const long recStart = recordStartPos.load();
            const int offset = static_cast<int> (juce::jlimit (0L, static_cast<long> (n), recStart - blockStart));
            const int count = n - offset;
            if (count > 0)
            {
                const juce::ScopedLock sl (writerLock);
                if (writer != nullptr)
                {
                    const float* chans[1] = { mono + offset };
                    if (! writer->write (chans, count))
                        writeOverflow.store (true);
                    if (firstWritten.load() < 0)
                        firstWritten.store (blockStart + offset);
                    writtenSamples.store (writtenSamples.load() + count);
                    if (peak > recPeak.load())
                        recPeak.store (peak);
                    if (peak >= 0.98f)
                        recClipped.store (true);
                }
            }
        }
        position.store (pos);
    }

    // Écoute logicielle (désactivée par défaut : retour direct par le micro).
    if (monitorOn.load())
    {
        const float g = monitorGain.load();
        for (int c = 0; c < std::min (2, numOut); ++c)
            if (out[c] != nullptr)
                juce::FloatVectorOperations::addWithMultiply (out[c], mono, g, n);
    }

    if (numOut > 0 && out[0] != nullptr)
    {
        const float pl = juce::FloatVectorOperations::findMaximum (out[0], numSamples);
        const float ml = -juce::FloatVectorOperations::findMinimum (out[0], numSamples);
        if (std::max (pl, ml) > outPeakL.load())
            outPeakL.store (std::max (pl, ml));
    }
    if (numOut > 1 && out[1] != nullptr)
    {
        const float pr = juce::FloatVectorOperations::findMaximum (out[1], numSamples);
        const float mr = -juce::FloatVectorOperations::findMinimum (out[1], numSamples);
        if (std::max (pr, mr) > outPeakR.load())
            outPeakR.store (std::max (pr, mr));
    }
}

void AudioEngine::audioDeviceAboutToStart (juce::AudioIODevice* device)
{
    currentSampleRate.store (device->getCurrentSampleRate());
    inputScratch.assign (static_cast<size_t> (std::max (16384, device->getCurrentBufferSizeSamples() * 4)), 0.0f);
    SV_LOG_INFO (kMod, "Carte son démarrée : "_u8 + device->getName() + ", " + juce::String (device->getCurrentSampleRate(), 0)
                       + " Hz, tampon " + juce::String (device->getCurrentBufferSizeSamples()));
    if (std::abs (device->getCurrentSampleRate() - kProjectSampleRate) > 1.0)
        SV_LOG_WARN (kMod, "La carte son tourne à "_u8 + juce::String (device->getCurrentSampleRate(), 0)
                           + " Hz (projet à 48000 Hz) : régler la carte sur 48 kHz pour éviter un décalage de hauteur."_u8);
}

void AudioEngine::audioDeviceStopped()
{
    juce::MessageManager::callAsync ([] { SV_LOG_INFO (kMod, "Carte son arrêtée"_u8); });
}

void AudioEngine::audioDeviceError (const juce::String& errorMessage)
{
    juce::MessageManager::callAsync ([errorMessage] { SV_LOG_ERROR (kMod, "Erreur carte son : "_u8 + errorMessage); });
}
} // namespace sv::app
