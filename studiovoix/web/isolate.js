// StudioVoix Web : isolation de la voix (IA) — modèle MDX-Net UVR-MDX-NET-Voc_FT (licence MIT, projet Ultimate Vocal
// Remover), exécuté par ONNX Runtime Web (carte graphique WebGPU si disponible, sinon processeur WASM multi-cœur).
// Garde uniquement la voix de la prise : musique extérieure (radio, télé, voisin), restes de l'instru, bruits.
//
// Reprise fidèle du prétraitement de python-audio-separator (MDXSeparator + STFT) :
//   44,1 kHz stéréo ; STFT n_fft 7680, pas 1024, fenêtre de Hann périodique, centrée (bords en miroir) ;
//   segments de 256 trames (chunk = 1024 × 255 échantillons), marge de 3840 échantillons, recouvrement 25 %
//   (fenêtre de Hann sur le segment) ; entrée du modèle [1, 4, 3072, 256] = (G réel, G imag., D réel, D imag.) × bandes
//   × trames, 3 premières bandes à zéro ; sortie = spectre de la voix, même forme ; ISTFT ; signal normalisé en crête
//   avant le modèle puis remis à son niveau.
// Module ES sans dépendance : utilisable dans un Web Worker (page) et dans Node (tests).

export const MDX = Object.freeze({
    sampleRate: 44100,
    nFft: 7680,
    hop: 1024,
    dimF: 3072,
    dimT: 256,
    overlap: 0.25,
    modelFile: 'UVR-MDX-NET-Voc_FT.onnx',
    modelBytes: 66762490,
    modelSha256: '534b2070fcc7df514b13ef660dc8cbb328679c2374d04354a5c42bb14ecce111',
    compensate: 1.021,   // réglage UVR (model_data, empreinte 77d07b2667ddf05b9e3175941b4454a0) : sortie × compensate
    primary: 'Vocals',
    label: 'voix',
});

// Modèles MDX-Net utilisés par « Séparer » (même architecture et même découpe ; réglages UVR model_data_new.json, repérés
// par l'empreinte UVR = md5 des 10 derniers Mo du fichier). primary = ce que le modèle rend ; l'autre partie = entrée − rendu.
export const MODELS = Object.freeze({
    voc: MDX,
    // UVR-MDX-NET Karaoke 2 (empreinte 1d64a6d2c30f709b8c9b4ce1366d96ee) : rend tout sauf la voix principale ; appliqué
    // aux voix seules, il rend les backs (chœurs, harmonies) ; voix principale = voix − backs.
    kara: Object.freeze({
        sampleRate: 44100, nFft: 5120, hop: 1024, dimF: 2048, dimT: 256, overlap: 0.25,
        modelFile: 'UVR_MDXNET_KARA_2.onnx', modelBytes: 52786726,
        modelSha256: 'bf32e15105a09c0f7dddd2b67346146334d6f3ecb399ed7638eba2ab07cbf5f4',
        compensate: 1.065, primary: 'Instrumental', label: 'voix principale / backs',
    }),
    // Reverb HQ by FoxJoy (empreinte cd5b2989ad863f116c855db1dfe24e39) : rend la réverb / l'écho de la voix ; voix sèche
    // = voix − réverb. Segments de 512 trames.
    reverb: Object.freeze({
        sampleRate: 44100, nFft: 6144, hop: 1024, dimF: 3072, dimT: 512, overlap: 0.25,
        modelFile: 'Reverb_HQ_By_FoxJoy.onnx', modelBytes: 66780123,
        modelSha256: '233bb5c6aaa365e568659a0a81211746fa881f8f47f82d9e864fce1f7692db80',
        compensate: 1.035, primary: 'Reverb', label: 'voix sèche / ambiance',
    }),
    // WeSpeaker ResNet34 VoxCeleb (sherpa-onnx, licence Apache-2.0) : empreinte de voix (256 valeurs) pour repérer les
    // chanteurs qui alternent (singers.js). Entrée fbank [1, T, 80] à 16 kHz.
    spk: Object.freeze({
        type: 'speaker', modelFile: 'wespeaker_en_voxceleb_resnet34.onnx', modelBytes: 26534365,
        modelSha256: '5ef208a9da1453335308a6b6f4e6dfbd7e183a38b604de0a57664f45d257fe94', label: 'empreinte de voix',
    }),
});

