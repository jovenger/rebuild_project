// Essai Node du repérage des chanteurs (singers.js : clusterVoices, findSingers) sur des empreintes de synthèse.
// Règle vérifiée : MÊME VOIX = MÊME PISTE ; dans le doute, une seule voix.
// Les empreintes de synthèse reproduisent les ressemblances mesurées sur de vraies voix (fenêtres de 2 s, modèle
// WeSpeaker) : une même voix dans le même ton ≈ 0,7 (parole) ou ≈ 0,4 (chant) ; la même voix dans un autre ton
// (transposée de 3 demi-tons) ≈ 0,25, centres de 0,14 à 0,5 ; deux personnes différentes ≈ 0 à 0,1 en parole.
//   node web/test/singers.mjs
import { clusterVoices, findSingers } from '../singers.js';
let failed = false;
const check = (name, ok, detail) => { console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${name} — ${detail}`); if (!ok) failed = true; };

// ---------------------------------------------------------------- empreintes de synthèse (tirage fixe, reproductible)
const D = 256;
let seed = 12345;
const rnd = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed / 4294967296; };
const gauss = () => Math.sqrt(-2 * Math.log(rnd() + 1e-12)) * Math.cos(2 * Math.PI * rnd());
/** Une fenêtre : part commune à toutes les voix (axe 0), part propre à la voix (axe 1 + voix), part propre au ton
 *  (axe 20 + ton), bruit propre à la fenêtre. Les poids sont des parts d'énergie : la ressemblance attendue de deux
 *  fenêtres vaut commun + voix (si même voix) + ton (si même ton). */
function emb({ voice, tone = 0, common = 0, wVoice, wTone = 0 }) {
    const e = new Float32Array(D), wNoise = Math.max(0, 1 - common - wVoice - wTone);
    let q = 0;
    for (let i = 40; i < D; ++i) { e[i] = gauss(); q += e[i] * e[i]; }
    for (let i = 40; i < D; ++i) e[i] *= Math.sqrt(wNoise / q);
    e[0] = Math.sqrt(common); e[1 + voice] = Math.sqrt(wVoice); e[20 + voice * 4 + tone] = Math.sqrt(wTone);
    return e;
}
const many = (n, spec) => Array.from({ length: n }, () => emb(spec));
const run = (embs, opts) => clusterVoices(embs, embs.map(() => 60), embs.map(() => 1), opts);
const sizes = (r) => r.dur.map((d) => d.toFixed(0)).join(' / ');

// 1) Une seule voix, même ton (parole) : une voix.
{
    const r = run(many(20, { voice: 0, wVoice: 0.7 }));
    check('une voix, même ton', r.k === 1 && r.trace.merges.length === 0, `${r.k} voix, ${r.trace.pure} groupe(s) sûr(s) au départ`);
}
// 2) Une voix dont l'empreinte dérive avec le ton : trois « couplets » de 10 s dans trois tons → UNE voix, par prudence.
{
    const tones = [0, 1, 2].flatMap((tone) => many(10, { voice: 0, tone, common: 0.05, wVoice: 0.2, wTone: 0.46 }));
    const r = run(tones);
    const worst = Math.min(...r.trace.merges.map((m) => m.sim));
    check('une voix sur trois tons → une seule voix', r.k === 1, `${r.k} voix (durées ${sizes(r)} s)`);
    check('… réunie par prudence, et la trace le dit', r.trace.sure === 3 && r.trace.merges.length === 2 && worst >= r.trace.simDiff && worst < 0.44,
        `${r.trace.sure} groupes avant la preuve, ${r.trace.merges.length} réunions par prudence, ressemblance la plus basse ${worst.toFixed(2)} (seuil ${r.trace.simDiff})`);
}
// 3) Deux voix nettement différentes qui alternent → deux voix, dans l'ordre d'apparition.
{
    const a = { voice: 0, wVoice: 0.7 }, b = { voice: 1, wVoice: 0.7 };
    const r = run([...many(6, a), ...many(6, b), ...many(6, a), ...many(6, b)]);
    const lab = r.labels.join('');
    check('deux voix nettement différentes → deux voix', r.k === 2 && lab === '000000111111000000111111', `${r.k} voix, étiquettes ${lab}, ressemblance des centres ${r.sims.map((s) => s.toFixed(2)).join(', ')}`);
    check('… rien n\'est réuni par prudence', r.trace.merges.length === 0 && r.sims[0] < r.trace.simDiff, `${r.trace.merges.length} réunion(s)`);
}
// 4) Deux groupes proches (ressemblance des centres ≈ 0,25 : au niveau d'une même voix qui change de ton) → UNE voix.
{
    const r = run([...many(10, { voice: 0, common: 0.2, wVoice: 0.5 }), ...many(10, { voice: 1, common: 0.2, wVoice: 0.5 })]);
    check('deux groupes proches → une seule voix, par prudence', r.k === 1 && r.trace.merges.length === 1 && r.trace.merges[0].sim > r.trace.simDiff && r.trace.merges[0].sim < 0.44,
        `${r.k} voix ; réunion à ${r.trace.merges[0]?.sim.toFixed(2)} (il faut moins de ${r.trace.simDiff} pour deux voix) ; durées réunies ${r.trace.merges[0]?.dur.join(' s et ')} s`);
}
// 5) Un groupe trop court : 2 s d'une autre voix au milieu de 20 s → absorbé, pas de piste pour si peu.
{
    const a = { voice: 0, wVoice: 0.7 }, b = { voice: 1, wVoice: 0.7 }, c = { voice: 2, wVoice: 0.7 };
    const r1 = run([...many(10, a), ...many(2, b), ...many(10, a)]);
    check('2 s d\'une autre voix dans 20 s → une seule voix', r1.k === 1 && r1.trace.absorbed.length === 1 && r1.trace.absorbed[0].dur === 2, `${r1.k} voix, ${r1.trace.absorbed.length} groupe absorbé de ${r1.trace.absorbed[0]?.dur} s (minimum ${r1.trace.minSec} s)`);
    const r2 = run([...many(10, a), ...many(2, c), ...many(10, b)]);
    check('2 s d\'une 3e voix entre deux voix → deux voix', r2.k === 2 && r2.trace.absorbed.length === 1, `${r2.k} voix (durées ${sizes(r2)} s), ${r2.trace.absorbed.length} groupe absorbé`);
    const r3 = run([...many(10, a), ...many(r1.trace.minSec + 2, b)]);
    check(`${r1.trace.minSec + 2} s d'une autre voix nette → deux voix`, r3.k === 2, `${r3.k} voix (durées ${sizes(r3)} s)`);
}
// 6) Trois voix nettes → trois voix ; la hauteur ne sert jamais de preuve (mêmes empreintes, hauteurs très différentes → une voix).
{
    const v = (voice) => many(8, { voice, wVoice: 0.7 });
    const r = run([...v(0), ...v(1), ...v(2)]);
    check('trois voix nettes → trois voix', r.k === 3, `${r.k} voix (durées ${sizes(r)} s)`);
    const one = many(20, { voice: 0, wVoice: 0.7 });
    const rp = clusterVoices(one, one.map((_, i) => i < 10 ? 45 : 57), one.map(() => 1));
    check('même voix une octave plus haut → une seule voix', rp.k === 1, `${rp.k} voix (hauteurs des fenêtres : 110 Hz puis 220 Hz)`);
}
// 7) Chant : fenêtres d'une même voix peu ressemblantes entre elles (≈ 0,4), deux tons → une seule voix.
{
    const r = run([...many(15, { voice: 0, tone: 0, common: 0.1, wVoice: 0.2, wTone: 0.1 }), ...many(15, { voice: 0, tone: 1, common: 0.1, wVoice: 0.2, wTone: 0.1 })]);
    check('voix chantée (fenêtres peu ressemblantes), deux tons → une seule voix', r.k === 1, `${r.k} voix, ${r.trace.pure} groupe(s) sûr(s) au départ, ${r.trace.merges.length} réunion(s) par prudence`);
}
// 8) Garde-fous d'entrée de clusterVoices.
{
    let r0 = null, err = '';
    try { r0 = clusterVoices([], [], []); } catch (e) { err = e.message; }
    check('aucune fenêtre → aucune voix, sans erreur', !!r0 && r0.k === 0 && r0.labels.length === 0, err || `k = ${r0.k}`);
    const r1 = run(many(1, { voice: 0, wVoice: 0.7 }));
    check('une seule fenêtre → une voix', r1.k === 1 && r1.labels.join('') === '0', `k = ${r1.k}`);
    const r2 = run(many(2, { voice: 0, wVoice: 0.7 }).concat(many(2, { voice: 1, wVoice: 0.7 })));
    check('2 s + 2 s de deux voix : trop court pour deux pistes → une voix', r2.k === 1, `k = ${r2.k} (minimum ${r2.trace.minSec} s par voix)`);
}

