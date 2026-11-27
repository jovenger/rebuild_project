# Ligne de base + candidats : mesures par extrait, gardées dans results/<extrait>.json (reprise : un candidat déjà
# mesuré n'est pas recalculé ; FORCE=1 pour tout refaire, ONLY=a,b pour ne faire que certains candidats).
#   python -I run_bench.py <items> <out> <results> [extrait …]
import sys, os, json, time
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from scipy.ndimage import uniform_filter

setup_log()
ITEMS, OUT, RES = sys.argv[1:4]
only_items = sys.argv[4:]
os.makedirs(RES, exist_ok=True)
C_VOC, C_INST = 1.021, 1.022       # « compensate » d'UVR : Voc_FT (produit), Inst_HQ_3 (empreinte 55657dd7…)
EPS = 1e-12
FREQ = np.fft.rfftfreq(NFFT, 1 / SR)
ONLY = set(filter(None, os.environ.get('ONLY', '').split(',')))


def load(iid, tag):
    p = os.path.join(OUT, f'{iid}.{tag}.f32')
    return read_f32(p) if os.path.exists(p + '.json') else None


def soft(x, a, b):
    return np.clip((x - a) / (b - a), 0, 1)


def smooth_tf(m, ft=(3, 1, 3)):
    return uniform_filter(m, size=ft, mode='nearest')


