#include "AudioIO.h"

#include "Log.h"

#include <numeric>

namespace sv::audio
{
namespace
{
    constexpr const char* kMod = "AudioIO";

    juce::AudioFormatManager& formatManager()
    {
        static juce::AudioFormatManager manager;
        static const bool registered = [] { manager.registerBasicFormats(); return true; }();
        juce::ignoreUnused (registered);
        return manager;
    }

    // Rééchantillonnage sinc fenêtré (Blackman), 24 points de chaque côté.
    // Le noyau est tabulé (512 pas par échantillon) pour éviter sin/cos dans la boucle.
    void resampleChannel (const float* in, int inLen, float* out, int outLen, double ratio /* from/to */)
    {
        constexpr int halfTaps = 24;
        constexpr int resolution = 512;
        const double cutoff = ratio > 1.0 ? 1.0 / ratio : 1.0;   // anti-repliement en sous-échantillonnage
        const double pi = juce::MathConstants<double>::pi;

        const int tableSize = 2 * halfTaps * resolution + 2;
        std::vector<float> table (static_cast<size_t> (tableSize));
        for (int i = 0; i < tableSize; ++i)
        {
            const double x = static_cast<double> (i) / resolution - halfTaps;   // [-halfTaps, halfTaps]
            const double xc = x * cutoff;
            const double sinc = std::abs (xc) < 1.0e-9 ? 1.0 : std::sin (pi * xc) / (pi * xc);
            const double wpos = (x + halfTaps) / (2.0 * halfTaps);
            const double w = (wpos <= 0.0 || wpos >= 1.0)
                               ? 0.0
                               : 0.42 - 0.5 * std::cos (2.0 * pi * wpos) + 0.08 * std::cos (4.0 * pi * wpos);
            table[static_cast<size_t> (i)] = static_cast<float> (sinc * w * cutoff);
        }

        for (int n = 0; n < outLen; ++n)
        {
            const double t = n * ratio;
            const int centre = static_cast<int> (std::floor (t));
            double acc = 0.0, wsum = 0.0;

            for (int k = centre - halfTaps + 1; k <= centre + halfTaps; ++k)
            {
                const double pos = (t - k + halfTaps) * resolution;
                const int idx = static_cast<int> (pos);
                if (idx < 0 || idx >= tableSize - 1)
                    continue;
                const double frac = pos - idx;
                const double coeff = table[static_cast<size_t> (idx)] * (1.0 - frac)
                                   + table[static_cast<size_t> (idx + 1)] * frac;
                wsum += coeff;
                if (k >= 0 && k < inLen)
                    acc += coeff * in[k];
            }

            out[n] = static_cast<float> (wsum > 1.0e-9 ? acc / wsum : acc);
        }
    }

