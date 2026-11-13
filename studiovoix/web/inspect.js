// StudioVoix Web : inspection d'une piste — mesures objectives de ce qui abîme une voix, pour que le programme dise
// lui-même « cette piste craque, c'est tel effet, voici quoi faire » au lieu de laisser chercher à l'oreille.
// Module ES pur (aucun accès à la page) : utilisé par la page et par les essais Node.
//
// Mesures :
//   voiceDirt   — saleté ajoutée par un traitement : sur les trames chantées (périodiques), part de l'énergie qui ne se
//                 répète pas d'une période à l'autre, comparée entre le son traité et le son d'origine, dans les graves
//                 et dans les aigus séparément (un égaliseur, linéaire, ne change pas la mesure à l'intérieur d'une bande).
//   clickRate   — craquements : pointes isolées de la dérivée seconde.
//   clipRuns    — écrêtage : plateaux collés à la crête.
//   gainRipple  — pompage : variation rapide du gain entre l'origine et le traité.

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

/** Craquements par seconde : échantillons dont la dérivée seconde dépasse 12 fois celle des 10 ms autour. */
export function clickRate(x, sr) {
    const n = x.length, w = Math.max(16, Math.round(0.01 * sr)), d = new Float32Array(w);
    let clicks = 0;
    for (let a = 2; a + w <= n; a += w) {
        let lv = 0;
        for (let i = 0; i < w; ++i) { d[i] = Math.abs(x[a + i] - 2 * x[a + i - 1] + x[a + i - 2]); lv += x[a + i] * x[a + i]; }
        if (lv / w < 1e-5) continue;
        const med = Float32Array.from(d).sort()[w >> 1] + 1e-9;
        for (let i = 0; i < w; ++i) if (d[i] > 12 * med && d[i] > 0.02) ++clicks;
    }
    return clicks / Math.max(1e-9, n / sr);
}

/** Écrêtage : nombre de plateaux (3 échantillons ou plus collés à la crête, à 0,5 % près) ; 0 si la crête est faible. */
export function clipRuns(x) {
    let peak = 0; for (let i = 0; i < x.length; ++i) { const a = Math.abs(x[i]); if (a > peak) peak = a; }
    if (peak < 0.5) return { runs: 0, peak };
    let runs = 0, len = 0;
    for (let i = 0; i < x.length; ++i) {
        if (Math.abs(x[i]) >= 0.995 * peak) ++len; else { if (len >= 3) ++runs; len = 0; }
    }
    if (len >= 3) ++runs;
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