// ------------------------------------------------------------------ FFT
// FFT complexe à bases mixtes (2, 3, 4, 5) : les tailles des modèles (7680 = 2⁹·3·5, 5120 = 2¹⁰·5, 6144 = 2¹¹·3) sont
// calculées directement, sans passer par deux FFT de 16 384 points (Bluestein) : même transformée, moins de calcul.
// Découpe « dans le temps » : une taille L = p·M se calcule à partir de p transformées de taille M (un échantillon sur
// p), X[k + q·M] = Σ_r W_p^(rq) · W_L^(rk) · Y_r[k]. Entrée rangée d'avance dans l'ordre voulu (perm), puis étages en place.
export class MixedFft {
    static supports(n) {
        if (!Number.isInteger(n) || n < 2) return false;
        for (const p of [2, 3, 5]) while (n % p === 0) n /= p;
        return n === 1;
    }
    constructor(n) {
        if (!MixedFft.supports(n)) throw new Error(`taille de FFT non prise en charge : ${n} (facteurs 2, 3 et 5 seulement)`);
        this.n = n;
        // Bases, du plus petit bloc au plus grand : 5 et 3 d'abord, puis 4, et un 2 s'il en reste un.
        const f = [];
        let m = n;
        while (m % 5 === 0) { f.push(5); m /= 5; }
        while (m % 3 === 0) { f.push(3); m /= 3; }
        while (m % 4 === 0) { f.push(4); m /= 4; }
        if (m === 2) f.push(2);
        this.factors = f;
        this.perm = new Uint32Array(n);   // perm[i] = place de l'échantillon i avant les étages
        for (let i = 0; i < n; ++i) {
            let x = i, size = n, pos = 0;
            for (let s = f.length - 1; s >= 0; --s) { const p = f[s], r = x % p; size /= p; pos += r * size; x = (x - r) / p; }
            this.perm[i] = pos;
        }
        // Facteurs de phase par étage : pour k < M et r = 1 … p − 1, exp(−2πi·r·k / L) (cos, sin) à la suite.
        this.tw = [];
        let M = 1;
        for (const p of f) {
            const L = M * p, tw = new Float64Array(2 * (p - 1) * M);
            for (let k = 0; k < M; ++k) {
                for (let r = 1; r < p; ++r) {
                    const a = -2 * Math.PI * ((r * k) % L) / L, j = 2 * (k * (p - 1) + r - 1);
                    tw[j] = Math.cos(a); tw[j + 1] = Math.sin(a);
                }
            }
            this.tw.push(tw);
            M = L;
        }
    }
    // (yr, yi) = transformée directe (exp(−2πi kn/N)) de (xr, xi) ; l'entrée n'est pas modifiée ; x et y distincts.
    // Transformée inverse × N : échanger les parties réelle et imaginaire à l'entrée et à la sortie, transform(xi, xr, yi, yr).
    transform(xr, xi, yr, yi) {
        const n = this.n, perm = this.perm, f = this.factors;
        for (let i = 0; i < n; ++i) { const p = perm[i]; yr[p] = xr[i]; yi[p] = xi[i]; }
        let M = 1;
        for (let s = 0; s < f.length; ++s) {
            const p = f[s], L = M * p, tw = this.tw[s];
            if (p === 4) {
                for (let b = 0; b < n; b += L) {
                    for (let k = 0, j = 0; k < M; ++k, j += 6) {
                        const i0 = b + k, i1 = i0 + M, i2 = i1 + M, i3 = i2 + M;
                        const t0r = yr[i0], t0i = yi[i0];
                        const t1r = yr[i1] * tw[j] - yi[i1] * tw[j + 1], t1i = yr[i1] * tw[j + 1] + yi[i1] * tw[j];
                        const t2r = yr[i2] * tw[j + 2] - yi[i2] * tw[j + 3], t2i = yr[i2] * tw[j + 3] + yi[i2] * tw[j + 2];
                        const t3r = yr[i3] * tw[j + 4] - yi[i3] * tw[j + 5], t3i = yr[i3] * tw[j + 5] + yi[i3] * tw[j + 4];
                        const ar = t0r + t2r, ai = t0i + t2i, br = t0r - t2r, bi = t0i - t2i;
                        const cr = t1r + t3r, ci = t1i + t3i, dr = t1r - t3r, di = t1i - t3i;
                        yr[i0] = ar + cr; yi[i0] = ai + ci;
                        yr[i1] = br + di; yi[i1] = bi - dr;   // b − i·d
                        yr[i2] = ar - cr; yi[i2] = ai - ci;
                        yr[i3] = br - di; yi[i3] = bi + dr;   // b + i·d
                    }
                }
            } else if (p === 2) {
                for (let b = 0; b < n; b += L) {
                    for (let k = 0, j = 0; k < M; ++k, j += 2) {
                        const i0 = b + k, i1 = i0 + M;
                        const tr = yr[i1] * tw[j] - yi[i1] * tw[j + 1], ti = yr[i1] * tw[j + 1] + yi[i1] * tw[j];
                        yr[i1] = yr[i0] - tr; yi[i1] = yi[i0] - ti;
                        yr[i0] += tr; yi[i0] += ti;
                    }
                }
            } else if (p === 3) {
                const h = Math.sqrt(3) / 2;
                for (let b = 0; b < n; b += L) {
                    for (let k = 0, j = 0; k < M; ++k, j += 4) {
                        const i0 = b + k, i1 = i0 + M, i2 = i1 + M;
                        const t1r = yr[i1] * tw[j] - yi[i1] * tw[j + 1], t1i = yr[i1] * tw[j + 1] + yi[i1] * tw[j];
                        const t2r = yr[i2] * tw[j + 2] - yi[i2] * tw[j + 3], t2i = yr[i2] * tw[j + 3] + yi[i2] * tw[j + 2];
                        const sr = t1r + t2r, si = t1i + t2i, dr = h * (t1r - t2r), di = h * (t1i - t2i);
                        const mr = yr[i0] - 0.5 * sr, mi = yi[i0] - 0.5 * si;
                        yr[i0] += sr; yi[i0] += si;
                        yr[i1] = mr + di; yi[i1] = mi - dr;
                        yr[i2] = mr - di; yi[i2] = mi + dr;
                    }
                }
            } else {   // p === 5
                const c1 = Math.cos(2 * Math.PI / 5), s1 = Math.sin(2 * Math.PI / 5), c2 = Math.cos(4 * Math.PI / 5), s2 = Math.sin(4 * Math.PI / 5);
                for (let b = 0; b < n; b += L) {
                    for (let k = 0, j = 0; k < M; ++k, j += 8) {
                        const i0 = b + k, i1 = i0 + M, i2 = i1 + M, i3 = i2 + M, i4 = i3 + M;
                        const t0r = yr[i0], t0i = yi[i0];
                        const t1r = yr[i1] * tw[j] - yi[i1] * tw[j + 1], t1i = yr[i1] * tw[j + 1] + yi[i1] * tw[j];
                        const t2r = yr[i2] * tw[j + 2] - yi[i2] * tw[j + 3], t2i = yr[i2] * tw[j + 3] + yi[i2] * tw[j + 2];
                        const t3r = yr[i3] * tw[j + 4] - yi[i3] * tw[j + 5], t3i = yr[i3] * tw[j + 5] + yi[i3] * tw[j + 4];
                        const t4r = yr[i4] * tw[j + 6] - yi[i4] * tw[j + 7], t4i = yr[i4] * tw[j + 7] + yi[i4] * tw[j + 6];
                        const p1r = t1r + t4r, p1i = t1i + t4i, d1r = t1r - t4r, d1i = t1i - t4i;
                        const p2r = t2r + t3r, p2i = t2i + t3i, d2r = t2r - t3r, d2i = t2i - t3i;
                        const ar = t0r + c1 * p1r + c2 * p2r, ai = t0i + c1 * p1i + c2 * p2i;
                        const br = t0r + c2 * p1r + c1 * p2r, bi = t0i + c2 * p1i + c1 * p2i;
                        const ur = s1 * d1r + s2 * d2r, ui = s1 * d1i + s2 * d2i;
                        const vr = s2 * d1r - s1 * d2r, vi = s2 * d1i - s1 * d2i;
                        yr[i0] = t0r + p1r + p2r; yi[i0] = t0i + p1i + p2i;
                        yr[i1] = ar + ui; yi[i1] = ai - ur;
                        yr[i2] = br + vi; yi[i2] = bi - vr;
                        yr[i3] = br - vi; yi[i3] = bi + vr;
                        yr[i4] = ar - ui; yi[i4] = ai + ur;
                    }
                }
            }
            M = L;
        }
    }
}

