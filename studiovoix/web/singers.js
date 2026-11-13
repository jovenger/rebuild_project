// StudioVoix Web : repérage des chanteurs qui alternent dans une voix séparée (« Séparer » → « par chanteur »).
// Phrases repérées par l'énergie, empreinte de voix (modèle WeSpeaker ResNet34, licence Apache-2.0) par fenêtre de 2 s
// + hauteur médiane, regroupement en autant de voix qu'il y en a (clusterVoices). (Essai écarté : timbre MFCC par phrase, dominé par les mots prononcés plutôt que par la
// personne : même voix coupée en deux, deux voix différentes non séparées.) Deux chanteurs qui chantent EN
// MÊME TEMPS ne sont pas séparés (aucune méthode fiable aujourd'hui).
// Module ES pur : utilisé par la page et par les essais Node.


export function fftReal(re, im) {   // FFT complexe radix 2 en place (exportée pour les essais)
    const n = re.length;
    for (let i = 1, j = 0; i < n; ++i) {
        let bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) { let t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
    }
    for (let len = 2; len <= n; len <<= 1) {
        const a = -2 * Math.PI / len, wr = Math.cos(a), wi = Math.sin(a);
        for (let i = 0; i < n; i += len) {
            let cr = 1, ci = 0;
            for (let k = 0; k < len / 2; ++k) {
                const p = i + k, q = p + len / 2;
                const xr = re[q] * cr - im[q] * ci, xi = re[q] * ci + im[q] * cr;
                re[q] = re[p] - xr; im[q] = im[p] - xi; re[p] += xr; im[p] += xi;
                const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
            }
        }
    }
}

/** Phrases (s) d'une voix mono : tranches de 50 ms au-dessus du seuil, trous < 0,3 s fusionnés, durée ≥ 0,8 s. */
export function findPhrases(mono, sr) {
    const hop = Math.round(0.05 * sr), lv = [];
    for (let s = 0; s + hop <= mono.length; s += hop) {
        let e = 0;
        for (let i = s; i < s + hop; ++i) e += mono[i] * mono[i];
        lv.push(10 * Math.log10(e / hop + 1e-20));
    }
    if (!lv.length) return [];
    const sorted = [...lv].sort((a, b) => a - b);
    const floor = sorted[Math.floor(sorted.length * 0.1)], peak = sorted[sorted.length - 1];
    const thr = Math.max(floor + 15, peak - 45);
    const out = [];
    let start = -1, lastOn = -1;
    for (let f = 0; f < lv.length; ++f) {
        if (lv[f] > thr) { if (start < 0) start = f; lastOn = f; }
        else if (start >= 0 && (f - lastOn) * 0.05 > 0.3) { out.push([start * 0.05, (lastOn + 1) * 0.05]); start = -1; }
    }
    if (start >= 0) out.push([start * 0.05, (lastOn + 1) * 0.05]);
    return out.filter(([a, b]) => b - a >= 0.8);
}

// ------------------------------------------------------------------ empreinte de voix (modèle WeSpeaker ResNet34)
// Préparation identique à WeSpeaker (infer_onnx.py) : 16 kHz, échantillons × 32768, fbank Kaldi 80 bandes (25 ms /
// 10 ms, fenêtre de Hamming, pré-accentuation 0,97, sans dither, bords coupés), puis moyenne retirée par bande.

/** Rééchantillonne vers 16 kHz (sinc fenêtré, 16 points de chaque côté). */
export function to16k(x, sr) {
    if (sr === 16000) return x.slice();
    const ratio = 16000 / sr, n = Math.floor(x.length * ratio), out = new Float32Array(n), half = 16, fc = Math.min(1, ratio) * 0.95;
    for (let i = 0; i < n; ++i) {
        const t = i / ratio, c = Math.floor(t);
        let acc = 0, wsum = 0;
        for (let k = c - half + 1; k <= c + half; ++k) {
            if (k < 0 || k >= x.length) continue;
            const d = t - k, w = 0.5 + 0.5 * Math.cos(Math.PI * d / half);
            const sinc = d === 0 ? 1 : Math.sin(Math.PI * fc * d) / (Math.PI * fc * d);
            acc += x[k] * sinc * w; wsum += sinc * w;
        }
        out[i] = wsum ? acc / wsum : 0;
    }
    return out;
}

