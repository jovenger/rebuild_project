// Essai Node des transformées et du découpage de « Séparer » (isolate.js), sans navigateur.
//  1) FFT à bases mixtes contre une DFT naïve (petites tailles : toutes les bases 2, 3, 4, 5).
//  2) STFT et ISTFT contre l'ancienne implémentation (DFT de Bluestein, copie gardée ci-dessous) pour les trois réglages
//     (voix, karaoké, réverb) sur des signaux aléatoires : écart relatif ≤ 1e-5 ; temps ancien / nouveau par morceau.
//  3) separateVocals en un seul appel contre l'ancienne version (faux modèle déterministe) : écart relatif ≤ 1e-5.
//  4) Découpage par tranches de morceaux (reprise après coupure) contre un seul appel : écart ≤ −90 dB, y compris avec
//     des morceaux sautés pour silence, une longueur quelconque et des tranches de toutes tailles.
//   node web/test/stft.mjs
import { MDX, MODELS, MixedFft, MdxStft, separateVocals, mdxGrid, mdxPart, mdxPartAdd, mdxFinish } from '../isolate.js';

// ------------------------------------------------------------------ référence : ancienne implémentation (copie figée)
// FFT complexe radix 2 en place (taille puissance de 2).
class RefRadix2 {
    constructor(m) {
        this.m = m;
        this.rev = new Uint32Array(m);
        const bits = Math.log2(m);
        for (let i = 0; i < m; ++i) {
            let r = 0;
            for (let b = 0; b < bits; ++b) r |= ((i >> b) & 1) << (bits - 1 - b);
            this.rev[i] = r;
        }
        this.cos = new Float64Array(m / 2);
        this.sin = new Float64Array(m / 2);
        for (let i = 0; i < m / 2; ++i) {
            this.cos[i] = Math.cos(-2 * Math.PI * i / m);
            this.sin[i] = Math.sin(-2 * Math.PI * i / m);
        }
    }
    // inverse = true : exp(+i…), sans division par m.
    run(re, im, inverse) {
        const m = this.m, rev = this.rev;
        for (let i = 0; i < m; ++i) {
            const j = rev[i];
            if (j > i) {
                let t = re[i]; re[i] = re[j]; re[j] = t;
                t = im[i]; im[i] = im[j]; im[j] = t;
            }
        }
        const sgn = inverse ? -1 : 1;
        for (let size = 2; size <= m; size <<= 1) {
            const half = size >> 1, step = m / size;
            for (let start = 0; start < m; start += size) {
                for (let k = 0; k < half; ++k) {
                    const wr = this.cos[k * step], wi = sgn * this.sin[k * step];
                    const a = start + k, b = a + half;
                    const xr = re[b] * wr - im[b] * wi, xi = re[b] * wi + im[b] * wr;
                    re[b] = re[a] - xr; im[b] = im[a] - xi;
                    re[a] += xr; im[a] += xi;
                }
            }
        }
    }
}

