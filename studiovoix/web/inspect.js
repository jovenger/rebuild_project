// StudioVoix Web : inspection d'une piste — mesures objectives de ce qui abîme une voix, pour que le programme dise
// lui-même « cette piste craque, c'est tel effet, voici quoi faire » au lieu de laisser chercher à l'oreille.
// Module ES pur (aucun accès à la page) : utilisé par la page et par les essais Node.
//
// Mesures :
//   voiceDirt   — saleté ajoutée par un traitement : sur les trames chantées (périodiques), part de l'énergie qui ne se
//                 répète pas d'une période à l'autre, comparée entre le son traité et le son d'origine, dans les graves
//                 et dans les aigus séparément (un égaliseur, linéaire, ne change pas la mesure à l'intérieur d'une bande).
//   clipRuns    — écrêtage : plateaux collés à la crête.
//   gainRipple  — pompage : variation rapide du gain entre l'origine et le traité (pas utilisée par la page).
//   addedDistortion — distorsion ajoutée par un effet non linéaire (saturation) : chaîne avec l'effet contre la même
//                 chaîne sans lui ; ce qu'un gain lent n'explique pas. Une saturation reste périodique : voiceDirt ne
//                 la voit pas.
//   findCrackles — craquements isolés d'une voix (findClicks : saut, échantillon faux ; findDropouts : court trou).
//                 Remplace l'ancienne mesure clickRate (pointes de la dérivée seconde > 12 fois la médiane), retirée :
//                 280 « craquements » sur 20 s d'une voix chantée saine, les impulsions glottiques et les consonnes
//                 la déclenchaient.

const db = (v) => 10 * Math.log10(v + 1e-30);

/** Filtre du 2e ordre (Butterworth) passe-bas ou passe-haut. */
function butter(x, sr, fc, high) {
    const w = Math.tan(Math.PI * fc / sr), n = 1 / (1 + Math.SQRT2 * w + w * w);
    const b0 = high ? n : w * w * n, b1 = high ? -2 * n : 2 * w * w * n, b2 = b0;
    const a1 = 2 * (w * w - 1) * n, a2 = (1 - Math.SQRT2 * w + w * w) * n;
    const y = new Float32Array(x.length);
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (let i = 0; i < x.length; ++i) {
        const v = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        x2 = x1; x1 = x[i]; y2 = y1; y1 = v; y[i] = v;
    }
    return y;
}

/** Corrélation normalisée entre x[a, a+W) et x[a+lag, a+lag+W), un échantillon sur `step`. */
function ncc(x, a, W, lag, step) {
    let s = 0, e0 = 0, e1 = 0;
    for (let i = a; i < a + W; i += step) { const p = x[i], q = x[i + lag]; s += p * q; e0 += p * p; e1 += q * q; }
    return s / Math.sqrt(e0 * e1 + 1e-30);
}
// « bruit » d'une trame de périodicité rho : énergie non répétée / énergie répétée (rapport), avec un plancher à
// -25 dB : en dessous, le bruit est masqué par la voix. Sans plancher, une voix parfaitement propre (synthèse) faisait
// passer -39 dB de bruit pour « +1 dB de saleté ».
const NOISE_FLOOR = Math.pow(10, -25 / 10);
const noiseDb = (rho) => { const r = Math.min(0.99999, Math.max(0.01, rho)); return db((1 - r) / r + NOISE_FLOOR); };

/**
 * Saleté ajoutée par un traitement, en dB (0 = rien d'ajouté ; +1 dB s'entend déjà sur une voix propre).
 * raw et proc : même prise avant / après, alignées (le traitement peut déplacer la hauteur de ±12 %).
 * Rend { low, high, lowLoud, highLoud, frames, loudFrames } : graves (< 1,5 kHz) et aigus (> 1,5 kHz), sur toutes les
 * trames chantées et sur le quart le plus fort (« quand le niveau monte »).
 */
