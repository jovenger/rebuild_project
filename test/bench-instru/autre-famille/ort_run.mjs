// Ré-exécute un ONNX avec onnxruntime-node (celui du banc B, 1.22.0) : node ort_run.mjs <onnx> <in.bin> <forme,…> <out.bin> [répétitions]
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire('/tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/bench/');
const ort = require('onnxruntime-node');
const [onnx, inBin, shapeS, outBin, repS] = process.argv.slice(2);
const THREADS = Number(process.env.THREADS || 3), reps = Number(repS || 2);
const log = (lvl, m) => console.log(`${new Date().toISOString()} [${lvl}] ort_run : ${m}`);
const shape = shapeS.split(',').map(Number);
const b = readFileSync(inBin), x = new Float32Array(b.buffer, b.byteOffset, b.length / 4);
if (x.length !== shape.reduce((a, c) => a * c, 1)) throw new Error(`entrée ${x.length} ≠ forme ${shape}`);
const t0 = performance.now();
const s = await ort.InferenceSession.create(onnx, { executionProviders: ['cpu'], graphOptimizationLevel: process.env.OPT || 'all', intraOpNumThreads: THREADS, interOpNumThreads: 1, ...(process.env.ARENA === '0' ? { enableCpuMemArena: false, enableMemPattern: false } : {}) });
if (process.env.ARENA === '0') log('info', 'arène mémoire et motif mémoire désactivés');
log('info', `session prête en ${(performance.now() - t0).toFixed(0)} ms (${THREADS} fils) ; entrées ${s.inputNames} ; sorties ${s.outputNames} ; mémoire max ${(process.resourceUsage().maxRSS / 1024).toFixed(0)} Mo`);
const times = [];
let out;
for (let i = 0; i < reps; ++i) {
    const t = performance.now();
    out = (await s.run({ [s.inputNames[0]]: new ort.Tensor('float32', x, shape) }))[s.outputNames[0]];
    times.push((performance.now() - t) / 1000);
    log('info', `passe ${i + 1} : ${times[i].toFixed(2)} s ; sortie ${out.dims} ; mémoire max ${(process.resourceUsage().maxRSS / 1024).toFixed(0)} Mo`);
}
for (let i = 0; i < out.data.length; ++i) if (!Number.isFinite(out.data[i])) throw new Error(`sortie non finie à ${i}`);
writeFileSync(outBin, Buffer.from(out.data.buffer, out.data.byteOffset, out.data.byteLength));
writeFileSync(outBin + '.json', JSON.stringify({ onnx, dims: out.dims, times, threads: THREADS, peakRssMb: process.resourceUsage().maxRSS / 1024, ort: '1.22.0 (onnxruntime-node du banc B)' }));