    // Rapport rationnel (44,1 -> 48 kHz = 160/147, 48 -> 16 kHz = 1/3…) : même noyau, mais coefficients
    // précalculés et normalisés pour chacune des L phases ; chaque échantillon devient un produit scalaire
    // de 48 points (au lieu de 48 interpolations de table). Retourne false si le rapport ne s'y prête pas.
    bool resamplePolyphase (const float* in, int inLen, float* out, int outLen, double fromSr, double toSr)
    {
        const double fr = std::round (fromSr), tr = std::round (toSr);
        if (std::abs (fr - fromSr) > 1.0e-9 || std::abs (tr - toSr) > 1.0e-9 || fr < 1.0 || tr < 1.0)
            return false;
        const long long g = std::gcd (static_cast<long long> (fr), static_cast<long long> (tr));
        const long long L = static_cast<long long> (tr) / g, M = static_cast<long long> (fr) / g;   // sortie n <-> entrée n*M/L
        if (L > 2048)
            return false;

        constexpr int halfTaps = 24, taps = 2 * halfTaps;
        const double ratio = fromSr / toSr;
        const double cutoff = ratio > 1.0 ? 1.0 / ratio : 1.0;
        const double pi = juce::MathConstants<double>::pi;
        std::vector<float> coeffs (static_cast<size_t> (L) * taps);
        for (long long ph = 0; ph < L; ++ph)
        {
            const double frac = static_cast<double> (ph) / static_cast<double> (L);
            float* c = coeffs.data() + static_cast<size_t> (ph) * taps;
            double sum = 0.0;
            std::array<double, taps> v {};
            for (int j = 0; j < taps; ++j)
            {
                const double x = frac + halfTaps - 1 - j;   // t - k, avec k = centre - halfTaps + 1 + j
                const double xc = x * cutoff;
                const double sinc = std::abs (xc) < 1.0e-9 ? 1.0 : std::sin (pi * xc) / (pi * xc);
                const double wpos = (x + halfTaps) / (2.0 * halfTaps);
                const double w = (wpos <= 0.0 || wpos >= 1.0) ? 0.0
                                                              : 0.42 - 0.5 * std::cos (2.0 * pi * wpos) + 0.08 * std::cos (4.0 * pi * wpos);
                v[static_cast<size_t> (j)] = sinc * w * cutoff;
                sum += v[static_cast<size_t> (j)];
            }
            for (int j = 0; j < taps; ++j)
                c[j] = static_cast<float> (sum > 1.0e-9 ? v[static_cast<size_t> (j)] / sum : v[static_cast<size_t> (j)]);
        }

        for (int n = 0; n < outLen; ++n)
        {
            const long long pos = static_cast<long long> (n) * M;
            const int centre = static_cast<int> (pos / L);
            const float* c = coeffs.data() + static_cast<size_t> (pos % L) * taps;
            const int k0 = centre - halfTaps + 1;
            float s = 0.0f;
            if (k0 >= 0 && k0 + taps <= inLen)
            {
                const float* x = in + k0;
                float a0 = 0.0f, a1 = 0.0f, a2 = 0.0f, a3 = 0.0f;
                for (int j = 0; j < taps; j += 4)
                {
                    a0 += c[j] * x[j];
                    a1 += c[j + 1] * x[j + 1];
                    a2 += c[j + 2] * x[j + 2];
                    a3 += c[j + 3] * x[j + 3];
                }
                s = (a0 + a1) + (a2 + a3);
            }
            else
            {
                for (int j = 0; j < taps; ++j)
                    if (const int k = k0 + j; k >= 0 && k < inLen)
                        s += c[j] * in[k];
            }
            out[n] = s;
        }
        return true;
    }
}

juce::String safeFileName (const juce::String& name, const juce::String& fallback)
{
    juce::String control;
    for (juce::juce_wchar c = 1; c < 32; ++c)
        control += juce::String::charToString (c);
    auto s = juce::File::createLegalFileName (name).removeCharacters (control).trim();
    while (s.endsWithChar ('.') || s.endsWithChar (' '))
        s = s.dropLastCharacters (1);
    if (s.isEmpty())
        s = fallback;
    const auto base = s.upToFirstOccurrenceOf (".", false, false).trim().toUpperCase();
    static const juce::StringArray reserved { "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
                                              "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9" };
    if (reserved.contains (base))
        s = "_" + s;
    return s;
}

juce::String extensionFor (FileFormat format)
{
    switch (format)
    {
        case FileFormat::Wav24:
        case FileFormat::Wav32Float: return ".wav";
        case FileFormat::Flac24:     return ".flac";
        case FileFormat::Mp3_320:    return ".mp3";
    }
    return ".wav";
}

float peak (const float* data, size_t n)
{
    float p = 0.0f;
    for (size_t i = 0; i < n; ++i)
        p = std::max (p, std::abs (data[i]));
    return p;
}

float rms (const float* data, size_t n)
{
    if (n == 0)
        return 0.0f;
    double acc = 0.0;
    for (size_t i = 0; i < n; ++i)
        acc += static_cast<double> (data[i]) * data[i];
    return static_cast<float> (std::sqrt (acc / static_cast<double> (n)));
}

bool hasNonFinite (const float* data, size_t n)
{
    for (size_t i = 0; i < n; ++i)
        if (! std::isfinite (data[i]))
            return true;
    return false;
}

size_t sanitize (float* data, size_t n)
{
    size_t fixed = 0;
    for (size_t i = 0; i < n; ++i)
    {
        if (! std::isfinite (data[i]))
        {
            data[i] = 0.0f;
            ++fixed;
        }
    }
    return fixed;
}

void applyFade (float* data, size_t size, size_t start, size_t len, bool fadeIn)
{
    if (len == 0 || start >= size)
        return;
    len = std::min (len, size - start);
    for (size_t i = 0; i < len; ++i)
    {
        const float g = static_cast<float> (i) / static_cast<float> (len);
        data[start + i] *= fadeIn ? g : (1.0f - g);
    }
}

Mono toMono (const Stereo& buffer)
{
    const int n = buffer.getNumSamples();
    Mono out (static_cast<size_t> (std::max (0, n)), 0.0f);
    const int ch = buffer.getNumChannels();
    if (ch == 0)
        return out;
    for (int c = 0; c < ch; ++c)
    {
        const float* src = buffer.getReadPointer (c);
        for (int i = 0; i < n; ++i)
            out[static_cast<size_t> (i)] += src[i];
    }
    const float scale = 1.0f / static_cast<float> (ch);
    for (auto& v : out)
        v *= scale;
    return out;
}

Stereo monoToStereo (const Mono& mono)
{
    Stereo s (2, static_cast<int> (mono.size()));
    for (int c = 0; c < 2; ++c)
        std::copy (mono.begin(), mono.end(), s.getWritePointer (c));
    return s;
}

Mono resample (const Mono& in, double fromSr, double toSr)
{
    if (in.empty() || fromSr <= 0.0 || toSr <= 0.0 || std::abs (fromSr - toSr) < 1.0e-6)
        return in;
    const double ratio = fromSr / toSr;
    const int outLen = static_cast<int> (std::floor (static_cast<double> (in.size()) / ratio));
    Mono out (static_cast<size_t> (std::max (0, outLen)));
    if (! resamplePolyphase (in.data(), static_cast<int> (in.size()), out.data(), outLen, fromSr, toSr))
        resampleChannel (in.data(), static_cast<int> (in.size()), out.data(), outLen, ratio);
    return out;
}

Stereo resample (const Stereo& in, double fromSr, double toSr)
{
    if (in.getNumSamples() == 0 || fromSr <= 0.0 || toSr <= 0.0 || std::abs (fromSr - toSr) < 1.0e-6)
        return Stereo (in);
    const double ratio = fromSr / toSr;
    const int outLen = static_cast<int> (std::floor (in.getNumSamples() / ratio));
    Stereo out (in.getNumChannels(), std::max (0, outLen));
    for (int c = 0; c < in.getNumChannels(); ++c)
        if (! resamplePolyphase (in.getReadPointer (c), in.getNumSamples(), out.getWritePointer (c), outLen, fromSr, toSr))
            resampleChannel (in.getReadPointer (c), in.getNumSamples(), out.getWritePointer (c), outLen, ratio);
    return out;
}

LoadResult loadStereo (const juce::File& file, double targetSampleRate, double maxSeconds)
{
    LoadResult result;
    log::ScopedTimer timer (kMod, "chargement " + file.getFileName());

    if (! file.existsAsFile())
    {
        result.error = "Fichier introuvable : " + file.getFullPathName();
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    constexpr juce::int64 maxBytes = (juce::int64) 2 * 1024 * 1024 * 1024;
    if (file.getSize() <= 0 || file.getSize() > maxBytes)
    {
        result.error = "Taille de fichier invalide (" + juce::String (file.getSize()) + " octets) : " + file.getFileName();
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    std::unique_ptr<juce::AudioFormatReader> reader (formatManager().createReaderFor (file));
    if (reader == nullptr)
    {
        result.error = "Format audio non reconnu : " + file.getFileName();
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    const auto sr = reader->sampleRate;
    const auto length = reader->lengthInSamples;
    const int channels = static_cast<int> (reader->numChannels);

    if (sr < 8000.0 || sr > 384000.0 || length <= 0 || channels <= 0)
    {
        result.error = "Paramètres audio invalides (taux "_u8 + juce::String (sr) + ", longueur "
                     + juce::String (length) + ", canaux " + juce::String (channels) + ")";
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    if (static_cast<double> (length) / sr > maxSeconds)
    {
        result.error = "Fichier trop long (" + juce::String (static_cast<double> (length) / sr, 1)
                     + " s, max " + juce::String (maxSeconds, 0) + " s)";
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    const int n = static_cast<int> (length);
    juce::AudioBuffer<float> raw (channels, n);
    if (! reader->read (&raw, 0, n, 0, true, true))
    {
        result.error = "Lecture impossible : " + file.getFileName();
        SV_LOG_ERROR (kMod, result.error);
        return result;
    }

    // Conversion en stéréo : mono dupliqué ; >2 canaux : gauche/droite + autres canaux au centre
    // (5.1 dans l'ordre WAV L R C LFE Ls Rs : caisson ignoré, surrounds sur leur côté).
    Stereo stereo;
    if (channels == 2)
    {
        stereo = std::move (raw);   // pas de copie
    }
    else if (channels == 1)
    {
        stereo.setSize (2, n);
        stereo.copyFrom (0, 0, raw, 0, 0, n);
        stereo.copyFrom (1, 0, raw, 0, 0, n);
    }
    else
    {
        stereo.setSize (2, n);
        stereo.clear();
        constexpr float side = 0.7071f;
        const float norm = 1.0f / (1.0f + side * static_cast<float> (channels - 2));
        stereo.addFrom (0, 0, raw, 0, 0, n, norm);
        stereo.addFrom (1, 0, raw, 1, 0, n, norm);
        for (int c = 2; c < channels; ++c)
        {
            if (channels == 6 && c == 3)
                continue;
            if (channels == 6 && (c == 4 || c == 5))
            {
                stereo.addFrom (c - 4, 0, raw, c, 0, n, side * norm);
                continue;
            }
            stereo.addFrom (0, 0, raw, c, 0, n, side * norm);
            stereo.addFrom (1, 0, raw, c, 0, n, side * norm);
        }
        SV_LOG_WARN (kMod, juce::String (channels) + " canaux mixés en stéréo"_u8);
    }

    for (int c = 0; c < 2; ++c)
    {
        const auto fixed = sanitize (stereo.getWritePointer (c), static_cast<size_t> (n));
        if (fixed > 0)
            SV_LOG_WARN (kMod, juce::String ((int) fixed) + " valeurs non finies corrigées (canal "_u8 + juce::String (c) + ")");
    }

    result.originalSampleRate = sr;
    result.originalChannels = channels;
    result.sampleRate = targetSampleRate;
    result.buffer = std::abs (sr - targetSampleRate) < 1.0e-6 ? std::move (stereo) : resample (stereo, sr, targetSampleRate);

    SV_LOG_INFO (kMod, "Chargé "_u8 + file.getFileName() + " : " + juce::String (channels) + " canal(aux), "
                       + juce::String (sr, 0) + " Hz -> " + juce::String (targetSampleRate, 0) + " Hz, "
                       + juce::String (result.buffer.getNumSamples() / targetSampleRate, 2) + " s");
    return result;
}

bool loadMono (const juce::File& file, double targetSampleRate, Mono& out, juce::String& error, double maxSeconds)
{
    auto res = loadStereo (file, targetSampleRate, maxSeconds);
    if (! res.ok())
    {
        error = res.error;
        return false;
    }
    out = toMono (res.buffer);
    return true;
}

juce::File findLameExecutable()
{
   #if JUCE_WINDOWS
    const juce::String exeName ("lame.exe");
    const juce::String separator (";");
   #else
    const juce::String exeName ("lame");
    const juce::String separator (":");
   #endif

    const auto sibling = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getSiblingFile (exeName);
    if (sibling.existsAsFile())
        return sibling;

    juce::StringArray paths;
    paths.addTokens (juce::SystemStats::getEnvironmentVariable ("PATH", {}), separator, "\"");
    for (const auto& p : paths)
    {
        if (p.trim().isEmpty())
            continue;
        const juce::File candidate = juce::File (p.trim()).getChildFile (exeName);
        if (candidate.existsAsFile())
            return candidate;
    }
    return {};
}

bool writeFile (const juce::File& file, const Stereo& buffer, double sampleRate, FileFormat format, juce::String& error)
{
    log::ScopedTimer timer (kMod, "écriture "_u8 + file.getFileName());

    if (buffer.getNumSamples() <= 0)
    {
        error = "Rien à écrire (tampon vide)"_u8;
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    const auto dir = file.getParentDirectory().createDirectory();
    if (dir.failed())
    {
        error = "Dossier impossible à créer : "_u8 + dir.getErrorMessage();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    std::unique_ptr<juce::AudioFormat> audioFormat;
    auto options = juce::AudioFormatWriterOptions{}
                       .withSampleRate (sampleRate)
                       .withNumChannels (buffer.getNumChannels());

    switch (format)
    {
        case FileFormat::Wav24:
            audioFormat = std::make_unique<juce::WavAudioFormat>();
            options = options.withBitsPerSample (24);
            break;
        case FileFormat::Wav32Float:
            audioFormat = std::make_unique<juce::WavAudioFormat>();
            options = options.withBitsPerSample (32).withSampleFormat (juce::AudioFormatWriterOptions::SampleFormat::floatingPoint);
            break;
        case FileFormat::Flac24:
            audioFormat = std::make_unique<juce::FlacAudioFormat>();
            options = options.withBitsPerSample (24);
            break;
        case FileFormat::Mp3_320:
        {
            const auto lame = findLameExecutable();
            if (! lame.existsAsFile())
            {
                error = "Export MP3 impossible : lame.exe introuvable (le placer à côté de StudioVoix.exe). "_u8
                        "Exporte en WAV ou FLAC en attendant.";
                SV_LOG_ERROR (kMod, error);
                return false;
            }
            audioFormat = std::make_unique<juce::LAMEEncoderAudioFormat> (lame);
            options = options.withBitsPerSample (16);
            const auto qualities = audioFormat->getQualityOptions();
            const int idx = qualities.indexOf ("320 Kb/s CBR");   // nom donné par JUCE
            options = options.withQualityOptionIndex (idx >= 0 ? idx : juce::jmax (0, qualities.size() - 1));
            break;
        }
    }

    // Écriture dans un fichier temporaire du même dossier : un fichier existant n'est remplacé
    // qu'une fois le nouveau écrit et vérifié.
    juce::TemporaryFile tmp (file);
    std::unique_ptr<juce::OutputStream> stream = std::make_unique<juce::FileOutputStream> (tmp.getFile());
    if (static_cast<juce::FileOutputStream*> (stream.get())->failedToOpen())
    {
        error = "Ouverture en écriture impossible : "_u8 + tmp.getFile().getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    auto writer = audioFormat->createWriterFor (stream, options);
    if (writer == nullptr)
    {
        error = "Création de l'encodeur impossible pour "_u8 + file.getFileName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    if (! writer->writeFromAudioSampleBuffer (buffer, 0, buffer.getNumSamples()))
    {
        error = "Échec d'écriture des échantillons : "_u8 + file.getFileName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }

    writer.reset();   // ferme le fichier ; pour le MP3, l'encodage par lame.exe a lieu ici (échec non remonté par JUCE)

    // Vérification : fichier non vide, relisible et complet (le MP3 ajoute un peu de remplissage).
    const auto bytes = tmp.getFile().getSize();
    long readable = -1;
    if (std::unique_ptr<juce::AudioFormatReader> check (formatManager().createReaderFor (tmp.getFile())); check != nullptr)
        readable = static_cast<long> (check->lengthInSamples);
    const long expected = buffer.getNumSamples();
    if (bytes <= 0 || readable < static_cast<long> (static_cast<double> (expected) * 0.98))
    {
        error = "Fichier écrit incomplet ou illisible ("_u8 + juce::String (bytes) + " octets, " + juce::String (readable) + "/"
                + juce::String (expected) + " échantillons)"_u8 + (format == FileFormat::Mp3_320 ? " : échec de lame.exe ?"_u8 : juce::String())
                + " — "_u8 + file.getFileName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    if (! tmp.overwriteTargetFileWithTemporary())
    {
        error = "Impossible de remplacer " + file.getFullPathName();
        SV_LOG_ERROR (kMod, error);
        return false;
    }
    SV_LOG_INFO (kMod, "Écrit "_u8 + file.getFullPathName() + " (" + juce::String (buffer.getNumSamples() / sampleRate, 2) + " s, "
                       + juce::String (bytes / 1024) + " Ko, relu et vérifié)"_u8);
    return true;
}

bool writeMonoWavFloat (const juce::File& file, const Mono& data, double sampleRate, juce::String& error)
{
    Stereo mono (1, static_cast<int> (data.size()));
    std::copy (data.begin(), data.end(), mono.getWritePointer (0));
    return writeFile (file, mono, sampleRate, FileFormat::Wav32Float, error);
}

double envelopeLagMs (const Mono& a, const Mono& b, double sr, int maxMs)
{
    const int n = static_cast<int> (std::min (a.size(), b.size()));
    const int hop = std::max (1, static_cast<int> (sr * 0.001)), win = std::max (hop, static_cast<int> (sr * 0.005));
    const int frames = n / hop;
    if (frames < 2 * maxMs + 10)
        return 0.0;
    std::vector<float> ea (static_cast<size_t> (frames)), eb (static_cast<size_t> (frames));
    double ma = 0.0, mb = 0.0;
    for (int f = 0; f < frames; ++f)
    {
        const int s = f * hop, e = std::min (n, s + win);
        ea[static_cast<size_t> (f)] = std::max (-60.0f, gainToDb (rms (a.data() + s, static_cast<size_t> (e - s))));
        eb[static_cast<size_t> (f)] = std::max (-60.0f, gainToDb (rms (b.data() + s, static_cast<size_t> (e - s))));
        ma += ea[static_cast<size_t> (f)];
        mb += eb[static_cast<size_t> (f)];
    }
    ma /= frames;
    mb /= frames;
    double best = -1.0e300;
    int bestLag = 0;
    for (int lag = -maxMs; lag <= maxMs; ++lag)
    {
        double sum = 0.0;
        int c = 0;
        for (int f = std::max (0, -lag); f < frames && f + lag < frames; ++f)
        {
            sum += (ea[static_cast<size_t> (f)] - ma) * (eb[static_cast<size_t> (f + lag)] - mb);
            ++c;
        }
        if (c > 0 && sum / c > best)
        {
            best = sum / c;
            bestLag = lag;
        }
    }
    return static_cast<double> (bestLag);
}
} // namespace sv::audio
