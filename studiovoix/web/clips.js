// StudioVoix Web — montage par « bouts » (clips), logique pure : aucune page, aucun son source modifié.
//
// Un bout = { id, src, off, len, at, gainDb, mute, rev, fadeIn, fadeOut }
//   src        identifiant du son source (gardé tel quel, jamais modifié) ;
//   off, len   zone utilisée dans la source, en échantillons ;
//   at         place du début du bout dans le morceau, en secondes ;
//   gainDb     gain du bout (appliqué au rendu, donc AVANT la chaîne d'effets de la piste) ;
//   mute, rev  bout muet, bout lu à l'envers ;
//   fadeIn/Out fondus d'entrée et de sortie, en secondes (cosinus relevé : deux fondus complémentaires font 1).
// Le rendu d'une liste de bouts donne { mono, startSec } : c'est ce que le reste de la page lit comme « la prise ».
// Toutes les opérations rendent une NOUVELLE liste (les bouts reçus ne sont pas modifiés) ; un geste impossible lève
// une ClipError dont le message est en français simple (affiché tel quel à l'utilisateur).

export const GAIN_MIN_DB = -24, GAIN_MAX_DB = 12;

export class ClipError extends Error {
    constructor(message) { super(message); this.name = 'ClipError'; this.clip = true; }
}
const fail = (msg) => { throw new ClipError(msg); };

export const dbToGain = (db) => (db === 0 ? 1 : Math.pow(10, db / 20));
export const clipEnd = (c, sr) => c.at + c.len / sr;
export const cloneClips = (clips) => (clips || []).map((c) => ({ ...c }));
export function makeClip(id, src, len, at) {
    return { id, src, off: 0, len, at, gainDb: 0, mute: false, rev: false, fadeIn: 0, fadeOut: 0 };
}
function find(clips, id) {
    const i = (clips || []).findIndex((c) => c.id === id);
    if (i < 0) fail('Ce bout n\'existe plus.');
    return i;
}
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const num = (v, d = 0) => (Number.isFinite(v) ? v : d);

// Bouts relus d'une sauvegarde (entrée externe) : on ne garde que ceux qui tiennent dans leur source.
// srcLenOf(src) → longueur de la source, ou 0 si elle manque. Rend { clips, dropped }.
export function sanitizeClips(list, srcLenOf, sr) {
    const clips = [];
    let dropped = 0;
    for (const c of Array.isArray(list) ? list : []) {
        const n = c ? srcLenOf(c.src) : 0;
        const off = Math.round(num(c?.off, -1)), len = Math.round(num(c?.len, 0)), at = num(c?.at, -1);
        if (!c || typeof c.id !== 'string' || !n || off < 0 || len < 1 || off + len > n || at < 0) { ++dropped; continue; }
        clips.push({
            id: c.id, src: c.src, off, len, at, gainDb: clamp(num(c.gainDb), GAIN_MIN_DB, GAIN_MAX_DB), mute: !!c.mute, rev: !!c.rev,
            fadeIn: clamp(num(c.fadeIn), 0, len / sr), fadeOut: clamp(num(c.fadeOut), 0, len / sr),
        });
    }
    return { clips, dropped };
}

// Poids du fondu d'entrée à l'échantillon i d'un fondu de n échantillons ; le fondu de sortie est 1 − ce poids.
const fadeW = (i, n) => 0.5 - 0.5 * Math.cos(Math.PI * (i + 0.5) / n);

// Rendu : somme des bouts (gain, muet, inversion, fondus) du début du premier à la fin du dernier.
// sources : Map ou objet { get(src) → Float32Array }. Un bout muet compte dans l'étendue mais n'ajoute rien.
export function renderClips(clips, sources, sr) {
    const list = (clips || []).filter((c) => c && c.len > 0 && sources.get(c.src));
    if (!list.length) return { mono: new Float32Array(0), startSec: 0 };
    let start = Infinity;
    for (const c of list) start = Math.min(start, c.at);
    let n = 0;
    const pos = list.map((c) => { const o = Math.round((c.at - start) * sr); n = Math.max(n, o + c.len); return o; });
    const mono = new Float32Array(n);
    list.forEach((c, k) => {
        if (c.mute) return;
        const src = sources.get(c.src), o = pos[k], len = Math.min(c.len, src.length - c.off), g = dbToGain(c.gainDb);
        if (len <= 0 || g === 0) return;
        const nIn = clamp(Math.round(num(c.fadeIn) * sr), 0, len), nOut = clamp(Math.round(num(c.fadeOut) * sr), 0, len);
        const last = c.off + len - 1;
        const edge = (i) => {   // échantillon dans un fondu (peu nombreux : pas la boucle rapide)
            let v = (c.rev ? src[last - i] : src[c.off + i]) * g;
            if (i < nIn) v *= fadeW(i, nIn);
            if (i >= len - nOut) v *= 1 - fadeW(i - (len - nOut), nOut);
            mono[o + i] += v;
        };
        const a = Math.min(nIn, len), b = Math.max(a, len - nOut);
        for (let i = 0; i < a; ++i) edge(i);
        if (c.rev) { if (g === 1) for (let i = a; i < b; ++i) mono[o + i] += src[last - i]; else for (let i = a; i < b; ++i) mono[o + i] += src[last - i] * g; }
        else if (g === 1) for (let i = a; i < b; ++i) mono[o + i] += src[c.off + i];
        else for (let i = a; i < b; ++i) mono[o + i] += src[c.off + i] * g;
        for (let i = b; i < len; ++i) edge(i);
    });
    return { mono, startSec: start };
}

