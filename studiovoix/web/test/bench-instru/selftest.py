# Vérifie chaque mesure sur des cas fabriqués dont la réponse est connue (instru vraie + défaut dosé).
#   python -I selftest.py <dossier items> [extrait]
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

setup_log()
root = sys.argv[1]; iid = sys.argv[2] if len(sys.argv) > 2 else 't_fem1'
it = Item(os.path.join(root, iid))
rng = np.random.default_rng(1)
fails = 0


def check(label, got, want, tol):
    global fails
    ok = abs(got - want) <= tol
    fails += 0 if ok else 1
    log.info(f"{'OK   ' if ok else 'ÉCHEC'} {label} : mesuré {got:.2f}, attendu {want:.2f} (± {tol})")


def frames_mask(mask):
    """Masque par échantillon à partir d'un masque de trames."""
    m = np.zeros(it.n, bool)
    for i in np.flatnonzero(mask): m[i * FR:(i + 1) * FR] = True
    return m[:, None]


log.info(f'extrait {iid} : {it.n / SR:.1f} s, trames chantées {it.sung.sum()}, non chantées {it.unsung.sum()}')
EI, EV = (it.I ** 2).sum(), (it.V ** 2).sum()

# 0) instru parfaite
m = metrics(it, it.I.copy() + 1e-9 * rng.standard_normal(it.I.shape))
check('0 instru parfaite : SDR > 100 dB', min(m['sdr'], 100), 100, 0.01)
check('0 instru parfaite : gain chanté', m['d3_gain_sung'], 0, 0.01)

# 1) instru vraie + 1 % de voix (−40 dB) : restes de voix = −40 dB de la voix vraie ; artefacts négligeables
m = metrics(it, it.I + 0.01 * it.V)
check('1 +1 % de voix : restes de voix / voix vraie', m['d1_voc_left'], -40, 0.1)
check('1 +1 % de voix : SIR = instru / (0,01·voix)', m['d1_sir'], db(EI / (1e-4 * EV)), 0.1)
check('1 +1 % de voix : SAR très haut (> 80 dB)', min(m['d2_sar'], 80), 80, 0.01)
check('1 +1 % de voix : SDR = SIR', m['sdr'], m['d1_sir'], 0.1)

# 2) voix filtrée et retardée (0,05 × voix retardée de 5 échantillons, canaux croisés) : −26 dB
vd = np.zeros_like(it.V); vd[5:, 0] = 0.05 * it.V[:-5, 1]; vd[5:, 1] = 0.05 * it.V[:-5, 0]
m = metrics(it, it.I + vd)
check('2 voix retardée et croisée à 5 % : restes de voix', m['d1_voc_left'], -26.02, 0.2)
check('2 idem : SAR haut (> 60 dB)', min(m['d2_sar'], 60), 60, 0.01)

# 3) bruit blanc à −30 dB de l'instru : SAR = 30 dB, pas de voix
nz = rng.standard_normal(it.I.shape); nz *= np.sqrt(EI * 1e-3 / (nz ** 2).sum())
m = metrics(it, it.I + nz)
check('3 bruit à −30 dB : SAR', m['d2_sar'], 30, 0.2)
check('3 bruit à −30 dB : SDR', m['sdr'], 30, 0.1)
check('3 bruit à −30 dB : restes de voix sous −50 dB (plancher de la mesure)', max(m['d1_voc_left'], -50), -50, 0.01)

# 4) bruit seulement dans 2–6 kHz, à −20 dB de l'instru de cette bande
b = band_split(nz)[2]; Ib = it.Ib[2]; b *= np.sqrt((Ib ** 2).sum() * 1e-2 / (b ** 2).sum())
m = metrics(it, it.I + b)
check('4 bruit dans 2–6 kHz à −20 dB : SDR 2–6 kHz', m['sdr_2-6k'], 20, 0.1)
check('4 idem : SDR 250 Hz–2 kHz intact (> 90 dB)', min(m['sdr_250-2k'], 90), 90, 0.01)

# 5) instru × 0,8 (−1,94 dB) là où la voix chante seulement
g = np.where(frames_mask(it.sung), 0.8, 1.0)
m = metrics(it, it.I * g)
check('5 instru × 0,8 où la voix chante : gain chanté', m['d3_gain_sung'], 20 * np.log10(0.8), 0.05)
check('5 idem : gain non chanté', m['d3_gain_unsung'], 0, 0.01)
check('5 idem : gain chanté, bande 250 Hz–2 kHz', m['d3_gain_sung_250-2k'], 20 * np.log10(0.8), 0.3)
check('5 idem : gain cohérent chanté', m['d3_coh_sung_250-2k'], 20 * np.log10(0.8), 0.3)
check('5 idem : écart type chanté (gain constant)', m['d3_std_sung'], 0, 0.05)
check('5 idem : pas de restes de voix (< −45 dB)', max(m['d1_voc_left'], -45), -45, 0.01)

# 6) gain qui bouge : alternance × 1 / × 0,5 d'une trame à l'autre où la voix chante → moyenne −3,01 dB, écart type 3,01 dB
alt = np.ones(it.k); idx = np.flatnonzero(it.sung); alt[idx[::2]] = 0.5
g = np.repeat(alt, FR)[:, None]; g = np.concatenate([g, np.ones((it.n - len(g), 1))])
m = metrics(it, it.I * g)
check('6 gain alterné 0 / −6 dB : moyenne chantée', m['d3_gain_sung'], -3.01, 0.15)
check('6 gain alterné 0 / −6 dB : écart type chanté', m['d3_std_sung'], 3.01, 0.15)

# 7) aigus (> 6 kHz) à −6 dB là où la voix chante seulement
hi = it.Ib[3] + it.Ib[4]
m = metrics(it, it.I - 0.5 * hi * frames_mask(it.sung))
check('7 aigus à −6 dB où la voix chante : niveau > 6 kHz chanté', m['d4_hf_level_sung'], -6.02, 0.15)
check('7 idem : niveau > 6 kHz non chanté', m['d4_hf_level_unsung'], 0, 0.02)
check('7 idem : part cohérente > 6 kHz chantée', m['d4_hf_coh_sung'], -6.02, 0.15)

# 8) « aigus seuls » du produit : erreur = bruit blanc → même formule que e2e.mjs, comparée au calcul direct
m = metrics(it, it.I + nz)
d2 = lambda x: x[2:] - 2 * x[1:-1] + x[:-2]
check('8 aigus seuls (dérivée seconde) : formule du produit', m['sdr_hf2'], db((d2(it.I) ** 2).sum() / (d2(nz) ** 2).sum()), 0.01)

# 9) SDR de la voix : voix vraie + 10 % d'instru
m = metrics(it, it.I, voc_est=it.V + 0.1 * it.I)
check('9 voix + 10 % d\'instru : SDR de la voix', m['voc_sdr'], db(EV / (0.01 * EI)), 0.01)

log.info(f'{fails} échec(s)')
sys.exit(1 if fails else 0)