export function voiceDirt(raw, proc, sr, opts = {}) {
    const W = 2 * Math.round(0.023 * sr), hop = opts.hop || W;
    const lagMin = Math.floor(sr / 500), lagMax = Math.ceil(sr / 70), n = Math.min(raw.length, proc.length);
    const rawLo = butter(raw, sr, 1500, false), rawHi = butter(raw, sr, 1500, true);
    const prLo = butter(proc, sr, 1500, false), prHi = butter(proc, sr, 1500, true);
    const rows = [];
    for (let a = 0; a + W + Math.ceil(lagMax * 1.13) + 2 < n; a += hop) {
        let e = 0; for (let i = a; i < a + W; i += 2) e += raw[i] * raw[i];
        e /= W / 2;
        if (e < 1e-7) continue;
        // période de la trame d'origine (pleine bande)
        let best = 0, lag = 0;
        for (let l = lagMin; l <= lagMax; l += 2) { const r = ncc(raw, a, W, l, 4); if (r > best) { best = r; lag = l; } }
        if (best < 0.8) continue;
        for (let l = Math.max(lagMin, lag - 2); l <= lag + 2; ++l) { const r = ncc(raw, a, W, l, 2); if (r > best) { best = r; lag = l; } }
        if (best < 0.85) continue;                                    // trame non chantée (consonne, souffle) : pas mesurée
        const l0 = Math.max(lagMin, Math.floor(lag * 0.88)), l1 = Math.ceil(lag * 1.12);
        const bandOf = (rb, pb) => {
            const rr = ncc(rb, a, W, lag, 1);
            let rp = -1;
            for (let l = l0; l <= l1; ++l) { const r = ncc(pb, a, W, l, 2); if (r > rp) rp = r; }
            return { rr, d: noiseDb(rp) - noiseDb(rr) };
        };
        rows.push({ e, lo: bandOf(rawLo, prLo), hi: bandOf(rawHi, prHi) });
    }
    const out = { low: 0, high: 0, lowLoud: 0, highLoud: 0, frames: rows.length, loudFrames: 0 };
    if (!rows.length) return out;
    const es = rows.map((r) => r.e).sort((p, q) => p - q), q75 = es[Math.floor(es.length * 0.75)];
    const mean = (sel, key) => { const v = rows.filter((r) => sel(r) && r[key].rr > 0.7).map((r) => r[key].d); return v.length ? v.reduce((p, q) => p + q, 0) / v.length : 0; };
    out.low = mean(() => true, 'lo'); out.high = mean(() => true, 'hi');
    out.lowLoud = mean((r) => r.e >= q75, 'lo'); out.highLoud = mean((r) => r.e >= q75, 'hi');
    out.loudFrames = rows.filter((r) => r.e >= q75).length;
    return out;
}

/**
 * Écrêtage : nombre de plateaux — 3 échantillons ou plus collés à la crête (à 0,5 % près) ET plats. 0 si la crête est faible.
 * « Plat » : le sommet arrondi d'une note pure non écrêtée reste lui aussi 3 échantillons à 0,5 % de sa crête (un sinus
 * de 440 Hz donnait 1760 « plateaux » en 2 s). Sur un sommet arrondi (parabole), la chute deux échantillons après le
 * bord vaut au plus 9 fois l'écart à l'intérieur ; sur un plateau écrêté l'intérieur ne bouge presque pas. On exige donc
 * un intérieur immobile (0,01 % de la crête) ou une chute dehors d'au moins 12 fois l'écart intérieur.
 */
export function clipRuns(x) {
    let peak = 0; for (let i = 0; i < x.length; ++i) { const a = Math.abs(x[i]); if (a > peak) peak = a; }
    if (peak < 0.5) return { runs: 0, peak };
    const n = x.length, thr = 0.995 * peak;
    let runs = 0;
    for (let i = 0; i < n; ++i) {
        if (Math.abs(x[i]) < thr) continue;
        let j = i, lo = Infinity, hi = 0;
        for (; j < n && Math.abs(x[j]) >= thr; ++j) { const a = Math.abs(x[j]); if (a < lo) lo = a; if (a > hi) hi = a; }
        if (j - i >= 3) {
            const inside = hi - lo;
            const before = i >= 2 ? hi - Math.abs(x[i - 2]) : 0, after = j + 1 < n ? hi - Math.abs(x[j + 1]) : 0;
            if (inside <= 1e-4 * peak || Math.max(before, after) >= 12 * inside) ++runs;
        }
        i = j;
    }
    return { runs, peak };
}