// Couper le bout `id` à l'instant atSec du morceau : deux bouts qui, rendus, redonnent le même son.
// Rend { clips, left, right } (identifiants des deux moitiés ; la gauche garde l'identifiant d'origine).
export function splitClip(clips, id, atSec, sr, newId) {
    const i = find(clips, id), c = clips[i];
    const s = Math.round((atSec - c.at) * sr);
    if (!Number.isFinite(s) || s < 1 || s > c.len - 1) fail('Le curseur n\'est pas sur ce bout : place-le dedans, puis coupe.');
    const a = { ...c, len: s, fadeOut: 0 }, b = { ...c, id: newId(), len: c.len - s, at: c.at + s / sr, fadeIn: 0 };
    if (c.rev) { a.off = c.off + c.len - s; b.off = c.off; } else b.off = c.off + s;
    a.fadeIn = Math.min(a.fadeIn, a.len / sr); b.fadeOut = Math.min(b.fadeOut, b.len / sr);
    const out = cloneClips(clips);
    out.splice(i, 1, a, b);
    return { clips: out, left: a.id, right: b.id };
}

// Rogner / re-dérouler un bord : edge = 'start' ou 'end', newSec = nouvel instant de ce bord dans le morceau.
// Le son ne bouge pas dans le temps ; on ne peut pas dépasser les bords de la source, ni descendre sous 1 échantillon.
export function trimClip(clips, id, edge, newSec, sr, srcLen) {
    const i = find(clips, id), c = clips[i];
    if (!Number.isFinite(newSec)) fail('Réglage invalide.');
    let n;
    if (edge === 'start') {
        let d = Math.round((newSec - c.at) * sr);                       // > 0 : rogne ; < 0 : re-déroule
        const room = Math.min(c.rev ? srcLen - (c.off + c.len) : c.off, Math.floor(c.at * sr));
        d = clamp(d, -Math.max(0, room), c.len - 1);
        n = { ...c, len: c.len - d, at: Math.max(0, c.at + d / sr) };
        if (!c.rev) n.off = c.off + d;
    } else if (edge === 'end') {
        let d = Math.round((newSec - clipEnd(c, sr)) * sr);             // > 0 : re-déroule ; < 0 : rogne
        const room = c.rev ? c.off : srcLen - (c.off + c.len);
        d = clamp(d, -(c.len - 1), Math.max(0, room));
        n = { ...c, len: c.len + d };
        if (c.rev) n.off = c.off - d;
    } else fail('Bord inconnu.');
    n.fadeIn = Math.min(n.fadeIn, n.len / sr); n.fadeOut = Math.min(n.fadeOut, n.len / sr);
    const out = cloneClips(clips);
    out[i] = n;
    return { clips: out, changed: n.len !== c.len };
}

