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
    // Seuil : 15 dB au-dessus du fond, mais jamais à moins de 20 dB sous la crête — sur un chant continu (rap, voix sans
    // pause) le « fond » est déjà de la voix, et le seuil passait au-dessus de tout : aucune phrase, donc aucun chanteur.
    const thr = Math.max(Math.min(floor + 15, peak - 20), peak - 45);
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
 * Regroupe des fenêtres de voix par chanteur, sans connaître leur nombre. Mesuré sur de vrais chants (fenêtres de 2 s,
 * voix séparées par la page) : deux fenêtres d'un même chanteur se ressemblent de 0,2 à 0,8 (moyenne ≈ 0,45), deux
 * chanteurs différents de −0,1 à 0,35 (moyenne ≈ 0,13) — fenêtre par fenêtre les deux se chevauchent, mais la
 * MOYENNE d'un groupe de fenêtres (centre) est beaucoup plus nette. D'où trois temps :
 *   1. petits groupes sûrs : regroupement hiérarchique (lien moyen) tant que la ressemblance ≥ simPure ;
 *   2. fusion des groupes dont les centres se ressemblent (cosinus des centres ≥ simCentre) ;
 *   3. chaque fenêtre rejoint le centre le plus proche ; les groupes trop courts (< minSec) rejoignent le plus proche.
 * `pitches` (hauteur médiane par fenêtre) ne sert qu'au compte rendu. Retourne { labels, k, sims, pitch, dur }.
 */
