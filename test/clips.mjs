// Essai du montage par « bouts » (web/clips.js), sans page : node web/test/clips.mjs
// Chaque contrôle écrit une ligne « OK » ou « ÉCHEC » ; code de sortie 1 au premier échec constaté en fin d'essai.
import {
    renderClips, splitClip, trimClip, setFades, setGain, setMute, setRev, moveClip, removeClip, duplicateClip, insertClip,
    mergeClips, crossfade, clipAt, makeClip, sanitizeClips, clipEnd, ClipError, GAIN_MIN_DB, GAIN_MAX_DB,
} from '../clips.js';

const sr = 44100;
let bad = 0, nId = 0;
const newId = () => `t${++nId}`;
function check(name, ok, detail = '') {
    console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${name}${detail ? ' — ' + detail : ''}`);
    if (!ok) ++bad;
}
function refused(name, fn) {
    try { fn(); check(name, false, 'geste accepté alors qu\'il devait être refusé'); }
    catch (e) { check(name, e instanceof ClipError, e instanceof ClipError ? `refusé : « ${e.message} »` : String(e)); }
}
const same = (a, b) => { if (a.length !== b.length) return false; for (let i = 0; i < a.length; ++i) if (a[i] !== b[i]) return false; return true; };
const maxDiff = (a, b) => { let m = a.length === b.length ? 0 : Infinity; for (let i = 0; i < Math.min(a.length, b.length); ++i) m = Math.max(m, Math.abs(a[i] - b[i])); return m; };
const rms = (x, a = 0, b = x.length) => { let e = 0; for (let i = a; i < b; ++i) e += x[i] * x[i]; return Math.sqrt(e / Math.max(1, b - a)); };

// Source : 3 s de « voix » (somme de sinus modulée + bruit déterministe), niveaux variés.
const N = 3 * sr, voice = new Float32Array(N);
let seed = 12345;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff - 0.5; };
for (let i = 0; i < N; ++i) voice[i] = 0.5 * Math.sin(2 * Math.PI * 220 * i / sr) * (0.6 + 0.4 * Math.sin(2 * Math.PI * 3 * i / sr)) + 0.1 * rnd();
const sources = new Map([['v', voice]]);
const lenOf = (id) => sources.get(id)?.length || 0;
const AT = 0.37;
const base = () => [makeClip('c0', 'v', N, AT)];

// 0. Une prise sans montage = un bout : rendu identique à la source.
{
    const r = renderClips(base(), sources, sr);
    check('un seul bout : rendu = source au bit près, même place', same(r.mono, voice) && r.startSec === AT);
}
// 1. Couper puis rendre = son d'origine au bit près.
{
    let clips = base();
    for (const sec of [1.0, 2.2, 0.371, 3.3]) { const hit = clipAt(clips, sec, sr); clips = splitClip(clips, hit.id, sec, sr, newId).clips; }
    const r = renderClips(clips, sources, sr);
    check('couper (4 coupes) puis rendre = d\'origine au bit près', clips.length === 5 && same(r.mono, voice) && r.startSec === AT, `${clips.length} bouts`);
}
// 2. Couper + recoller en fondu croisé sur lui-même = d'origine.
//    Tolérance 1e-6 : x·w + x·(1−w) en simple précision, soit au pire deux arrondis de 6e-8 sur un signal ≤ 1.
{
    const cut = splitClip(base(), 'c0', 1.5, sr, newId);
    const x = crossfade(cut.clips, cut.left, sr, lenOf, 0.03);
    const r = renderClips(x.clips, sources, sr);
    const d = maxDiff(r.mono, voice);
    check('couper + fondu croisé sur lui-même = d\'origine', d <= 1e-6 && x.sec > 0.02 && r.startSec === AT, `écart max ${d.toExponential(2)} (tolérance 1e-6), fondu ${(x.sec * 1000).toFixed(1)} ms`);
    // fondu croisé long par recouvrement manuel : la moitié droite re-déroulée de 0,5 s vers la gauche
    let c2 = trimClip(cut.clips, cut.right, 'start', 1.0, sr, N).clips;
    const x2 = crossfade(c2, cut.right, sr, lenOf);
    const d2 = maxDiff(renderClips(x2.clips, sources, sr).mono, voice);
    check('fondu croisé long (recouvrement de 0,5 s) = d\'origine', d2 <= 1e-6 && Math.abs(x2.sec - 0.5) < 1 / sr, `écart max ${d2.toExponential(2)}, fondu ${x2.sec.toFixed(3)} s`);
}
// 3. Rogner puis re-dérouler = d'origine.
{
    let clips = trimClip(base(), 'c0', 'start', AT + 0.8, sr, N).clips;
    clips = trimClip(clips, 'c0', 'end', AT + 2.0, sr, N).clips;
    const cut = renderClips(clips, sources, sr);
    const o = Math.round(0.8 * sr);
    check('rogner : le rendu est la zone gardée, à sa place', cut.mono.length === Math.round(1.2 * sr) && same(cut.mono, voice.subarray(o, o + cut.mono.length)) && Math.abs(cut.startSec - (AT + 0.8)) < 1e-9);
    check('rogner : la source n\'est pas modifiée', sources.get('v') === voice && voice.length === N);
    clips = trimClip(clips, 'c0', 'start', -5, sr, N).clips;    // au-delà du bord : borné à la source
    clips = trimClip(clips, 'c0', 'end', 99, sr, N).clips;
    const r = renderClips(clips, sources, sr);
    check('rogner puis re-dérouler à fond = d\'origine au bit près', same(r.mono, voice) && Math.abs(r.startSec - AT) < 1e-9 && clips[0].off === 0 && clips[0].len === N);
}
// 4. Inverser deux fois = d'origine ; une fois = lu à l'envers.
{
    const once = setRev(base(), 'c0', true), r1 = renderClips(once, sources, sr);
    let ok = r1.mono.length === N;
    for (let i = 0; i < N && ok; ++i) ok = r1.mono[i] === voice[N - 1 - i];
    check('inverser : le bout est lu à l\'envers', ok);
    const twice = setRev(once, 'c0', false);
    check('inverser deux fois = d\'origine au bit près', same(renderClips(twice, sources, sr).mono, voice));
    // couper un bout inversé ne change pas le rendu ; rogner son début retire bien le début entendu
    const cut = splitClip(once, 'c0', AT + 1.1, sr, newId);
    check('couper un bout inversé : rendu inchangé', same(renderClips(cut.clips, sources, sr).mono, r1.mono));
    const tr = renderClips(trimClip(once, 'c0', 'start', AT + 0.5, sr, N).clips, sources, sr);
    check('rogner le début d\'un bout inversé', same(tr.mono, r1.mono.subarray(Math.round(0.5 * sr))));
}
// 5. Gain −6 dB = niveau divisé par deux.
{
    const r = renderClips(setGain(base(), 'c0', -6), sources, sr);
    const ratio = rms(r.mono) / rms(voice), want = Math.pow(10, -6 / 20);
    check('gain −6 dB : niveau ÷ 2', Math.abs(ratio - want) < 1e-4, `rapport ${ratio.toFixed(4)} (attendu ${want.toFixed(4)})`);
    const lim = setGain(setGain(base(), 'c0', 99), 'c0', 99)[0].gainDb, lim2 = setGain(base(), 'c0', -99)[0].gainDb;
    check('gain borné de −24 à +12 dB', lim === GAIN_MAX_DB && lim2 === GAIN_MIN_DB, `${lim2} … ${lim}`);
    // gain d'un seul bout : les autres ne bougent pas
    const cut = splitClip(base(), 'c0', AT + 1, sr, newId), g = renderClips(setGain(cut.clips, cut.right, -6), sources, sr).mono;
    check('gain d\'un bout : le reste est intact', same(g.subarray(0, sr), voice.subarray(0, sr)) && Math.abs(rms(g, sr) / rms(voice, sr) - want) < 1e-4);
}
// 6. Muet = silence sur la zone du bout et rien d'autre.
{
    let clips = splitClip(base(), 'c0', AT + 1, sr, newId).clips;
    const cut2 = splitClip(clips, clips[1].id, AT + 2, sr, newId);
    const r = renderClips(setMute(cut2.clips, cut2.left, true), sources, sr);
    let silent = true; for (let i = sr; i < 2 * sr; ++i) if (r.mono[i] !== 0) { silent = false; break; }
    check('muet : silence sur le bout, le reste au bit près', silent && r.mono.length === N && same(r.mono.subarray(0, sr), voice.subarray(0, sr)) && same(r.mono.subarray(2 * sr), voice.subarray(2 * sr)));
    const end = renderClips(setMute(cut2.clips, cut2.right, true), sources, sr);
    check('muet sur le dernier bout : la prise garde sa longueur', end.mono.length === N && rms(end.mono, 2 * sr) === 0);
}
// 7. Fusion = même rendu, un seul bout.
{
    let clips = splitClip(base(), 'c0', AT + 1, sr, newId).clips;
    clips = setGain(clips, clips[1].id, -3);
    clips = setFades(clips, clips[0].id, { fadeIn: 0.2 }, sr);
    clips = moveClip(clips, clips[1].id, AT + 1.4);   // trou de 0,4 s
    const before = renderClips(clips, sources, sr);
    const m = mergeClips(clips, sources, sr, 'merged', newId);
    const s2 = new Map([...sources, [m.source.id, m.source.data]]);
    const after = renderClips(m.clips, s2, sr);
    check('fusionner : un seul bout, même rendu au bit près, même place', m.clips.length === 1 && same(after.mono, before.mono) && after.startSec === before.startSec, `${before.mono.length} échantillons`);
    check('fusionner : les sources d\'origine restent intactes', same(sources.get('v'), voice));
}
// 8. Déplacement = même son, autre place ; dupliquer ; coller.
{
    const r = renderClips(moveClip(base(), 'c0', 5.25), sources, sr);
    check('déplacer : même son, autre place', same(r.mono, voice) && r.startSec === 5.25);
    const neg = moveClip(base(), 'c0', -3)[0].at;
    check('déplacer avant 0 : ramené à 0', neg === 0);
    const cut = splitClip(base(), 'c0', AT + 1, sr, newId);
    const d = duplicateClip(cut.clips, cut.left, sr, newId, 10), rd = renderClips(d.clips, sources, sr);
    const o = Math.round((10 - AT) * sr);
    check('dupliquer : la copie joue le même son à sa place', d.clips.length === 3 && same(rd.mono.subarray(o, o + sr), voice.subarray(0, sr)) && same(rd.mono.subarray(0, N), voice));
    const def = duplicateClip(base(), 'c0', sr, newId);
    check('dupliquer sans place : juste après l\'original', Math.abs(def.clips[1].at - (AT + 3)) < 1e-9 && def.clips[1].id !== 'c0');
    // envoyer vers une autre piste en gardant la place : le bout part d'une liste et arrive dans une autre, même `at`
    const moved = cut.clips.find((c) => c.id === cut.right);
    const other = insertClip([], moved, moved.at, newId), ro = renderClips(other.clips, sources, sr);
    check('envoyer vers une autre piste : même son, même instant', same(ro.mono, voice.subarray(sr)) && Math.abs(ro.startSec - (AT + 1)) < 1e-9);
    const rest = renderClips(removeClip(cut.clips, cut.right), sources, sr);
    check('… et il a quitté la piste d\'origine', same(rest.mono, voice.subarray(0, sr)) && rest.startSec === AT);
}
// 9. Fondus : forme, bornes, recouvrement qui s'additionne.
{
    const f = renderClips(setFades(base(), 'c0', { fadeIn: 0.5, fadeOut: 0.25 }, sr), sources, sr).mono;
    const mid = same(f.subarray(sr, 2 * sr), voice.subarray(sr, 2 * sr));
    check('fondus : début et fin atténués, milieu intact', mid && Math.abs(f[0]) < 1e-4 && Math.abs(f[N - 1]) < 1e-4 && rms(f, 0, sr / 4) < 0.5 * rms(voice, 0, sr / 4));
    const ones = new Float32Array(sr).fill(1), so = new Map([['o', ones]]);
    const w = renderClips(setFades([makeClip('a', 'o', sr, 0)], 'a', { fadeIn: 0.1 }, sr), so, sr).mono;
    const n = Math.round(0.1 * sr);
    let mono = true; for (let i = 1; i < n; ++i) if (w[i] < w[i - 1]) mono = false;
    check('fondu d\'entrée : courbe en cosinus, croissante de 0 à 1', mono && w[0] < 0.001 && Math.abs(w[n >> 1] - 0.5) < 0.01 && w[n] === 1);
    const ov = renderClips([makeClip('a', 'o', sr, 0), makeClip('b', 'o', sr, 0.5)], so, sr).mono;
    check('bouts qui se recouvrent : ils s\'additionnent', ov[sr / 4] === 1 && ov[Math.round(0.75 * sr)] === 2 && ov[Math.round(1.25 * sr)] === 1);
    const x = crossfade([makeClip('a', 'o', sr, 0), makeClip('b', 'o', sr, 0.5)], 'a', sr, () => sr), xr = renderClips(x.clips, so, sr).mono;
    let flat = 0; for (let i = 0; i < xr.length; ++i) flat = Math.max(flat, Math.abs(xr[i] - 1));
    check('fondu croisé de deux bouts qui se recouvrent : niveau constant', flat <= 1e-6 && Math.abs(x.sec - 0.5) < 1e-9, `écart max ${flat.toExponential(2)}`);
}
// 10. Garde-fous.
{
    refused('coupe hors du bout', () => splitClip(base(), 'c0', AT + 9, sr, newId));
    refused('coupe avant le bout', () => splitClip(base(), 'c0', 0.1, sr, newId));
    refused('coupe exactement sur un bord', () => splitClip(base(), 'c0', AT, sr, newId));
    refused('coupe à un instant invalide (NaN)', () => splitClip(base(), 'c0', NaN, sr, newId));
    refused('bout inconnu', () => setGain(base(), 'nope', 3));
    refused('fusion d\'un seul bout', () => mergeClips(base(), sources, sr, 'm', newId));
    refused('fusion d\'une liste vide', () => mergeClips([], sources, sr, 'm', newId));
    refused('fondu croisé sans voisin', () => crossfade(base(), 'c0', sr, lenOf));
    refused('coller rien', () => insertClip(base(), null, 1, newId));
    const tiny = trimClip(base(), 'c0', 'end', -50, sr, N).clips[0];
    check('rogner à fond : il reste au moins 1 échantillon (jamais de bout de longueur nulle)', tiny.len === 1);
    const tiny2 = trimClip(base(), 'c0', 'start', 99, sr, N).clips[0];
    check('rogner le début à fond : 1 échantillon, celui de la fin', tiny2.len === 1 && tiny2.off === N - 1);
    const lf = setFades(base(), 'c0', { fadeIn: 99, fadeOut: 99 }, sr)[0];
    const rl = renderClips([lf], sources, sr).mono;
    check('fondus plus longs que le bout : bornés à sa durée, rendu sans valeur invalide', Math.abs(lf.fadeIn - 3) < 1e-9 && Math.abs(lf.fadeOut - 3) < 1e-9 && rl.length === N && rl.every((v) => Number.isFinite(v)));
    const short = trimClip(setFades(base(), 'c0', { fadeIn: 1, fadeOut: 1 }, sr), 'c0', 'end', AT + 0.5, sr, N).clips[0];
    check('rogner un bout plus court que ses fondus : fondus réduits', short.fadeIn <= 0.5 + 1e-9 && short.fadeOut <= 0.5 + 1e-9);
    const empty = renderClips([], sources, sr), none = renderClips(null, sources, sr);
    check('liste vide : rendu vide, sans erreur', empty.mono.length === 0 && empty.startSec === 0 && none.mono.length === 0);
    const lost = renderClips([makeClip('z', 'absente', 100, 0)], sources, sr);
    check('source manquante : bout ignoré, sans erreur', lost.mono.length === 0);
    check('clipAt hors de tout bout : rien', clipAt(base(), 99, sr) === null && clipAt([], 1, sr) === null);
    const s = sanitizeClips([{ id: 'ok', src: 'v', off: 0, len: 100, at: 1, gainDb: 50, fadeIn: -1, fadeOut: 9 }, { id: 'x', src: 'v', off: N - 10, len: 100, at: 0 },
        { id: 'y', src: 'absente', off: 0, len: 10, at: 0 }, { id: 'z', src: 'v', off: 0, len: 0, at: 0 }, null, { id: 5, src: 'v', off: 0, len: 5, at: 0 }, { id: 'n', src: 'v', off: 0, len: 5, at: -1 }], lenOf, sr);
    check('bouts relus d\'une sauvegarde : seuls les bouts valides sont gardés, valeurs bornées', s.clips.length === 1 && s.dropped === 6 && s.clips[0].gainDb === GAIN_MAX_DB && s.clips[0].fadeIn === 0 && Math.abs(s.clips[0].fadeOut - 100 / sr) < 1e-12);
    check('sauvegarde illisible (pas une liste) : aucun bout', sanitizeClips('n\'importe quoi', lenOf, sr).clips.length === 0);
    const b0 = base(); splitClip(b0, 'c0', AT + 1, sr, newId); setGain(b0, 'c0', -6); trimClip(b0, 'c0', 'end', AT + 1, sr, N);
    check('les opérations ne modifient pas la liste reçue', JSON.stringify(b0) === JSON.stringify(base()));
    check('fin d\'un bout', Math.abs(clipEnd(base()[0], sr) - (AT + 3)) < 1e-12);
}
// 11. Temps de rendu d'une prise de 3 min 30 (mesure, pas un seuil) : 1 bout, puis 40 bouts avec gain et fondus.
{
    const n = Math.round(210 * sr), long = new Float32Array(n);
    for (let i = 0; i < n; ++i) long[i] = Math.sin(i * 0.01) * 0.5;
    const sl = new Map([['l', long]]);
    let clips = [makeClip('l0', 'l', n, 0)];
    let t0 = performance.now(); const r1 = renderClips(clips, sl, sr); const ms1 = performance.now() - t0;
    for (let k = 1; k < 40; ++k) { const hit = clipAt(clips, k * 5.1, sr); clips = splitClip(clips, hit.id, k * 5.1, sr, newId).clips; }
    clips = clips.map((c, k) => ({ ...c, gainDb: k % 2 ? -3 : 2, fadeIn: 0.05, fadeOut: 0.05, rev: k % 5 === 0 }));
    t0 = performance.now(); const r2 = renderClips(clips, sl, sr); const ms2 = performance.now() - t0;
    check('rendu d\'une prise de 3 min 30', r1.mono.length === n && r2.mono.length === n, `1 bout : ${ms1.toFixed(0)} ms ; 40 bouts (gain, fondus, 8 inversés) : ${ms2.toFixed(0)} ms`);
}
console.log(bad ? `ÉCHEC : ${bad} contrôle(s) en échec` : 'OK : tous les contrôles du montage passent');
process.exit(bad ? 1 : 0);
