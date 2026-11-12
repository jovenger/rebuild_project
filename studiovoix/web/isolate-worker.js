// StudioVoix Web : worker d'isolation de la voix (IA). Charge ONNX Runtime Web (vendor/, version épinglée par la CI)
// et le modèle MDX-Net (models/, vérifié par SHA-256 puis gardé dans le cache du navigateur), puis renvoie la voix
// seule. Carte graphique (WebGPU) si le navigateur en a une, sinon processeur (WASM, multi-cœur si la page est isolée).
import * as ort from './vendor/ort.webgpu.min.mjs';
import { separateVocals, MDX } from './isolate.js';

const MODEL_URL = './models/' + MDX.modelFile;
const CACHE_NAME = 'studiovoix-ia-v1';
let session = null, backend = '', loading = null;

const ts = () => new Date().toISOString().slice(11, 23);
function log(level, msg) {
    const line = `${ts()} [${level}] isolation : ${msg}`;
    if (level === 'error') console.error(line); else console.log(line);
    postMessage({ type: 'log', level, msg });
}
const progress = (stage, done, total) => postMessage({ type: 'progress', stage, done, total });

async function sha256Hex(buf) {
    const h = new Uint8Array(await crypto.subtle.digest('SHA-256', buf));
    return Array.from(h, (b) => b.toString(16).padStart(2, '0')).join('');
}

// Modèle : cache du navigateur s'il est là et intact, sinon téléchargement avec progression, puis contrôle SHA-256.
async function loadModelBytes() {
    let cache = null;
    try { cache = typeof caches !== 'undefined' ? await caches.open(CACHE_NAME) : null; }
    catch (e) { log('warn', `cache du navigateur indisponible (${e.message}) : le modèle sera retéléchargé à chaque visite`); }
    if (cache) {
        const hit = await cache.match(MODEL_URL);
        if (hit) {
            const buf = await hit.arrayBuffer();
            if (buf.byteLength === MDX.modelBytes && await sha256Hex(buf) === MDX.modelSha256) {
                log('info', `modèle lu dans le cache (${(buf.byteLength / 1e6).toFixed(1)} Mo, SHA-256 vérifié)`);
                return buf;
            }
            log('warn', 'modèle en cache abîmé ou ancien : retéléchargement');
            await cache.delete(MODEL_URL);
        }
    }
    const t0 = performance.now();
    const resp = await fetch(MODEL_URL);
    if (!resp.ok) throw new Error(`modèle introuvable (${resp.status} sur ${MODEL_URL})`);
    const total = Number(resp.headers.get('content-length')) || MDX.modelBytes;
    const out = new Uint8Array(MDX.modelBytes);
    let got = 0, last = 0;
    const reader = resp.body.getReader();
    for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (got + value.length > out.length) throw new Error('modèle plus gros que prévu : refusé');
        out.set(value, got);
        got += value.length;
        if (got - last > 2e6) { last = got; progress('download', got, total); }
    }
    if (got !== MDX.modelBytes) throw new Error(`modèle incomplet (${got} octets sur ${MDX.modelBytes})`);
    const sum = await sha256Hex(out.buffer);
    if (sum !== MDX.modelSha256) throw new Error(`modèle refusé : SHA-256 ${sum} au lieu de ${MDX.modelSha256}`);
    log('info', `modèle téléchargé en ${((performance.now() - t0) / 1000).toFixed(1)} s (${(got / 1e6).toFixed(1)} Mo, SHA-256 vérifié)`);
    if (cache) {
        try { await cache.put(MODEL_URL, new Response(out.buffer.slice(0), { headers: { 'content-type': 'application/octet-stream' } })); }
        catch (e) { log('warn', `modèle non gardé dans le cache (${e.message})`); }
    }
    return out.buffer;
}

async function hasWebGpu() {
    try { return !!(self.navigator?.gpu && await navigator.gpu.requestAdapter()); }
    catch (e) { log('warn', `WebGPU indisponible (${e.message})`); return false; }
}

