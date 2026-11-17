// StudioVoix Web : instru d'une chanson séparée = chanson − g × voix estimée, avec g = « porte dans le temps ».
// Pourquoi : la voix estimée par le modèle n'est jamais nulle. Là où personne ne chante, c'est un bruit du modèle, et le
// soustraire abîme l'instru pour rien. La porte ferme la soustraction (g = 0) là où la voix estimée est très en dessous
// de la chanson : l'instru y est la chanson d'origine, à l'échantillon près. Ailleurs g = 1 : chanson − voix, comme avant.
// Règle (mesurée en recherche : web/test/bench-instru/run_bench.py, tgate(-30)) :
//   - trames de 50 ms sans recouvrement, les deux canaux ensemble ;
//   - r = 10·log10(énergie de la voix estimée / énergie de la chanson) dans la trame ;
//   - g = 0 si r ≤ −30 dB, 1 si r ≥ −24 dB, droite entre les deux ;
//   - tenue : g de la trame = min(1, somme des g des 5 trames centrées sur elle) → une trame active garde ouvertes
//     ses voisines à ± 100 ms (débuts et fins de mots) ;
//   - passage aux échantillons : droite entre les centres de trames (pas de saut : au plus 1/trame par échantillon) ;
//     avant le premier centre et après le dernier (reste de moins d'une trame compris), la valeur de la trame du bord.
// Hors de la règle mesurée, choisi ici : un son plus court qu'une trame compte pour une seule trame ; une énergie non
// finie (NaN dans la voix) laisse la porte ouverte (soustraction comme avant, rien n'est masqué).
// Seule l'instru est concernée : les pistes de voix ne passent pas par ici.
// Module ES pur (ni page ni journal) : utilisé par la page et par l'essai Node web/test/gate.mjs.

/** Réglages de la porte : seuil (dB, voix estimée / chanson), pente (dB), trame (s), tenue (nombre impair de trames). */
export const GATE_DEFAULTS = Object.freeze({ thresholdDb: -30, slopeDb: 6, frameSec: 0.05, holdFrames: 5 });

const BLOCK = 1 << 15;

/** Gain de la porte par trame, tenue comprise. Rend { g, frame } (frame = taille d'une trame en échantillons). */
function gateFrames(songL, songR, voiceL, voiceR, sampleRate, opts) {
    const o = { ...GATE_DEFAULTS, ...(opts || {}) };
    if (!(sampleRate > 0) || !Number.isFinite(sampleRate)) throw new Error(`porte de l'instru : fréquence invalide (${sampleRate})`);
    if (!(o.frameSec > 0) || !Number.isFinite(o.thresholdDb) || !(o.slopeDb >= 0) || !(o.holdFrames >= 1))
        throw new Error(`porte de l'instru : réglages invalides (${JSON.stringify(o)})`);
    const sR = songR || songL, vL = voiceL || [], vR = voiceR || vL, n = songL.length;
    if (sR.length !== n) throw new Error(`porte de l'instru : canaux de la chanson de longueurs différentes (${n} et ${sR.length})`);
    const fr = Math.max(1, Math.floor(o.frameSec * sampleRate + 1e-6));   // = int(0.05 × fréquence) de la règle mesurée
    const k = n >= fr ? Math.floor(n / fr) : (n > 0 ? 1 : 0);
    const raw = new Float64Array(k), lo = o.thresholdDb, hi = o.thresholdDb + o.slopeDb;
    for (let j = 0; j < k; ++j) {
        const a = j * fr, b = Math.min(n, a + fr), bl = Math.min(b, vL.length), br = Math.min(b, vR.length);
        let es = 0, ev = 0;
        for (let i = a; i < b; ++i) es += songL[i] * songL[i] + sR[i] * sR[i];
        for (let i = a; i < bl; ++i) ev += vL[i] * vL[i];      // voix plus courte que la chanson : la suite vaut 0
        for (let i = a; i < br; ++i) ev += vR[i] * vR[i];
        if (!Number.isFinite(es) || !Number.isFinite(ev)) { raw[j] = 1; continue; }
        const r = 10 * Math.log10(Math.max(ev / Math.max(es, 1e-12), 1e-30));
        raw[j] = r <= lo ? 0 : r >= hi ? 1 : (r - lo) / (hi - lo);
    }
    const half = Math.floor((Math.round(o.holdFrames) - 1) / 2), g = new Float64Array(k);
    for (let j = 0; j < k; ++j) {
        let s = 0;
        for (let d = Math.max(0, j - half); d <= Math.min(k - 1, j + half); ++d) s += raw[d];
        g[j] = Math.min(1, s);
    }
    return { g, frame: fr };
}

