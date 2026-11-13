// Essai Node de la répartition d'une voix sur plusieurs pistes (singers.js) :
//  - splitRanges : la somme des pistes redonne la voix d'origine, même quand la coupe tombe en plein chant ;
//  - sectionRanges : coupes couplets / refrains déplacées dans un creux de la voix (pas au milieu d'un mot).
//   node web/test/split.mjs
import { splitRanges, keepPhrases, sectionRanges } from '../singers.js';
const sr = 44100;
let failed = false;
const check = (name, ok, detail) => { console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${name} — ${detail}`); if (!ok) failed = true; };
const maxErr = (a, b, from = 0, to = a.length) => { let m = 0; for (let i = from; i < to; ++i) m = Math.max(m, Math.abs(a[i] - b[i])); return m; };
const sum = (parts) => { const o = new Float32Array(parts[0].length); for (const p of parts) for (let i = 0; i < o.length; ++i) o[i] += p[i]; return o; };

// 1) Chant continu de 10 s, trois chanteurs qui se relaient toutes les 2 s sans pause.
{
    const n = 10 * sr, x = new Float32Array(n);
    for (let i = 0; i < n; ++i) x[i] = 0.5 * Math.sin(2 * Math.PI * 220 * i / sr);
    const ranges = [0, 1, 2, 0, 1].map((singer, k) => ({ start: 2 * k, end: 2 * k + 2, singer }));
    const parts = splitRanges(x, sr, ranges, 3);
    const e = maxErr(sum(parts), x, Math.round(0.05 * sr), n - Math.round(0.05 * sr));
    check('relais sans pause : somme des pistes = voix d\'origine', e < 1e-5, `écart max ${e.toExponential(1)} (une bosse de fondu donnerait 0,5)`);
    const k1 = keepPhrases(x, sr, ranges, 1);
    check('keepPhrases = piste du chanteur', maxErr(k1, parts[1]) === 0, 'identique à splitRanges');
    let outside = 0; for (let i = 0; i < 1.9 * sr; ++i) outside = Math.max(outside, Math.abs(parts[1][i]));
    check('chaque piste se tait hors de ses plages', outside === 0, `niveau hors plage ${outside}`);
}
// 2) Plage isolée (silence autour) : fondu de 30 ms vers l'extérieur, rien au-delà.
{
    const n = 6 * sr, x = new Float32Array(n).fill(0.3);
    const p = splitRanges(x, sr, [{ start: 2, end: 4, singer: 0 }], 1)[0];
    const at = (t) => p[Math.round(t * sr)];
    check('bord libre : fondu vers l\'extérieur', Math.abs(at(3) - 0.3) < 1e-6 && at(1.985) > 0.1 && at(1.985) < 0.2 && at(1.96) === 0 && at(4.04) === 0, `milieu ${at(3)}, 15 ms avant ${at(1.985).toFixed(3)}, 40 ms avant ${at(1.96)}`);
}
// 3) Couplets / refrains : mots de 0,8 s séparés par 0,2 s ; un mot est à cheval sur la frontière à 8 s.
{
    const n = 24 * sr, x = new Float32Array(n);
    for (let w = 0; w < 24; ++w) { const a = Math.round((w + 0.6) * sr), b = Math.round((w + 1.4) * sr); for (let i = a; i < Math.min(n, b); ++i) x[i] = 0.4 * Math.sin(2 * Math.PI * 200 * i / sr); }   // mots de w+0,6 à w+1,4 s
    const sections = [{ start: 0, end: 8, kind: 'couplet' }, { start: 8, end: 16, kind: 'refrain' }, { start: 16, end: 24, kind: 'couplet' }];
    const r = sectionRanges(x, sr, sections);
    check('couplets / refrains : plages trouvées', !!r && r.length === 3 && r[0].part === 0 && r[1].part === 1 && r[2].part === 0, JSON.stringify(r?.map((q) => [q.start.toFixed(2), q.end.toFixed(2), q.part])));
    if (r) {
        const inWord = (t) => { const f = (t % 1 + 1) % 1; return f > 0.62 || f < 0.38; };   // un mot occupe [0,6 ; 1,4] modulo 1
        check('coupes proches des frontières', Math.abs(r[0].end - 8) < 0.6 && Math.abs(r[1].end - 16) < 0.6, `à ${r[0].end.toFixed(2)} et ${r[1].end.toFixed(2)} s`);
        check('coupes dans un creux de la voix', r.slice(0, -1).every((q) => !inWord(q.end)), `coupes à ${r.slice(0, -1).map((q) => q.end.toFixed(2)).join(' et ')} s (frontières à 8 et 16 s, mots à cheval)`);
        const parts = splitRanges(x, sr, r, 2, 'part');
        check('couplets + refrains = voix d\'origine', maxErr(sum(parts), x) < 1e-5, `écart max ${maxErr(sum(parts), x).toExponential(1)}`);
    }
    check('morceau sans refrain : pas de découpage', sectionRanges(x, sr, [{ start: 0, end: 24, kind: 'couplet' }]) === null, 'null');
}
console.log(failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