async function createSession(bytes, ep) {
    const t0 = performance.now();
    const s = await ort.InferenceSession.create(new Uint8Array(bytes), { executionProviders: [ep], graphOptimizationLevel: 'all' });
    log('info', `session ${ep} prête en ${(performance.now() - t0).toFixed(0)} ms`);
    return s;
}

const runWith = (s) => async (x) => {
    const out = await s.run({ input: new ort.Tensor('float32', x, [1, 4, MDX.dimF, MDX.dimT]) });
    return out.output.data;
};

// Contrôle de cohérence d'une sortie du modèle (WebGPU peut rendre n'importe quoi sur certains pilotes).
function sane(x, y) {
    let ex = 0, ey = 0;
    for (let i = 0; i < y.length; ++i) { const v = y[i]; if (!Number.isFinite(v)) return false; ey += v * v; ex += x[i] * x[i]; }
    return ey <= 4 * ex + 1e-6;
}

async function ensureSession() {
    if (session) return session;
    if (!loading) loading = (async () => {
        ort.env.wasm.wasmPaths = new URL('./vendor/', import.meta.url).href;
        const cores = self.navigator?.hardwareConcurrency || 2;
        ort.env.wasm.numThreads = self.crossOriginIsolated ? Math.max(1, Math.min(8, cores - 1)) : 1;
        log('info', `ONNX Runtime Web ${ort.env.versions?.web || '?'} ; isolée=${self.crossOriginIsolated} ; fils WASM ${ort.env.wasm.numThreads} (cœurs ${cores})`);
        const bytes = await loadModelBytes();
        if (await hasWebGpu()) {
            try {
                const s = await createSession(bytes, 'webgpu');
                // Essai sur une entrée connue : si la carte graphique rend une sortie aberrante, on passe au processeur.
                const probe = new Float32Array(4 * MDX.dimF * MDX.dimT);
                for (let i = 0; i < probe.length; ++i) probe[i] = Math.sin(i * 0.37) * 0.5;
                if (sane(probe, await runWith(s)(probe))) { session = s; backend = 'carte graphique (WebGPU)'; return s; }
                log('warn', 'sortie WebGPU aberrante : passage au processeur');
            } catch (e) { log('warn', `WebGPU refusé (${e.message}) : passage au processeur`); }
        }
        session = await createSession(bytes, 'wasm');
        backend = `processeur (WASM, ${ort.env.wasm.numThreads} fil${ort.env.wasm.numThreads > 1 ? 's' : ''})`;
        return session;
    })();
    try { return await loading; } catch (e) { loading = null; throw e; }
}

onmessage = async (e) => {
    const { id, cmd } = e.data;
    try {
        if (cmd === 'prepare') {
            await ensureSession();
            postMessage({ id, ok: true, backend });
        } else if (cmd === 'isolate') {
            const { left, right } = e.data;
            if (!(left instanceof Float32Array) || !(right instanceof Float32Array) || left.length !== right.length)
                throw new Error('entrée invalide (deux Float32Array de même longueur attendus, 44,1 kHz)');
            const s = await ensureSession();
            const t0 = performance.now();
            const run = runWith(s);
            const out = await separateVocals(left, right, run, (d, t) => progress('isolate', d, t));
            const sec = (performance.now() - t0) / 1000;
            log('info', `voix isolée : ${(left.length / MDX.sampleRate).toFixed(1)} s traitées en ${sec.toFixed(1)} s sur ${backend}`);
            postMessage({ id, ok: true, left: out.left, right: out.right, seconds: sec, backend }, [out.left.buffer, out.right.buffer]);
        } else throw new Error('commande inconnue : ' + cmd);
    } catch (err) {
        log('error', err.message || String(err));
        postMessage({ id, ok: false, error: err.message || String(err) });
    }
};
