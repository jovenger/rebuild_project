// StudioVoix Web : page principale. Micro et lecture par Web Audio, moteur C++ (WebAssembly) dans un Web Worker.
// Principes repris du logiciel : tout arrive brut ; les effets viennent quand on choisit un style, réglés d'après la
// mesure de la prise ; l'instru n'est jamais modifiée (hors creux sous la voix, à 0 par défaut ici).

const $ = (id) => document.getElementById(id);
const ui = {
    status: $('status'), log: $('log'), version: $('version'),
    instruFile: $('instruFile'), instruInfo: $('instruInfo'), instruWave: $('instruWave'),
    style: $('style'), useScale: $('useScale'), cleaning: $('cleaning'),
    recBtn: $('recBtn'), stopBtn: $('stopBtn'), playBtn: $('playBtn'), playRawBtn: $('playRawBtn'), stopPlayBtn: $('stopPlayBtn'),
    processBtn: $('processBtn'), exportBtn: $('exportBtn'), voiceWave: $('voiceWave'), voiceInfo: $('voiceInfo'),
    report: $('report'), meterIn: $('meterIn'), meterOut: $('meterOut'), latencyMs: $('latencyMs'), countIn: $('countIn'),
    keyBox: $('keyBox'), bpmBox: $('bpmBox'), voiceFile: $('voiceFile'), demoBtn: $('demoBtn'),
};

const state = {
    ctx: null,            // AudioContext (créé au premier geste)
    worker: null, ready: false, pending: new Map(), nextId: 1,
    instru: null,         // { left, right, sampleRate, seconds, analysis }
    voice: null,          // { mono, sampleRate, startSec } prise brute
    processed: null,      // { left, right, report }
    mix: null,            // { left, right, report }
    playing: [], recorder: null, recChunks: [], recStartCtxTime: 0,
    analyser: null, meterTimer: 0,
};

// ------------------------------------------------------------------ journal et état
function setStatus(text) { ui.status.textContent = text; }
function log(level, msg) {
    const line = document.createElement('div');
    line.className = 'l-' + level;
    line.textContent = new Date().toLocaleTimeString() + '  ' + msg;
    ui.log.prepend(line);
    while (ui.log.childElementCount > 200) ui.log.lastChild.remove();
    if (level === 'error') console.error(msg); else console.log(msg);
}

// ------------------------------------------------------------------ moteur (worker)
function startWorker() {
    state.worker = new Worker('./worker.js', { type: 'module' });
    state.worker.onmessage = (e) => {
        const m = e.data;
        if (m.type === 'log') { log(m.level, '[moteur] ' + m.msg); return; }
        if (m.type === 'ready') {
            state.ready = true;
            ui.version.textContent = m.version;
            fillStyles(m.styles);
            setStatus('Moteur prêt. Pose une instru, puis enregistre.');
            refreshButtons();
            return;
        }
        if (m.type === 'fatal') { setStatus('Moteur indisponible : ' + m.error); return; }
        const p = state.pending.get(m.id);
        if (!p) return;
        state.pending.delete(m.id);
        m.ok ? p.resolve(m) : p.reject(new Error(m.error));
    };
}
function call(cmd, payload, transfer = []) {
    return new Promise((resolve, reject) => {
        const id = state.nextId++;
        state.pending.set(id, { resolve, reject });
        state.worker.postMessage({ id, cmd, ...payload }, transfer);
    });
}
function fillStyles(groups) {
    ui.style.innerHTML = '';
    for (const g of groups) {
        const og = document.createElement('optgroup');
        og.label = g.family;
        for (const s of g.styles) {
            const o = document.createElement('option');
            o.value = s.id; o.textContent = s.name;
            if (s.id === 'rap_conscient') o.selected = true;
            og.appendChild(o);
        }
        ui.style.appendChild(og);
    }
}

