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
});

// ------------------------------------------------------------------ FFT
// FFT complexe radix 2 en place (taille puissance de 2).
class Radix2 {
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
export class Bluestein {
    constructor(n) {
        this.n = n;
        let m = 1;
        while (m < 2 * n - 1) m <<= 1;
        this.m = m;
        this.fft = new Radix2(m);
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

// ------------------------------------------------------------------ STFT / ISTFT façon torch (center=True, miroir)
export class MdxStft {
    constructor({ nFft, hop, dimF, dimT } = MDX) {
        this.nFft = nFft; this.hop = hop; this.dimF = dimF; this.dimT = dimT;
        this.chunk = hop * (dimT - 1);
        this.dft = new Bluestein(nFft);
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

// ------------------------------------------------------------------ séparation
/**
 * Isole la voix d'un signal stéréo 44,1 kHz (Float32Array left/right de même longueur).
 * runModel(Float32Array [1,4,dimF,dimT]) → Promise<Float32Array> (spectre de la voix) ; onProgress(fait, total).
 * Retourne { left, right } (voix seule).
 */
export async function separateVocals(left, right, runModel, onProgress = () => {}, cfg = MDX) {
    const stft = new MdxStft(cfg);
    const n = left.length, trim = cfg.nFft / 2, chunk = stft.chunk, gen = chunk - 2 * trim;
    let peak = 0;
    for (let i = 0; i < n; ++i) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
    if (peak < 1e-6) return { left: new Float32Array(n), right: new Float32Array(n) };
    const pad = gen + trim - (n % gen);
    const len = trim + n + pad;
    const ml = new Float32Array(len), mr = new Float32Array(len);
    for (let i = 0; i < n; ++i) { ml[trim + i] = left[i] / peak; mr[trim + i] = right[i] / peak; }
    const step = Math.floor((1 - cfg.overlap) * chunk);
    const resL = new Float64Array(len), resR = new Float64Array(len), div = new Float64Array(len);
    const spec = new Float32Array(4 * cfg.dimF * cfg.dimT);
    const cl = new Float32Array(chunk), cr = new Float32Array(chunk);
    const ol = new Float32Array(chunk), or = new Float32Array(chunk);
    const total = Math.ceil(len / step);
    let done = 0;
    for (let start = 0; start < len; start += step) {
        const end = Math.min(start + chunk, len), actual = end - start;
        cl.fill(0); cr.fill(0);
        cl.set(ml.subarray(start, end)); cr.set(mr.subarray(start, end));
        stft.forward(cl, cr, spec);
        const voc = await runModel(spec);
        stft.inverse(voc, ol, or);
        for (let i = 0; i < actual; ++i) {
            const w = actual > 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (actual - 1)) : 1;   // np.hanning (symétrique)
            resL[start + i] += ol[i] * w;
            resR[start + i] += or[i] * w;
            div[start + i] += w;
        }
        onProgress(++done, total);
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
