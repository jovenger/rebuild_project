// Banc « Séparer une chanson » (StudioVoix web) hors navigateur : même chaîne que web/app.js separateSong, étape 1.
//   node sep.mjs <jobs.json>
// jobs.json = [{ in: "song.wav", out: "voc.f32", model: "voc"|"insthq3"|..., neg: false, shift: 0, overlap: 0.25 }, …]
// Sortie de chaque travail : la sortie du modèle ramenée dans le temps (AVANT « compensate »), stéréo entrelacée float32
// à 44,1 kHz, plus <out>.json (durées, morceaux). Si l'entrée n'est pas à 44,1 kHz : rééchantillonnage sinc du produit
// (copie figée de resample.js) et écriture de <out>.in44.f32 n'est PAS faite (voir fidelity.mjs pour le chemin 48 kHz).
// neg : entrée × −1 (sert à recomposer « Finition soignée » : 0,5 × (modèle(x) − modèle(−x)), linéaire après le modèle).
// shift : s échantillons de silence ajoutés devant (puis retirés de la sortie) — décalage temporel moyenné.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MDX, separateVocals } from '../frozen/isolate.js';
import { resampleSinc } from '../frozen/resample.js';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const ort = require('onnxruntime-node');
const THREADS = Number(process.env.THREADS || 3);
const log = (lvl, msg) => console.log(`${new Date().toISOString()} [${lvl}] sep : ${msg}`);

const MODELS_DIR = '/home/user/rebuild_project/studiovoix/web/models';
// Réglages : voc = copie de MDX (produit). Les autres : UVR model_data_new.json (voir logs/model_data_new.json).
export const CFGS = {
    voc: { ...MDX, file: `${MODELS_DIR}/UVR-MDX-NET-Voc_FT.onnx` },
    insthq3: { sampleRate: 44100, nFft: 6144, hop: 1024, dimF: 3072, dimT: 256, overlap: 0.25, compensate: 1.022, primary: 'Instrumental', file: resolve(here, '../models/UVR-MDX-NET-Inst_HQ_3.onnx') },
    insthq4: { sampleRate: 44100, nFft: 5120, hop: 1024, dimF: 2560, dimT: 256, overlap: 0.25, compensate: 1.019, primary: 'Instrumental', file: resolve(here, '../models/UVR-MDX-NET-Inst_HQ_4.onnx') },
    kim2: { sampleRate: 44100, nFft: 7680, hop: 1024, dimF: 3072, dimT: 256, overlap: 0.25, compensate: 1.009, primary: 'Vocals', file: resolve(here, '../models/Kim_Vocal_2.onnx') },
};

export function readWav(path) {
    const b = readFileSync(path);
    if (b.toString('ascii', 0, 4) !== 'RIFF' || b.toString('ascii', 8, 12) !== 'WAVE') throw new Error(`${path} : pas un WAV`);
    let o = 12, ch = 0, sr = 0, bits = 0, fmt = 0;
    while (o + 8 <= b.length) {
        const id = b.toString('ascii', o, o + 4), size = b.readUInt32LE(o + 4);
        if (id === 'fmt ') { fmt = b.readUInt16LE(o + 8); ch = b.readUInt16LE(o + 10); sr = b.readUInt32LE(o + 12); bits = b.readUInt16LE(o + 22); if (fmt === 0xfffe) fmt = b.readUInt16LE(o + 32); }
        if (id === 'data') {
            const bytes = bits / 8, n = Math.floor(Math.min(size, b.length - o - 8) / bytes / ch), l = new Float32Array(n), r = new Float32Array(n);
            const rd = fmt === 3 && bits === 32 ? (p) => b.readFloatLE(p) : bits === 16 ? (p) => b.readInt16LE(p) / 32768 : bits === 24 ? (p) => b.readIntLE(p, 3) / 8388608 : null;
            if (!rd) throw new Error(`${path} : format WAV non pris en charge (fmt ${fmt}, ${bits} bits)`);
            for (let i = 0; i < n; ++i) { l[i] = rd(o + 8 + i * ch * bytes); r[i] = rd(o + 8 + (i * ch + (ch > 1 ? 1 : 0)) * bytes); }
            return { l, r, sr };
        }
        o += 8 + size + (size & 1);
    }
    throw new Error(`${path} : pas de données`);
}
export function writeF32(path, l, r) {
    const o = new Float32Array(2 * l.length);
    for (let i = 0; i < l.length; ++i) { o[2 * i] = l[i]; o[2 * i + 1] = r[i]; }
    writeFileSync(path, Buffer.from(o.buffer));
}
export function readF32(path) {
    const b = readFileSync(path), x = new Float32Array(b.buffer, b.byteOffset, b.length / 4), n = x.length / 2;
    const l = new Float32Array(n), r = new Float32Array(n);
    for (let i = 0; i < n; ++i) { l[i] = x[2 * i]; r[i] = x[2 * i + 1]; }
    return { l, r };
}