// ------------------------------------------------------------------ audio
function audioContext() {
    if (!state.ctx) {
        state.ctx = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: 'interactive' });
        log('info', `AudioContext ${state.ctx.sampleRate} Hz, latence de base ${Math.round(state.ctx.baseLatency * 1000)} ms`);
    }
    if (state.ctx.state === 'suspended') state.ctx.resume();
    return state.ctx;
}
async function decodeFile(file) {
    const ctx = audioContext();
    const bytes = await file.arrayBuffer();
    return await ctx.decodeAudioData(bytes);   // décodage par le navigateur (MP3, WAV, FLAC, OGG, AAC selon le navigateur)
}
function channels(buffer) {
    const left = buffer.getChannelData(0).slice();
    const right = buffer.numberOfChannels > 1 ? buffer.getChannelData(1).slice() : left.slice();
    return { left, right };
}
function toMono(buffer) {
    const n = buffer.length, out = new Float32Array(n);
    for (let c = 0; c < buffer.numberOfChannels; ++c) {
        const d = buffer.getChannelData(c);
        for (let i = 0; i < n; ++i) out[i] += d[i] / buffer.numberOfChannels;
    }
    return out;
}
function makeBuffer(left, right) {
    const ctx = audioContext();
    const b = ctx.createBuffer(2, left.length, ctx.sampleRate);
    b.copyToChannel(left, 0);
    b.copyToChannel(right || left, 1);
    return b;
}
function stopPlayback() {
    for (const s of state.playing) { try { s.stop(); } catch (_) { /* déjà arrêté */ } }
    state.playing = [];
    stopMeter(ui.meterOut);
}
function play(sources /* [{buffer, when, gain}] */) {
    stopPlayback();
    const ctx = audioContext();
    const t0 = ctx.currentTime + 0.05;
    const out = ctx.createGain();
    out.connect(ctx.destination);
    startMeter(out, ui.meterOut);
    for (const s of sources) {
        const node = ctx.createBufferSource();
        node.buffer = s.buffer;
        const g = ctx.createGain();
        g.gain.value = s.gain ?? 1;
        node.connect(g).connect(out);
        node.start(t0 + (s.when || 0));
        state.playing.push(node);
    }
}

// Vumètre : crête du nœud, échelle -48…+3 dB comme dans le logiciel.
function startMeter(node, el) {
    const ctx = audioContext();
    const an = ctx.createAnalyser();
    an.fftSize = 2048;
    node.connect(an);
    const data = new Float32Array(an.fftSize);
    let hold = 0, holdUntil = 0;
    const tick = () => {
        an.getFloatTimeDomainData(data);
        let peak = 0;
        for (let i = 0; i < data.length; ++i) peak = Math.max(peak, Math.abs(data[i]));
        const now = performance.now();
        if (peak >= hold || now > holdUntil) { hold = peak; holdUntil = now + 1500; }
        drawMeter(el, peak, hold);
        el._raf = requestAnimationFrame(tick);
    };
    stopMeter(el);
    el._raf = requestAnimationFrame(tick);
}
function stopMeter(el) { if (el._raf) cancelAnimationFrame(el._raf); el._raf = 0; drawMeter(el, 0, 0); }
function drawMeter(canvas, peak, hold) {
    const g = canvas.getContext('2d'), w = canvas.width, h = canvas.height;
    const x = (db) => Math.max(0, Math.min(w, (db + 48) / 51 * w));
    const db = 20 * Math.log10(Math.max(peak, 1e-6));
    g.fillStyle = '#000'; g.fillRect(0, 0, w, h);
    const xl = x(db), x12 = x(-12), x0 = x(0);
    g.fillStyle = '#3fb950'; g.fillRect(0, 2, Math.min(xl, x12), h - 4);
    if (xl > x12) { g.fillStyle = '#e07b20'; g.fillRect(x12, 2, Math.min(xl, x0) - x12, h - 4); }
    if (xl > x0) { g.fillStyle = '#e5484d'; g.fillRect(x0, 2, xl - x0, h - 4); }
    g.fillStyle = 'rgba(255,255,255,.35)';
    for (const t of [-24, -12, -6]) g.fillRect(x(t), 2, 1, h - 4);
    g.fillStyle = '#fff'; g.fillRect(x0, 0, 2, h);
    if (hold > 1e-4) { const xh = x(20 * Math.log10(hold)); g.fillStyle = xh > x0 ? '#e5484d' : '#fff'; g.fillRect(xh - 1, 2, 2, h - 4); }
}

