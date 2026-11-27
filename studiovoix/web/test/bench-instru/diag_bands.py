# Diagnostic : où est l'erreur de la ligne de base, par bandes fines ; et d'où vient le chiffre « aigus seuls » du
# produit (erreur pondérée par la dérivée seconde).   python -I diag_bands.py <items> <out> extrait…
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
setup_log()
ITEMS, OUT = sys.argv[1:3]
edges = [0, 250, 2000, 6000, 8000, 10000, 12000, 14000, 16000, 17640, 22051]
for iid in sys.argv[3:]:
    it = Item(os.path.join(ITEMS, iid))
    e = it.song - 1.021 * read_f32(os.path.join(OUT, f'{iid}.voc.f32'))[:it.n] - it.I
    f = np.fft.rfftfreq(it.n, 1 / SR)
    w2 = (2 - 2 * np.cos(2 * np.pi * f / SR)) ** 2            # |H|² de la dérivée seconde
    P = lambda x: (np.abs(np.fft.rfft(x, axis=0)) ** 2).sum(axis=1) / it.n   # énergie par raie (Parseval, à un facteur près)
    Pe, Pi, Pv = P(e), P(it.I), P(it.V)
    tot_e2, tot_i2 = (Pe * w2).sum(), (Pi * w2).sum()
    log.info(f'{iid} : SDR {db(Pi.sum() / Pe.sum()):.2f} dB ; aigus seuls {db(tot_i2 / tot_e2):.2f} dB')
    scale = 2 / (it.n * 2)                                     # → énergie moyenne par échantillon et par canal
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (f >= lo) & (f < hi)
        log.info(f'  {lo:5d}-{hi:5d} Hz : instru vraie {db(Pi[m].sum() * scale):6.1f} dBFS, voix vraie {db(Pv[m].sum() * scale):6.1f}, erreur {db(Pe[m].sum() * scale):6.1f} ; '
                 f'SDR {db(Pi[m].sum() / Pe[m].sum()):6.1f} dB ; part de l\'erreur « aigus seuls » {100 * (Pe[m] * w2[m]).sum() / tot_e2:5.1f} % ; part de la référence « aigus seuls » {100 * (Pi[m] * w2[m]).sum() / tot_i2:5.1f} %')
