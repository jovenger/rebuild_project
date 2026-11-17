# Banc de mesure « Séparer une chanson » : mesures des quatre défauts entendus sur l'instru séparée.
# Tout est en float64, stéréo (n, 2), 44,1 kHz. Définitions : dans chaque fonction (metrics, Item.decompose).
import json, os, time, logging
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
BANDS = [('<250', 0, 250), ('250-2k', 250, 2000), ('2-6k', 2000, 6000), ('6-12k', 6000, 12000), ('>12k', 12000, SR / 2 + 1)]
FR = int(0.05 * SR)          # trames de 50 ms
L_TAPS = 32                  # filtre court de la projection (0,73 ms), retards centrés
WIN = SR                     # projection par fenêtres de 1 s (façon museval)
log = logging.getLogger('bench')


def setup_log(path=None):
    h = [logging.StreamHandler()]
    if path: h.append(logging.FileHandler(path))
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s : %(message)s', handlers=h, force=True)


def read_f32(path):
    return np.fromfile(path, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def read_wav(path):
    x, sr = sf.read(path, dtype='float64', always_2d=True)
    if sr != SR: raise ValueError(f'{path} : {sr} Hz au lieu de {SR}')
    if x.shape[1] == 1: x = np.repeat(x, 2, axis=1)
    return x


def db(x):
    return 10 * np.log10(np.maximum(x, 1e-30))


def band_split(x):
    """x (n, 2) → liste de 5 signaux (n, 2), filtres en brique dans le domaine de Fourier (somme = x)."""
    X = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return [np.fft.irfft(X * ((f >= lo) & (f < hi))[:, None], n=len(x), axis=0) for _, lo, hi in BANDS]


def hp2(x):
    y = np.zeros_like(x)
    y[2:] = x[2:] - 2 * x[1:-1] + x[:-2]
    return y


def frame_energy(x):
    k = len(x) // FR
    return (x[:k * FR].reshape(k, FR, -1) ** 2).sum(axis=(1, 2))


class Item:
    """Un extrait à vérité connue : chanson, instru vraie, voix vraie, trames « la voix chante » / « ne chante pas »."""

    def __init__(self, d, name=None):
        self.dir = d
        self.id = name or os.path.basename(d)
        self.song = read_wav(os.path.join(d, 'song.wav'))
        self.I = read_wav(os.path.join(d, 'truth_instru.wav'))
        n = min(len(self.song), len(self.I))
        self.song, self.I = self.song[:n], self.I[:n]
        pv = os.path.join(d, 'truth_voc.wav')
        self.V = read_wav(pv)[:n] if os.path.exists(pv) else self.song - self.I
        self.n = n
        mp = os.path.join(d, 'meta.json')
        self.meta = json.load(open(mp)) if os.path.exists(mp) else {}
        self.junction = self.meta.get('junction')
        # Trames de 50 ms : chante = énergie de la voix vraie > crête des trames − 30 dB ; ne chante pas = énergie par
        # échantillon ≤ 1e-8 (seuil de l'essai du produit, e2e.mjs). Trames exclues : 0,25 s autour de la jonction, 0,1 s aux bords.
        ve = frame_energy(self.V) / (2 * FR)
        k = len(ve)
        t = (np.arange(k) + 0.5) * FR
        ok = (t > 0.1 * SR) & (t < n - 0.1 * SR)
        if self.junction: ok &= np.abs(t - self.junction) > 0.25 * SR
        self.sung = ok & (ve > ve.max() * 1e-3)
        self.unsung = ok & (ve <= 1e-8)
        self.k = k
        self.Ib = band_split(self.I)
        self.Ibe = [frame_energy(b) for b in self.Ib]
        self.Ie = frame_energy(self.I)
        self._proj = None

    # ---- projection façon BSS Eval : erreur = part « voix » + part « instru » + reste (artefacts)
    def _refs(self, w0, w1):
        """Matrice des références retardées pour la fenêtre [w0, w1) : colonnes = (V_g, V_d, I_g, I_d) × L_TAPS retards."""
        cols = []
        for src in (getattr(self, 'Vp', self.V), self.I):   # Vp : fausse voix (mesure du plancher, floor.py)
            for c in (0, 1):
                p = np.pad(src[:, c], (L_TAPS, L_TAPS))
                for dly in range(-L_TAPS // 2, L_TAPS // 2):
                    cols.append(p[L_TAPS + w0 - dly: L_TAPS + w1 - dly])
        return np.stack(cols, axis=1).astype(np.float32)

    def proj(self):
        if self._proj is None:
            self._proj = []
            for w0 in range(0, self.n - WIN // 2, WIN):
                w1 = min(self.n, w0 + WIN)
                A = self._refs(w0, w1)
                A64 = A.astype(np.float64)
                G = A64.T @ A64
                # Régularisation par bloc (voix, instru) : 1e-6 × énergie moyenne du bloc (références à bande limitée
                # presque colinéaires, voix muette dans la fenêtre).
                nv = 2 * L_TAPS
                dg = np.diag(G).copy()
                rd = np.concatenate([np.full(nv, 1e-6 * dg[:nv].mean()), np.full(len(dg) - nv, 1e-6 * dg[nv:].mean())]) + 1e-12
                G += np.diag(rd)
                self._proj.append((w0, w1, A, np.linalg.cholesky(G)))
        return self._proj

    def decompose(self, e):
        """e (n, 2) = erreur de l'instru. Rend e_voc, e_ins, e_art (n, 2) : projection par fenêtres de 1 s sur la voix
        vraie et l'instru vraie retardées (filtre de L_TAPS points), reste = artefacts."""
        ev, ei = np.zeros_like(e), np.zeros_like(e)
        nv = 2 * L_TAPS
        for w0, w1, A, Lc in self.proj():
            for c in (0, 1):
                b = A.T.astype(np.float64) @ e[w0:w1, c]
                coef = np.linalg.solve(Lc.T, np.linalg.solve(Lc, b))
                ev[w0:w1, c] = A[:, :nv] @ coef[:nv]
                ei[w0:w1, c] = A[:, nv:] @ coef[nv:]
        return ev, ei, e - ev - ei


def sel_energy(x, mask):
    """Énergie de x sur les trames de 50 ms choisies."""
    fe = frame_energy(x)
    return fe[mask[:len(fe)]].sum()


def metrics(it, est, voc_est=None):
    """Toutes les mesures de l'instru estimée `est` (n, 2) contre la vérité de l'extrait `it`."""
    n = it.n
    est = est[:n]
    e = est - it.I
    m = {}
    m['sdr'] = db((it.I ** 2).sum() / (e ** 2).sum())
    m['sdr_song'] = db((it.I ** 2).sum() / (it.V ** 2).sum())                    # chanson brute prise comme instru
    m['sdr_hf2'] = db((hp2(it.I) ** 2).sum() / (hp2(e) ** 2).sum())              # « aigus seuls » du produit
    eb = band_split(e)
    estb = band_split(est)
    for (name, _, _), Ib, ebb in zip(BANDS, it.Ib, eb):
        m[f'sdr_{name}'] = db((Ib ** 2).sum() / (ebb ** 2).sum())
    # Défauts 1 et 2 : décomposition de l'erreur
    ev, ei, ea = it.decompose(e)
    EI, EV = (it.I ** 2).sum(), (it.V ** 2).sum()
    m['d1_sir'] = db(EI / (ev ** 2).sum())                    # instru vraie / restes de voix (plus haut = mieux)
    m['d1_voc_left'] = db((ev ** 2).sum() / EV)               # restes de voix / voix vraie (atténuation de la voix)
    m['d2_sar'] = db(EI / (ea ** 2).sum())                    # instru vraie / artefacts (plus haut = mieux)
    m['d_ins_loss'] = db(EI / (ei ** 2).sum())                # instru vraie / part de l'instru retirée ou déformée
    if it.sung.any():
        Es = sel_energy(it.I, it.sung)
        m['d1_sir_sung'] = db(Es / sel_energy(ev, it.sung))
        m['d2_sar_sung'] = db(Es / sel_energy(ea, it.sung))
        m['sdr_sung'] = db(Es / sel_energy(e, it.sung))
    if it.unsung.any():
        Eu = sel_energy(it.I, it.unsung)
        m['d2_sar_unsung'] = db(Eu / max(sel_energy(ea, it.unsung), 1e-30))
        m['sdr_unsung'] = db(Eu / max(sel_energy(e, it.unsung), 1e-30))
    # Défaut 3 : gain par trame de 50 ms et par bande (énergie estimée / énergie vraie), chante contre ne chante pas.
    for (name, _, _), Ib, Ibe, Eb_ in zip(BANDS, it.Ib, it.Ibe, estb):
        ge = frame_energy(Eb_)
        valid = Ibe > Ibe.max() * 1e-5                         # trames où la bande existe dans l'instru vraie (> −50 dB)
        g = db(ge / np.maximum(Ibe, 1e-30))
        for tag, mask in (('sung', it.sung), ('unsung', it.unsung)):
            sel = mask & valid
            if sel.sum() >= 5:
                m[f'd3_gain_{tag}_{name}'] = float(g[sel].mean())
                m[f'd3_std_{tag}_{name}'] = float(g[sel].std())
                # gain cohérent : part de l'instru vraie encore présente (projection trame par trame)
                k = len(ge)
                num = (Eb_[:k * FR].reshape(k, FR, 2) * Ib[:k * FR].reshape(k, FR, 2)).sum(axis=(1, 2))
                gc = 20 * np.log10(np.maximum(num[sel] / Ibe[sel], 0.03))
                m[f'd3_coh_{tag}_{name}'] = float(gc.mean())
                m[f'd3_cohstd_{tag}_{name}'] = float(gc.std())
    # Synthèse du défaut 3 (toutes bandes) : gain pleine bande par trame
    ge = frame_energy(est)
    g = db(ge / np.maximum(it.Ie, 1e-30))
    valid = it.Ie > it.Ie.max() * 1e-5
    for tag, mask in (('sung', it.sung), ('unsung', it.unsung)):
        sel = mask & valid
        if sel.sum() >= 5:
            m[f'd3_gain_{tag}'] = float(g[sel].mean()); m[f'd3_std_{tag}'] = float(g[sel].std())
            m[f'd3_absmean_{tag}'] = float(np.abs(g[sel]).mean())
    # Défaut 4 : niveau au-dessus de 6 kHz, estimée / vraie, énergie cumulée sur les trames chantées / non chantées.
    Ih = it.Ib[3] + it.Ib[4]; Eh = estb[3] + estb[4]
    for tag, mask in (('sung', it.sung), ('unsung', it.unsung)):
        if mask.any():
            den = sel_energy(Ih, mask)
            m[f'd4_hf_level_{tag}'] = db(sel_energy(Eh, mask) / den)
            k = it.k
            num = (Eh[:k * FR].reshape(k, FR, 2) * Ih[:k * FR].reshape(k, FR, 2)).sum(axis=(1, 2))[mask].sum()
            m[f'd4_hf_coh_{tag}'] = 20 * np.log10(max(num / den, 1e-6))          # part cohérente (aigus vrais gardés)
            m[f'd4_hf_sdr_{tag}'] = db(den / max(sel_energy(Eh - Ih, mask), 1e-30))
    if voc_est is not None:
        ev_ = voc_est[:n] - it.V
        m['voc_sdr'] = db((it.V ** 2).sum() / (ev_ ** 2).sum())
    return {k: float(v) for k, v in m.items()}


# ---------------------------------------------------------------- transformées (mêmes réglages que le modèle voix)
NFFT, HOP = 7680, 1024


def stft(x, nfft=NFFT, hop=HOP):
    _, _, Z = signal.stft(x, fs=SR, window='hann', nperseg=nfft, noverlap=nfft - hop, boundary='even', padded=True, axis=0)
    return Z                                                    # (F, 2, T)


def istft(Z, n, nfft=NFFT, hop=HOP):
    _, x = signal.istft(Z, fs=SR, window='hann', nperseg=nfft, noverlap=nfft - hop, boundary=True, time_axis=-1, freq_axis=0)
    x = np.moveaxis(x, 0, -1) if x.shape[0] == 2 else x
    out = np.zeros((n, 2))
    m = min(n, len(x))
    out[:m] = x[:m]
    return out