// ------------------------------------------------------------------ STFT / ISTFT façon torch (center=True, miroir)
export class MdxStft {
    constructor({ nFft, hop, dimF, dimT } = MDX) {
        this.nFft = nFft; this.hop = hop; this.dimF = dimF; this.dimT = dimT;
        this.chunk = hop * (dimT - 1);
        this.dft = new MixedFft(nFft);
        this.win = new Float64Array(nFft);
        for (let i = 0; i < nFft; ++i) this.win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / nFft);   // Hann périodique
        this.re = new Float64Array(nFft);
        this.im = new Float64Array(nFft);
        this.xr = new Float64Array(nFft);   // entrée de la FFT (la sortie va dans re, im)
        this.xi = new Float64Array(nFft);
        // Segment prolongé en miroir de nFft / 2 de chaque côté (center=True), rempli à chaque appel de forward.
        this.pl = new Float32Array(this.chunk + nFft);
        this.pr = new Float32Array(this.chunk + nFft);
        // ISTFT : tampons de la somme de recouvrement, et 1 / Σ w² (ne dépend que de la fenêtre : calculé une fois).
        const total = hop * (dimT - 1) + nFft, half = nFft / 2, env = new Float64Array(total);
        this.yl = new Float64Array(total);
        this.yr = new Float64Array(total);
        for (let t = 0; t < dimT; ++t) {
            const o = t * hop;
            for (let i = 0; i < nFft; ++i) { const w = this.win[i]; env[o + i] += w * w; }
        }
        this.gain = new Float64Array(this.chunk);
        for (let m = 0; m < this.chunk; ++m) { const e = env[m + half]; this.gain[m] = e > 1e-11 ? 1 / e : 0; }
    }
    // l, r : segment stéréo de this.chunk échantillons → spectre [4, dimF, dimT] (bandes < 3 à zéro).
    forward(l, r, out) {
        const { nFft, hop, dimF, dimT, chunk, re, im, xr, xi, win, pl, pr } = this;
        const half = nFft / 2, F = dimF, T = dimT;
        // Miroir aux bords : indice m < 0 → −m ; m ≥ chunk → 2 (chunk − 1) − m.
        for (let q = 0; q < half; ++q) { pl[q] = l[half - q]; pr[q] = r[half - q]; }
        pl.set(l.subarray(0, chunk), half); pr.set(r.subarray(0, chunk), half);
        for (let q = 0; q < half; ++q) { pl[half + chunk + q] = l[chunk - 2 - q]; pr[half + chunk + q] = r[chunk - 2 - q]; }
        for (let t = 0; t < T; ++t) {
            const base = t * hop;
            for (let i = 0; i < nFft; ++i) {
                const w = win[i];
                xr[i] = pl[base + i] * w;   // deux canaux réels en un seul passage : z = l + i·r
                xi[i] = pr[base + i] * w;
            }
            this.dft.transform(xr, xi, re, im);
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
        const { nFft, hop, dimF, dimT, chunk, re, im, xr, xi, win, yl, yr, gain } = this;
        const half = nFft / 2, F = dimF, T = dimT, inv = 1 / nFft;
        yl.fill(0); yr.fill(0);
        for (let t = 0; t < T; ++t) {
            xr.fill(0); xi.fill(0);
            // z = L + i·R (deux spectres hermitiens) : Z[f] = L[f] + i R[f], Z[N-f] = conj(L[f]) + i conj(R[f]).
            for (let f = 0; f < F; ++f) {
                const lr = spec[(0 * F + f) * T + t], li = spec[(1 * F + f) * T + t];
                const rr = spec[(2 * F + f) * T + t], ri = spec[(3 * F + f) * T + t];
                xr[f] = lr - ri; xi[f] = li + rr;
                if (f > 0) { xr[nFft - f] = lr + ri; xi[nFft - f] = -li + rr; }
            }
            this.dft.transform(xi, xr, im, re);   // transformée inverse × N (parties réelle et imaginaire échangées)
            const o = t * hop;
            for (let i = 0; i < nFft; ++i) {
                const w = win[i] * inv;
                yl[o + i] += re[i] * w;
                yr[o + i] += im[i] * w;
            }
        }
        for (let m = 0; m < chunk; ++m) {
            const g = gain[m];
            outL[m] = yl[m + half] * g;
            outR[m] = yr[m + half] * g;
        }
    }
}