function drawWave(canvas, data, color) {
    const g = canvas.getContext('2d'), w = canvas.width, h = canvas.height;
    g.fillStyle = '#12151c'; g.fillRect(0, 0, w, h);
    if (!data || data.length === 0) return;
    g.fillStyle = color;
    const per = Math.max(1, Math.floor(data.length / w));
    for (let px = 0; px < w; ++px) {
        let mx = 0;
        const a = px * per, b = Math.min(data.length, a + per);
        for (let i = a; i < b; ++i) mx = Math.max(mx, Math.abs(data[i]));
        const hh = Math.max(1, mx * (h / 2 - 2));
        g.fillRect(px, h / 2 - hh, 1, hh * 2);
    }
}

// ------------------------------------------------------------------ instru
ui.instruFile.addEventListener('change', async () => {
    const file = ui.instruFile.files[0];
    if (!file) return;
    try {
        setStatus('Lecture du fichier…');
        const buf = await decodeFile(file);
        const { left, right } = channels(buf);
        state.instru = { left, right, sampleRate: buf.sampleRate, seconds: buf.duration, name: file.name };
        state.mix = null;
        drawWave(ui.instruWave, left, '#8a94a8');
        setStatus('Analyse de l\'instru (tonalité, tempo, structure)…');
        const r = await call('analyze', { left: left.slice(), right: right.slice(), sampleRate: buf.sampleRate });
        state.instru.analysis = r;
        ui.keyBox.textContent = r.key;
        ui.bpmBox.textContent = r.bpm.toFixed(1);
        const secs = (r.sections || []).map((s) => `${s.label} ${fmt(s.start)}–${fmt(s.end)}`).join(' · ');
        ui.instruInfo.textContent = `${file.name} · ${fmt(buf.duration)} · ${buf.sampleRate} Hz · ${r.lufs.toFixed(1)} LUFS · crête ${r.peakDb.toFixed(1)} dBFS` + (secs ? `\n${secs}` : '');
        setStatus(`Instru analysée : ${r.key}, ${r.bpm.toFixed(1)} BPM. Tu peux enregistrer (REC).`);
    } catch (err) { setStatus('Instru illisible : ' + err.message); log('error', err.message); }
    refreshButtons();
});

// Démo : instru et voix synthétiques fabriquées par le moteur (mêmes signaux que les tests du logiciel).
ui.demoBtn.addEventListener('click', async () => {
    try {
        const ctx = audioContext();
        setStatus('Fabrication de la démo (instru La mineur 100 BPM + voix)…');
        const bars = 16;
        const i = await call('demoInstru', { sampleRate: ctx.sampleRate, bars });
        state.instru = { left: i.left, right: i.right, sampleRate: ctx.sampleRate, seconds: i.frames / ctx.sampleRate, name: 'démo' };
        drawWave(ui.instruWave, i.left, '#8a94a8');
        const r = await call('analyze', { left: i.left.slice(), right: i.right.slice(), sampleRate: ctx.sampleRate });
        state.instru.analysis = r;
        ui.keyBox.textContent = r.key; ui.bpmBox.textContent = r.bpm.toFixed(1);
        ui.instruInfo.textContent = `Instru de démo · ${fmt(state.instru.seconds)} · ${r.lufs.toFixed(1)} LUFS`;
        const v = await call('demoVoice', { sampleRate: ctx.sampleRate, bars });
        state.voice = { mono: v.left, sampleRate: ctx.sampleRate, startSec: 0, raw: true };
        state.processed = null; state.mix = null;
        drawWave(ui.voiceWave, v.left, '#3a9bff');
        ui.voiceInfo.textContent = `Voix de démo : ${fmt(v.frames / ctx.sampleRate)} · brute, légèrement fausse exprès (25 cents)`;
        setStatus(`Démo prête : ${r.key}, ${r.bpm.toFixed(1)} BPM. Choisis un style puis « Appliquer le style ».`);
    } catch (err) { setStatus('Démo impossible : ' + err.message); log('error', err.message); }
    refreshButtons();
});

