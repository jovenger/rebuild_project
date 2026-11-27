#!/usr/bin/env python3
"""Fabrique les fichiers de l'essai « prise au micro sans casque » (bibliothèque standard seulement).

    python3 web/test/make_fake_mic.py <dossier> [--voice voix.wav]

- instru.wav : instru synthétique 20 s (accords + basse + batterie), 48 kHz stéréo 16 bits ;
- mic.wav    : ce qu'entendrait le micro : une voix synthétique (phrases chantées) + l'instru sortie des haut-parleurs,
               captée 300 ms plus tard, assombrie et 12 dB plus bas. Joué par le faux micro de Chromium
               (--use-file-for-fake-audio-capture), il permet de vérifier que la page retire la musique de la prise.
Avec --voice (vraie voix, WAV 16 bits mono, par exemple jfk.wav de whisper.cpp, domaine public) :
- la voix synthétique est remplacée par cette vraie voix ;
- une « radio » (autre morceau, inconnu de la page) joue en plus dans la pièce, au niveau de la voix : seule
  l'isolation IA peut la retirer ;
- voice.wav : la voix seule, telle qu'elle est dans mic.wav (référence pour mesurer ce qui reste dans la prise).
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

SR = 48000
SECONDS = 20.0


def write_wav(path, channels):
    n = len(channels[0])
    with wave.open(str(path), "wb") as w:
        w.setnchannels(len(channels))
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for i in range(n):
            for ch in channels:
                frames += struct.pack("<h", max(-32767, min(32767, int(ch[i] * 32767))))
        w.writeframes(bytes(frames))


def instru():
    rnd = random.Random(7)
    n = int(SECONDS * SR)
    out = [0.0] * n
    bpm = 100.0
    beat = 60.0 / bpm
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]  # Am F C G (MIDI)
    hz = lambda m: 440.0 * 2 ** ((m - 69) / 12)
    for i in range(n):
        t = i / SR
        bar = int(t / (4 * beat)) % 4
        c = chords[bar]
        v = sum(0.06 * math.sin(2 * math.pi * hz(m) * t) for m in c)
        v += 0.12 * math.sin(2 * math.pi * hz(c[0] - 24) * t)
        out[i] = v
    for b in range(int(SECONDS / beat)):  # grosse caisse sur chaque temps, caisse claire sur 2 et 4
        s = int(b * beat * SR)
        for k in range(int(0.12 * SR)):
            if s + k < n:
                e = math.exp(-k / (0.03 * SR))
                out[s + k] += 0.35 * e * math.sin(2 * math.pi * (55 + 60 * e) * k / SR)
                if b % 2 == 1:
                    out[s + k] += 0.15 * math.exp(-k / (0.02 * SR)) * (rnd.random() * 2 - 1)
    return out


def voice(n):
    out = [0.0] * n
    notes = [69, 72, 71, 67, 69, 64]
    t0 = 1.0
    while t0 < SECONDS - 1.5:
        for m in notes[: 3 + int(t0) % 3]:
            f0 = 440.0 * 2 ** ((m - 69) / 12)
            dur = 0.45
            s, e = int(t0 * SR), int((t0 + dur) * SR)
            phase = 0.0
            for i in range(s, min(e, n)):
                tt = (i - s) / SR
                env = min(1.0, tt / 0.03) * min(1.0, (dur - tt) / 0.05)
                f = f0 * (1 + 0.006 * math.sin(2 * math.pi * 5.5 * tt))
                phase += 2 * math.pi * f / SR
                out[i] += 0.25 * env * sum(math.sin(h * phase) / h for h in range(1, 8))
            t0 += dur + 0.05
        t0 += 0.8
    return out


def read_voice(path, n):
    """Vraie voix (WAV 16 bits mono) ramenée à 48 kHz (interpolation linéaire), posée à 0,8 s puis répétée."""
    with wave.open(str(path), "rb") as w:
        if w.getsampwidth() != 2 or w.getnchannels() != 1:
            raise SystemExit(f"{path} : WAV 16 bits mono attendu")
        sr = w.getframerate()
        raw = w.readframes(w.getnframes())
    src = [x / 32768.0 for x in struct.unpack("<%dh" % (len(raw) // 2), raw)]
    peak = max(1e-9, max(abs(x) for x in src))
    m = int(len(src) * SR / sr)
    res = []
    for i in range(m):
        p = i * sr / SR
        j = int(p)
        f = p - j
        a = src[j] if j < len(src) else 0.0
        b = src[j + 1] if j + 1 < len(src) else 0.0
        res.append(0.5 * (a + f * (b - a)) / peak)
    out = [0.0] * n
    start = int(0.8 * SR)
    while start < n:
        for i in range(min(m, n - start)):
            out[start + i] += res[i]
        start += m + int(0.7 * SR)
    return out


def radio(n):
    """Autre morceau (Ré mineur, 128 BPM, timbre « cuivré »), absent de la page : la musique extérieure."""
    rnd = random.Random(11)
    out = [0.0] * n
    beat = 60.0 / 128.0
    chords = [(62, 65, 69), (58, 62, 65), (65, 69, 72), (60, 64, 67)]  # Dm Bb F C
    hz = lambda m: 440.0 * 2 ** ((m - 69) / 12)
    for i in range(n):
        t = i / SR
        c = chords[int(t / (2 * beat)) % 4]
        v = 0.0
        for m in c:
            ph = 2 * math.pi * hz(m) * t
            v += 0.05 * sum(math.sin(h * ph) / h for h in (1, 2, 3, 4, 5))
        mel = chords[int(t / (beat / 2)) % 4][int(t / (beat / 2)) % 3] + 12
        v += 0.06 * math.sin(2 * math.pi * hz(mel) * t) * (0.6 + 0.4 * math.sin(2 * math.pi * 3 * t))
        out[i] = v
    for b in range(int(n / SR / (beat / 2))):  # charleston sur chaque croche
        s = int(b * beat / 2 * SR)
        for k in range(int(0.04 * SR)):
            if s + k < n:
                out[s + k] += 0.05 * math.exp(-k / (0.008 * SR)) * (rnd.random() * 2 - 1)
    return out


def rms(x):
    return math.sqrt(sum(v * v for v in x) / max(1, len(x)))


def main():
    args = sys.argv[1:]
    voice_path = None
    no_radio = "--no-radio" in args   # vraie voix + instru captée seulement (cas sans musique extérieure)
    if no_radio:
        args.remove("--no-radio")
    if "--voice" in args:
        k = args.index("--voice")
        voice_path = args[k + 1]
        del args[k:k + 2]
    folder = Path(args[0] if args else ".")
    folder.mkdir(parents=True, exist_ok=True)
    ins = instru()
    write_wav(folder / "instru.wav", [ins, ins])
    n = len(ins) + int(0.5 * SR)
    lag = int(0.300 * SR)
    g = 10 ** (-12 / 20)
    v = read_voice(voice_path, n) if voice_path else voice(n)
    ext = [0.0] * n
    if voice_path:
        write_wav(folder / "voice.wav", [v])
    if voice_path and not no_radio:
        r = radio(n)
        k = rms([x for x in v if abs(x) > 1e-4]) / max(1e-9, rms(r))   # radio au niveau de la voix (quand elle parle)
        ext = [k * x for x in r]
    mic = [0.0] * n
    lp = 0.0
    for i in range(n):
        j = i - lag
        lp += 0.35 * ((ins[j] if 0 <= j < len(ins) else 0.0) - lp)
        mic[i] = v[i] + g * lp + ext[i]
    peak = max(abs(x) for x in mic)
    if peak > 0.99:   # pas d'écrêtage dans le fichier du faux micro
        mic = [x * 0.99 / peak for x in mic]
        if voice_path:
            write_wav(folder / "voice.wav", [x * 0.99 / peak for x in v])
    write_wav(folder / "mic.wav", [mic])
    extra = (" + radio extérieure au niveau de la voix" if not no_radio else " sans radio") + ", voice.wav = référence" if voice_path else ""
    print(f"instru.wav et mic.wav écrits dans {folder} ({SECONDS:.0f} s, musique captée à -12 dB, décalage 300 ms{extra})")


if __name__ == "__main__":
    main()
