# Extraits passés par un MP3 128 kb/s (coupe-haut vers 16 kHz) : bruit que la séparation ajoute dans la bande que le MP3
# a vidée (16,5–17,6 kHz), et erreur de la voix estimée sous 15 kHz, contre les mêmes extraits non compressés.
#   python -I diag_mp3.py
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
setup_log()
B = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def band_db(x, lo, hi):
    X = np.fft.rfft(x, axis=0); f = np.fft.rfftfreq(len(x), 1 / SR); m = (f >= lo) & (f < hi)
    return db((np.abs(X[m]) ** 2).sum() * 2 / (len(x) ** 2) / 2)            # énergie moyenne par échantillon et par canal
def lp(x, hi):
    X = np.fft.rfft(x, axis=0); f = np.fft.rfftfreq(len(x), 1 / SR); return np.fft.irfft(X * (f < hi)[:, None], n=len(x), axis=0)
for d in sorted(os.listdir(B + '/items_mp3')):
    song = read_wav(f'{B}/items_mp3/{d}/song.wav'); V = read_wav(f'{B}/items_mp3/{d}/truth_voc.wav'); n = len(song)
    voc = 1.021 * read_f32(f'{B}/out/{d}.voc.f32')[:n]; sub = read_f32(f'{B}/out/{d}.post_borne_bande.f32')[:n]
    vclean = 1.021 * read_f32(f'{B}/out/{d[2:]}.voc.f32')[:n]
    sdrv = lambda est: db((lp(V, 15000) ** 2).sum() / (lp(est - V, 15000) ** 2).sum())
    log.info(f"{d} : bande 16,5–17,6 kHz — chanson MP3 {band_db(song, 16500, 17640):.1f} dBFS ; instru ligne de base {band_db(song - voc, 16500, 17640):.1f} dBFS ; instru borne par bande {band_db(song - sub, 16500, 17640):.1f} dBFS ; "
             f"voix estimée < 15 kHz : SDR {sdrv(voc):.2f} dB sur MP3 (borne par bande {sdrv(sub):.2f}) contre {sdrv(vclean):.2f} dB sans MP3")