const sessions = new Map();
async function session(key) {
    if (sessions.has(key)) return sessions.get(key);
    const cfg = CFGS[key];
    if (!cfg) throw new Error(`modèle inconnu : ${key}`);
    const t0 = performance.now();
    const s = await ort.InferenceSession.create(cfg.file, { executionProviders: ['cpu'], graphOptimizationLevel: 'all', intraOpNumThreads: THREADS, interOpNumThreads: 1 });
    log('info', `session ${key} prête en ${(performance.now() - t0).toFixed(0)} ms (${THREADS} fils) ; entrées ${s.inputNames} ; sorties ${s.outputNames}`);
    sessions.set(key, s);
    return s;
}

export async function runJob(job) {
    const key = job.model || 'voc', cfg = CFGS[key], s = await session(key);
    const runModel = async (x) => (await s.run({ [s.inputNames[0]]: new ort.Tensor('float32', x, [1, 4, cfg.dimF, cfg.dimT]) }))[s.outputNames[0]].data;
    const wav = readWav(job.in);
    let L = wav.l, R = wav.r;
    if (wav.sr !== 44100) { L = resampleSinc(L, wav.sr, 44100); R = resampleSinc(R, wav.sr, 44100); log('info', `rééchantillonnage ${wav.sr} → 44100 Hz (sinc du produit)`); }
    const n = L.length, shift = job.shift | 0, sign = job.neg ? -1 : 1;
    const inL = new Float32Array(n + shift), inR = new Float32Array(n + shift);
    for (let i = 0; i < n; ++i) { inL[i + shift] = sign * L[i]; inR[i + shift] = sign * R[i]; }
    const t0 = performance.now();
    const overlap = Number.isFinite(job.overlap) ? job.overlap : 0.25;
    // Mêmes options que app.js SEP_OPTS.voc : recouvrement 0,25, morceaux sous −60 dB sautés.
    const v = await separateVocals(inL, inR, runModel, () => {}, cfg, { overlap, skipBelowDb: -60 });
    const secs = (performance.now() - t0) / 1000;
    const outL = v.left.subarray(shift), outR = v.right.subarray(shift);
    for (const x of [outL, outR]) for (let i = 0; i < x.length; ++i) if (!Number.isFinite(x[i])) throw new Error(`${job.out} : sortie non finie à ${i}`);
    writeF32(job.out, outL, outR);
    const meta = { ...job, model: key, n, seconds: secs, profile: v.profile, threads: THREADS, ort: ort.env?.versions?.node || '1.22.0' };
    writeFileSync(job.out + '.json', JSON.stringify(meta));
    log('info', `${job.out} : ${key} neg=${!!job.neg} shift=${shift} overlap=${overlap} — ${secs.toFixed(1)} s (${v.profile.chunks} morceaux, modèle ${(v.profile.modelMs / 1000).toFixed(1)} s, transformées ${((v.profile.stftMs + v.profile.istftMs) / 1000).toFixed(1)} s)`);
    return meta;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
    for (const job of jobs) {
        if (existsSync(job.out) && existsSync(job.out + '.json') && !process.env.FORCE) { log('info', `${job.out} : déjà fait, sauté`); continue; }
        try { await runJob(job); } catch (e) { log('error', `${job.out} : ${e.stack || e.message}`); process.exitCode = 1; }
    }
}