// ------------------------------------------------------------------ prise
ui.recBtn.addEventListener('click', async () => {
    try {
        const ctx = audioContext();
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1 },
        });
        const src = ctx.createMediaStreamSource(stream);
        const sink = ctx.createGain(); sink.gain.value = 0; src.connect(sink).connect(ctx.destination);   // pour le vumètre d'entrée
        startMeter(src, ui.meterIn);
        const mime = ['audio/webm;codecs=pcm', 'audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'].find((m) => MediaRecorder.isTypeSupported(m)) || '';
        state.recorder = new MediaRecorder(stream, mime ? { mimeType: mime, audioBitsPerSecond: 256000 } : undefined);
        state.recChunks = [];
        state.recorder.ondataavailable = (e) => { if (e.data.size) state.recChunks.push(e.data); };
        state.recorder.onstop = () => finishRecording(stream);
        // Compte à rebours d'une mesure sur l'instru, puis départ de la prise en même temps que l'instru à 0:00.
        const bpm = state.instru?.analysis?.bpm || 100;
        const bars = Number(ui.countIn.value || 1);
        const countSec = bars * 4 * 60 / bpm;
        const t0 = ctx.currentTime + 0.1;
        if (state.instru) {
            stopPlayback();
            const node = ctx.createBufferSource();
            node.buffer = makeBuffer(state.instru.left, state.instru.right);
            node.connect(ctx.destination);
            node.start(t0, 0);
            state.playing.push(node);
        }
        // Clics du compte à rebours.
        for (let i = 0; i < bars * 4; ++i) {
            const o = ctx.createOscillator(), g = ctx.createGain();
            o.frequency.value = i % 4 === 0 ? 1500 : 1000;
            g.gain.setValueAtTime(0.25, t0 + i * 60 / bpm); g.gain.exponentialRampToValueAtTime(0.001, t0 + i * 60 / bpm + 0.05);
            o.connect(g).connect(ctx.destination); o.start(t0 + i * 60 / bpm); o.stop(t0 + i * 60 / bpm + 0.06);
        }
        state.recStartCtxTime = t0;            // la prise est écrite dès maintenant ; sa position vaut (début réel - t0)
        state.recorder.start(250);
        state.recCtxStart = ctx.currentTime;   // instant du démarrage réel de l'enregistreur
        setStatus(`Enregistrement… compte à rebours ${bars} mesure(s) à ${bpm.toFixed(0)} BPM, puis chante. Stop pour finir.`);
        ui.recBtn.disabled = true; ui.stopBtn.disabled = false;
    } catch (err) { setStatus('Micro indisponible : ' + err.message); log('error', err.message); }
});
ui.stopBtn.addEventListener('click', () => {
    if (state.recorder && state.recorder.state !== 'inactive') state.recorder.stop();
    stopPlayback();
    ui.stopBtn.disabled = true;
});
async function finishRecording(stream) {
    try {
        stream.getTracks().forEach((t) => t.stop());
        stopMeter(ui.meterIn);
        const blob = new Blob(state.recChunks, { type: state.recorder.mimeType || 'audio/webm' });
        const buf = await decodeFile(new File([blob], 'prise.webm'));
        const mono = toMono(buf);
        // Position de la prise sur la grille : l'enregistreur a démarré à recCtxStart, l'instru à recStartCtxTime ;
        // on retire aussi la latence (sortie + entrée) saisie en ms.
        const latency = Number(ui.latencyMs.value || 0) / 1000;
        const startSec = Math.max(0, (state.recCtxStart - state.recStartCtxTime) - latency);
        state.voice = { mono, sampleRate: buf.sampleRate, startSec, raw: true };
        state.processed = null; state.mix = null;
        drawWave(ui.voiceWave, mono, '#3a9bff');
        ui.voiceInfo.textContent = `Prise : ${fmt(buf.duration)} · ${buf.sampleRate} Hz · brute, aucun effet (position ${startSec.toFixed(2)} s)`;
        setStatus('Prise enregistrée, brute. Choisis un style puis « Appliquer le style », ou écoute telle quelle.');
    } catch (err) { setStatus('Prise illisible : ' + err.message); log('error', err.message); }
    ui.recBtn.disabled = false;
    refreshButtons();
}
ui.voiceFile.addEventListener('change', async () => {
    const file = ui.voiceFile.files[0];
    if (!file) return;
    try {
        const buf = await decodeFile(file);
        const mono = toMono(buf);
        state.voice = { mono, sampleRate: buf.sampleRate, startSec: 0, raw: true };
        state.processed = null; state.mix = null;
        drawWave(ui.voiceWave, mono, '#3a9bff');
        ui.voiceInfo.textContent = `${file.name} : ${fmt(buf.duration)} · ${buf.sampleRate} Hz · brute, aucun effet`;
        setStatus('Voix importée, brute. Choisis un style puis « Appliquer le style ».');
    } catch (err) { setStatus('Voix illisible : ' + err.message); }
    refreshButtons();
});