// DFT complexe de taille quelconque n (algorithme de Bluestein, FFT radix 2 de taille m ≥ 2n − 1).
class RefBluestein {
    constructor(n) {
        this.n = n;
        let m = 1;
        while (m < 2 * n - 1) m <<= 1;
        this.m = m;
        this.fft = new RefRadix2(m);
        this.cr = new Float64Array(n);
        this.ci = new Float64Array(n);
        for (let k = 0; k < n; ++k) {
            const a = Math.PI * ((k * k) % (2 * n)) / n;   // exp(-iπk²/n), k² réduit modulo 2n (précision)
            this.cr[k] = Math.cos(a);
            this.ci[k] = -Math.sin(a);
        }
        this.br = new Float64Array(m);
        this.bi = new Float64Array(m);
        this.br[0] = this.cr[0]; this.bi[0] = -this.ci[0];
        for (let k = 1; k < n; ++k) {
            this.br[k] = this.br[m - k] = this.cr[k];
            this.bi[k] = this.bi[m - k] = -this.ci[k];
        }
        this.fft.run(this.br, this.bi, false);
        this.wr = new Float64Array(m);
        this.wi = new Float64Array(m);
    }
    // Transformée directe (exp(-2πi kn/N)) de (re, im) en place.
    forward(re, im) {
        const { n, m, cr, ci, br, bi, wr, wi } = this;
        wr.fill(0); wi.fill(0);
        for (let k = 0; k < n; ++k) {
            wr[k] = re[k] * cr[k] - im[k] * ci[k];
            wi[k] = re[k] * ci[k] + im[k] * cr[k];
        }
        this.fft.run(wr, wi, false);
        for (let k = 0; k < m; ++k) {
            const r = wr[k] * br[k] - wi[k] * bi[k], i = wr[k] * bi[k] + wi[k] * br[k];
            wr[k] = r; wi[k] = i;
        }
        this.fft.run(wr, wi, true);
        for (let k = 0; k < n; ++k) {
            const r = wr[k] / m, i = wi[k] / m;
            re[k] = r * cr[k] - i * ci[k];
            im[k] = r * ci[k] + i * cr[k];
        }
    }
    // Transformée inverse (exp(+2πi kn/N) / N) en place : conj(DFT(conj(x))) / N.
    inverse(re, im) {
        for (let k = 0; k < this.n; ++k) im[k] = -im[k];
        this.forward(re, im);
        const s = 1 / this.n;
        for (let k = 0; k < this.n; ++k) { re[k] *= s; im[k] = -im[k] * s; }
    }
}

// STFT / ISTFT façon torch (center=True, miroir) — ancienne version.
class RefStft {
    constructor({ nFft, hop, dimF, dimT } = MDX) {
        this.nFft = nFft; this.hop = hop; this.dimF = dimF; this.dimT = dimT;
        this.chunk = hop * (dimT - 1);
        this.dft = new RefBluestein(nFft);
        this.win = new Float64Array(nFft);
        for (let i = 0; i < nFft; ++i) this.win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / nFft);   // Hann périodique
        this.re = new Float64Array(nFft);
        this.im = new Float64Array(nFft);
    }
    // l, r : segment stéréo de this.chunk échantillons → spectre [4, dimF, dimT] (bandes < 3 à zéro).
    forward(l, r, out) {
        const { nFft, hop, dimF, dimT, chunk, re, im, win } = this;
        const half = nFft / 2, F = dimF, T = dimT;
        const at = (x, m) => x[m < 0 ? -m : (m >= chunk ? 2 * (chunk - 1) - m : m)];
        for (let t = 0; t < T; ++t) {
            const base = t * hop - half;
            for (let i = 0; i < nFft; ++i) {
                const w = win[i];
                re[i] = at(l, base + i) * w;   // deux canaux réels en un seul passage : z = l + i·r
                im[i] = at(r, base + i) * w;
            }
            this.dft.forward(re, im);
            for (let f = 0; f < F; ++f) {
                const g = f === 0 ? 0 : nFft - f;
                const zr = re[f], zi = im[f], cr = re[g], ci = -im[g];   // conj(Z[N-f])
                const lr = 0.5 * (zr + cr), li = 0.5 * (zi + ci);          // L = (Z + conj Z[N-f]) / 2
                const rr = 0.5 * (zi - ci), ri = -0.5 * (zr - cr);         // R = (Z - conj Z[N-f]) / 2i
                const keep = f >= 3 ? 1 : 0;
                out[(0 * F + f) * T + t] = lr * keep;
                out[(1 * F + f) * T + t] = li * keep;
                out[(2 * F + f) * T + t] = rr * keep;
                out[(3 * F + f) * T + t] = ri * keep;
            }
        }
    }
    // Spectre [4, dimF, dimT] → segment stéréo de this.chunk échantillons (somme de recouvrement normalisée par Σ w²).
    inverse(spec, outL, outR) {
        const { nFft, hop, dimF, dimT, chunk, re, im, win } = this;
        const half = nFft / 2, F = dimF, T = dimT, total = hop * (T - 1) + nFft;
        const yl = new Float64Array(total), yr = new Float64Array(total), env = new Float64Array(total);
        for (let t = 0; t < T; ++t) {
            re.fill(0); im.fill(0);
            // z = L + i·R (deux spectres hermitiens) : Z[f] = L[f] + i R[f], Z[N-f] = conj(L[f]) + i conj(R[f]).
            for (let f = 0; f < F; ++f) {
                const lr = spec[(0 * F + f) * T + t], li = spec[(1 * F + f) * T + t];
                const rr = spec[(2 * F + f) * T + t], ri = spec[(3 * F + f) * T + t];
                re[f] = lr - ri; im[f] = li + rr;
                if (f > 0) { re[nFft - f] = lr + ri; im[nFft - f] = -li + rr; }
            }
            this.dft.inverse(re, im);
            const o = t * hop;
            for (let i = 0; i < nFft; ++i) {
                const w = win[i];
                yl[o + i] += re[i] * w;
                yr[o + i] += im[i] * w;
                env[o + i] += w * w;
            }
        }
        for (let m = 0; m < chunk; ++m) {
            const e = env[m + half];
            const g = e > 1e-11 ? 1 / e : 0;
            outL[m] = yl[m + half] * g;
            outR[m] = yr[m + half] * g;
        }
    }
}

