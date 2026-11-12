// StudioVoix Web : worker de l'IA de séparation (isolation de la voix d'une prise, « Séparer » une chanson).
// Charge ONNX Runtime Web (vendor/, version épinglée par la CI) et les modèles MDX-Net (models/, vérifiés par SHA-256
// puis gardés dans le cache du navigateur). Carte graphique (WebGPU) si le navigateur en a une, sinon processeur
// (WASM, multi-cœur si la page est isolée). Plusieurs modèles (isolate.js, MODELS) : une session par modèle, chargée à
// la demande ; « release » la libère après usage (mémoire limitée sur téléphone).
import * as ort from './vendor/ort.webgpu.min.mjs';
import { separateVocals, MODELS } from './isolate.js';

const CACHE_NAME = 'studiovoix-ia-v1';
const sessions = new Map();   // clé du modèle → { session, backend } ; loading : clé → promesse
const loading = new Map();
let gpuChecked = null, configured = false;

const ts = () => new Date().toISOString().slice(11, 23);
function log(level, msg) {
    const line = `${ts()} [${level}] isolation : ${msg}`;
    if (level === 'error') console.error(line); else console.log(line);
    postMessage({ type: 'log', level, msg });
}
const progress = (stage, done, total, model) => postMessage({ type: 'progress', stage, done, total, model });

async function sha256Hex(buf) {
    const h = new Uint8Array(await crypto.subtle.digest('SHA-256', buf));
    return Array.from(h, (b) => b.toString(16).padStart(2, '0')).join('');
}
function cfgOf(key) {
    const cfg = MODELS[key];
    if (!cfg) throw new Error('modèle inconnu : ' + key);
    return cfg;
}

// Modèle : cache du navigateur s'il est là et intact, sinon téléchargement avec progression, puis contrôle SHA-256.
async function loadModelBytes(key) {
    const cfg = cfgOf(key), url = './models/' + cfg.modelFile;
    let cache = null;
    try { cache = typeof caches !== 'undefined' ? await caches.open(CACHE_NAME) : null; }
    catch (e) { log('warn', `cache du navigateur indisponible (${e.message}) : le modèle sera retéléchargé à chaque visite`); }
    if (cache) {
        const hit = await cache.match(url);
        if (hit) {
            const buf = await hit.arrayBuffer();
            if (buf.byteLength === cfg.modelBytes && await sha256Hex(buf) === cfg.modelSha256) {
                log('info', `modèle ${cfg.label} lu dans le cache (${(buf.byteLength / 1e6).toFixed(1)} Mo, SHA-256 vérifié)`);
                return buf;
            }
            log('warn', `modèle ${cfg.label} en cache abîmé ou ancien : retéléchargement`);
            await cache.delete(url);
        }
    }
    const t0 = performance.now();
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`modèle introuvable (${resp.status} sur ${url})`);
    const total = Number(resp.headers.get('content-length')) || cfg.modelBytes;
    const out = new Uint8Array(cfg.modelBytes);
    let got = 0, last = 0;
    const reader = resp.body.getReader();
    for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (got + value.length > out.length) throw new Error('modèle plus gros que prévu : refusé');
        out.set(value, got);
        got += value.length;
        if (got - last > 2e6) { last = got; progress('download', got, total, key); }
    }
    if (got !== cfg.modelBytes) throw new Error(`modèle incomplet (${got} octets sur ${cfg.modelBytes})`);
    const sum = await sha256Hex(out.buffer);
    if (sum !== cfg.modelSha256) throw new Error(`modèle refusé : SHA-256 ${sum} au lieu de ${cfg.modelSha256}`);
    log('info', `modèle ${cfg.label} téléchargé en ${((performance.now() - t0) / 1000).toFixed(1)} s (${(got / 1e6).toFixed(1)} Mo, SHA-256 vérifié)`);
    if (cache) {
        try { await cache.put(url, new Response(out.buffer.slice(0), { headers: { 'content-type': 'application/octet-stream' } })); }
        catch (e) { log('warn', `modèle non gardé dans le cache (${e.message})`); }
    }
    return out.buffer;
}

async function hasWebGpu() {
    if (gpuChecked === null) {
        gpuChecked = (async () => {
            try { return !!(self.navigator?.gpu && await navigator.gpu.requestAdapter()); }
            catch (e) { log('warn', `WebGPU indisponible (${e.message})`); return false; }
        })();
    }
    return gpuChecked;
}

async function createSession(bytes, ep) {
    const t0 = performance.now();
    const s = await ort.InferenceSession.create(new Uint8Array(bytes), { executionProviders: [ep], graphOptimizationLevel: 'all' });
    log('info', `session ${ep} prête en ${(performance.now() - t0).toFixed(0)} ms`);
    return s;
}

const runWith = (s, cfg) => async (x) => {
    const out = await s.run({ input: new ort.Tensor('float32', x, [1, 4, cfg.dimF, cfg.dimT]) });
    return out.output.data;
};

