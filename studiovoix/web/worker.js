// StudioVoix Web : le moteur WebAssembly tourne dans ce Web Worker pour ne jamais figer la page.
// Messages reçus : { id, cmd, ... } ; réponses : { id, ok, ...résultat } ou { id, ok:false, error }.
// Les tampons audio (Float32Array) sont copiés dans la mémoire WebAssembly puis libérés.

let engine = null;
let api = null;

const log = (level, msg) => postMessage({ type: 'log', level, msg: String(msg) });

async function boot() {
    const { default: createStudioVoix } = await import('./dist/studiovoix.js');
    engine = await createStudioVoix({
        print: (t) => log('info', t),
        printErr: (t) => log('warn', t),
        locateFile: (f) => './dist/' + f,
    });
    api = {
        version: engine.cwrap('sv_version', 'string', []),
        styles: engine.cwrap('sv_styles', 'string', []),
        analyze: engine.cwrap('sv_analyze_instru', 'string', ['number', 'number', 'number', 'number']),
        setContext: engine.cwrap('sv_set_context', null, ['number', 'number', 'number', 'number', 'number']),
        processVoice: engine.cwrap('sv_process_voice', 'string', ['number', 'number', 'number', 'string', 'number', 'number']),
        cleanTake: engine.cwrap('sv_clean_take', 'string', ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number']),
        demoInstru: engine.cwrap('sv_demo_instru', 'string', ['number', 'number']),
        demoVoice: engine.cwrap('sv_demo_voice', 'string', ['number', 'number']),
        mix: engine.cwrap('sv_mix', 'string', ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number']),
        outLeft: engine.cwrap('sv_out_left', 'number', []),
        outRight: engine.cwrap('sv_out_right', 'number', []),
        outFrames: engine.cwrap('sv_out_frames', 'number', []),
        outRelease: engine.cwrap('sv_out_release', null, []),
        alloc: engine.cwrap('sv_alloc', 'number', ['number']),
        free: engine.cwrap('sv_free', null, ['number']),
    };
    log('info', 'Moteur prêt : ' + api.version());
    postMessage({ type: 'ready', version: api.version(), styles: JSON.parse(api.styles()) });
}

// Copie un Float32Array dans la mémoire du moteur ; retourne le pointeur (à libérer).
function push(arr) {
    if (!arr || arr.length === 0) return 0;
    const ptr = api.alloc(arr.length);
    engine.HEAPF32.set(arr, ptr >> 2);
    return ptr;
}

// Lit le résultat stéréo du moteur (copie, car la mémoire WebAssembly peut bouger ensuite).
function pullOut() {
    const n = api.outFrames();
    const l = api.outLeft() >> 2, r = api.outRight() >> 2;
    const left = engine.HEAPF32.slice(l, l + n);
    const right = engine.HEAPF32.slice(r, r + n);
    api.outRelease();
    return { left, right, frames: n };
}

function parse(json) {
    const r = JSON.parse(json);
    if (r && r.ok === false) throw new Error(r.error || 'erreur du moteur');
    return r;
}

const handlers = {
    analyze({ left, right, sampleRate }) {
        const pl = push(left), pr = push(right);
        try { return parse(api.analyze(pl, pr, left.length, sampleRate)); }
        finally { api.free(pl); if (pr) api.free(pr); }
    },
    setContext({ root, minor, bpm, firstBeatSec, useScale }) {
        api.setContext(root, minor ? 1 : 0, bpm, firstBeatSec, useScale ? 1 : 0);
        return {};
    },
    processVoice({ mono, sampleRate, styleId, cleaning, useScale }) {
        const p = push(mono);
        try {
            const report = parse(api.processVoice(p, mono.length, sampleRate, styleId, cleaning ? 1 : 0, useScale ? 1 : 0));
            const out = pullOut();
            return { report, ...out };
        } finally { api.free(p); }
    },
    cleanTake({ rec, instruL, instruR, sampleRate, recOffsetSec, fallbackLatencySec }) {
        const pr = push(rec), il = push(instruL), ir = push(instruR);
        try {
            const report = parse(api.cleanTake(pr, rec.length, il, ir, instruL ? instruL.length : 0, sampleRate, recOffsetSec, fallbackLatencySec));
            const out = pullOut();
            return { report, left: out.left, right: null, frames: out.frames };
        } finally { api.free(pr); if (il) api.free(il); if (ir) api.free(ir); }
    },
    demoInstru({ sampleRate, bars }) { const report = parse(api.demoInstru(sampleRate, bars)); return { report, ...pullOut() }; },
    demoVoice({ sampleRate, bars }) { const report = parse(api.demoVoice(sampleRate, bars)); return { report, ...pullOut() }; },
    mix({ instruL, instruR, voiceL, voiceR, voiceStartSec, sampleRate, duckingDb, vocalOverInstruLu }) {
        const il = push(instruL), ir = push(instruR), vl = push(voiceL), vr = push(voiceR);
        try {
            const report = parse(api.mix(il, ir, instruL.length, vl, vr, voiceL ? voiceL.length : 0,
                                         voiceStartSec, sampleRate, duckingDb, vocalOverInstruLu));
            const out = pullOut();
            return { report, ...out };
        } finally { api.free(il); if (ir) api.free(ir); if (vl) api.free(vl); if (vr) api.free(vr); }
    },
};

onmessage = async (e) => {
    const { id, cmd } = e.data;
    try {
        if (!api) throw new Error('moteur pas encore prêt');
        const t0 = performance.now();
        const result = handlers[cmd](e.data);
        const ms = Math.round(performance.now() - t0);
        log('info', `${cmd} : ${ms} ms`);
        const transfer = [];
        for (const k of ['left', 'right']) if (result[k]) transfer.push(result[k].buffer);
        postMessage({ id, ok: true, ms, ...result }, transfer);
    } catch (err) {
        log('error', `${cmd} : ${err.message || err}`);
        postMessage({ id, ok: false, error: String(err.message || err) });
    }
};

boot().catch((err) => {
    log('error', 'Chargement du moteur impossible : ' + (err.message || err));
    postMessage({ type: 'fatal', error: String(err.message || err) });
});