// Ancienne séparation (un seul appel), avec l'ancienne STFT.
async function refSeparateVocals(left, right, runModel, onProgress = () => {}, cfg = MDX, opts = {}) {
    const stft = new RefStft(cfg);
    const n = left.length, trim = cfg.nFft / 2, chunk = stft.chunk, gen = chunk - 2 * trim;
    // opts.peak : crête du morceau entier quand on traite une tranche (même niveau d'entrée pour toutes les tranches).
    let peak = 0;
    for (let i = 0; i < n; ++i) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
    if (peak < 1e-6) return { left: new Float32Array(n), right: new Float32Array(n) };
    if (Number.isFinite(opts.peak) && opts.peak >= peak) peak = opts.peak;
    const pad = gen + trim - (n % gen);
    const len = trim + n + pad;
    const ml = new Float32Array(len), mr = new Float32Array(len);
    for (let i = 0; i < n; ++i) { ml[trim + i] = left[i] / peak; mr[trim + i] = right[i] / peak; }
    const overlap = Number.isFinite(opts.overlap) ? Math.min(0.5, Math.max(0, opts.overlap)) : cfg.overlap;
    const step = Math.floor((1 - overlap) * chunk);
    const skipRms = Number.isFinite(opts.skipBelowDb) ? Math.pow(10, opts.skipBelowDb / 20) : -1;   // signal normalisé à crête 1
    const resL = new Float64Array(len), resR = new Float64Array(len), div = new Float64Array(len);
    const spec = new Float32Array(4 * cfg.dimF * cfg.dimT);
    const neg = opts.denoise ? new Float32Array(spec.length) : null;
    const cl = new Float32Array(chunk), cr = new Float32Array(chunk);
    const ol = new Float32Array(chunk), or = new Float32Array(chunk);
    const total = Math.ceil(len / step);
    let done = 0;
    for (let start = 0; start < len; start += step) {
        const end = Math.min(start + chunk, len), actual = end - start;
        cl.fill(0); cr.fill(0);
        cl.set(ml.subarray(start, end)); cr.set(mr.subarray(start, end));
        let e = 0;
        if (skipRms > 0) { for (let i = 0; i < actual; ++i) e += cl[i] * cl[i] + cr[i] * cr[i]; e = Math.sqrt(e / Math.max(1, 2 * actual)); }
        const skipped = skipRms > 0 && e < skipRms;
        if (skipped) { ol.fill(0); or.fill(0); }
        else {
            stft.forward(cl, cr, spec);
            let voc = await runModel(spec);
            if (opts.denoise) {
                // Débruitage du modèle (comme « Denoise » d'UVR) : le réseau ajoute son propre bruit (crépitement dans
                // les aigus), qui ne change pas de signe avec l'entrée. Moyenne de modèle(x) et de −modèle(−x) : la voix
                // reste, ce bruit s'annule. Coût : deux calculs par morceau.
                const pos = Float32Array.from(voc);
                for (let i = 0; i < spec.length; ++i) neg[i] = -spec[i];
                const vneg = await runModel(neg);
                for (let i = 0; i < pos.length; ++i) pos[i] = 0.5 * (pos[i] - vneg[i]);
                voc = pos;
            }
            stft.inverse(voc, ol, or);
        }
        for (let i = 0; i < actual; ++i) {
            const w = actual > 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (actual - 1)) : 1;   // np.hanning (symétrique)
            resL[start + i] += ol[i] * w;
            resR[start + i] += or[i] * w;
            div[start + i] += w;
        }
        onProgress(++done, total, skipped);
    }
    const outL = new Float32Array(n), outR = new Float32Array(n);
    for (let i = 0; i < n; ++i) {
        const d = div[trim + i];
        const g = d > 1e-9 ? peak / d : 0;
        outL[i] = resL[trim + i] * g;
        outR[i] = resR[trim + i] * g;
    }
    return { left: outL, right: outR };
}