/** Gain par échantillon pour les échantillons [a, b) : out[i − a]. Droite entre centres de trames, bords tenus. */
function fillGain(g, fr, a, b, out) {
    const k = g.length;
    for (let i = a; i < b;) {
        // segment j : du centre de la trame j (compris) au centre de la trame j + 1 (exclu) ; −1 = avant le premier centre
        const j = Math.min(k - 1, Math.floor((2 * i - fr) / (2 * fr)));
        const end = j >= k - 1 ? b : Math.min(b, Math.ceil((j + 1.5) * fr));
        const g0 = g[Math.max(0, j)], d = j < 0 || j >= k - 1 ? 0 : g[j + 1] - g0;
        if (d === 0) out.fill(g0, i - a, end - a);              // 0 et 1 restent exacts
        else { const c = (j + 0.5) * fr; for (let x = i; x < end; ++x) out[x - a] = g0 + d * ((x - c) / fr); }
        i = end;
    }
}

const share = (count, n) => (n ? count / n : 0);
const report = (n, closed, open, frames, frame) => ({ closed: share(closed, n), open: share(open, n), between: share(n - closed - open, n), frames, frame });

/**
 * Gain de la porte par échantillon (0 = rien n'est retiré, 1 = la voix estimée est retirée en entier).
 * Chanson et voix estimée à la même fréquence ; la sortie a la longueur de la chanson (voix plus courte : complétée
 * par du silence ; plus longue : la suite est ignorée).
 * Rend { gain, closed, open, between, frames, frame } : parts de la durée (0 à 1) où la porte est fermée (gain 0),
 * ouverte (gain 1) et entre les deux ; nombre de trames ; taille d'une trame en échantillons.
 */
export function instruGate(songL, songR, voiceL, voiceR, sampleRate, opts) {
    const { g, frame } = gateFrames(songL, songR, voiceL, voiceR, sampleRate, opts), n = songL.length;
    const gain = new Float32Array(n);
    fillGain(g, frame, 0, n, gain);
    let closed = 0, open = 0;
    for (let i = 0; i < n; ++i) { if (gain[i] === 0) ++closed; else if (gain[i] === 1) ++open; }
    return { gain, ...report(n, closed, open, g.length, frame) };
}

/**
 * Instru = chanson − gain × voix estimée (même gain que instruGate, sans garder le gain par échantillon en mémoire).
 * Porte fermée : la chanson est recopiée telle quelle. Porte ouverte : chanson − voix, exactement.
 * Rend { left, right, closed, open, between, frames, frame } (mêmes parts que instruGate).
 */
export function gatedInstru(songL, songR, voiceL, voiceR, sampleRate, opts) {
    const { g, frame } = gateFrames(songL, songR, voiceL, voiceR, sampleRate, opts), n = songL.length;
    const sR = songR || songL, vL = voiceL || [], vR = voiceR || vL;
    const left = new Float32Array(n), right = new Float32Array(n), buf = new Float32Array(Math.min(n, BLOCK));
    let closed = 0, open = 0;
    for (let a = 0; a < n; a += BLOCK) {
        const b = Math.min(n, a + BLOCK);
        fillGain(g, frame, a, b, buf);
        for (let i = a; i < b; ++i) {
            const w = buf[i - a];
            if (w === 0) { left[i] = songL[i]; right[i] = sR[i]; ++closed; continue; }
            if (w === 1) ++open;
            left[i] = songL[i] - w * (i < vL.length ? vL[i] : 0);
            right[i] = sR[i] - w * (i < vR.length ? vR[i] : 0);
        }
    }
    return { left, right, ...report(n, closed, open, g.length, frame) };
}