const FB = { len: 400, shift: 160, nfft: 512, mels: 80 };
let fbCache = null;
function fbankFilters() {
    if (fbCache) return fbCache;
    const mel = (f) => 1127 * Math.log(1 + f / 700);
    const lo = mel(20), hi = mel(8000), step = (hi - lo) / (FB.mels + 1), bins = FB.nfft / 2;
    const filters = [];
    for (let m = 0; m < FB.mels; ++m) {
        const l = lo + m * step, c = lo + (m + 1) * step, r = lo + (m + 2) * step, w = new Float64Array(bins);
        for (let k = 0; k < bins; ++k) {
            const mk = mel(k * 16000 / FB.nfft);
            if (mk > l && mk < r) w[k] = mk <= c ? (mk - l) / (c - l) : (r - mk) / (r - c);
        }
        filters.push(w);
    }
    const win = new Float64Array(FB.len);
    for (let i = 0; i < FB.len; ++i) win[i] = 0.54 - 0.46 * Math.cos(2 * Math.PI * i / (FB.len - 1));
    fbCache = { filters, win };
    return fbCache;
}
/** fbank Kaldi 80 bandes d'un signal 16 kHz (−1..1) → Float32Array [T × 80] (moyenne retirée), T. */
export function fbank80(x16) {
    const { filters, win } = fbankFilters();
    const T = x16.length >= FB.len ? 1 + Math.floor((x16.length - FB.len) / FB.shift) : 0;
    const out = new Float32Array(T * FB.mels), re = new Float64Array(FB.nfft), im = new Float64Array(FB.nfft), fr = new Float64Array(FB.len);
    for (let t = 0; t < T; ++t) {
        const o = t * FB.shift;
        let mean = 0;
        for (let i = 0; i < FB.len; ++i) { fr[i] = x16[o + i] * 32768; mean += fr[i]; }
        mean /= FB.len;
        for (let i = 0; i < FB.len; ++i) fr[i] -= mean;                       // composante continue retirée
        for (let i = FB.len - 1; i > 0; --i) fr[i] -= 0.97 * fr[i - 1];       // pré-accentuation
        fr[0] -= 0.97 * fr[0];
        re.fill(0); im.fill(0);
        for (let i = 0; i < FB.len; ++i) re[i] = fr[i] * win[i];
        fftReal(re, im);
        for (let m = 0; m < FB.mels; ++m) {
            const w = filters[m];
            let e = 0;
            for (let k = 0; k < FB.nfft / 2; ++k) if (w[k]) e += w[k] * (re[k] * re[k] + im[k] * im[k]);
            out[t * FB.mels + m] = Math.log(Math.max(e, 1.1920929e-7));
        }
    }
    for (let m = 0; m < FB.mels; ++m) {   // moyenne retirée par bande (CMN)
        let s = 0;
        for (let t = 0; t < T; ++t) s += out[t * FB.mels + m];
        s /= Math.max(1, T);
        for (let t = 0; t < T; ++t) out[t * FB.mels + m] -= s;
    }
    return { feats: out, frames: T };
}

const cos = (a, b) => { let s = 0, na = 0, nb = 0; for (let i = 0; i < a.length; ++i) { s += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; } return s / Math.sqrt(na * nb + 1e-20); };

/** Hauteur médiane (demi-tons MIDI) d'un extrait 16 kHz, par autocorrélation normalisée (70–600 Hz) sur des trames
 *  de 40 ms ; NaN si l'extrait n'est pas assez voisé. Sert d'indice en plus de l'empreinte (homme / femme). */
export function medianPitch(x16) {
    const sr = 16000, N = 640, hop = 320, lo = Math.floor(sr / 600), hi = Math.ceil(sr / 70), vals = [];
    for (let s = 0; s + N + hi <= x16.length; s += hop) {
        let e0 = 0;
        for (let i = 0; i < N; ++i) e0 += x16[s + i] * x16[s + i];
        if (e0 < 1e-5) continue;
        let best = 0, bl = 0;
        for (let l = lo; l <= hi; ++l) {
            let c = 0, e1 = 0;
            for (let i = 0; i < N; ++i) { c += x16[s + i] * x16[s + i + l]; e1 += x16[s + i + l] * x16[s + i + l]; }
            const r = c / Math.sqrt(e0 * e1 + 1e-20);
            if (r > best + 0.02) { best = r; bl = l; }   // +0,02 : à force égale, la période la plus courte (pas l'octave du dessous)
        }
        if (best > 0.6 && bl > 0) vals.push(69 + 12 * Math.log2(sr / bl / 440));
    }
    if (vals.length < 5) return NaN;
    vals.sort((a, b) => a - b);
    return vals[vals.length >> 1];
}

