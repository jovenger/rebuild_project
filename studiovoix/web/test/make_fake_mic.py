#!/usr/bin/env python3
"""Fabrique les fichiers de l'essai « prise au micro sans casque » (bibliothèque standard seulement).

    python3 web/test/make_fake_mic.py <dossier>

- instru.wav : instru synthétique 20 s (accords + basse + batterie), 48 kHz stéréo 16 bits ;
- mic.wav    : ce qu'entendrait le micro : une voix synthétique (phrases chantées) + l'instru sortie des haut-parleurs,
               captée 300 ms plus tard, assombrie et 12 dB plus bas. Joué par le faux micro de Chromium
               (--use-file-for-fake-audio-capture), il permet de vérifier que la page retire la musique de la prise.
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


def main():
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    folder.mkdir(parents=True, exist_ok=True)
    ins = instru()
    write_wav(folder / "instru.wav", [ins, ins])
    n = len(ins) + int(0.5 * SR)
    lag = int(0.300 * SR)
    g = 10 ** (-12 / 20)
    v = voice(n)
    mic = [0.0] * n
    lp = 0.0
    for i in range(n):
        j = i - lag
        lp += 0.35 * ((ins[j] if 0 <= j < len(ins) else 0.0) - lp)
        mic[i] = v[i] + g * lp
    write_wav(folder / "mic.wav", [mic])
    print(f"instru.wav et mic.wav écrits dans {folder} ({SECONDS:.0f} s, musique captée à -12 dB, décalage 300 ms)")


if __name__ == "__main__":
    main()
