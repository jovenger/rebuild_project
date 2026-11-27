// Prototype des règles de sep_post.mjs dans la chaîne du produit, sur les extraits et sur la chanson d'essai à 48 kHz.
//   node run_post.mjs <règle,règle…> <extrait|chemin song.wav> …
// Écrit out/<extrait>.post_<règle>.f32 (signal à soustraire, 44,1 kHz) ; compare la voix à out/<extrait>.voc.f32 ;
// journalise le temps ajouté par morceau. Pour un WAV qui n'est pas à 44,1 kHz (chanson d'essai 48 kHz) : refait les
// deux chiffres du produit (SDR, aigus seuls) à la fréquence d'origine, avec et sans la règle.
import { existsSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, basename } from 'node:path';
import { readWav, readF32, writeF32, CFGS } from './sep.mjs';
import { separateWithSubs } from './sep_post.mjs';
import { resampleSinc } from '../frozen/resample.js';

const require = createRequire(import.meta.url);
const ort = require('onnxruntime-node');
const B = new URL('..', import.meta.url).pathname, THREADS = Number(process.env.THREADS || 3);
const log = (lvl, msg) => console.log(`${new Date().toISOString()} [${lvl}] post : ${msg}`);
const [rulesArg, ...targets] = process.argv.slice(2);
const rules = rulesArg.split(',');
const cfg = CFGS.voc;
const s = await ort.InferenceSession.create(cfg.file, { executionProviders: ['cpu'], graphOptimizationLevel: 'all', intraOpNumThreads: THREADS, interOpNumThreads: 1 });
const runModel = async (x) => (await s.run({ input: new ort.Tensor('float32', x, [1, 4, cfg.dimF, cfg.dimT]) })).output.data;
const sdrOf = (ref, est, n) => { let a = 0, e = 0; for (const c of ['l', 'r']) for (let i = 0; i < n; ++i) { a += ref[c][i] ** 2; e += (ref[c][i] - est[c][i]) ** 2; } return 10 * Math.log10(a / Math.max(1e-20, e)); };
const hp = (x) => { const y = new Float32Array(x.length); for (let i = 2; i < x.length; ++i) y[i] = x[i] - 2 * x[i - 1] + x[i - 2]; return y; };

for (const t of targets) {
    const isPath = t.endsWith('.wav'), songPath = isPath ? t : `${B}items/${t}/song.wav`, tag = isPath ? (process.env.TAG || basename(dirname(t))) : t;
    const wav = readWav(songPath);
    let L = wav.l, R = wav.r;
    if (wav.sr !== 44100) { L = resampleSinc(L, wav.sr, 44100); R = resampleSinc(R, wav.sr, 44100); }
    const t0 = performance.now();
    const CONS = process.env.CONSISTENT === '1', pre = CONS ? 'post_c_' : 'post_';
    const v = await separateWithSubs(L, R, runModel, cfg, { overlap: 0.25, skipBelowDb: -60, consistent: CONS }, rules);
    const secs = (performance.now() - t0) / 1000, p = v.profile, per = Math.max(1, p.chunks);
    log('info', `${tag} : ${secs.toFixed(1)} s, ${p.chunks} morceaux — par morceau : modèle ${(p.modelMs / per).toFixed(0)} ms, aller ${(p.stftMs / per).toFixed(0)} ms, retour ${(p.istftMs / per).toFixed(0)} ms, ` +
        `règle(s) + transformées en plus ${(p.postMs / per).toFixed(0)} ms (${(100 * p.postMs / (p.modelMs + p.stftMs + p.istftMs)).toFixed(1)} % du calcul de base, ${rules.length} règle(s))`);
    const ref = `${B}out/${tag}.voc.f32`;
    if (existsSync(ref)) {
        const b = readF32(ref); let d = 0, e = 0;
        for (let i = 0; i < b.l.length; ++i) { d += (b.l[i] - v.left[i]) ** 2 + (b.r[i] - v.right[i]) ** 2; e += b.l[i] ** 2 + b.r[i] ** 2; }
        log('info', `${tag} : voix du prototype contre separateVocals (copie figée) : écart ${(10 * Math.log10(d / Math.max(1e-30, e) + 1e-30)).toFixed(1)} dB`);
    }
    if (CONS) log('info', `${tag} : part de la sortie brute du modèle jetée par la transformée retour (énergie, < 6 kHz / 6–12 kHz / > 12 kHz) : ${p.incNum.map((x, i) => (10 * Math.log10(x / Math.max(1e-30, p.incDen[i]))).toFixed(1) + ' dB').join(' / ')}`);
    if (!existsSync(ref)) { writeF32(ref, v.left, v.right); writeFileSync(ref + '.json', JSON.stringify({ in: songPath, model: 'voc', seconds: secs, profile: p, threads: THREADS, via: 'run_post.mjs' })); }
    for (const r of rules) writeF32(`${B}out/${tag}.${pre}${r}.f32`, v.subs[r].left, v.subs[r].right);
    writeFileSync(`${B}out/${tag}.${CONS ? 'post_c' : 'post'}.json`, JSON.stringify({ rules, seconds: secs, profile: p, threads: THREADS }));
    const truthPath = isPath ? `${dirname(t)}/truth_instru.wav` : null;
    if (truthPath && existsSync(truthPath)) {
        // Chiffres du produit, à la fréquence d'origine : instru = chanson − (signal à soustraire rééchantillonné).
        const truth = readWav(truthPath), fit = (x) => { const o = new Float32Array(wav.l.length); o.set(x.subarray(0, o.length)); return o; };
        const back = (x) => fit(wav.sr === 44100 ? x : resampleSinc(x, 44100, wav.sr));
        const n = Math.min(truth.l.length, wav.l.length);
        const evalSub = (name, sl, sr_) => {
            const a = back(sl), b = back(sr_), got = { l: wav.l.map((x, i) => x - a[i]), r: wav.r.map((x, i) => x - b[i]) };
            const sdr = sdrOf(truth, got, n), hi = sdrOf({ l: hp(truth.l), r: hp(truth.r) }, { l: hp(got.l), r: hp(got.r) }, n);
            log('info', `${tag} (${wav.sr} Hz) / ${name} : instru SDR ${sdr.toFixed(2)} dB ; aigus seuls ${hi.toFixed(2)} dB`);
        };
        evalSub('ligne de base (voix × 1,021)', v.left.map((x) => x * cfg.compensate), v.right.map((x) => x * cfg.compensate));
        for (const r of rules) evalSub(r, v.subs[r].left, v.subs[r].right);
    }
}