/** Pompage : écart type (dB) de la variation rapide du gain traité / origine, trames de 10 ms, tendance de 100 ms retirée. */
export function gainRipple(raw, proc, sr) {
    const w = Math.max(16, Math.round(0.01 * sr)), n = Math.min(raw.length, proc.length), g = [];
    for (let a = 0; a + w <= n; a += w) {
        let e0 = 0, e1 = 0; for (let i = a; i < a + w; ++i) { e0 += raw[i] * raw[i]; e1 += proc[i] * proc[i]; }
        g.push(e0 / w > 1e-5 && e1 > 0 ? db(e1 / e0) : NaN);
    }
    let s = 0, c = 0;
    for (let i = 5; i + 5 < g.length; ++i) {
        let m = 0, k = 0;
        for (let j = i - 5; j <= i + 5; ++j) if (!Number.isNaN(g[j])) { m += g[j]; ++k; }
        if (Number.isNaN(g[i]) || k < 9) continue;
        const dv = g[i] - m / k; s += dv * dv; ++c;
    }
    return c ? Math.sqrt(s / c) : 0;
}

/**
 * Distorsion ajoutée par un effet non linéaire (saturation) : `ref` = la chaîne SANS l'effet, `test` = la même chaîne
 * AVEC, alignées à l'échantillon (rien ne doit déplacer le temps ni la hauteur entre les deux). Par trames de 46 ms, la
 * partie de `test` qui s'explique linéairement par `ref` (3 coefficients autour du retard nul : gain, pente, petit
 * retard — un compresseur ou un limiteur en aval ne font que changer ce gain lentement) est retirée ; ce qui reste est
 * la distorsion. Rend { db, loudDb, frames } : distorsion / signal en dB (0 dB = autant de distorsion que de voix) sur
 * toutes les trames actives et sur le quart le plus fort ; -120 dB si rien n'est mesurable.
 */
export function addedDistortion(ref, test, sr) {
    const N = 2 * Math.round(0.023 * sr), hop = N >> 1, n = Math.min(ref.length, test.length);
    const win = new Float32Array(N); for (let i = 0; i < N; ++i) win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * (i + 0.5) / N);
    let top = 0;
    const rows = [];
    for (let a = 1; a + N + 1 <= n; a += hop) {
        // moindres carrés : test ≈ c0·ref[i-1] + c1·ref[i] + c2·ref[i+1]
        let m00 = 0, m01 = 0, m02 = 0, m11 = 0, m12 = 0, m22 = 0, v0 = 0, v1 = 0, v2 = 0, et = 0;
        for (let i = 0; i < N; ++i) {
            const w = win[i], p = w * ref[a + i - 1], q = w * ref[a + i], r = w * ref[a + i + 1], t = w * test[a + i];
            m00 += p * p; m01 += p * q; m02 += p * r; m11 += q * q; m12 += q * r; m22 += r * r;
            v0 += p * t; v1 += q * t; v2 += r * t; et += t * t;
        }
        if (!(m11 >= 1e-9 * N) || !(et >= 1e-9 * N)) continue;       // trame muette (ou échantillons non finis) : pas mesurée
        if (m11 > top) top = m11;
        const reg = 1e-6 * m11; m00 += reg; m11 += reg; m22 += reg;
        const det = m00 * (m11 * m22 - m12 * m12) - m01 * (m01 * m22 - m12 * m02) + m02 * (m01 * m12 - m11 * m02);
        let ed;
        if (Math.abs(det) > 1e-30) {
            const c0 = (v0 * (m11 * m22 - m12 * m12) - m01 * (v1 * m22 - m12 * v2) + m02 * (v1 * m12 - m11 * v2)) / det;
            const c1 = (m00 * (v1 * m22 - m12 * v2) - v0 * (m01 * m22 - m12 * m02) + m02 * (m01 * v2 - v1 * m02)) / det;
            const c2 = (m00 * (m11 * v2 - v1 * m12) - m01 * (m01 * v2 - v1 * m02) + v0 * (m01 * m12 - m11 * m02)) / det;
            ed = Math.max(0, et - (c0 * v0 + c1 * v1 + c2 * v2));
        } else ed = Math.max(0, et - v1 * v1 / m11);
        rows.push({ er: m11, et, ed });
    }
    const act = rows.filter((r) => r.er > 1e-4 * top);          // trames à moins de 40 dB sous la plus forte
    const out = { db: -120, loudDb: -120, frames: act.length };
    if (!act.length) return out;
    const es = act.map((r) => r.er).sort((p, q) => p - q), q75 = es[Math.floor(es.length * 0.75)];
    const ratio = (sel) => { let d = 0, t = 0; for (const r of act) if (sel(r)) { d += r.ed; t += r.et; } return t > 0 ? Math.max(-120, db(d / t)) : -120; };
    out.db = ratio(() => true); out.loudDb = ratio((r) => r.er >= q75);
    return out;
}