// ------------------------------------------------------------------ style, mix, écoute, export
ui.processBtn.addEventListener('click', async () => {
    if (!state.voice) return;
    try {
        ui.processBtn.disabled = true;
        const styleName = ui.style.selectedOptions[0]?.textContent || ui.style.value;
        setStatus(`Mesure de la prise et chaîne du style ${styleName}… (quelques secondes)`);
        const r = await call('processVoice', {
            mono: state.voice.mono.slice(), sampleRate: state.voice.sampleRate, styleId: ui.style.value,
            cleaning: ui.cleaning.checked, useScale: ui.useScale.checked,
        });
        state.processed = { left: r.left, right: r.right, report: r.report };
        drawWave(ui.voiceWave, r.left, '#e94e8a');
        const rep = r.report;
        ui.report.textContent =
            `Style ${rep.style} — réglé d'après la mesure de la prise :\n${rep.fitNotes || 'rien à ajuster'}\n\n` +
            `Mesuré sur la prise : ${rep.found || 'aucun défaut notable'}\n\n` +
            `Chaîne appliquée :\n${rep.chain}\n\n` +
            `Justesse ${Math.round(rep.meanCorrectionCents)} c · compression ${rep.compGrDb.toFixed(1)} dB · ${rep.lufs.toFixed(1)} LUFS` +
            (rep.adaptedKey ? ` · gamme adaptée à la voix : ${rep.adaptedKey}` : '') + (rep.chromatic ? ' · note par note' : '') +
            (rep.nearSilent ? '\nPRISE QUASI SILENCIEUSE : vérifie le micro' : '');
        await remix();
        setStatus(`Voix traitée (${styleName}) et mixée avec l'instru. Lecture, ou export WAV.`);
    } catch (err) { setStatus('Traitement impossible : ' + err.message); log('error', err.message); }
    ui.processBtn.disabled = false;
    refreshButtons();
});
async function remix() {
    if (!state.instru || !state.processed) return;
    const r = await call('mix', {
        instruL: state.instru.left.slice(), instruR: state.instru.right.slice(),
        voiceL: state.processed.left.slice(), voiceR: state.processed.right.slice(),
        voiceStartSec: state.voice.startSec, sampleRate: state.instru.sampleRate, duckingDb: 0, vocalOverInstruLu: 1.0,
    });
    state.mix = { left: r.left, right: r.right, report: r.report };
    log('info', `Mix : gain voix ${r.report.vocalGainDb.toFixed(1)} dB, mix ${r.report.mixLufs.toFixed(1)} LUFS, limiteur ${r.report.limiterGrDb.toFixed(1)} dB`);
}
ui.playBtn.addEventListener('click', () => {
    if (state.mix) play([{ buffer: makeBuffer(state.mix.left, state.mix.right) }]);
    else if (state.processed) play([{ buffer: makeBuffer(state.processed.left, state.processed.right), when: state.voice.startSec }]);
    else if (state.instru) play([{ buffer: makeBuffer(state.instru.left, state.instru.right) }]);
});
ui.playRawBtn.addEventListener('click', () => {
    const list = [];
    if (state.instru) list.push({ buffer: makeBuffer(state.instru.left, state.instru.right) });
    if (state.voice) list.push({ buffer: makeBuffer(state.voice.mono, state.voice.mono), when: state.voice.startSec });
    if (list.length) play(list);
});
ui.stopPlayBtn.addEventListener('click', stopPlayback);
ui.exportBtn.addEventListener('click', () => {
    const src = state.mix || state.processed;
    if (!src) return;
    const sr = state.instru ? state.instru.sampleRate : state.voice.sampleRate;
    const wav = encodeWav16(src.left, src.right, sr);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([wav], { type: 'audio/wav' }));
    a.download = `StudioVoix-${(ui.style.selectedOptions[0]?.textContent || 'mix').replace(/[^\w-]+/g, '_')}.wav`;
    document.body.appendChild(a); a.click(); a.remove();
    setStatus('WAV exporté (16 bits, ' + sr + ' Hz).');
});
function encodeWav16(left, right, sampleRate) {
    const n = left.length, bytes = 44 + n * 4;
    const buf = new ArrayBuffer(bytes), v = new DataView(buf);
    const str = (o, s) => { for (let i = 0; i < s.length; ++i) v.setUint8(o + i, s.charCodeAt(i)); };
    str(0, 'RIFF'); v.setUint32(4, bytes - 8, true); str(8, 'WAVE'); str(12, 'fmt ');
    v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 2, true);
    v.setUint32(24, sampleRate, true); v.setUint32(28, sampleRate * 4, true); v.setUint16(32, 4, true); v.setUint16(34, 16, true);
    str(36, 'data'); v.setUint32(40, n * 4, true);
    let o = 44;
    for (let i = 0; i < n; ++i) {
        v.setInt16(o, Math.max(-1, Math.min(1, left[i])) * 32767, true); o += 2;
        v.setInt16(o, Math.max(-1, Math.min(1, right[i])) * 32767, true); o += 2;
    }
    return buf;
}

function fmt(sec) { const m = Math.floor(sec / 60), s = Math.floor(sec % 60); return `${m}:${String(s).padStart(2, '0')}`; }
function refreshButtons() {
    ui.recBtn.disabled = !state.ready;
    ui.demoBtn.disabled = !state.ready;
    ui.processBtn.disabled = !(state.ready && state.voice);
    ui.playBtn.disabled = !(state.instru || state.processed);
    ui.playRawBtn.disabled = !(state.instru || state.voice);
    ui.exportBtn.disabled = !(state.mix || state.processed);
}

drawMeter(ui.meterIn, 0, 0); drawMeter(ui.meterOut, 0, 0);
drawWave(ui.instruWave, null); drawWave(ui.voiceWave, null);
setStatus('Chargement du moteur…');
startWorker();