// ------------------------------------------------------------------ outils
let failed = false;
const check = (ok, text) => { if (!ok) failed = true; console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${text}`); };
function rng(seed) {   // mulberry32 : suite reproductible
    let a = seed >>> 0;
    return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const noise = (n, rnd, amp = 0.5) => { const x = new Float32Array(n); for (let i = 0; i < n; ++i) x[i] = amp * (2 * rnd() - 1); return x; };
// Écart relatif (norme de la différence / norme de la référence).
function relErr(a, b) {
    if (a.length !== b.length) return Infinity;
    let d = 0, e = 0;
    for (let i = 0; i < a.length; ++i) { const x = a[i] - b[i]; d += x * x; e += b[i] * b[i]; }
    return Math.sqrt(d / Math.max(e, 1e-300));
}
const db = (r) => 20 * Math.log10(Math.max(r, 1e-300));
// Faux modèle déterministe : gain par bande + terme non linéaire (le résultat dépend du contenu de chaque morceau).
const fakeModel = (cfg) => async (spec) => {
    const F = cfg.dimF, T = cfg.dimT, y = new Float32Array(spec.length);
    for (let c = 0; c < 4; ++c) for (let f = 0; f < F; ++f) {
        const g = 0.55 + 0.35 * Math.cos(0.013 * f + c), o = (c * F + f) * T;
        for (let t = 0; t < T; ++t) { const x = spec[o + t]; y[o + t] = g * x + 0.2 * Math.tanh(0.05 * x); }
    }
    return y;
};
// Le découpage de la page (app.js, sepStep) : tranches de « per » morceaux, crête de l'étape entière, assemblage.
async function byParts(L, R, cfg, opts, per, seen) {
    const n = L.length, grid = mdxGrid(n, cfg, opts.overlap);
    let peak = 0;
    for (let i = 0; i < n; ++i) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
    const outL = new Float32Array(n), outR = new Float32Array(n), prof = { chunks: 0, skipped: 0, parts: 0 };
    for (let k0 = 0; k0 < grid.total; k0 += per) {
        const part = mdxPart(grid, k0, Math.min(grid.total, k0 + per));
        const y = await separateVocals(L.slice(part.s0, part.s1), R.slice(part.s0, part.s1), fakeModel(cfg),
            (d, t, sk) => seen.push([d, t, sk]), cfg, { ...opts, peak, part: { n, k0: part.k0, k1: part.k1 } });
        if (y.left.length !== part.p1 - part.p0) throw new Error(`tranche ${k0} : ${y.left.length} échantillons au lieu de ${part.p1 - part.p0}`);
        mdxPartAdd(grid, part, y, outL, outR);
        prof.chunks += y.profile.chunks; prof.skipped += y.profile.skipped; ++prof.parts;
    }
    mdxFinish(grid, outL, outR);
    return { left: outL, right: outR, grid, prof };
}

// ------------------------------------------------------------------ 1) FFT contre DFT naïve
{
    const rnd = rng(1);
    let worst = 0;
    const sizes = [2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 16, 18, 20, 24, 25, 27, 30, 32, 45, 60, 64, 75, 120, 128, 240, 480, 960];
    for (const n of sizes) {
        const fft = new MixedFft(n), xr = new Float64Array(n), xi = new Float64Array(n), yr = new Float64Array(n), yi = new Float64Array(n);
        for (let i = 0; i < n; ++i) { xr[i] = 2 * rnd() - 1; xi[i] = 2 * rnd() - 1; }
        fft.transform(xr, xi, yr, yi);
        const nr = new Float64Array(n), ni = new Float64Array(n);
        for (let k = 0; k < n; ++k) for (let j = 0; j < n; ++j) {
            const a = -2 * Math.PI * ((k * j) % n) / n, c = Math.cos(a), s = Math.sin(a);
            nr[k] += xr[j] * c - xi[j] * s; ni[k] += xr[j] * s + xi[j] * c;
        }
        let e = Math.max(relErr(yr, nr), relErr(yi, ni));
        // inverse × N par échange des parties réelle et imaginaire : on doit retrouver l'entrée
        const br = new Float64Array(n), bi = new Float64Array(n);
        fft.transform(yi, yr, bi, br);
        for (let i = 0; i < n; ++i) { br[i] /= n; bi[i] /= n; }
        e = Math.max(e, relErr(br, xr), relErr(bi, xi));
        worst = Math.max(worst, e);
    }
    check(worst < 1e-12, `FFT à bases mixtes contre DFT naïve, ${sizes.length} tailles de 2 à 960, aller et retour : écart relatif max ${worst.toExponential(1)} (limite 1e-12)`);
    // Aux vraies tailles des modèles (DFT naïve avec table de cosinus).
    let big = 0;
    for (const n of [7680, 5120, 6144]) {
        const fft = new MixedFft(n), xr = new Float64Array(n), xi = new Float64Array(n), yr = new Float64Array(n), yi = new Float64Array(n);
        const c = new Float64Array(n), s = new Float64Array(n), nr = new Float64Array(n), ni = new Float64Array(n);
        for (let i = 0; i < n; ++i) { xr[i] = 2 * rnd() - 1; xi[i] = 2 * rnd() - 1; c[i] = Math.cos(-2 * Math.PI * i / n); s[i] = Math.sin(-2 * Math.PI * i / n); }
        fft.transform(xr, xi, yr, yi);
        for (let k = 0; k < n; ++k) {
            let ar = 0, ai = 0;
            for (let j = 0, q = 0; j < n; ++j, q = (q + k) % n) { ar += xr[j] * c[q] - xi[j] * s[q]; ai += xr[j] * s[q] + xi[j] * c[q]; }
            nr[k] = ar; ni[k] = ai;
        }
        big = Math.max(big, relErr(yr, nr), relErr(yi, ni));
    }
    check(big < 1e-12, `FFT à bases mixtes contre DFT naïve aux tailles des modèles (7680, 5120, 6144) : écart relatif max ${big.toExponential(1)} (limite 1e-12)`);
    check(!MixedFft.supports(7) && !MixedFft.supports(7680 * 7) && MixedFft.supports(7680) && MixedFft.supports(5120) && MixedFft.supports(6144), 'tailles prises en charge : 7680, 5120, 6144 oui ; multiples de 7 non');
}

// ------------------------------------------------------------------ 2) STFT / ISTFT contre l'ancienne version
for (const key of ['voc', 'kara', 'reverb']) {
    const cfg = MODELS[key], rnd = rng(100 + key.length), neu = new MdxStft(cfg), ref = new RefStft(cfg);
    const n = neu.chunk, size = 4 * cfg.dimF * cfg.dimT;
    let eF = 0, eI = 0, eB = 0, tRef = 0, tNew = 0;
    const REPS = 2;
    for (let rep = 0; rep < REPS; ++rep) {
        const l = noise(n, rnd), r = noise(n, rnd);
        if (rep === 1) { l.fill(0, 0, n >> 2); for (let i = 0; i < n; ++i) r[i] = 0.3 * Math.sin(i * 0.05) + 0.1 * r[i]; }   // silence au bord, son pur
        const a = new Float32Array(size), b = new Float32Array(size);
        let t0 = performance.now(); ref.forward(l, r, a); const t1 = performance.now(); neu.forward(l, r, b); let t2 = performance.now();
        tRef += t1 - t0; tNew += t2 - t1;
        eF = Math.max(eF, relErr(b, a));
        for (let f = 0; f < 3; ++f) for (let c = 0; c < 4; ++c) for (let t = 0; t < cfg.dimT; ++t) if (b[(c * cfg.dimF + f) * cfg.dimT + t] !== 0) eF = Infinity;   // bandes < 3 à zéro
        // spectre quelconque (pas celui d'un vrai signal) : celui du signal, modifié bande par bande + bruit
        const spec = (await fakeModel(cfg)(a)).map((x) => x + 0.01 * (2 * rnd() - 1));
        const al = new Float32Array(n), ar = new Float32Array(n), bl = new Float32Array(n), br = new Float32Array(n);
        t0 = performance.now(); ref.inverse(spec, al, ar); const t3 = performance.now(); neu.inverse(spec, bl, br); t2 = performance.now();
        tRef += t3 - t0; tNew += t2 - t3;
        eI = Math.max(eI, relErr(bl, al), relErr(br, ar));
        // aller-retour : ISTFT(STFT(x)) = x filtré (bandes < 3 et > dimF retirées) ; même résultat que l'ancienne chaîne
        ref.inverse(a, al, ar); neu.inverse(b, bl, br);
        eB = Math.max(eB, relErr(bl, al), relErr(br, ar));
    }
    check(eF <= 1e-5 && eI <= 1e-5 && eB <= 1e-5, `${key} (n_fft ${cfg.nFft}, ${cfg.dimT} trames) : écart relatif spectre ${eF.toExponential(1)}, signal reconstruit ${eI.toExponential(1)}, ` +
        `aller-retour ${eB.toExponential(1)} (limite 1e-5) — transformées par morceau : ancien ${(tRef / REPS).toFixed(0)} ms, nouveau ${(tNew / REPS).toFixed(0)} ms (÷ ${(tRef / tNew).toFixed(1)})`);
}

// ------------------------------------------------------------------ 3) un seul appel : nouveau contre ancien
{
    const cfg = MODELS.kara, rnd = rng(7), n = 12 * 44100 + 321;
    const L = noise(n, rnd, 0.4), R = noise(n, rnd, 0.4);
    L.fill(0, 5 * 44100, 11 * 44100); R.fill(0, 5 * 44100, 11 * 44100);   // 6 s de silence : au moins un morceau sauté
    const opts = { overlap: 0.25, skipBelowDb: -45, peak: 0.6 };
    const pa = [], pb = [];
    const a = await refSeparateVocals(L, R, fakeModel(cfg), (d, t, sk) => pa.push(`${d}/${t}${sk ? 's' : ''}`), cfg, opts);
    const b = await separateVocals(L, R, fakeModel(cfg), (d, t, sk) => pb.push(`${d}/${t}${sk ? 's' : ''}`), cfg, opts);
    const e = Math.max(relErr(b.left, a.left), relErr(b.right, a.right));
    check(e <= 1e-5 && pa.join() === pb.join() && b.profile.skipped >= 1, `un seul appel (karaoké, 12 s, ${b.profile.chunks} morceaux calculés, ${b.profile.skipped} sauté(s)) : nouveau contre ancien, écart relatif ${e.toExponential(1)} (limite 1e-5), même progression (${pb.at(-1)})`);
    const z = await separateVocals(new Float32Array(1000), new Float32Array(1000), fakeModel(cfg), () => {}, cfg, {});
    check(z.left.length === 1000 && z.left.every((x) => x === 0) && z.profile.chunks === 0, 'signal nul : sortie nulle, aucun calcul');
}

// ------------------------------------------------------------------ 4) tranches de morceaux contre un seul appel
{
    // Petit réglage (même structure que les modèles, 480 = 2⁵·3·5) pour essayer beaucoup de découpages, puis un vrai réglage.
    const small = { nFft: 480, hop: 64, dimF: 200, dimT: 32, overlap: 0.25 };
    const gen = 64 * 31 - 480;
    const cases = [
        { name: 'longueur quelconque', cfg: small, n: 50001, per: [1, 2, 3, 9, 1000], opts: { overlap: 0.25 } },
        { name: 'silences sautés', cfg: small, n: 61234, per: [1, 4, 9], opts: { overlap: 0.25, skipBelowDb: -45 }, quiet: [[9000, 21000], [40000, 61234]] },
        { name: 'longueur multiple du pas (fin dans le remplissage)', cfg: small, n: 20 * gen, per: [1, 3, 7], opts: { overlap: 0.25, skipBelowDb: -45 } },
        { name: 'plus court qu\'un morceau', cfg: small, n: 700, per: [1, 2], opts: { overlap: 0.25 } },
        { name: 'recouvrement 0,5 et débruitage', cfg: small, n: 30011, per: [2, 5], opts: { overlap: 0.5, denoise: true, skipBelowDb: -50 }, quiet: [[100, 9000]] },
        { name: 'vrai réglage karaoké, 31 s', cfg: MODELS.kara, n: 31 * 44100 + 77, per: [3], opts: { overlap: 0.25, skipBelowDb: -45 }, quiet: [[9 * 44100, 19 * 44100]] },
    ];
    for (const c of cases) {
        const rnd = rng(1000 + c.n), L = noise(c.n, rnd, 0.3), R = noise(c.n, rnd, 0.3);
        for (const [a, b] of c.quiet || []) { for (let i = a; i < b; ++i) { L[i] *= 1e-4; R[i] *= 1e-4; } }
        let peak = 0;
        for (let i = 0; i < c.n; ++i) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
        const one = await separateVocals(L, R, fakeModel(c.cfg), () => {}, c.cfg, { ...c.opts, peak });
        let worst = -Infinity, ok = true, note = '';
        for (const per of c.per) {
            const seen = [], p = await byParts(L, R, c.cfg, c.opts, per, seen);
            const e = db(Math.max(relErr(p.left, one.left), relErr(p.right, one.right)));
            worst = Math.max(worst, e);
            // mêmes morceaux calculés et sautés qu'en un seul appel ; progression = n° du morceau dans l'étape entière
            const order = seen.every(([d, t], i) => d === i + 1 && t === p.grid.total) && seen.length === p.grid.total;
            if (!(e <= -90) || p.prof.chunks !== one.profile.chunks || p.prof.skipped !== one.profile.skipped || !order) ok = false;
            note = `${one.profile.chunks} calculés, ${one.profile.skipped} sautés`;
        }
        check(ok && (!c.quiet || one.profile.skipped > 0), `tranches contre un seul appel — ${c.name} (${c.n} échantillons, ${note}, tranches de ${c.per.join(' / ')} morceaux) : écart max ${worst.toFixed(0)} dB (limite -90 dB)`);
    }
    // Nombre de morceaux à calculer (ceux qui contiennent du signal ; ceux qui tombent dans le remplissage final sont
    // sautés) : ancien découpage de la page (tranches de 40 s + 2 s de marge de chaque côté, chacune sur sa propre
    // grille) contre la grille unique, pour une chanson de 3 min 35.
    const n = 215 * 44100, core = 40 * 44100, margin = 2 * 44100;
    const withSignal = (g) => Math.min(g.total, Math.ceil((g.trim + g.n) / g.step));
    let before = 0;
    for (let a = 0; a < n; a += core) before += withSignal(mdxGrid(Math.min(n, a + core + margin) - Math.max(0, a - margin), MDX, 0.25));
    const after = withSignal(mdxGrid(n, MDX, 0.25));
    check(after < before, `chanson de 3 min 35, étape voix : ${before} morceaux à calculer avec les tranches de 44 s (marges calculées deux fois), ${after} sur une seule grille (-${(100 * (1 - after / before)).toFixed(0)} %)`);
}

console.log(failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