// ---------------------------------------------------------------- findSingers : du son aux plages par chanteur
// Son d'essai : phrases de 6 s (note tenue) séparées par 1 s de silence, à 16 kHz. L'empreinte est donnée par un faux
// modèle : la n-ième fenêtre reçoit l'empreinte prévue pour elle (5 fenêtres de 2 s par phrase de 6 s).
const sr = 16000;
function song(nPhrases, phraseSec = 6) {
    const x = new Float32Array(Math.round((nPhrases * (phraseSec + 1) + 1) * sr));
    for (let p = 0; p < nPhrases; ++p) {
        const a = Math.round((1 + p * (phraseSec + 1)) * sr), n = Math.round(phraseSec * sr);
        for (let i = 0; i < n; ++i) x[a + i] = 0.3 * Math.sin(2 * Math.PI * 200 * i / sr) * Math.min(1, i / 800, (n - i) / 800);
    }
    return x;
}
const fake = (list) => { let k = 0; const f = async () => { if (k >= list.length) throw new Error('trop de fenêtres demandées'); return list[k++]; }; f.count = () => k; return f; };
{
    // 4 phrases : voix A, voix B, voix A, voix B → 2 chanteurs, chaque phrase entière à son chanteur.
    const a = { voice: 0, wVoice: 0.7 }, b = { voice: 1, wVoice: 0.7 };
    const emb4 = fake([...many(5, a), ...many(5, b), ...many(5, a), ...many(5, b)]);
    const r = await findSingers(song(4), sr, emb4);
    const who = r.phrases.map((p) => p.singer).join('');
    check('findSingers : deux voix qui alternent → 2 chanteurs', r.singers === 2 && who === '0101' && emb4.count() === 20, `${r.singers} chanteurs, phrases ${who}, ${emb4.count()} fenêtres`);
    check('… compte rendu : parts, seuil et groupes de départ', /2 voix différentes/.test(r.why) && /il faut moins de/.test(r.why) && /groupe\(s\) sûr\(s\) au départ/.test(r.why) && r.detail?.merges.length === 0, r.why);
}
{
    // 3 couplets de la même voix dans trois tons → 1 chanteur, toutes les phrases sur la même piste, raison écrite.
    const emb3 = fake([0, 1, 2].flatMap((tone) => many(5, { voice: 0, tone, common: 0.05, wVoice: 0.2, wTone: 0.46 })));
    const r = await findSingers(song(3), sr, emb3);
    check('findSingers : trois couplets d\'une même voix sur trois tons → 1 chanteur', r.singers === 1 && r.phrases.length === 3 && r.phrases.every((p) => p.singer === 0), `${r.singers} chanteur, ${r.phrases.length} phrases sur la piste 1`);
    check('… compte rendu : réunion par prudence et sa ressemblance', /dans le doute/.test(r.why) && /réunion\(s\) par prudence : ressemblance 0[.,]\d\d/.test(r.why) && /change de ton/.test(r.why), r.why);
}
{
    // Une 2e voix faite seulement de fenêtres isolées (une par phrase, entre deux fenêtres de la 1re) : le lissage les
    // rend à la 1re voix ; il ne doit rester ni piste vide ni piste de moins de quelques secondes.
    const a = { voice: 0, wVoice: 0.7 }, b = { voice: 1, wVoice: 0.7 };
    const r = await findSingers(song(5), sr, fake(Array.from({ length: 5 }, () => [...many(2, a), ...many(1, b), ...many(2, a)]).flat()));
    const sec = [0, 0]; for (const p of r.phrases) sec[p.singer] += p.end - p.start;
    check('findSingers : 2e voix effacée par le lissage → pas de piste vide', r.singers === 1 && r.phrases.every((p) => p.singer === 0) && r.detail.kept === 2 && r.detail.dropped === 1,
        `${r.singers} chanteur (clusterVoices en voyait ${r.detail.kept}), durées par piste ${sec.map((d) => d.toFixed(1)).join(' / ')} s — ${r.why}`);
}
{
    // Garde-fous : aucune fenêtre (silence, son vide), une seule fenêtre, empreinte invalide.
    const never = fake([]);
    const r0 = await findSingers(new Float32Array(0), sr, never);
    check('findSingers : son vide → 1 chanteur, aucune plage', r0.singers === 1 && r0.phrases.length === 0 && never.count() === 0, r0.why);
    const r1 = await findSingers(new Float32Array(5 * sr), sr, never);
    check('findSingers : silence → 1 chanteur, modèle non appelé', r1.singers === 1 && r1.phrases.length === 0 && never.count() === 0, r1.why);
    const r2 = await findSingers(song(1, 1.5), sr, never);
    check('findSingers : une seule fenêtre → 1 chanteur, modèle non appelé', r2.singers === 1 && r2.phrases.length === 1 && never.count() === 0, r2.why);
    const bad = many(10, { voice: 0, wVoice: 0.7 }); bad[3] = new Float32Array(D).fill(NaN);
    const r3 = await findSingers(song(2), sr, fake(bad));
    check('findSingers : empreinte invalide → 1 chanteur, raison écrite', r3.singers === 1 && /invalide/.test(r3.why), r3.why);
}
if (failed) { console.error('ÉCHEC : repérage des chanteurs'); process.exit(1); }
console.log('Repérage des chanteurs OK');