/**
 * Regroupe des fenêtres de voix par chanteur, sans connaître leur nombre : regroupement hiérarchique (lien moyen sur le
 * cosinus des empreintes), arrêté quand les deux groupes les plus proches ne se ressemblent plus assez.
 *   - ressemblance ≥ simSame : même voix, fusion ;
 *   - entre simDiff et simSame : zone douteuse → fusion seulement si les hauteurs médianes sont proches (≤ pitchTol
 *     demi-tons : une voix d'homme et une voix de femme restent séparées) ;
 *   - < simDiff : voix différentes.
 * Les groupes trop courts (< minSec) rejoignent le groupe le plus ressemblant. Retourne { labels, k, sims }.
 */
export function clusterVoices(embs, pitches, durs, { simSame = 0.5, simDiff = 0.3, pitchTol = 4, minSec = 4, maxSingers = 12 } = {}) {
    const n = embs.length;
    const S = Array.from({ length: n }, () => new Float32Array(n));
    for (let i = 0; i < n; ++i) for (let j = i; j < n; ++j) { const v = i === j ? 1 : cos(embs[i], embs[j]); S[i][j] = v; S[j][i] = v; }
    let groups = embs.map((_, i) => [i]);
    const link = (g, h) => { let a = 0; for (const i of g) for (const j of h) a += S[i][j]; return a / (g.length * h.length); };
    const pitchOf = (g) => { const v = g.map((i) => pitches[i]).filter(Number.isFinite).sort((a, b) => a - b); return v.length ? v[v.length >> 1] : NaN; };
    const durOf = (g) => g.reduce((a, i) => a + durs[i], 0);
    const mayMerge = (g, h, v) => {
        if (v >= simSame) return true;
        if (v < simDiff) return false;
        const pg = pitchOf(g), ph = pitchOf(h);
        return !(Number.isFinite(pg) && Number.isFinite(ph)) || Math.abs(pg - ph) <= pitchTol;
    };
    for (;;) {
        let bi = -1, bj = -1, best = -2;
        for (let i = 0; i < groups.length; ++i) for (let j = i + 1; j < groups.length; ++j) {
            const v = link(groups[i], groups[j]);
            if (v > best && (groups.length > maxSingers || mayMerge(groups[i], groups[j], v))) { best = v; bi = i; bj = j; }
        }
        if (bi < 0) break;
        groups[bi] = groups[bi].concat(groups[bj]);
        groups.splice(bj, 1);
        if (groups.length === 1) break;
    }
    // Groupes trop courts : rattachés au groupe le plus ressemblant (une voix d'une ou deux fenêtres n'est pas une piste).
    for (;;) {
        if (groups.length <= 1) break;
        let k = -1, kd = Infinity;
        groups.forEach((g, i) => { const d = durOf(g); if (d < minSec && d < kd) { kd = d; k = i; } });
        if (k < 0) break;
        let to = -1, best = -2;
        groups.forEach((g, i) => { if (i !== k) { const v = link(groups[k], g); if (v > best) { best = v; to = i; } } });
        groups[to] = groups[to].concat(groups[k]);
        groups.splice(k, 1);
    }
    groups.sort((a, b) => Math.min(...a) - Math.min(...b));   // chanteur 1 = le premier entendu
    const labels = new Array(n).fill(0);
    groups.forEach((g, k) => g.forEach((i) => { labels[i] = k; }));
    const sims = [];
    for (let i = 0; i < groups.length; ++i) for (let j = i + 1; j < groups.length; ++j) sims.push(link(groups[i], groups[j]));
    return { labels, k: groups.length, sims, pitch: groups.map(pitchOf), dur: groups.map(durOf) };
}

/**
 * Repère les chanteurs qui alternent (autant qu'il y en a), avec l'empreinte de voix : fenêtres de `win` s (pas `hop`)
 * dans les phrases, une empreinte par fenêtre (embed(feats, frames) → Float32Array(256), fourni par l'appelant :
 * modèle ONNX) + hauteur médiane, puis clusterVoices. Les fenêtres isolées entre deux fenêtres d'un même chanteur
 * sont rattachées à celui-ci. Retourne { singers, phrases: [{ start, end, singer }], similarity, why }.
 */