/** Coefficients de prédiction linéaire (Levinson-Durbin) d'autocorrélations r[0..p] ; a[0] = 1. */
function lpc(r, p, a, tmp) {
    a.fill(0); a[0] = 1;
    let err = r[0];
    if (!(err > 0)) return;
    for (let i = 1; i <= p; ++i) {
        let acc = r[i]; for (let j = 1; j < i; ++j) acc += a[j] * r[i - j];
        const k = -acc / err;
        for (let j = 1; j < i; ++j) tmp[j] = a[j] + k * a[i - j];
        for (let j = 1; j < i; ++j) a[j] = tmp[j];
        a[i] = k; err *= 1 - k * k;
        if (!(err > 1e-12 * r[0])) break;
    }
}

/**
 * Résidu de prédiction linéaire de x (ce que les `order` échantillons précédents n'annoncent pas), par trames de
 * 23 ms recouvertes de moitié, puis filtre adapté à une impulsion : un échantillon faux de hauteur h laisse dans le
 * résidu le motif h·a[k] (les coefficients du prédicteur), que l'on corrèle avec ce même motif. Une voix est très
 * prévisible et n'a presque rien dans l'extrême aigu : une discontinuité (craquement, saut, trou) y ressort de 20 à
 * 40 dB, alors qu'une impulsion glottique, qui n'a pas ce motif, ressort beaucoup moins.
 * Rend { z (résidu filtré, à l'échelle du résidu), gain (par trame : z = h × gain pour une impulsion h),
 * scale (par trame : médiane de |z| × 1,4826), hop }.
 */
export function lpcResidual(x, sr, order = 24) {
    const n = x.length, H = Math.max(64, Math.round(0.0116 * sr)), W = 2 * H, p = order;
    const e = new Float32Array(n + p), z = new Float32Array(n), frames = Math.ceil(n / H), scale = new Float32Array(frames), gain = new Float32Array(frames);
    const coef = new Float32Array(frames * (p + 1));
    const win = new Float32Array(W); for (let i = 0; i < W; ++i) win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * (i + 0.5) / W);
    const seg = new Float64Array(W), r = new Float64Array(p + 1), a = new Float64Array(p + 1), tmp = new Float64Array(p + 1), mag = new Float32Array(H);
    for (let f = 0; f < frames; ++f) {
        const a0 = f * H, s0 = a0 - (H >> 1);                    // fenêtre d'analyse centrée sur la trame
        for (let i = 0; i < W; ++i) { const k = s0 + i; seg[i] = k >= 0 && k < n ? x[k] * win[i] : 0; }
        for (let l = 0; l <= p; ++l) { let s = 0; for (let i = l; i < W; ++i) s += seg[i] * seg[i - l]; r[l] = s; }
        r[0] = r[0] * 1.0003 + 1e-12;                             // un peu de bruit blanc : son à bande limitée (16 kHz) bien conditionné
        lpc(r, p, a, tmp);
        let g = 0; for (let k = 0; k <= p; ++k) { coef[f * (p + 1) + k] = a[k]; g += a[k] * a[k]; }
        gain[f] = Math.sqrt(g);
        const end = Math.min(n, a0 + H);
        for (let i = a0; i < end; ++i) {
            let s = x[i]; const kmax = Math.min(p, i);
            for (let k = 1; k <= kmax; ++k) s += a[k] * x[i - k];
            e[i] = s;
        }
    }
    for (let f = 0; f < frames; ++f) {
        const a0 = f * H, end = Math.min(n, a0 + H), c = f * (p + 1), inv = 1 / gain[f];
        for (let i = a0; i < end; ++i) {
            let s = 0; for (let k = 0; k <= p; ++k) s += coef[c + k] * e[i + k];
            z[i] = s * inv; mag[i - a0] = Math.abs(z[i]);
        }
        const m = mag.subarray(0, end - a0).slice().sort();
        scale[f] = 1.4826 * m[m.length >> 1];
    }
    return { z, gain, scale, hop: H };
}

