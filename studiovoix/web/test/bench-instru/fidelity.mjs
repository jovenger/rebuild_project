// Fidélité du banc : refait les deux chiffres du produit (web/test/e2e.mjs, lignes ~320-346) hors navigateur.
//   node fidelity.mjs <song.wav> <truth_instru.wav> [tag]
// Chaîne = app.js separateSong : chanson → 44,1 kHz (sinc) → modèle voix → × 1,021 → retour à la fréquence d'origine
// (sinc) → instru = chanson d'origine − voix. SDR et « aigus seuls » : mêmes formules que l'essai du produit.
import { writeFileSync } from 'node:fs';
import { runJob, readWav, readF32, writeF32 } from './sep.mjs';
import { resampleSinc } from '../frozen/resample.js';

const [songPath, truthPath, tag = 'fid'] = process.argv.slice(2);
const log = (lvl, msg) => console.log(`${new Date().toISOString()} [${lvl}] fidelity : ${msg}`);
const out = new URL(`../out/${tag}.voc.f32`, import.meta.url).pathname;
await runJob({ in: songPath, out, model: 'voc' });
const song = readWav(songPath), truth = readWav(truthPath), v = readF32(out);
const comp = 1.021;
let VL = v.l.map((x) => x * comp), VR = v.r.map((x) => x * comp);
if (song.sr !== 44100) { VL = resampleSinc(VL, 44100, song.sr); VR = resampleSinc(VR, 44100, song.sr); }
const fit = (x) => { const o = new Float32Array(song.l.length); o.set(x.subarray(0, o.length)); return o; };
const vl = fit(VL), vr = fit(VR);
const got = { l: song.l.map((x, i) => x - vl[i]), r: song.r.map((x, i) => x - vr[i]) };
const n = Math.min(truth.l.length, got.l.length);
const sdr = (ref, est) => { let a = 0, e = 0; for (const c of ['l', 'r']) for (let i = 0; i < n; ++i) { a += ref[c][i] ** 2; e += (ref[c][i] - est[c][i]) ** 2; } return 10 * Math.log10(a / Math.max(1e-20, e)); };
const before = sdr(truth, song), after = sdr(truth, got);
const hp = (x) => { const y = new Float32Array(x.length); for (let i = 2; i < x.length; ++i) y[i] = x[i] - 2 * x[i - 1] + x[i - 2]; return y; };
const hi = sdr({ l: hp(truth.l), r: hp(truth.r) }, { l: hp(got.l), r: hp(got.r) });
log('info', `${songPath} (${song.sr} Hz) : instru SDR ${after.toFixed(2)} dB (chanson brute ${before.toFixed(2)} dB) ; aigus seuls ${hi.toFixed(2)} dB`);
writeF32(new URL(`../out/${tag}.instru.f32`, import.meta.url).pathname, got.l, got.r);
writeFileSync(new URL(`../out/${tag}.fidelity.json`, import.meta.url).pathname, JSON.stringify({ songPath, sr: song.sr, sdr: after, sdrBefore: before, hf: hi }));