export async function findSingers(mono, sr, embed, { win = 2, hop = 1, onProgress = null, ...cl } = {}) {
    const phrases = findPhrases(mono, sr);
    const x16 = to16k(mono, sr);
    const wins = [];
    for (const [a, b] of phrases) {
        if (b - a < win) { if (b - a >= 1) wins.push([a, b]); continue; }
        let t = a;
        for (; t + win <= b + 1e-6; t += hop) wins.push([t, t + win]);
        if (b - (t - hop + win) > 0.4) wins.push([b - win, b]);
    }
    const one = (why, sim = 1) => ({ singers: 1, phrases: phrases.map(([start, end]) => ({ start, end, singer: 0 })), similarity: sim, why });
    if (wins.length < 3) return one(`${wins.length} passage(s) chanté(s) assez longs seulement : pas assez pour comparer les voix`);
    const embs = [], pitches = [];
    for (const [a, b] of wins) {
        const seg = x16.subarray(Math.round(a * 16000), Math.round(b * 16000));
        const { feats, frames } = fbank80(seg);
        embs.push(await embed(feats, frames));
        pitches.push(medianPitch(seg));
        onProgress?.(embs.length, wins.length);
    }
    const durs = wins.map(([a, b]) => b - a);
    const c = clusterVoices(embs, pitches, durs, cl);
    const maxSim = c.sims.length ? Math.max(...c.sims) : 1;
    if (c.k < 2) return one('une seule voix repérée (toutes les fenêtres se ressemblent)', maxSim);
    // Lissage : une fenêtre seule entre deux fenêtres d'un même autre chanteur (dans la même phrase) suit ses voisines.
    const lab = c.labels.slice();
    const phraseOf = wins.map((w) => phrases.findIndex(([a, b]) => (w[0] + w[1]) / 2 >= a && (w[0] + w[1]) / 2 <= b));
    for (let i = 1; i + 1 < lab.length; ++i)
        if (lab[i - 1] === lab[i + 1] && lab[i] !== lab[i - 1] && phraseOf[i - 1] === phraseOf[i] && phraseOf[i + 1] === phraseOf[i]) lab[i] = lab[i - 1];
    // chaque phrase est coupée là où le chanteur change (milieu entre deux centres de fenêtres)
    const out = [];
    phrases.forEach(([a, b], pi) => {
        const inside = wins.map((w, i) => ({ mid: (w[0] + w[1]) / 2, s: lab[i], p: phraseOf[i] })).filter((w) => w.p === pi);
        if (!inside.length) {   // phrase trop courte pour une empreinte : chanteur de la fenêtre la plus proche dans le temps
            const mid = (a + b) / 2;
            let bi = 0, bd = Infinity;
            wins.forEach((w, i) => { const d = Math.abs((w[0] + w[1]) / 2 - mid); if (d < bd) { bd = d; bi = i; } });
            out.push({ start: a, end: b, singer: lab[bi] });
            return;
        }
        let cur = inside[0].s, segStart = a;
        for (let k = 1; k < inside.length; ++k) {
            if (inside[k].s !== cur) {
                const cut = (inside[k - 1].mid + inside[k].mid) / 2;
                out.push({ start: segStart, end: cut, singer: cur });
                segStart = cut; cur = inside[k].s;
            }
        }
        out.push({ start: segStart, end: b, singer: cur });
    });
    const tot = c.dur.reduce((x, y) => x + y, 0);
    const parts = c.dur.map((d) => `${Math.round(100 * d / tot)} %`).join(' / ');
    const hz = c.pitch.map((m) => Number.isFinite(m) ? `${Math.round(440 * Math.pow(2, (m - 69) / 12))} Hz` : '?').join(' / ');
    return { singers: c.k, similarity: maxSim, phrases: out,
             why: `${c.k} voix différentes (ressemblance la plus forte entre deux voix ${maxSim.toFixed(2)} ; parts ${parts} ; hauteurs ${hz})` };
}

/** Copie d'une voix gardant seulement les phrases d'un chanteur (fondus de 30 ms aux bords). */
export function keepPhrases(mono, sr, phrases, singer) {
    const out = new Float32Array(mono.length), fade = Math.round(0.03 * sr);
    for (const p of phrases) {
        if (p.singer !== singer) continue;
        const a = Math.max(0, Math.round(p.start * sr) - fade), b = Math.min(mono.length, Math.round(p.end * sr) + fade);
        for (let i = a; i < b; ++i) {
            const g = Math.min(1, (i - a) / fade, (b - 1 - i) / fade);
            out[i] = mono[i] * Math.max(0, g);
        }
    }
    return out;
}