// ------------------------------------------------------------------ séparation
// Grille des morceaux d'un signal de n échantillons : le signal est prolongé (trim zéros avant, pad zéros après) ; le
// morceau k couvre [k·step, k·step + chunk) de ce signal prolongé (le dernier peut être plus court). Positions « p »
// = dans le signal prolongé ; l'échantillon p correspond à l'échantillon p − trim du signal.
export function mdxGrid(n, cfg = MDX, overlap = cfg.overlap) {
    const trim = cfg.nFft / 2, chunk = cfg.hop * (cfg.dimT - 1), gen = chunk - 2 * trim;
    const pad = gen + trim - (n % gen), len = trim + n + pad;
    const ov = Number.isFinite(overlap) ? Math.min(0.5, Math.max(0, overlap)) : cfg.overlap;
    const step = Math.floor((1 - ov) * chunk);
    return { n, trim, chunk, len, step, total: Math.ceil(len / step) };
}
// Tranche de morceaux [k0, k1) de la grille : elle couvre [p0, p1) du signal prolongé et lit [s0, s1) du signal.
export function mdxPart(grid, k0, k1) {
    if (!Number.isInteger(k0) || !Number.isInteger(k1) || k0 < 0 || k1 <= k0 || k1 > grid.total) throw new Error(`tranche de morceaux invalide : ${k0} à ${k1} sur ${grid.total}`);
    const p0 = k0 * grid.step, p1 = Math.min((k1 - 1) * grid.step + grid.chunk, grid.len);
    const s0 = Math.min(grid.n, Math.max(0, p0 - grid.trim)), s1 = Math.max(s0, Math.min(grid.n, p1 - grid.trim));
    return { k0, k1, p0, p1, s0, s1 };
}
// Ajoute à l'étape entière (outL, outR : n échantillons) les sommes pondérées rendues pour une tranche de morceaux.
export function mdxPartAdd(grid, part, y, outL, outR) {
    const { trim, n } = grid;
    for (let p = Math.max(part.p0, trim), e = Math.min(part.p1, trim + n); p < e; ++p) {
        outL[p - trim] += y.left[p - part.p0];
        outR[p - trim] += y.right[p - part.p0];
    }
}
// Fin de l'assemblage : division par la somme des poids de tous les morceaux (fenêtre de Hann sur chaque morceau),
// comme le fait separateVocals en un seul appel. Toutes les tranches doivent avoir été ajoutées.
export function mdxFinish(grid, outL, outR) {
    const { trim, n, chunk, len, step, total } = grid;
    const div = new Float32Array(n), full = new Float64Array(chunk);
    for (let i = 0; i < chunk; ++i) full[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (chunk - 1));
    for (let k = 0; k < total; ++k) {
        const start = k * step, actual = Math.min(start + chunk, len) - start;
        for (let i = Math.max(0, trim - start), e = Math.min(actual, trim + n - start); i < e; ++i)
            div[start + i - trim] += actual === chunk ? full[i] : (actual > 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (actual - 1)) : 1);
    }
    for (let i = 0; i < n; ++i) {
        const d = div[i];
        if (d > 1e-9) { outL[i] /= d; outR[i] /= d; } else { outL[i] = 0; outR[i] = 0; }
    }
}