/**
 * Craquements isolés (discontinuités : saut, échantillon faux, court trou) dans une voix. Un craquement = un pic du
 * résidu de prédiction qui est à la fois très au-dessus du résidu courant (`kSigma` fois l'échelle de la trame),
 * audible (au-dessus de `minAmp` × la crête de la prise) et ISOLÉ : `kIso` fois plus fort que le 3e autre pic des
 * 40 ms autour. Les impulsions glottiques et les consonnes, qui faisaient crier l'ancienne mesure, ne sont pas
 * isolées : elles se répètent à la période de la voix, ou sont suivies d'un bruit du même ordre.
 * Rend { clicks: [{ at (échantillon), amp (hauteur estimée du saut), ratio, iso }], candidates }. Les pics à moins
 * de 15 ms comptent pour un. Seuils par défaut = ceux du calibrage (260 s de voix propres : aucune fausse détection).
 * Limite : calé à 44,1 / 48 kHz sur des voix qui n'occupent pas tout le spectre ; à 16 kHz natif, la mesure crie
 * (20 fausses détections sur 107 s) — ne pas l'utiliser sous 32 kHz.
 */
export function findClicks(x, sr, opts = {}) {
    const { order = 24, kSigma = 12, kIso = 6, minAmp = 0.02, res = null } = opts;
    const n = x.length, { z: e, gain, scale, hop } = res || lpcResidual(x, sr, order);
    let peak = opts.peak || 0; if (!peak) for (let i = 0; i < n; ++i) { const v = Math.abs(x[i]); if (v > peak) peak = v; }
    const floor = Math.max(1e-5, minAmp * peak), guard = Math.max(8, Math.round(0.0015 * sr)), span = Math.round(0.04 * sr), merge = Math.round(0.015 * sr);
    const clicks = []; let candidates = 0;
    // n-ième plus fort pic de |e| dans [lo, hi) hors des zones exclues (±guard autour des pics déjà pris)
    const otherPeak = (lo, hi, at) => {
        const ex = [at]; let v = 0;
        for (let k = 0; k < 3; ++k) {
            v = 0; let arg = -1;
            for (let i = lo; i < hi; ++i) {
                const m = Math.abs(e[i]); if (m <= v) continue;
                let ok = true; for (const c of ex) if (Math.abs(i - c) <= guard) { ok = false; break; }
                if (ok) { v = m; arg = i; }
            }
            if (arg < 0) return 0;
            ex.push(arg);
        }
        return v;
    };
    for (let i = 1; i + 1 < n; ++i) {
        const m = Math.abs(e[i]);
        if (m < 1e-5) continue;
        const f = Math.min(scale.length - 1, Math.floor(i / hop)), s = scale[f], amp = m / gain[f];
        if (amp < floor || m < kSigma * s) continue;
        // pic local sur ±guard
        let top = true; const lo = Math.max(0, i - guard), hi = Math.min(n, i + guard + 1);
        for (let j = lo; j < hi; ++j) if (Math.abs(e[j]) > m) { top = false; break; }
        if (!top) continue;
        ++candidates;
        const ref = otherPeak(Math.max(0, i - span), Math.min(n, i + span + 1), i);
        const iso = m / (ref + 1e-9);
        if (iso < kIso) continue;
        const last = clicks[clicks.length - 1];
        if (last && i - last.end <= merge) { if (amp > last.amp) { last.amp = amp; last.ratio = m / (s + 1e-9); last.iso = iso; } last.end = i; continue; }
        clicks.push({ at: i, end: i, amp, ratio: m / (s + 1e-9), iso });
    }
    return { clicks, candidates };
}

/**
 * Trous : le son tombe d'un coup à zéro pendant 0,7 à 30 ms puis revient d'un coup (bloc perdu à l'enregistrement).
 * Un trou = une suite d'échantillons sous `zero` × la crête (-60 dB) qui remplit deux conditions, des deux côtés :
 *  - du son autour : dans la milliseconde et demie qui touche, un niveau moyen d'au moins `edge` fois ce seuil ;
 *  - des bords en RUPTURE : à moins de 0,07 ms du bord (3 échantillons à 44,1 / 48 kHz), un échantillon d'au moins
 *    `jump` fois le seuil. Sans cette condition, un son grave et faible qui traverse zéro en pente douce passait pour
 *    un trou (mesuré : prise micro avec de la basse captée, 1,02 ms sous le seuil, voisins du bord à 1,6 fois le
 *    seuil seulement, niveau moyen 1,5 ms plus loin déjà à 10 fois). Un son continu resté 0,7 ms sous le seuil ne
 *    peut pas valoir 5 fois ce seuil 0,07 ms plus loin sans une cassure de sa pente : c'est la signature d'une coupure.
 * Rend [{ at, end (échantillons) }]. `jump: 0` rend l'ancienne règle (pour mesurer l'écart).
 */