// Contrôle de cohérence d'une sortie du modèle (WebGPU peut rendre n'importe quoi sur certains pilotes).
function sane(x, y) {
    let ex = 0, ey = 0;
    for (let i = 0; i < y.length; ++i) { const v = y[i]; if (!Number.isFinite(v)) return false; ey += v * v; ex += x[i] * x[i]; }
    return ey <= 4 * ex + 1e-6;
}

function configure() {
    if (configured) return;
    configured = true;
    ort.env.wasm.wasmPaths = new URL('./vendor/', import.meta.url).href;
    const cores = self.navigator?.hardwareConcurrency || 2;
    ort.env.wasm.numThreads = self.crossOriginIsolated ? Math.max(1, Math.min(8, cores - 1)) : 1;
    log('info', `ONNX Runtime Web ${ort.env.versions?.web || '?'} ; isolée=${self.crossOriginIsolated} ; fils WASM ${ort.env.wasm.numThreads} (cœurs ${cores})`);
}

async function ensureSession(key) {
    if (sessions.has(key)) return sessions.get(key);
    if (!loading.has(key)) loading.set(key, (async () => {
        configure();
        const cfg = cfgOf(key);
        const bytes = await loadModelBytes(key);
        if (cfg.type !== 'speaker' && await hasWebGpu()) {   // petit modèle d'empreinte de voix : processeur suffit
            try {
                const s = await createSession(bytes, 'webgpu');
                // Essai sur une entrée connue : si la carte graphique rend une sortie aberrante, on passe au processeur.
                const probe = new Float32Array(4 * cfg.dimF * cfg.dimT);
                for (let i = 0; i < probe.length; ++i) probe[i] = Math.sin(i * 0.37) * 0.5;
                if (sane(probe, await runWith(s, cfg)(probe))) {
                    const e = { session: s, backend: 'carte graphique (WebGPU)' };
                    sessions.set(key, e);
                    return e;
                }
                log('warn', 'sortie WebGPU aberrante : passage au processeur');
                await s.release?.();
            } catch (e) { log('warn', `WebGPU refusé (${e.message}) : passage au processeur`); }
        }
        const s = await createSession(bytes, 'wasm');
        const e = { session: s, backend: `processeur (WASM, ${ort.env.wasm.numThreads} fil${ort.env.wasm.numThreads > 1 ? 's' : ''})` };
        sessions.set(key, e);
        return e;
    })());
    try { return await loading.get(key); } finally { loading.delete(key); }
}

async function releaseSession(key) {
    const e = sessions.get(key);
    if (!e) return;
    sessions.delete(key);
    try { await e.session.release?.(); log('info', `modèle ${cfgOf(key).label} libéré (mémoire)`); }
    catch (err) { log('warn', `libération du modèle ${key} : ${err.message}`); }
}

onmessage = async (e) => {
    const { id, cmd } = e.data;
    const key = e.data.model || 'voc';
    try {
        if (cmd === 'prepare') {
            const s = await ensureSession(key);
            postMessage({ id, ok: true, backend: s.backend });
        } else if (cmd === 'isolate') {
            const { left, right, release } = e.data;
            const cfg = cfgOf(key);
            if (!(left instanceof Float32Array) || !(right instanceof Float32Array) || left.length !== right.length)
                throw new Error('entrée invalide (deux Float32Array de même longueur attendus, 44,1 kHz)');
            const s = await ensureSession(key);
            const t0 = performance.now();
            const out = await separateVocals(left, right, runWith(s.session, cfg), (d, t) => progress('isolate', d, t, key), cfg);
            const sec = (performance.now() - t0) / 1000;
            log('info', `${cfg.label} : ${(left.length / cfg.sampleRate).toFixed(1)} s traitées en ${sec.toFixed(1)} s sur ${s.backend}`);
            if (release) await releaseSession(key);
            postMessage({ id, ok: true, left: out.left, right: out.right, seconds: sec, backend: s.backend }, [out.left.buffer, out.right.buffer]);
        } else if (cmd === 'embed') {
            // Empreinte de voix : fbank [T × 80] → 256 valeurs.
            const { feats, frames } = e.data;
            if (!(feats instanceof Float32Array) || feats.length !== frames * 80) throw new Error('fbank invalide');
            const s = await ensureSession(key);
            const out = await s.session.run({ feats: new ort.Tensor('float32', feats, [1, frames, 80]) });
            const emb = out.embs.data.slice();
            postMessage({ id, ok: true, emb }, [emb.buffer]);
        } else if (cmd === 'release') {
            await releaseSession(key);
            postMessage({ id, ok: true });
        } else throw new Error('commande inconnue : ' + cmd);
    } catch (err) {
        log('error', err.message || String(err));
        postMessage({ id, ok: false, error: err.message || String(err) });
    }
};