/**
 * Isole la voix d'un signal stéréo 44,1 kHz (Float32Array left/right de même longueur).
 * runModel(Float32Array [1,4,dimF,dimT]) → Promise<Float32Array> (spectre de la voix) ; onProgress(fait, total).
 * Retourne { left, right, profile } (voix seule ; profile = temps par poste, en ms : { chunks, skipped, stftMs,
 * modelMs, istftMs } — morceaux calculés / sautés, STFT aller, modèle, STFT retour).
 * opts.overlap : recouvrement des morceaux (défaut cfg.overlap) ; opts.skipBelowDb : un morceau dont le niveau RMS est
 * sous ce seuil (dB par rapport à la crête du signal) n'est pas calculé (sortie nulle) — passages sans voix à l'étape
 * voix principale / backs. opts.denoise : deux calculs par morceau, bruit propre au modèle annulé. opts.peak : crête de référence (tranche d'un morceau). onProgress(fait, total, sauté).
 * opts.part = { n, k0, k1 } : calcul d'une tranche de morceaux seulement (reprise après coupure, « Séparer »). Le signal
 * entier fait n échantillons ; left/right en sont la partie [s0, s1) de mdxPart(mdxGrid(n, cfg, overlap), k0, k1) ;
 * opts.peak (crête du signal entier) est obligatoire. Rend les sommes pondérées des morceaux k0 à k1 − 1 sur [p0, p1)
 * (pas encore divisées par la somme des poids : mdxPartAdd puis mdxFinish), de sorte que l'assemblage de toutes les
 * tranches égale un seul appel sur le signal entier, sans morceau calculé deux fois. onProgress(k + 1, total de la grille, sauté).
 */