def candidates(it, o):
    """Rend {nom: (famille, coût relatif, fonction → (instru, voix ou None))}. voix None = pistes de voix inchangées."""
    song, n = it.song, it.n
    voc = o['voc'][:n]
    v0 = C_VOC * voc
    cache = {}

    def S():
        if 'S' not in cache: cache['S'] = stft(song)
        return cache['S']

    def V(x=None):
        if x is None:
            if 'V' not in cache: cache['V'] = stft(v0)
            return cache['V']
        return stft(x)

    def back(Z):
        return istft(Z, n)

    c = {}
    c['base'] = ('ref', 1.0, lambda: (song - v0, v0))
    # ---------------- famille A : post-traitements, sans calcul de modèle en plus
    for k in (0.90, 0.95, 1.00, 1.05, 1.10):
        c[f'A_comp_{k:.2f}'] = ('A', 1.0, lambda k=k: (song - k * voc, None))

    def wiener(p, tsmooth=False, joint=False):
        s, v = S(), V(); nn = s - v
        a, b = np.abs(nn) ** p, np.abs(v) ** p
        if joint: a, b = a.sum(axis=1, keepdims=True), b.sum(axis=1, keepdims=True)
        m = a / (a + b + EPS)
        if tsmooth: m = uniform_filter(m, size=(1, 1, 3), mode='nearest')
        return back(m * s), None
    c['A_wiener2'] = ('A', 1.0, lambda: wiener(2))
    c['A_wiener1'] = ('A', 1.0, lambda: wiener(1))
    c['A_wiener2_liss3'] = ('A', 1.0, lambda: wiener(2, tsmooth=True))
    c['A_wiener2_joint'] = ('A', 1.0, lambda: wiener(2, joint=True))

    def psm():
        # masque sensible à la phase : part de la voix estimée cohérente avec la chanson, bornée à [0, 1]
        s, v = S(), V()
        m = np.clip((v * np.conj(s)).real / (np.abs(s) ** 2 + EPS), 0, 1)
        return back((1 - m) * s), None
    c['A_psm'] = ('A', 1.0, psm)

    def limit(which):
        s, v = S(), V()
        if which in ('v', 'vn'): v = v * np.minimum(1, np.abs(s) / (np.abs(v) + EPS))
        nn = s - v
        if which in ('n', 'vn'): nn = nn * np.minimum(1, np.abs(s) / (np.abs(nn) + EPS))
        return back(nn), None
    c['A_borne_instru'] = ('A', 1.0, lambda: limit('n'))      # |instru| ≤ |chanson| à chaque point temps-fréquence
    c['A_borne_voix'] = ('A', 1.0, lambda: limit('v'))        # |voix| ≤ |chanson|
    c['A_borne_2'] = ('A', 1.0, lambda: limit('vn'))

    def gate(f0, a, b, sm=True, borne=False):
        # soustraction limitée quand la voix estimée est faible devant la chanson (estimation peu fiable), au-dessus de f0
        s, v = S(), V()
        r = (smooth_tf(np.abs(v)) if sm else np.abs(v)) / ((smooth_tf(np.abs(s)) if sm else np.abs(s)) + EPS)
        g = soft(r, a, b)
        g = np.where((FREQ >= f0)[:, None, None], g, 1.0)
        nn = s - g * v
        if borne: nn = nn * np.minimum(1, np.abs(s) / (np.abs(nn) + EPS))
        return back(nn), None
    c['A_seuil_aigus6k_10_30'] = ('A', 1.0, lambda: gate(6000, 0.10, 0.30))
    c['A_seuil_aigus6k_20_50'] = ('A', 1.0, lambda: gate(6000, 0.20, 0.50))
    c['A_seuil_aigus4k_20_50'] = ('A', 1.0, lambda: gate(4000, 0.20, 0.50))
    c['A_seuil_tout_10_30'] = ('A', 1.0, lambda: gate(0, 0.10, 0.30))
    c['A_seuil_tout_20_50'] = ('A', 1.0, lambda: gate(0, 0.20, 0.50))
    c['A_seuil_tout_10_30_borne'] = ('A', 1.0, lambda: gate(0, 0.10, 0.30, borne=True))
    c['A_seuil_aigus6k_20_50_borne'] = ('A', 1.0, lambda: gate(6000, 0.20, 0.50, borne=True))

    def comp_hf(f0, k, width=1000.0):
        # « compensate » par bandes : soustraction × k au-dessus de f0 (transition douce de `width` Hz)
        s, v = S(), V()
        w = 1 + (k - 1) * np.clip((FREQ - (f0 - width / 2)) / width, 0, 1)
        return back(s - w[:, None, None] * v), None
    for f0, k in ((6000, 0.5), (6000, 0.75), (4000, 0.75), (2000, 0.85), (6000, 1.15)):
        c[f'A_comp_aigus{f0 // 1000}k_{k:.2f}'] = ('A', 1.0, lambda f0=f0, k=k: comp_hf(f0, k))

    def floor_hf(f0, beta, borne=False):
        # plancher : au-dessus de f0, l'instru garde au moins beta × |chanson| à chaque point (pas de trou creusé)
        s, v = S(), V(); nn = s - v
        a = np.abs(nn); tgt = beta * np.abs(s)
        g = np.where((FREQ >= f0)[:, None, None] & (a < tgt), tgt / (a + EPS), 1.0)
        nn = nn * g
        if borne: nn = nn * np.minimum(1, np.abs(s) / (np.abs(nn) + EPS))
        return back(nn), None
    c['A_plancher_aigus6k_0.30'] = ('A', 1.0, lambda: floor_hf(6000, 0.30))
    c['A_plancher_aigus6k_0.50'] = ('A', 1.0, lambda: floor_hf(6000, 0.50))
    c['A_plancher_aigus4k_0.50'] = ('A', 1.0, lambda: floor_hf(4000, 0.50))
    c['A_plancher_aigus6k_0.50_borne'] = ('A', 1.0, lambda: floor_hf(6000, 0.50, borne=True))

    def midside(k):
        mid, side = 0.5 * (v0[:, 0] + v0[:, 1]), 0.5 * (v0[:, 0] - v0[:, 1])
        v = np.stack([mid + k * side, mid - k * side], axis=1)
        return song - v, None
    c['A_centre_seul'] = ('A', 1.0, lambda: midside(0.0))        # on ne retire que le centre de la voix estimée
    c['A_cotes_moitie'] = ('A', 1.0, lambda: midside(0.5))

    def tgate(thr_db):
        # porte dans le temps : trames de 50 ms où la voix estimée est sous (chanson + thr_db) → pas de soustraction
        k = n // FR
        ev = (v0[:k * FR].reshape(k, FR, 2) ** 2).sum(axis=(1, 2)); es = (song[:k * FR].reshape(k, FR, 2) ** 2).sum(axis=(1, 2))
        r = db(ev / np.maximum(es, 1e-12))
        g = soft(r, thr_db, thr_db + 6)
        g = np.minimum(1, np.convolve(g, np.ones(5), mode='same'))          # tenue : ± 100 ms autour d'une trame active
        gi = np.interp(np.arange(n), (np.arange(k) + 0.5) * FR, g)[:, None]
        return song - gi * v0, None
    c['A_porte_temps_-30'] = ('A', 1.0, lambda: tgate(-30))
    c['A_porte_temps_-40'] = ('A', 1.0, lambda: tgate(-40))

    def ratio_smooth(kind):
        # lissage dans le temps du rapport complexe voix estimée / chanson (3 trames), borné à |rapport| ≤ 2
        s, v = S(), V()
        m = v / (s + EPS * (1 + 0j))
        m = m / np.maximum(1, np.abs(m) / 2)
        from scipy.ndimage import median_filter
        f = (lambda x: uniform_filter(x, size=(1, 1, 3), mode='nearest')) if kind == 'moy' else (lambda x: median_filter(x, size=(1, 1, 3), mode='nearest'))
        m2 = f(m.real) + 1j * f(m.imag)
        return back(s - m2 * s), None
    c['A_rapport_liss3'] = ('A', 1.0, lambda: ratio_smooth('moy'))
    c['A_rapport_med3'] = ('A', 1.0, lambda: ratio_smooth('med'))

    def combo(seuil_hf):
        # borne (+ seuil dans les aigus) dans le domaine des transformées, puis porte dans le temps à −30 dB
        est = (gate(6000, 0.20, 0.50, borne=True) if seuil_hf else limit('n'))[0]
        sub = song - est
        k = n // FR
        ev = (v0[:k * FR].reshape(k, FR, 2) ** 2).sum(axis=(1, 2)); es = (song[:k * FR].reshape(k, FR, 2) ** 2).sum(axis=(1, 2))
        g = soft(db(ev / np.maximum(es, 1e-12)), -30, -24)
        g = np.minimum(1, np.convolve(g, np.ones(5), mode='same'))
        gi = np.interp(np.arange(n), (np.arange(k) + 0.5) * FR, g)[:, None]
        return song - gi * sub, None
    c['A_combo_borne+porte'] = ('A', 1.0, lambda: combo(False))
    c['A_combo_borne+seuil6k+porte'] = ('A', 1.0, lambda: combo(True))

    # ---------------- famille B : avec un coût
    if o.get('vocn') is not None:
        vd = C_VOC * 0.5 * (voc - o['vocn'][:n])
        c['B_finition'] = ('B', 2.0, lambda: (song - vd, vd))             # « Finition soignée » du produit

        def dn_then(fn):
            # post-traitement A appliqué à la sortie de « Finition soignée »
            sv = cache.get('V'); cache['V'] = stft(vd)
            try: return fn()
            finally:
                if sv is not None: cache['V'] = sv
                else: cache.pop('V', None)
        c['B_finition+seuil_tout_10_30'] = ('B', 2.0, lambda: (dn_then(lambda: gate(0, 0.10, 0.30))[0], vd))
        c['B_finition+borne_instru'] = ('B', 2.0, lambda: (dn_then(lambda: limit('n'))[0], vd))
    if o.get('vocs') is not None:
        vs = C_VOC * 0.5 * (voc + o['vocs'][:n])
        c['B_decalage2'] = ('B', 2.0, lambda: (song - vs, vs))            # moyenne de 2 décalages (½ morceau + ½ pas)
        if o.get('vocn') is not None and o.get('vocsn') is not None:
            v4 = C_VOC * 0.25 * (voc - o['vocn'][:n] + o['vocs'][:n] - o['vocsn'][:n])
            c['B_decalage2+finition'] = ('B', 4.0, lambda: (song - v4, v4))
    if o.get('voco') is not None:
        vo = C_VOC * o['voco'][:n]
        c['B_recouvrement_0.5'] = ('B', 1.5, lambda: (song - vo, vo))
    if o.get('inst') is not None:
        ih = C_INST * o['inst'][:n]
        c['B_insthq3_seul'] = ('B', 1.0, lambda: (ih, song - ih))         # remplace le modèle voix : voix = chanson − instru
        c['B_insthq3_instru+voix_FT'] = ('B', 2.0, lambda: (ih, v0))      # instru du modèle instru, voix du modèle voix
        c['B_ens_moyenne'] = ('B', 2.0, lambda: (0.5 * (ih + song - v0), None))

        def ens_spec(mode):
            a, b = stft(ih), S() - V()
            pick = (np.abs(a) <= np.abs(b)) if mode == 'min' else (np.abs(a) >= np.abs(b))
            return back(np.where(pick, a, b)), None
        c['B_ens_min_spectre'] = ('B', 2.0, lambda: ens_spec('min'))
        c['B_ens_max_spectre'] = ('B', 2.0, lambda: ens_spec('max'))
        if o.get('instn') is not None:
            ihd = C_INST * 0.5 * (o['inst'][:n] - o['instn'][:n])
            c['B_insthq3_finition'] = ('B', 2.0, lambda: (ihd, song - ihd))
            if o.get('vocn') is not None:
                c['B_ens_moyenne+finition'] = ('B', 4.0, lambda: (0.5 * (ihd + song - vd), vd))
    # Deux autres modèles publics de la même famille (UVR model_data_new.json) : Kim_Vocal_2 (voix, compensate 1,009),
    # UVR-MDX-NET-Inst_HQ_4 (instru, compensate 1,019, bande entière 0–22 kHz).
    if o.get('kim') is not None:
        vk = 1.009 * o['kim'][:n]
        c['B_kim2_seul'] = ('B', 1.0, lambda: (song - vk, vk))
        va = 0.5 * (v0 + vk)
        c['B_ens_voixFT+kim2'] = ('B', 2.0, lambda: (song - va, va))
        if o.get('inst') is not None:
            ih3 = C_INST * o['inst'][:n]
            c['B_ens3_FT+kim2+insthq3'] = ('B', 3.0, lambda: ((2 * song - v0 - vk + ih3) / 3, va))
    if o.get('inst4') is not None:
        ih4 = 1.019 * o['inst4'][:n]
        c['B_insthq4_seul'] = ('B', 1.0, lambda: (ih4, song - ih4))
        c['B_ens_FT+insthq4'] = ('B', 2.0, lambda: (0.5 * (ih4 + song - v0), None))
    # Prototype JavaScript dans la boucle par morceaux du produit (sep_post.mjs, run_post.mjs) : signal à soustraire
    for rule in ('borne', 'seuil6k', 'seuil6k_borne', 'borne_bande', 'borne_bande1'):
        pj = os.path.join(OUT, f'{it.id}.post_{rule}.f32')
        if os.path.exists(pj) and os.path.exists(os.path.join(OUT, f'{it.id}.post.json')):
            c[f'A_js_{rule}'] = ('A', 1.0, lambda pj=pj: (song - read_f32(pj)[:n], None))
    pj = os.path.join(OUT, f'{it.id}.post_borne_bande.f32')
    if os.path.exists(pj):   # même règle, mais la piste de voix devient aussi le signal borné (aucune transformée en plus)
        c['A_js_borne_bande_voix_aussi'] = ('A', 1.0, lambda pj=pj: (song - read_f32(pj)[:n], read_f32(pj)[:n]))
    for rule in ('borne', 'seuil6k_borne', 'borne_bande', 'borne_bande1'):
        pj = os.path.join(OUT, f'{it.id}.post_c_{rule}.f32')
        if os.path.exists(pj) and os.path.exists(os.path.join(OUT, f'{it.id}.post_c.json')):
            c[f'A_jsc_{rule}'] = ('A', 1.0, lambda pj=pj: (song - read_f32(pj)[:n], None))
    return c