export function clusterVoices(embs, pitches, durs, { simPure = 0.45, simCentre = 0.44, minSec = 3, maxSingers = 12 } = {}) {
    const n = embs.length, D = embs[0].length;
    const unit = embs.map((e) => { let q = 0; for (let i = 0; i < D; ++i) q += e[i] * e[i]; q = Math.sqrt(q) + 1e-20; return Float32Array.from(e, (v) => v / q); });
    const S = Array.from({ length: n }, () => new Float32Array(n));
    for (let i = 0; i < n; ++i) for (let j = i; j < n; ++j) { let v = 0; if (i === j) v = 1; else for (let k = 0; k < D; ++k) v += unit[i][k] * unit[j][k]; S[i][j] = v; S[j][i] = v; }
    const link = (g, h) => { let a = 0; for (const i of g) for (const j of h) a += S[i][j]; return a / (g.length * h.length); };
    const centre = (g) => { const c = new Float32Array(D); for (const i of g) for (let k = 0; k < D; ++k) c[k] += unit[i][k]; return c; };
    const ccos = (g, h) => cos(centre(g), centre(h));
    const durOf = (g) => g.reduce((a, i) => a + durs[i], 0);
    const pitchOf = (g) => { const v = g.map((i) => pitches[i]).filter(Number.isFinite).sort((a, b) => a - b); return v.length ? v[v.length >> 1] : NaN; };
    const mergeWhile = (score, thr, force = () => false) => {
        for (;;) {
            if (groups.length <= 1) return;
            let bi = -1, bj = -1, best = -2;
            for (let i = 0; i < groups.length; ++i) for (let j = i + 1; j < groups.length; ++j) { const v = score(groups[i], groups[j]); if (v > best) { best = v; bi = i; bj = j; } }
            if (best < thr && !force()) return;
            groups[bi] = groups[bi].concat(groups[bj]);
            groups.splice(bj, 1);
        }
    };
    let groups = unit.map((_, i) => [i]);
    mergeWhile(link, simPure);                                        // 1. petits groupes sûrs
    mergeWhile(ccos, simCentre, () => groups.length > maxSingers);    // 2. centres qui se ressemblent
    // 3. chaque fenêtre vers le centre le plus proche (2 passes), puis groupes trop courts absorbés
    for (let pass = 0; pass < 2 && groups.length > 1; ++pass) {
        const cs = groups.map(centre), next = groups.map(() => []);
        for (let i = 0; i < n; ++i) { let bk = 0, best = -2; cs.forEach((c, k) => { const v = cos(unit[i], c); if (v > best) { best = v; bk = k; } }); next[bk].push(i); }
        groups = next.filter((g) => g.length);
    }
    for (;;) {
        if (groups.length <= 1) break;
        let k = -1, kd = Infinity;
        groups.forEach((g, i) => { const d = durOf(g); if (d < minSec && d < kd) { kd = d; k = i; } });
        if (k < 0) break;
        let to = -1, best = -2;
        groups.forEach((g, i) => { if (i !== k) { const v = ccos(groups[k], g); if (v > best) { best = v; to = i; } } });
        groups[to] = groups[to].concat(groups[k]);
        groups.splice(k, 1);
    }
    mergeWhile(ccos, simCentre);                                      // les absorptions peuvent rapprocher deux centres
    groups.sort((a, b) => Math.min(...a) - Math.min(...b));           // chanteur 1 = le premier entendu
    const labels = new Array(n).fill(0);
    groups.forEach((g, k) => g.forEach((i) => { labels[i] = k; }));
    const sims = [];
    for (let i = 0; i < groups.length; ++i) for (let j = i + 1; j < groups.length; ++j) sims.push(ccos(groups[i], groups[j]));
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
    // Durée propre à chaque fenêtre (les fenêtres glissantes se recouvrent : chacune compte pour son pas).
    const durs = wins.map(([a, b]) => Math.min(b - a, hop));
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

/**
 * Répartit une voix sur plusieurs pistes d'après des plages [{ start, end, <clé> }] (clé = numéro de piste, 0..n-1).
 * Là où deux plages se touchent (changement de chanteur ou de section en plein chant), fondu enchaîné de 20 ms centré
 * sur la coupe : la somme des pistes redonne exactement la voix d'origine (pas de bosse ni de trou à la coupe).
 * Aux bords libres (silence autour), fondu de 30 ms vers l'extérieur. Retourne n Float32Array de la longueur de mono.
 */
export function splitRanges(mono, sr, ranges, n, key = 'singer') {
    const out = Array.from({ length: n }, () => new Float32Array(mono.length));
    const rs = ranges.filter((r) => r.end > r.start && r[key] >= 0 && r[key] < n).slice().sort((a, b) => a.start - b.start);
    const edge = Math.round(0.03 * sr), xf = Math.round(0.01 * sr);   // xf : demi-largeur du fondu enchaîné
    rs.forEach((r, i) => {
        const prev = rs[i - 1], next = rs[i + 1];
        const a = Math.round(r.start * sr), b = Math.round(r.end * sr);
        const joinL = !!prev && Math.abs(prev.end - r.start) < 1e-3, joinR = !!next && Math.abs(next.start - r.end) < 1e-3;
        const sameL = joinL && prev[key] === r[key], sameR = joinR && next[key] === r[key];
        // début et fin de la zone écrite, avec leurs rampes
        const a0 = sameL ? a : joinL ? a - xf : a - edge, a1 = sameL ? a : joinL ? a + xf : a;
        const b0 = sameR ? b : joinR ? b - xf : b, b1 = sameR ? b : joinR ? b + xf : b + edge;
        const dst = out[r[key]];
        for (let i2 = Math.max(0, a0); i2 < Math.min(mono.length, b1); ++i2) {
            let g = 1;
            if (i2 < a1) g = Math.min(g, (i2 - a0) / Math.max(1, a1 - a0));
            if (i2 >= b0) g = Math.min(g, (b1 - i2) / Math.max(1, b1 - b0));
            if (g > 0) dst[i2] += mono[i2] * g;
        }
    });
    return out;
}

/** Copie d'une voix gardant seulement les phrases d'un chanteur (voir splitRanges). */
export function keepPhrases(mono, sr, phrases, singer) {
    const n = phrases.reduce((m, p) => Math.max(m, p.singer + 1), singer + 1);
    return splitRanges(mono, sr, phrases, n)[singer];
}

/**
 * Coupes couplets / refrains d'une voix d'après les sections du morceau [{ start, end, kind }] (kind : "refrain",
 * "couplet", "intro", "pont", "outro"). Chaque frontière entre « refrain » et le reste est déplacée vers le creux de
 * la voix le plus proche (± snapSec), pour ne pas couper un mot. Retourne les plages [{ start, end, part }]
 * (part 0 = couplets et le reste, 1 = refrains), ou null s'il n'y a pas les deux.
 */
export function sectionRanges(mono, sr, sections, snapSec = 1.5) {
    const dur = mono.length / sr;
    const secs = (sections || []).filter((x) => x.end > x.start).slice().sort((a, b) => a.start - b.start);
    const isRef = (x) => x.kind === 'refrain';
    if (!secs.some(isRef) || !secs.some((x) => !isRef(x))) return null;
    // frontières où le genre change
    const cuts = [];
    for (let i = 1; i < secs.length; ++i) if (isRef(secs[i]) !== isRef(secs[i - 1])) cuts.push({ t: secs[i].start, ref: isRef(secs[i]) });
    const hop = Math.round(0.05 * sr), lv = [];
    for (let s = 0; s + hop <= mono.length; s += hop) { let e = 0; for (let i = s; i < s + hop; ++i) e += mono[i] * mono[i]; lv.push(e / hop); }
    const snap = (t) => {
        const f0 = Math.max(0, Math.round((t - snapSec) / 0.05)), f1 = Math.min(lv.length - 2, Math.round((t + snapSec) / 0.05));
        // Creux de 100 ms : parmi les plus silencieux de la fenêtre (à 6 dB près du plus creux), le plus proche de la frontière.
        let m = Infinity;
        for (let f = f0; f <= f1; ++f) m = Math.min(m, lv[f] + lv[f + 1]);
        let best = -1, bd = Infinity;
        for (let f = f0; f <= f1; ++f) {
            if (lv[f] + lv[f + 1] > Math.max(4 * m, 1e-8)) continue;
            const d = Math.abs((f + 1) * 0.05 - t);
            if (d < bd) { bd = d; best = f; }
        }
        return best < 0 ? t : (best + 1) * 0.05;
    };
    const out = [];
    let start = 0, part = isRef(secs[0]) ? 1 : 0;
    for (const c of cuts) {
        const t = Math.min(dur, Math.max(start, snap(c.t)));
        if (t > start) out.push({ start, end: t, part });
        start = t; part = c.ref ? 1 : 0;
    }
    if (dur > start) out.push({ start, end: dur, part });
    return out;
}