export async function separateVocals(left, right, runModel, onProgress = () => {}, cfg = MDX, opts = {}) {
    const stft = new MdxStft(cfg);
    const part = opts.part || null;
    const n = part ? part.n : left.length;
    if (part && (!Number.isInteger(n) || n < left.length)) throw new Error('tranche de morceaux : longueur du signal entier invalide');
    const grid = mdxGrid(n, cfg, opts.overlap);
    const { trim, chunk, len, step, total } = grid;
    const range = part ? mdxPart(grid, part.k0, part.k1) : { k0: 0, k1: total, p0: 0, p1: len, s0: 0, s1: n };
    const span = range.p1 - range.p0;
    if (left.length !== range.s1 - range.s0 || right.length !== left.length) throw new Error(`tranche de morceaux : ${left.length} échantillons reçus, ${range.s1 - range.s0} attendus`);
    const prof = { chunks: 0, skipped: 0, stftMs: 0, modelMs: 0, istftMs: 0 };   // profil permanent : où part le temps
    // opts.peak : crête du morceau entier quand on traite une tranche (même niveau d'entrée pour toutes les tranches).
    let peak = 0;
    if (part) {
        if (!Number.isFinite(opts.peak) || opts.peak < 0) throw new Error('tranche de morceaux : crête du signal entier (opts.peak) obligatoire');
        peak = opts.peak;
        if (peak < 1e-6) return { left: new Float32Array(span), right: new Float32Array(span), profile: prof };
    } else {
        for (let i = 0; i < n; ++i) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
        if (peak < 1e-6) return { left: new Float32Array(n), right: new Float32Array(n), profile: prof };
        if (Number.isFinite(opts.peak) && opts.peak >= peak) peak = opts.peak;
    }
    // Signal prolongé, limité à [p0, p1) ; indices locaux = position − p0.
    const ml = new Float32Array(span), mr = new Float32Array(span);
    for (let i = 0, o = trim + range.s0 - range.p0; i < left.length; ++i) { ml[o + i] = left[i] / peak; mr[o + i] = right[i] / peak; }
    const skipRms = Number.isFinite(opts.skipBelowDb) ? Math.pow(10, opts.skipBelowDb / 20) : -1;   // signal normalisé à crête 1
    const resL = new Float64Array(span), resR = new Float64Array(span), div = new Float64Array(part ? 0 : span);
    const spec = new Float32Array(4 * cfg.dimF * cfg.dimT);
    const neg = opts.denoise ? new Float32Array(spec.length) : null;
    const cl = new Float32Array(chunk), cr = new Float32Array(chunk);
    const ol = new Float32Array(chunk), or = new Float32Array(chunk);
    for (let k = range.k0; k < range.k1; ++k) {
        const start = k * step - range.p0, end = Math.min(start + chunk, len - range.p0), actual = end - start;
        cl.fill(0); cr.fill(0);
        cl.set(ml.subarray(start, end)); cr.set(mr.subarray(start, end));
        let e = 0;
        if (skipRms > 0) { for (let i = 0; i < actual; ++i) e += cl[i] * cl[i] + cr[i] * cr[i]; e = Math.sqrt(e / Math.max(1, 2 * actual)); }
        const skipped = skipRms > 0 && e < skipRms;
        if (skipped) { ol.fill(0); or.fill(0); ++prof.skipped; }
        else {
            const t0 = performance.now();
            stft.forward(cl, cr, spec);
            const t1 = performance.now();
            let voc = await runModel(spec);
            prof.stftMs += t1 - t0; prof.modelMs += performance.now() - t1;
            if (opts.denoise) {
                // Débruitage du modèle (comme « Denoise » d'UVR) : le réseau ajoute son propre bruit (crépitement dans
                // les aigus), qui ne change pas de signe avec l'entrée. Moyenne de modèle(x) et de −modèle(−x) : la voix
                // reste, ce bruit s'annule. Coût : deux calculs par morceau.
                const pos = Float32Array.from(voc);
                for (let i = 0; i < spec.length; ++i) neg[i] = -spec[i];
                const t2 = performance.now();
                const vneg = await runModel(neg);
                prof.modelMs += performance.now() - t2;
                for (let i = 0; i < pos.length; ++i) pos[i] = 0.5 * (pos[i] - vneg[i]);
                voc = pos;
            }
            const t3 = performance.now();
            stft.inverse(voc, ol, or);
            prof.istftMs += performance.now() - t3; ++prof.chunks;
        }
        for (let i = 0; i < actual; ++i) {
            const w = actual > 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (actual - 1)) : 1;   // np.hanning (symétrique)
            resL[start + i] += ol[i] * w;
            resR[start + i] += or[i] * w;
            if (!part) div[start + i] += w;
        }
        onProgress(k + 1, total, skipped);
    }
    if (part) {
        // Sommes pondérées de la tranche, au niveau d'origine ; la page les assemble (mdxPartAdd, mdxFinish).
        const sumL = new Float32Array(span), sumR = new Float32Array(span);
        for (let i = 0; i < span; ++i) { sumL[i] = resL[i] * peak; sumR[i] = resR[i] * peak; }
        return { left: sumL, right: sumR, profile: prof };
    }
    const outL = new Float32Array(n), outR = new Float32Array(n);
    for (let i = 0; i < n; ++i) {
        const d = div[trim + i];
        const g = d > 1e-9 ? peak / d : 0;
        outL[i] = resL[trim + i] * g;
        outR[i] = resR[trim + i] * g;
    }
    return { left: outL, right: outR, profile: prof };
}