export function findDropouts(x, sr, opts = {}) {
    const { zero = 0.001, edge = 10, jump = 5 } = opts, n = x.length;
    let peak = opts.peak || 0; if (!peak) for (let i = 0; i < n; ++i) { const v = Math.abs(x[i]); if (v > peak) peak = v; }
    const out = [];
    if (peak < 1e-4) return out;
    const thr = zero * peak, minLen = Math.max(4, Math.round(0.0007 * sr)), maxLen = Math.round(0.03 * sr), w = Math.max(8, Math.round(0.0015 * sr));
    const near = Math.max(2, Math.round(0.00007 * sr));
    const meanAbs = (a, b) => { let s = 0; for (let i = a; i < b; ++i) s += Math.abs(x[i]); return s / Math.max(1, b - a); };
    const maxAbs = (a, b) => { let m = 0; for (let i = a; i < b; ++i) { const v = Math.abs(x[i]); if (v > m) m = v; } return m; };
    for (let i = 0; i < n; ++i) {
        if (Math.abs(x[i]) > thr) continue;
        let j = i; while (j < n && Math.abs(x[j]) <= thr) ++j;
        const len = j - i;
        if (len >= minLen && len <= maxLen && i >= w && j + w <= n && meanAbs(i - w, i) >= edge * thr && meanAbs(j, j + w) >= edge * thr
            && maxAbs(i - near, i) >= jump * thr && maxAbs(j, j + near) >= jump * thr) out.push({ at: i, end: j });
        i = j;
    }
    return out;
}

/**
 * Craquements d'une prise : discontinuités isolées (findClicks) et trous (findDropouts), réunis et triés ; deux
 * défauts à moins de 15 ms comptent pour un. Rend [{ at (échantillon), kind: 'clic' | 'trou', amp, iso, ms }].
 */
export function findCrackles(x, sr, opts = {}) {
    // entrée externe : un échantillon non fini (NaN, infini) est lu comme un zéro, sinon toute sa trame serait perdue
    let bad = 0; for (let i = 0; i < x.length; ++i) if (!Number.isFinite(x[i])) ++bad;
    if (bad) x = Float32Array.from(x, (v) => (Number.isFinite(v) ? v : 0));
    let peak = 0; for (let i = 0; i < x.length; ++i) { const v = Math.abs(x[i]); if (v > peak) peak = v; }
    if (peak < 1e-4) return [];
    const holes = findDropouts(x, sr, { ...opts, peak }).map((h) => ({ at: h.at, end: h.end, kind: 'trou', amp: 0, iso: 0, ms: 1000 * (h.end - h.at) / sr }));
    const clicks = findClicks(x, sr, { ...opts, peak }).clicks.map((c) => ({ at: c.at, end: c.end, kind: 'clic', amp: c.amp, iso: c.iso, ms: 0 }));
    // les 20 ms du début et de la fin ne comptent pas : un son coupé net y fait un saut qui n'est pas un craquement
    const merge = Math.round(0.015 * sr), edge = Math.round(0.02 * sr), out = [];
    const all = [...holes, ...clicks].filter((c) => c.at >= edge && c.at < x.length - edge).sort((p, q) => p.at - q.at);
    for (const c of all) {
        const last = out[out.length - 1];
        if (last && c.at - last.end <= merge) { last.end = Math.max(last.end, c.end); if (c.kind === 'trou') { last.kind = 'trou'; last.ms = Math.max(last.ms, c.ms); } else { last.amp = Math.max(last.amp, c.amp); last.iso = Math.max(last.iso, c.iso); } }
        else out.push({ ...c });
    }
    return out;
}

/** Passage le plus fort de `sec` secondes (début en échantillons) : c'est là que les défauts s'entendent. */
export function loudestWindow(x, sr, sec) {
    const len = Math.min(x.length, Math.round(sec * sr)), step = Math.max(1, Math.round(0.25 * sr));
    if (len >= x.length) return 0;
    const pre = new Float64Array(Math.floor(x.length / step) + 1);
    for (let k = 0; k + 1 < pre.length; ++k) { let e = 0; for (let i = k * step; i < (k + 1) * step; i += 4) e += x[i] * x[i]; pre[k + 1] = pre[k] + e; }
    const wk = Math.floor(len / step); let best = 0, at = 0;
    for (let k = 0; k + wk < pre.length; ++k) { const e = pre[k + wk] - pre[k]; if (e > best) { best = e; at = k; } }
    return at * step;
}