function patch(clips, id, fn) {
    const i = find(clips, id), out = cloneClips(clips);
    out[i] = fn(out[i]);
    return out;
}
// Fondus (secondes), bornés à la durée du bout. Une valeur absente laisse le fondu tel quel.
export function setFades(clips, id, { fadeIn, fadeOut }, sr) {
    return patch(clips, id, (c) => ({
        ...c,
        fadeIn: fadeIn == null ? c.fadeIn : clamp(num(fadeIn), 0, c.len / sr),
        fadeOut: fadeOut == null ? c.fadeOut : clamp(num(fadeOut), 0, c.len / sr),
    }));
}
export const setGain = (clips, id, db) => patch(clips, id, (c) => ({ ...c, gainDb: clamp(num(db), GAIN_MIN_DB, GAIN_MAX_DB) }));
export const setMute = (clips, id, on) => patch(clips, id, (c) => ({ ...c, mute: !!on }));
export const setRev = (clips, id, on) => patch(clips, id, (c) => ({ ...c, rev: !!on }));
export const moveClip = (clips, id, at) => patch(clips, id, (c) => ({ ...c, at: Math.max(0, num(at, c.at)) }));
export function removeClip(clips, id) {
    const i = find(clips, id), out = cloneClips(clips);
    out.splice(i, 1);
    return out;
}
// Copie d'un bout posée à l'instant `at` (par défaut : juste après l'original). Rend { clips, id }.
export function duplicateClip(clips, id, sr, newId, at = null) {
    const c = clips[find(clips, id)];
    return insertClip(clips, c, at == null ? clipEnd(c, sr) : at, newId);
}
// Coller : copie du bout `clip` (venu de n'importe quelle piste) posée à l'instant `at`. Rend { clips, id }.
export function insertClip(clips, clip, at, newId) {
    if (!clip || !(clip.len >= 1)) fail('Rien à coller.');
    const n = { ...clip, id: newId(), at: Math.max(0, num(at)) };
    return { clips: [...cloneClips(clips), n], id: n.id };
}
// Fusionner : tous les bouts rendus en un seul son, qui devient une nouvelle source (srcId) lue par un seul bout.
// Rend { clips: [bout], source: { id, data } } ; le rendu avant et après est le même.
export function mergeClips(clips, sources, sr, srcId, newId) {
    if (!clips || clips.length < 2) fail('Il n\'y a qu\'un seul bout sur cette piste : rien à fusionner.');
    const r = renderClips(clips, sources, sr);
    if (!r.mono.length) fail('Rien à fusionner.');
    return { clips: [makeClip(newId(), srcId, r.mono.length, r.startSec)], source: { id: srcId, data: r.mono } };
}
// Fondu croisé entre le bout `id` et son voisin : celui qui commence pendant ce bout ou juste à sa fin, sinon celui qui
// finit pendant ce bout ou juste à son début. S'ils se touchent sans se recouvrir, chaque bord est d'abord re-déroulé
// de joinSec / 2 (si la source le permet). Fondu de sortie sur le premier, d'entrée sur le second, de la longueur du
// recouvrement. Rend { clips, a, b, sec } (a : bout qui sort, b : bout qui entre, sec : durée du fondu).
export function crossfade(clips, id, sr, srcLenOf, joinSec = 0.03) {
    const c = clips[find(clips, id)], eps = 1.5 / sr;
    const after = clips.filter((o) => o.id !== id && o.at > c.at && o.at <= clipEnd(c, sr) + eps).sort((x, y) => y.at - x.at)[0];
    const before = clips.filter((o) => o.id !== id && o.at <= c.at && clipEnd(o, sr) >= c.at - eps && clipEnd(o, sr) < clipEnd(c, sr) + eps)
        .sort((x, y) => clipEnd(x, sr) - clipEnd(y, sr))[0];
    const A0 = after ? c : before, B0 = after ? after : (before ? c : null);
    if (!A0 || !B0) fail('Aucun bout voisin : fais se toucher ou se recouvrir deux bouts, puis redemande le fondu croisé.');
    let out = cloneClips(clips);
    const get = (cid) => out.find((o) => o.id === cid);
    if (Math.round((clipEnd(A0, sr) - B0.at) * sr) < 2) {   // ils se touchent : re-dérouler les deux bords
        const h = joinSec / 2;
        out = trimClip(out, A0.id, 'end', clipEnd(A0, sr) + h, sr, srcLenOf(A0.src)).clips;
        out = trimClip(out, B0.id, 'start', B0.at - h, sr, srcLenOf(B0.src)).clips;
    }
    const A = get(A0.id), B = get(B0.id);
    const ov = Math.min(Math.round((clipEnd(A, sr) - B.at) * sr), A.len, B.len);
    if (ov < 2) fail('Ces deux bouts se touchent sans réserve de son : re-déroule un bord (Rogner) pour qu\'ils se recouvrent.');
    A.fadeOut = ov / sr; B.fadeIn = ov / sr;
    return { clips: out, a: A.id, b: B.id, sec: ov / sr };
}
// Bout sous l'instant sec (le dernier de la liste l'emporte s'ils se recouvrent ; `prefer` passe devant).
export function clipAt(clips, sec, sr, prefer = null) {
    let hit = null;
    for (const c of clips || []) if (sec >= c.at && sec <= clipEnd(c, sr)) { if (c.id === prefer) return c; hit = c; }
    return hit;
}