TAGS = ['voc', 'vocn', 'inst', 'vocs', 'voco', 'instn', 'vocsn', 'kim', 'inst4']
ids = only_items or sorted(d for d in os.listdir(ITEMS) if os.path.isdir(os.path.join(ITEMS, d)))
for iid in ids:
    o = {t: load(iid, t) for t in TAGS}
    if o['voc'] is None: log.warning(f'{iid} : sortie du modèle voix absente, sauté'); continue
    rp = os.path.join(RES, f'{iid}.json')
    res = json.load(open(rp)) if os.path.exists(rp) and not os.environ.get('FORCE') else {}
    it = Item(os.path.join(ITEMS, iid))
    cands = candidates(it, o)
    todo = [k for k in cands if k not in res and (not ONLY or k in ONLY)]
    log.info(f'{iid} : {len(cands)} candidats, {len(todo)} à mesurer ; trames chantées {int(it.sung.sum())}, non chantées {int(it.unsung.sum())}')
    base_voc = C_VOC * o['voc'][:it.n]
    for k in todo:
        fam, cost, fn = cands[k]
        t0 = time.perf_counter()
        try:
            est, v = fn()
        except Exception as e:
            log.error(f'{iid} / {k} : {type(e).__name__} : {e}'); continue
        t1 = time.perf_counter()
        m = metrics(it, est, voc_est=base_voc if v is None else v)
        m.update(family=fam, cost=cost, voice_changed=v is not None and k != 'base', post_ms=1000 * (t1 - t0))
        res[k] = m
        log.info(f"{iid} / {k} : SDR {m['sdr']:.2f} aigus {m['sdr_hf2']:.2f} restes voix {m['d1_voc_left']:.1f} SAR {m['d2_sar']:.1f} voix SDR {m['voc_sdr']:.2f} ({1000 * (time.perf_counter() - t1):.0f} ms de mesure)")
        json.dump(res, open(rp, 'w'))
    json.dump(res, open(rp, 'w'))
log.info('fini')
