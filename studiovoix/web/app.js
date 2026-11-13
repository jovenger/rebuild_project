// StudioVoix Web : studio multipiste. Micro et lecture par Web Audio, moteur C++ (WebAssembly) dans un Web Worker,
// isolation de la voix (IA) dans un second worker.
// Pistes : l'instru en haut (jouée telle quelle, jamais modifiée), puis autant de pistes voix que voulu. Chaque piste
// a son nom, son type (voix principale, back, ambiance, doublage…) et son style : sa prise est traitée par la chaîne
// du style réglée pour ce type et d'après la mesure de la prise ; le mix équilibre les pistes entre elles selon leur
// type (back -7 LU sous la principale, ambiance -14 LU…) puis l'ensemble des voix par rapport à l'instru.

import { findSingers, keepPhrases } from './singers.js';
import { resampleSincAsync } from './resample.js';

const $ = (id) => document.getElementById(id);
const ui = {
    status: $('status'), log: $('log'), version: $('version'), tracks: $('tracks'), report: $('report'),
    recBtn: $('recBtn'), stopBtn: $('stopBtn'), playBtn: $('playBtn'), playRawBtn: $('playRawBtn'), stopPlayBtn: $('stopPlayBtn'),
    exportBtn: $('exportBtn'), meterOut: $('meterOut'), time: $('time'),
    addTrackBtn: $('addTrackBtn'), addRole: $('addRole'),
    countIn: $('countIn'), latencyMs: $('latencyMs'), isolateVoice: $('isolateVoice'), isolateInfo: $('isolateInfo'),
    useScale: $('useScale'), cleaning: $('cleaning'),
    listen: $('listen'), allBtn: $('allBtn'), skipIsoBtn: $('skipIsoBtn'), levelBtn: $('levelBtn'), clipInfo: $('clipInfo'),
    fxPanel: $('fxPanel'), fxTitle: $('fxTitle'), fxInfo: $('fxInfo'), fxList: $('fxList'), fxResetAll: $('fxResetAll'),
    sepBtn: $('sepBtn'), sepLeadBack: $('sepLeadBack'), sepAmbiance: $('sepAmbiance'), sepSingers: $('sepSingers'), sepInfo: $('sepInfo'), sepDenoise: $('sepDenoise'),
    sepProg: $('sepProg'), sepStep: $('sepStep'), sepPct: $('sepPct'), sepBar: $('sepBar'), sepTime: $('sepTime'), sepStopBtn: $('sepStopBtn'), sepSub: $('sepSub'), sepEst: $('sepEst'),
    finalMixBtn: $('finalMixBtn'), finalTarget: $('finalTarget'), finalDuck: $('finalDuck'), finalPlayRow: $('finalPlayRow'),
    playFinalBtn: $('playFinalBtn'), playBeforeBtn: $('playBeforeBtn'), exportFinalBtn: $('exportFinalBtn'), finalInfo: $('finalInfo'), stemsBtn: $('stemsBtn'), newBtn: $('newBtn'), saveInfo: $('saveInfo'),
};

const state = {
    ctx: null,             // AudioContext (créé au premier geste)
    worker: null, ready: false, pending: new Map(), nextId: 1,
    styles: [], roles: [],
    // Instru : { left, right, sampleRate, seconds, name, analysis } ; réglages de piste à part (existe sans fichier).
    instru: null,
    instruTrack: { volumeDb: 0, mute: false, solo: false },
    // Pistes voix : { id, name, roleId, styleId, volumeDb, mute, solo, take: { mono, sampleRate, startSec, note } | null,
    //                 takes: [prises de cette piste], processed: { left, right, report, key } | null, status, token }
    //   take = prise active (une des takes) ; chaque REC sur la piste ajoute une prise, les anciennes restent.
    tracks: [], nextTrackId: 1, selectedId: 0, armedId: 0,
    balance: null, balanceDirty: true,   // gains par piste (dB) calculés par le moteur pour « Mix »
    jobs: Promise.resolve(), busy: 0,    // traitements en file (un à la fois, dans l'ordre)
    player: null,                        // lecture en cours : { mode, nodes, t0, fromSec, raf }
    playFromSec: 0,
    rec: null, workletReady: false, isolating: false,
    restoring: false,                    // projet relu depuis le navigateur : pas de sauvegarde pendant ce temps
    finalMix: null,                      // chanson mixée : { left, right, sampleRate, report, stale }
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
            state.styles = m.styles;
            state.roles = m.roles;
            fillRoleSelect(ui.addRole, 'manual_back');
            setStatus('Moteur prêt. Pose une instru (piste Instru), arme une piste (●) puis REC.');
            restoreProject().then((restored) => {
                if (!restored && state.tracks.length === 0) addTrack('lead', 'Voix principale');
                renderTracks();
            });
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
// ------------------------------------------------------------------ isolation de la voix (IA, worker séparé)
// Retire tout ce qui n'est pas la voix (musique extérieure, restes de l'instru, bruits). Le modèle (67 Mo) n'est
// téléchargé qu'au premier usage, puis gardé par le navigateur.
const iso = { worker: null, pending: new Map(), nextId: 1, backend: '', prep: null };
// Essai e2e seulement (?svTestGpuHang=1) : simule une carte graphique qui bloque au 1er calcul.
const TEST_GPU_HANG = new URLSearchParams(location.search).has('svTestGpuHang');
function gpuBanned() { try { return !!localStorage.getItem('sv-no-webgpu'); } catch { return false; } }
function isoWorker() {
    if (iso.worker) return iso.worker;
    iso.worker = new Worker('./isolate-worker.js', { type: 'module' });
    iso.worker.onmessage = (e) => {
        const m = e.data;
        if (m.type === 'gpu' && !m.ok) {   // carte graphique inutilisable ici : on s'en souvient (processeur direct la prochaine fois)
            try { localStorage.setItem('sv-no-webgpu', m.reason || '1'); } catch (err) { log('warn', `préférence processeur non gardée : ${err.message}`); }
            log('warn', `carte graphique écartée pour l'IA sur cet appareil (${m.reason})`);
            return;
        }
        if (m.type === 'log') {
            log(m.level, '[isolation] ' + m.msg);
            if (state.separating) ui.sepSub.textContent = 'IA : ' + m.msg;   // ce que fait l'IA, visible sans ouvrir le journal
            return;
        }
        if (m.type === 'progress') {
            const pct = Math.round(100 * m.done / Math.max(1, m.total));
            let eta = '';
            if (m.stage === 'isolate') {
                if (m.done <= 1 || !iso.t0) iso.t0 = performance.now();
                const el = (performance.now() - iso.t0) / 1000;
                if (m.done > 1) { const left = Math.max(0, el / (m.done - 1) * (m.total - m.done + 1) - el); eta = ` — encore ~${fmt(left + 1)}`; }
            }
            // Pendant « Séparer », la progression va dans la carte Séparation (sinon le dernier téléchargement,
            // celui du modèle d'empreinte de voix, restait affiché « 100 % » dans la carte Enregistrement).
            if (state.separating) {
                const what = SEP_MODELS[m.model] || 'IA';
                if (m.stage === 'download' && m.done >= m.total) sepSet(null, `${sepRun.stepLabel} — modèle ${what} téléchargé, démarrage de l'IA…`, 0);
                else if (m.stage === 'download') sepSet(null, `${sepRun.stepLabel} — téléchargement du modèle ${what} (une seule fois) : ${(m.done / 1e6).toFixed(0)} / ${(m.total / 1e6).toFixed(0)} Mo`, 0);
                else sepChunk(m.done, m.total, m.skipped);
                return;
            }
            const box = ui.isolateInfo;
            box.textContent = m.stage === 'download'
                ? `Téléchargement du modèle IA (une seule fois) : ${pct} % de ${(m.total / 1e6).toFixed(0)} Mo`
                : `${state.separating ? 'Séparation' : 'Isolation de la voix'} (IA) : ${pct} %${eta}` + (iso.backend ? ` (${iso.backend})` : '');
            if (state.isolating) setStatus(box.textContent);
            return;
        }
        const p = iso.pending.get(m.id);
        if (!p) return;
        iso.pending.delete(m.id);
        m.ok ? p.resolve(m) : p.reject(new Error(m.error));
    };
    iso.worker.onerror = (e) => {
        log('error', `[isolation] worker en échec : ${e.message || 'erreur de chargement'}`);
        for (const p of iso.pending.values()) p.reject(new Error('isolation indisponible : ' + (e.message || 'worker en échec')));
        iso.pending.clear(); iso.worker = null; iso.prep = null;
    };
    return iso.worker;
}
// « Passer l'IA » : arrête le calcul en cours (le modèle reste dans le cache du navigateur pour la prochaine fois).
function cancelIsolation() {
    if (!iso.worker) return;
    iso.worker.terminate();
    for (const p of iso.pending.values()) { const e = new Error('IA passée à la demande'); e.skipped = true; p.reject(e); }
    iso.pending.clear(); iso.worker = null; iso.prep = null; iso.t0 = 0;
    log('warn', 'Isolation IA arrêtée à la demande');
}
function isoCall(cmd, payload = {}, transfer = []) {
    const w = isoWorker();
    return new Promise((resolve, reject) => {
        const id = iso.nextId++;
        iso.pending.set(id, { resolve, reject });
        w.postMessage({ id, cmd, noGpu: gpuBanned(), testGpuHang: TEST_GPU_HANG, ...payload }, transfer);
    }).catch((err) => {
        // Carte graphique bloquée à l'essai : worker neuf en processeur seul, même commande (une seule fois).
        if (err.message !== '__gpu_restart__' || payload.__retried) throw err;
        log('warn', 'IA relancée sur le processeur (carte graphique bloquée)');
        if (state.separating) ui.sepSub.textContent = 'IA : carte graphique bloquée → relance sur le processeur…';
        try { iso.worker?.terminate(); } catch (e2) { log('warn', `arrêt du worker : ${e2.message}`); }
        for (const p of iso.pending.values()) p.reject(new Error('__gpu_restart__'));   // les autres appels repartent aussi
        iso.pending.clear();
        iso.worker = null; iso.prep = null; iso.backend = '';
        return isoCall(cmd, { ...payload, __retried: true }, []);
    });
}
// Prépare le modèle (téléchargement + session) en tâche de fond, par exemple pendant la prise.
function prepareIsolation() {
    if (!ui.isolateVoice.checked) return null;
    if (!iso.prep) {
        iso.prep = isoCall('prepare').then((m) => {
            iso.backend = m.backend;
            ui.isolateInfo.textContent = `IA prête : ${m.backend}`;
            log('info', `Isolation prête sur ${m.backend}`);
            return m;
        }).catch((err) => { iso.prep = null; throw err; });
        iso.prep.catch(() => { /* signalé à l'usage */ });
    }
    return iso.prep;
}
async function resampleMono(data, fromSr, toSr) {
    if (fromSr === toSr) return data.slice();   // copie : le résultat peut être transféré au worker (tampon détaché)
    // Sinc fenêtré (resample.js) : le rééchantillonnage du navigateur est linéaire (aigus étouffés et distordus).
    return resampleSincAsync(data, fromSr, toSr);
}
function rmsDb(x) { let e = 0; for (let i = 0; i < x.length; ++i) e += x[i] * x[i]; return 10 * Math.log10(e / Math.max(1, x.length) + 1e-20); }
// mono (Float32Array, sr Hz) → { mono, removedDb, seconds, backend } : voix seule, même longueur et même fréquence.
async function isolateVoice(mono, sr) {
    const t0 = performance.now();
    await prepareIsolation();
    const x = await resampleMono(mono, sr, 44100);
    if (x.length === 0 || mono.length === 0) throw new Error('prise vide : rien à isoler');
    const r = await isoCall('isolate', { left: x, right: x.slice() }, [x.buffer]);
    const v = new Float32Array(r.left.length);
    for (let i = 0; i < v.length; ++i) v[i] = 0.5 * (r.left[i] + r.right[i]);
    let out = await resampleMono(v, 44100, sr);
    if (out.length !== mono.length) { const o = new Float32Array(mono.length); o.set(out.subarray(0, mono.length)); out = o; }
    if (out.length !== mono.length || out.length === 0) throw new Error(`longueur incohérente après isolation (${out.length} au lieu de ${mono.length})`);
    const removedDb = rmsDb(mono) - rmsDb(out);
    const total = (performance.now() - t0) / 1000;
    log('info', `Isolation : ${(mono.length / sr).toFixed(1)} s en ${total.toFixed(1)} s (${r.backend}) ; énergie retirée ${removedDb.toFixed(1)} dB`);
    return { mono: out, removedDb, seconds: total, backend: r.backend };
}
// Fond sonore de la prise : tranches de 50 ms ; voix = 90e centile, fond = 10e centile (silences entre les phrases).
// Un grand écart = rien d'autre que la voix (pas de musique extérieure continue) : l'IA n'est alors pas nécessaire.
const CLEAN_GAP_DB = 25;   // mesuré : radio au niveau de la voix 7,4 dB ; instru captée seule (retirée) 33,3 dB
function backgroundGap(mono, sr) {
    const hop = Math.max(1, Math.round(0.05 * sr)), lv = [];
    for (let s = 0; s + hop <= mono.length; s += hop) {
        let e = 0;
        for (let i = s; i < s + hop; ++i) e += mono[i] * mono[i];
        lv.push(10 * Math.log10(e / hop + 1e-20));
    }
    if (lv.length < 20) return { gapDb: 0, floorDb: -200, voiceDb: -200 };
    lv.sort((a, b) => a - b);
    const floorDb = lv[Math.floor(lv.length * 0.1)], voiceDb = lv[Math.floor(lv.length * 0.9)];
    return { gapDb: voiceDb - floorDb, floorDb, voiceDb };
}
// Applique l'isolation si la case est cochée ; en cas d'échec, garde la prise telle quelle et le dit.
async function maybeIsolate(mono, sr) {
    if (!ui.isolateVoice.checked) return { mono, note: 'isolation IA désactivée' };
    const bg = backgroundGap(mono, sr);
    log('info', `Fond sonore de la prise : voix ${bg.voiceDb.toFixed(1)} dBFS, fond ${bg.floorDb.toFixed(1)} dBFS, écart ${bg.gapDb.toFixed(1)} dB (IA si < ${CLEAN_GAP_DB} dB)`);
    if (bg.gapDb >= CLEAN_GAP_DB) {
        ui.isolateInfo.textContent = `Prise déjà propre (fond ${bg.gapDb.toFixed(0)} dB sous la voix) : IA non nécessaire`;
        return { mono, note: `aucun son extérieur détecté (fond ${bg.gapDb.toFixed(0)} dB sous la voix) : IA non nécessaire` };
    }
    state.isolating = true;
    ui.skipIsoBtn.hidden = false;
    setStatus(`Son extérieur détecté (fond seulement ${bg.gapDb.toFixed(0)} dB sous la voix) : isolation de la voix (IA)… « Passer l'IA » pour garder la prise sans elle.`);
    try {
        const r = await isolateVoice(mono, sr);
        ui.isolateInfo.textContent = `Dernière isolation : ${r.seconds.toFixed(0)} s sur ${r.backend}`;
        return { mono: r.mono, note: `voix isolée par IA (${r.removedDb.toFixed(1)} dB d'autres sons retirés)`, isolated: r };
    } catch (err) {
        if (err.skipped) {
            ui.isolateInfo.textContent = 'IA passée : prise gardée avec la musique des haut-parleurs retirée, sans l\'IA';
            return { mono, note: '⚠ IA passée à la demande (sons extérieurs non retirés)' };
        }
        log('error', 'Isolation IA impossible : ' + err.message);
        ui.isolateInfo.textContent = 'Isolation IA impossible : ' + err.message;
        return { mono, note: `⚠ isolation IA impossible (${err.message}) : prise gardée sans elle` };
    } finally { state.isolating = false; ui.skipIsoBtn.hidden = true; iso.t0 = 0; }
}


// ------------------------------------------------------------------ listes (styles, types de piste)
function fillStyleSelect(sel, value) {
    sel.innerHTML = '';
    for (const g of state.styles) {
        const og = document.createElement('optgroup');
        og.label = g.family;
        for (const s of g.styles) {
            const o = document.createElement('option');
            o.value = s.id; o.textContent = s.name;
            og.appendChild(o);
        }
        sel.appendChild(og);
    }
    sel.value = value;
    if (!sel.value && sel.options.length) sel.selectedIndex = 0;
}
function fillRoleSelect(sel, value) {
    sel.innerHTML = '';
    for (const r of state.roles) {
        const o = document.createElement('option');
        o.value = r.id; o.textContent = roleLabel(r.id); o.title = r.label;
        sel.appendChild(o);
    }
    sel.value = value;
}
// Libellés courts des types (ceux que Yann a nommés d'abord : principale, back, ambiance).
function roleLabel(id) {
    const short = { lead: 'Voix principale', manual_back: 'Voix back', ambiance: "Voix d'ambiance", double: 'Doublage',
                    harmony: 'Harmonie', adlib: 'Ad-libs', instrument: 'Instrument' };
    return short[id] || state.roles.find((r) => r.id === id)?.name || id;
}
function styleName(id) {
    for (const g of state.styles) for (const s of g.styles) if (s.id === id) return s.name;
    return id;
}

// ------------------------------------------------------------------ pistes
function nextTrackName(roleId) {
    if (roleId === 'lead' && !state.tracks.some((t) => t.roleId === 'lead')) return 'Voix principale';
    const n = state.tracks.length + 1;
    if (n === 2) return 'Seconde voix';
    return `Voix ${n}`;
}
function addTrack(roleId, name) {
    const t = {
        id: state.nextTrackId++, name: name || nextTrackName(roleId), roleId, styleId: state.tracks[0]?.styleId || 'rap_conscient',
        volumeDb: 0, mute: false, solo: false, take: null, takes: [], processed: null, status: 'vide', token: 0,
    };
    state.tracks.push(t);
    if (!state.armedId) state.armedId = t.id;
    log('info', `Piste ajoutée : « ${t.name} » (${roleLabel(roleId)}, ${styleName(t.styleId)})`);
    markDirty();
    return t;
}
// Nouvelle prise sur une piste : elle devient la prise active, les précédentes restent au choix (« Prise n »).
let nextAudioId = 1;
function addTake(t, take) {
    take.audioId = take.audioId || `a${Date.now().toString(36)}${(nextAudioId++).toString(36)}`;
    take.label = take.label || `Prise ${t.takes.length + 1}`;
    t.takes.push(take);
    t.take = take;
    t.processed = null;
    t.status = 'raw';
    state.balanceDirty = true;
    log('info', `« ${t.name} » : ${take.label} (${fmt(take.mono.length / take.sampleRate)} à ${take.startSec.toFixed(2)} s)`);
    markDirty();
}
function selectTake(t, index) {
    const take = t.takes[index];
    if (!take || take === t.take) return;
    t.take = take;
    t.processed = null;
    state.balanceDirty = true;
    log('info', `« ${t.name} » : ${take.label} choisie`);
    markDirty();
    renderTracks();
    queueProcess(t);
}
function findTrack(id) { return state.tracks.find((t) => t.id === id) || null; }
function removeTrack(id) {
    const t = findTrack(id);
    if (!t) return;
    if (t.take && !confirm(`Supprimer la piste « ${t.name} » et sa prise ?`)) return;
    state.tracks = state.tracks.filter((x) => x.id !== id);
    if (state.armedId === id) state.armedId = state.tracks[0]?.id || 0;
    if (state.selectedId === id) state.selectedId = 0;
    state.balanceDirty = true;
    log('info', `Piste supprimée : « ${t.name} »`);
    markDirty();
    renderTracks();
}

function songSeconds() {
    let end = state.instru ? state.instru.seconds : 0;
    for (const t of state.tracks) if (t.take) end = Math.max(end, t.take.startSec + t.take.mono.length / t.take.sampleRate);
    return Math.max(end, 10);
}

// En-tête + forme d'onde de chaque piste. Reconstruit à chaque changement de structure (ajout, suppression).
function renderTracks() {
    ui.tracks.innerHTML = '';
    ui.tracks.appendChild(instruRow());
    for (const t of state.tracks) ui.tracks.appendChild(trackRow(t));
    drawAllLanes();
    refreshAudibility();
    refreshButtons();
}
// Pistes entendues (muet / solo) : les autres sont grisées ; indication dans la barre de transport.
function refreshAudibility() {
    const rows = [[0, state.instruTrack], ...state.tracks.map((t) => [t.id, t])];
    let on = 0;
    for (const [id, obj] of rows) {
        const r = rowOf(id);
        const a = audible(obj);
        if (a && (id === 0 ? state.instru : obj.take)) ++on;
        if (r) r.classList.toggle('off', !a);
    }
    const total = (state.instru ? 1 : 0) + state.tracks.filter((t) => t.take).length;
    const anyOff = rows.some(([, o]) => !audible(o));
    ui.listen.textContent = anyOff ? `Écoute : ${on} piste(s) sur ${total}` : 'Écoute : tout';
    ui.allBtn.disabled = !anyOff;
}
function el(tag, props = {}, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(props)) {
        if (k === 'class') e.className = v;
        else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
        else if (k in e) e[k] = v;
        else e.setAttribute(k, v);
    }
    for (const k of kids) if (k != null) e.append(k);
    return e;
}
// Muet : coupe cette piste. Solo : n'écoute que les pistes en solo (une ou plusieurs). Effet immédiat, même en lecture.
function toggles(obj, onChange) {
    const m = el('button', { class: 'tog m' + (obj.mute ? ' on' : ''), textContent: 'M', title: 'Muet : couper le son de cette piste',
        onclick: (e) => { e.stopPropagation(); obj.mute = !obj.mute; e.target.classList.toggle('on', obj.mute); onChange(); } });
    const s = el('button', { class: 'tog s' + (obj.solo ? ' on' : ''), textContent: 'S', title: 'Solo : n\'écouter que cette piste (et les autres en solo)',
        onclick: (e) => { e.stopPropagation(); obj.solo = !obj.solo; e.target.classList.toggle('on', obj.solo); onChange(); } });
    const v = el('input', { type: 'range', class: 'vol', min: -24, max: 12, step: 0.5, value: obj.volumeDb, title: `Volume ${obj.volumeDb} dB`,
        oninput: (e) => { obj.volumeDb = Number(e.target.value); e.target.title = `Volume ${obj.volumeDb} dB`; liveGains(); markDirty(); } });
    return [m, s, v];
}
function instruRow() {
    const row = el('div', { class: 'track instru', 'data-id': '0' });
    const file = el('input', { type: 'file', accept: 'audio/*', id: 'instruFile', onchange: (e) => loadInstruFile(e.target.files[0]) });
    const info = state.instru
        ? `${state.instru.name} · ${fmt(state.instru.seconds)}` + (state.instru.analysis ? ` · ${state.instru.analysis.key} · ${state.instru.analysis.bpm.toFixed(0)} BPM` : '')
        : 'aucune instru';
    const meter = el('canvas', { class: 'meter', width: 300, height: 9 });
    row._meter = meter;
    const head = el('div', { class: 'head' },
        el('div', { class: 'r' }, el('span', { class: 'tag', textContent: 'Instru' }), el('span', { class: 'name', textContent: state.instru ? state.instru.name : 'Instrumental' })),
        meter,
        el('div', { class: 'r' },
            el('span', { class: 'file' }, el('button', { textContent: 'Importer l\'instru' }), file),
            el('button', { id: 'demoBtn', textContent: 'Démo', disabled: !state.ready, title: 'Instru et deux voix de démonstration (La mineur, 100 BPM)', onclick: loadDemo })),
        state.instru?.original ? el('div', { class: 'r' }, el('button', { textContent: '↺ Rétablir le morceau', title: 'Remettre la chanson d\'origine (avant séparation) sur cette piste', onclick: (e) => { e.stopPropagation(); restoreOriginalSong(); } })) : null,
        el('div', { class: 'r' }, ...toggles(state.instruTrack, onMuteSolo)),
        el('div', { class: 'tinfo', textContent: info, title: 'Jouée telle quelle, jamais modifiée' }));
    const lane = el('div', { class: 'lane' }, el('canvas'), state.instru ? null : el('div', { class: 'empty', textContent: 'Importe l\'instru (MP3, WAV…) : elle va seule sur cette piste' }));
    laneEvents(lane, null);
    row.append(head, lane);
    row._lane = lane;
    return row;
}
function trackRow(t) {
    const row = el('div', { class: 'track' + (t.id === state.selectedId ? ' sel' : '') + (t.id === state.armedId ? ' armed' : ''), 'data-id': String(t.id) });
    const arm = el('button', { class: 'arm' + (t.id === state.armedId ? ' on' : ''), textContent: '●', title: 'Armer : le prochain REC enregistre sur cette piste',
        onclick: (e) => { e.stopPropagation(); state.armedId = t.id; renderTracks(); } });
    const name = el('input', { type: 'text', class: 'name', value: t.name, title: 'Nom de la piste (libre)',
        onchange: (e) => { t.name = e.target.value.trim() || t.name; log('info', `Piste renommée : « ${t.name} »`); markDirty(); } });
    const role = el('select', { class: 'role', title: 'Type de piste : règle la chaîne (effets) et la place dans le mix' });
    fillRoleSelect(role, t.roleId);
    role.addEventListener('change', () => { t.roleId = role.value; log('info', `« ${t.name} » : type ${roleLabel(t.roleId)}`); markDirty(); queueProcess(t); });
    const style = el('select', { class: 'style', title: 'Style de mixage de cette voix' });
    fillStyleSelect(style, t.styleId);
    style.addEventListener('change', () => { t.styleId = style.value; log('info', `« ${t.name} » : style ${styleName(t.styleId)}`); markDirty(); queueProcess(t); });
    const file = el('input', { type: 'file', accept: 'audio/*', class: 'voiceFile', onchange: (e) => importVoice(t, e.target.files[0]) });
    const meter = el('canvas', { class: 'meter', width: 300, height: 9 });
    const badge = el('span', { class: 'badge', textContent: badgeText(t) });
    const info = el('div', { class: 'tinfo', textContent: trackInfo(t) });
    row._meter = meter; row._badge = badge; row._info = info;
    const head = el('div', { class: 'head', onclick: () => selectTrack(t.id) },
        el('div', { class: 'r' }, arm, name, badge,
            el('button', { class: 'x', textContent: '✕', title: 'Supprimer la piste', onclick: (e) => { e.stopPropagation(); removeTrack(t.id); } })),
        el('div', { class: 'r' }, role, style),
        meter,
        el('div', { class: 'r' }, ...toggles(t, onMuteSolo),
            el('button', { class: 'tog fx' + (t.noFx ? '' : ' on'), textContent: 'FX', title: t.noFx ? 'Sans effet : jouée telle quelle (clique pour appliquer la chaîne du style)' : 'Effets du style appliqués (clique pour jouer la piste telle quelle)',
                onclick: (e) => { e.stopPropagation(); t.noFx = !t.noFx; log('info', `« ${t.name} » : ${t.noFx ? 'sans effet' : 'effets du style'}`); markDirty(); renderTracks(); queueProcess(t); } }),
            el('button', { class: 'tog lock' + (t.locked ? ' on' : ''), textContent: t.locked ? '🔒' : '🔓',
                title: t.locked ? 'Piste verrouillée : la prise ne peut pas être déplacée (clique pour déverrouiller)' : 'Piste libre : glisser la prise la déplace (clique pour la verrouiller à sa place)',
                onclick: (e) => { e.stopPropagation(); t.locked = !t.locked; log('info', `« ${t.name} » : ${t.locked ? 'verrouillée (déplacement bloqué)' : 'déverrouillée (déplacement permis)'}`); markDirty(); renderTracks(); } }),
            el('span', { class: 'file' }, el('button', { textContent: 'Importer', title: 'Importer une voix sur cette piste' }), file)),
        t.take?.raw ? el('div', { class: 'r' }, el('button', { class: 'raw', textContent: '🎙 Micro brut',
            title: 'Écouter ce que le micro a vraiment capté (avant nettoyage), pour comparer avec la prise gardée',
            onclick: (e) => { e.stopPropagation(); playRawMic(t); } })) : null,
        t.takes.length > 1 ? el('div', { class: 'r' }, takeSelect(t)) : null,
        info);
    const lane = el('div', { class: 'lane' }, el('canvas'), t.take ? null : el('div', { class: 'empty', textContent: 'Arme la piste (●) puis REC, ou importe une voix' }));
    laneEvents(lane, t);
    row.append(head, lane);
    row._lane = lane;
    return row;
}
function takeSelect(t) {
    const sel = el('select', { class: 'take', title: 'Prises de cette piste : chaque REC en ajoute une, choisis celle qui joue' });
    t.takes.forEach((k, i) => sel.appendChild(el('option', { value: String(i), textContent: `${k.label} · ${fmt(k.mono.length / k.sampleRate)}` })));
    sel.value = String(t.takes.indexOf(t.take));
    sel.addEventListener('change', () => selectTake(t, Number(sel.value)));
    sel.addEventListener('click', (e) => e.stopPropagation());
    return sel;
}
// Micro brut d'une prise, seul, à sa place : pour entendre ce qui a été retiré (musique captée, sons extérieurs).
function playRawMic(t) {
    if (!t.take?.raw) return;
    if (state.player?.mode === 'rawmic') { stopPlayback(); setStatus('Lecture arrêtée.'); return; }
    stopPlayback();
    const ctx = audioContext();
    const src = ctx.createBufferSource();
    src.buffer = makeBuffer(t.take.raw, t.take.raw);
    src.connect(ctx.destination);
    const t0 = ctx.currentTime + 0.05;
    src.start(t0);
    const player = { mode: 'rawmic', nodes: [{ key: -1, src }], t0, fromSec: t.take.startSec, raf: 0 };
    state.player = player;
    const tick = () => { if (state.player !== player) return; setPlayhead(t.take.startSec + ctx.currentTime - t0); player.raf = requestAnimationFrame(tick); };
    player.raf = requestAnimationFrame(tick);
    src.onended = () => { if (state.player === player) { stopPlayback(); setStatus('Fin du micro brut.'); } };
    setStatus(`Micro brut de « ${t.name} » (${t.take.label}) : ce que le micro a capté avant nettoyage. Écoute « Mix » ou mets la piste en solo pour la prise gardée.`);
}
function badgeText(t) {
    if (t.status === 'busy') return 'traitement…';
    if (t.status === 'isolating') return 'isolation IA…';
    if (t.noFx && t.take) return 'sans effet';
    if (t.processed) return 'traitée';
    if (t.take) return 'brute';
    return 'vide';
}
function trackInfo(t) {
    const g = state.balance?.gains.get(t.id);
    const parts = [`${roleLabel(t.roleId)} · ${styleName(t.styleId)}`];
    if (t.take) parts.push(`prise ${fmt(t.take.mono.length / t.take.sampleRate)} à ${fmt(t.take.startSec)}`);
    const lvl = mixLevelDb(t);
    // En tête de ligne (l'en-tête de piste est étroit) : le niveau au Mix doit rester lisible.
    if (lvl != null) parts.unshift(`niveau au mix ${lvl.toFixed(1).replace('.', ',')} LUFS (auto ${g >= 0 ? '+' : ''}${g.toFixed(1)} dB)`);
    else if (g != null && !state.balanceDirty) parts.push(`mix ${g >= 0 ? '+' : ''}${g.toFixed(1)} dB`);
    if (t.take?.note) parts.push(t.take.note);
    const rg = rawLevelOn() && rawLevelFresh() ? state.balanceRaw.gains.get(t.id) : null;
    if (rg != null) parts.unshift(`brut égalisé ${rg >= 0 ? '+' : ''}${rg.toFixed(1)} dB`);
    return parts.join(' · ');
}
function rowOf(id) { return ui.tracks.querySelector(`.track[data-id="${id}"]`); }
function updateRow(t) {
    const row = rowOf(t.id);
    if (!row) return;
    row._badge.textContent = badgeText(t);
    row._badge.className = 'badge' + (t.status === 'busy' || t.status === 'isolating' ? ' busy' : t.processed ? ' done' : '');
    row._info.textContent = trackInfo(t);
    row._info.classList.toggle('warn', !!t.take?.note?.startsWith('⚠'));
    const empty = row._lane.querySelector('.empty');
    if (t.take && empty) empty.remove();
    drawLane(row, t);
    if (t.id === state.selectedId) { showReport(t); renderFx(); }
    refreshButtons();
}
function selectTrack(id) {
    state.selectedId = id;
    for (const r of ui.tracks.querySelectorAll('.track')) r.classList.toggle('sel', r.dataset.id === String(id));
    const t = findTrack(id);
    if (t) showReport(t);
    renderFx(true);
}
function showReport(t) {
    const rep = t.processed?.report;
    const g = state.balance?.gains.get(t.id);
    const b = state.balance?.items?.get(t.id);
    if (!t.take) { ui.report.textContent = `« ${t.name} » : ${roleLabel(t.roleId)}, style ${styleName(t.styleId)}. Pas encore de prise.`; return; }
    if (!rep) { ui.report.textContent = `« ${t.name} » : prise brute (${t.take.note || 'sans effet'}). Traitement à venir.`; return; }
    ui.report.textContent =
        `« ${t.name} » — ${rep.role}, style ${rep.style}, réglé d'après la mesure de la prise :\n${rep.fitNotes || 'rien à ajuster'}\n\n` +
        `Mesuré sur la prise : ${rep.found || 'aucun défaut notable'}\n\n` +
        `Chaîne appliquée :\n${rep.chain}\n\n` +
        `Justesse ${Math.round(rep.meanCorrectionCents)} c · compression ${rep.compGrDb.toFixed(1)} dB · ${rep.lufs.toFixed(1)} LUFS` +
        (rep.adaptedKey ? ` · gamme adaptée à la voix : ${rep.adaptedKey}` : '') + (rep.chromatic ? ' · note par note' : '') +
        (rep.nearSilent ? '\nPRISE QUASI SILENCIEUSE : vérifie le micro' : '') +
        (g != null && !state.balanceDirty
            ? `\n\nPlace dans le mix : ${b && b.placeLu ? `${b.placeLu} LU sous la voix principale, ` : ''}gain ${g >= 0 ? '+' : ''}${g.toFixed(1)} dB (+ fader ${t.volumeDb} dB)`
            : '') +
        (t.take.note ? `\nPrise : ${t.take.note}` : '');
}

// Forme d'onde placée sur la ligne de temps commune (toute la chanson sur la largeur de la piste).
function drawLane(row, t, force = false) {
    if (!force && t && state.rec && state.rec.trackId === t.id) return;   // forme d'onde en direct : ne pas l'effacer
    const canvas = row._lane.querySelector('canvas');
    const dpr = window.devicePixelRatio || 1;
    const w = Math.max(50, Math.round(row._lane.clientWidth * dpr)), h = Math.max(40, Math.round(row._lane.clientHeight * dpr));
    if (canvas.width !== w) canvas.width = w;
    if (canvas.height !== h) canvas.height = h;
    const g = canvas.getContext('2d');
    g.fillStyle = '#10131a'; g.fillRect(0, 0, w, h);
    const total = songSeconds();
    // repères de mesure (si l'instru est analysée)
    const bpm = state.instru?.analysis?.bpm;
    if (bpm) {
        g.fillStyle = 'rgba(255,255,255,.05)';
        const bar = 4 * 60 / bpm, first = state.instru.analysis.firstBeatSec || 0;
        for (let s = first; s < total; s += bar) g.fillRect(Math.round(s / total * w), 0, 1, h);
    }
    let data = null, sr = 0, start = 0, color = '#3a9bff';
    if (!t) { if (state.instru) { data = state.instru.left; sr = state.instru.sampleRate; color = '#8a94a8'; } }
    else if (t.take) {
        data = t.processed ? t.processed.left : t.take.mono; sr = t.take.sampleRate; start = t.take.startSec;
        color = t.processed ? '#e94e8a' : '#3a9bff';
    }
    if (!data || !data.length) return;
    const x0 = start / total * w, x1 = (start + data.length / sr) / total * w;
    g.fillStyle = color + '22'; g.fillRect(x0, 2, x1 - x0, h - 4);
    g.fillStyle = color;
    const per = data.length / Math.max(1, x1 - x0);
    for (let px = Math.floor(x0); px < Math.min(w, x1); ++px) {
        const a = Math.floor((px - x0) * per), b = Math.min(data.length, Math.floor((px + 1 - x0) * per));
        let mx = 0;
        for (let i = Math.max(0, a); i < b; i += 4) mx = Math.max(mx, Math.abs(data[i]));
        const hh = Math.max(1, mx * (h / 2 - 3));
        g.fillRect(px, h / 2 - hh, 1, hh * 2);
    }
}
// Forme d'onde en direct pendant la prise : la piste armée est vidée, puis chaque crête du micro (toutes les 256
// échantillons, ~6 ms) est dessinée à sa place sur la ligne de temps dès qu'elle arrive.
function liveStart(t) {
    const row = rowOf(t.id);
    if (!row) return;
    drawLane(row, { ...t, take: null, processed: null }, true);   // fond + repères de mesure seulement
    row._lane.querySelector('.empty')?.remove();
    const c = row._lane.querySelector('canvas'), g = c.getContext('2d'), dpr = window.devicePixelRatio || 1;
    g.fillStyle = 'rgba(255,255,255,.55)';
    g.font = `${Math.round(11 * dpr)}px system-ui, sans-serif`;
    g.fillText('● micro en direct — la musique des haut-parleurs sera retirée à l\'arrêt', 6 * dpr, 14 * dpr);
    log('info', `Forme d'onde en direct sur « ${t.name} » (latence d'entrée annoncée ${Math.round((state.rec?.inLatency || 0) * 1000)} ms, compensée à l'affichage)`);
}
function livePeak(t, p) {
    const r = state.rec;
    if (!r || r.trackId !== t.id) return;
    const row = rowOf(t.id);
    const canvas = row?._lane.querySelector('canvas');
    if (!canvas) return;
    const sec = p.frame / r.sampleRate - r.songStartCtx + r.fromSec - r.inLatency;
    if (sec < 0) return;   // compte à rebours : avant le début du morceau
    const w = canvas.width, h = canvas.height, total = r.total;
    const x = Math.min(w - 1, Math.floor(sec / total * w));
    const dx = Math.max(1, Math.ceil(p.n / r.sampleRate / total * w));
    const amp = Math.min(1, Math.max(Math.abs(p.min), Math.abs(p.max)) * 2.5);   // voix souvent faible : agrandie à l'écran
    const hh = Math.max(1, amp * (h / 2 - 3));
    const g = canvas.getContext('2d');
    g.fillStyle = '#e5484d';
    g.fillRect(x, h / 2 - hh, dx, hh * 2);
}
function drawAllLanes() {
    const ir = rowOf(0);
    if (ir) drawLane(ir, null);
    for (const t of state.tracks) { const r = rowOf(t.id); if (r) drawLane(r, t); }
}
window.addEventListener('resize', () => drawAllLanes());

// Ligne de temps : un clic place la tête de lecture (et le départ du prochain REC) ; glisser une prise la déplace.
function laneEvents(lane, t) {
    let drag = null;
    lane.addEventListener('pointerdown', (e) => {
        const r = lane.getBoundingClientRect(), total = songSeconds();
        const sec = (e.clientX - r.left) / r.width * total;
        const k = t?.take;
        const onClip = k && sec >= k.startSec && sec <= k.startSec + k.mono.length / k.sampleRate;
        drag = { x: e.clientX, w: r.width, total, start: k ? k.startSec : 0, moved: false, onClip, sec };
        if (onClip) lane.setPointerCapture(e.pointerId);
    });
    lane.addEventListener('pointermove', (e) => {
        if (!drag || !drag.onClip) return;
        const dx = e.clientX - drag.x;
        if (!drag.moved && Math.abs(dx) < 6) return;
        if (t.locked) {   // cadenas : la prise reste calée sur l'instru ; le geste ne fait que placer la tête de lecture
            if (!drag.warned) { drag.warned = true; setStatus(`« ${t.name} » est verrouillée 🔒 : la prise ne bouge pas. Clique le cadenas de la piste pour la déplacer.`); log('info', `« ${t.name} » : déplacement refusé (piste verrouillée)`); }
            return;
        }
        drag.moved = true;
        t.take.startSec = Math.max(0, drag.start + dx / drag.w * drag.total);
        drawLane(lane.parentElement, t);
    });
    const end = (e) => {
        if (!drag) return;
        const d = drag; drag = null;
        if (d.moved) {
            log('info', `« ${t.name} » : prise déplacée de ${d.start.toFixed(2)} s à ${t.take.startSec.toFixed(2)} s`);
            state.balanceDirty = true;
            markDirty();
            drawAllLanes();
            queueProcess(t);   // grille rythmique vue depuis la nouvelle place
            return;
        }
        const sec = Math.max(0, Math.min(d.total, d.sec));
        state.playFromSec = sec;
        setPlayhead(sec);
        if (state.player) play(state.player.mode, sec);
    };
    lane.addEventListener('pointerup', end);
    lane.addEventListener('pointercancel', () => { drag = null; });
}
function setPlayhead(sec) {
    // Position bornée [0, durée] : une valeur négative ou NaN (arrêt, séparation) affichait « -1:-0.0 ».
    const total = songSeconds();
    const out = !Number.isFinite(sec) || sec < 0 || (total > 0 && sec > total);
    if (out && !setPlayhead.warned) log('debug', `tête de lecture hors bornes (${sec}) : ramenée dans [0, ${total.toFixed(1)}]`);
    setPlayhead.warned = out;   // un seul log par sortie de bornes (évite d'inonder le journal à chaque image)
    sec = Math.min(Math.max(Number.isFinite(sec) ? sec : 0, 0), total > 0 ? total : 0);
    ui.tracks.style.setProperty('--pos', `${total > 0 ? (sec / total) * 100 : 0}%`);
    ui.time.textContent = `${Math.floor(sec / 60)}:${(sec % 60).toFixed(1).padStart(4, '0')}`;
}

// ------------------------------------------------------------------ traitement par piste (file d'attente)
function setBusy(delta) {
    state.busy += delta;
    document.body.dataset.busy = String(state.busy);
}
function queueProcess(t) {
    if (!t.take) { updateRow(t); return; }
    if (t.noFx) {   // piste « sans effet » (voix séparée d'une chanson déjà produite) : jouée telle quelle
        ++t.token; t.processed = null; t.status = 'raw'; state.balanceDirty = true; updateRow(t);
        return state.jobs;
    }
    const token = ++t.token;
    t.status = 'busy';
    state.balanceDirty = true;
    updateRow(t);
    setBusy(1);
    state.jobs = state.jobs.then(() => processTrack(t, token)).catch((err) => log('error', err.message)).finally(() => setBusy(-1));
    state.jobs.then(() => liveRefresh(t, token));   // lecture « Mix » en cours : le nouveau son remplace l'ancien sans arrêter
    return state.jobs;
}
async function processTrack(t, token) {
    if (token !== t.token || !findTrack(t.id) || !t.take) return;   // réglage changé entre-temps : seul le dernier compte
    const fx = t.fx && Object.keys(t.fx).length ? t.fx : null;   // réglages faits à la main dans le tableau des effets
    const key = `${t.styleId}|${t.roleId}|${ui.cleaning.checked}|${ui.useScale.checked}|${fx ? JSON.stringify(fx) : ''}`;
    const t0 = performance.now();
    setStatus(`Traitement de « ${t.name} » : ${roleLabel(t.roleId)}, style ${styleName(t.styleId)}…`);
    try {
        const r = await call('processVoice', {
            mono: t.take.mono.slice(), sampleRate: t.take.sampleRate, styleId: t.styleId, roleId: t.roleId,
            cleaning: ui.cleaning.checked, useScale: ui.useScale.checked, startSec: t.take.startSec, fx,
        });
        if (token !== t.token) return;
        t.processed = { left: r.left, right: r.right, report: r.report, key };
        t.status = 'done';
        state.balanceDirty = true;
        log('info', `« ${t.name} » traitée (${r.report.role}, ${r.report.style}) en ${Math.round(performance.now() - t0)} ms`);
        setStatus(`Piste « ${t.name} » traitée : ${roleLabel(t.roleId)}, style ${styleName(t.styleId)}.`);
    } catch (err) {
        t.status = 'error';
        log('error', `« ${t.name} » : traitement impossible : ${err.message}`);
        setStatus(`Traitement de « ${t.name} » impossible : ${err.message}`);
    }
    updateRow(t);
}
function reprocessAll() { for (const t of state.tracks) if (t.take) queueProcess(t); }
ui.cleaning.addEventListener('change', reprocessAll);
ui.useScale.addEventListener('change', () => {
    if (state.instru?.analysis) {
        const a = state.instru.analysis;
        call('setContext', { root: a.root, minor: a.minor, bpm: a.bpm, firstBeatSec: a.firstBeatSec || 0, useScale: ui.useScale.checked }).catch((e) => log('warn', e.message));
    }
    reprocessAll();
});

// ------------------------------------------------------------------ tableau des effets (piste sélectionnée)
// Le moteur rend, pour chaque piste traitée, le pré-réglage (style + type, ajusté à la mesure de la prise) et les
// réglages réellement appliqués, un objet par effet. Ce tableau les montre, permet d'éteindre / allumer un effet et
// d'en changer les valeurs ; les changements (t.fx, gardés avec le projet) sont renvoyés au moteur, qui retraite la
// piste ; si la lecture « Mix » tourne, le nouveau son remplace l'ancien sans l'arrêter.
const fPct = (v) => `${Math.round(v * 100)} %`, fDb = (v) => `${v > 0 ? '+' : ''}${(+v).toFixed(1)} dB`, fHz = (v) => `${Math.round(v)} Hz`, fMs = (v) => `${Math.round(v)} ms`;
const fNote = (v) => ({ 0.25: 'double croche', 0.5: 'croche', 0.75: 'croche pointée', 1: 'noire' }[v] || `${v} temps`);
const FX_DEFS = [
    { id: 'clean', icon: '🧹', name: 'Nettoyage', fields: [
        { k: 'denoiseDb', label: 'Souffle retiré', min: 0, max: 24, step: 1, fmt: fDb },
        { k: 'gateRangeDb', label: 'Silences baissés', min: 0, max: 24, step: 1, fmt: fDb },
        { k: 'breathReductionDb', label: 'Respirations baissées', min: 0, max: 18, step: 1, fmt: fDb },
        { k: 'hpfHz', label: 'Coupe-bas', min: 20, max: 250, step: 5, fmt: fHz }] },
    { id: 'leveler', icon: '📏', name: 'Niveleur (volume régulier)', fields: [
        { k: 'maxBoostDb', label: 'Passages faibles remontés jusqu\'à', min: 0, max: 12, step: 0.5, fmt: fDb },
        { k: 'maxCutDb', label: 'Passages forts baissés jusqu\'à', min: 0, max: 12, step: 0.5, fmt: fDb }] },
    { id: 'timing', icon: '⏱', name: 'Recalage rythmique', fields: [{ k: 'strength', label: 'Force', min: 0, max: 1, step: 0.05, fmt: fPct }] },
    { id: 'pitch', icon: '🎯', name: 'Autotune (justesse)', fields: [
        { k: 'amount', label: 'Quantité', min: 0, max: 1, step: 0.05, fmt: fPct },
        { k: 'retuneMs', label: 'Vitesse (0 = effet robot)', min: 0, max: 400, step: 5, fmt: fMs },
        { k: 'humanize', label: 'Naturel', min: 0, max: 1, step: 0.05, fmt: fPct }] },
    { id: 'eq', icon: '🎚', name: 'Égaliseur', fields: [
        { k: 'lowCutHz', label: 'Coupe-bas', min: 20, max: 300, step: 5, fmt: fHz },
        { k: 'lowShelfDb', label: 'Graves', min: -12, max: 12, step: 0.5, fmt: fDb },
        { k: 'mudDb', label: 'Bas-médium (boue)', min: -12, max: 12, step: 0.5, fmt: fDb },
        { k: 'presenceDb', label: 'Présence', min: -12, max: 12, step: 0.5, fmt: fDb },
        { k: 'airDb', label: 'Air (aigus)', min: -12, max: 12, step: 0.5, fmt: fDb }] },
    { id: 'resonance', icon: '〰️', name: 'Résonances (dureté)', fields: [{ k: 'maxReductionDb', label: 'Baisse maximale', min: 0, max: 12, step: 0.5, fmt: fDb }] },
    { id: 'comp', icon: '🗜️', name: 'Compresseur', fields: [
        { k: 'thresholdDb', label: 'Seuil', min: -50, max: 0, step: 1, fmt: fDb },
        { k: 'ratio', label: 'Taux', min: 1, max: 20, step: 0.1, fmt: (v) => `${(+v).toFixed(1)}:1` },
        { k: 'attackMs', label: 'Attaque', min: 0.1, max: 200, step: 0.5, fmt: (v) => `${(+v).toFixed(1)} ms` },
        { k: 'releaseMs', label: 'Relâchement', min: 10, max: 1000, step: 10, fmt: fMs },
        { k: 'mix', label: 'Dosage', min: 0, max: 1, step: 0.05, fmt: fPct }] },
    { id: 'comp2', icon: '🧈', name: 'Compresseur doux', fields: [
        { k: 'thresholdDb', label: 'Seuil', min: -50, max: 0, step: 1, fmt: fDb },
        { k: 'ratio', label: 'Taux', min: 1, max: 10, step: 0.1, fmt: (v) => `${(+v).toFixed(1)}:1` }] },
    { id: 'deEss', icon: '🐍', name: 'De-esser (sifflantes)', fields: [
        { k: 'amount', label: 'Quantité', min: 0, max: 1, step: 0.05, fmt: fPct },
        { k: 'freqHz', label: 'Fréquence', min: 3000, max: 12000, step: 100, fmt: fHz }] },
    { id: 'sat', icon: '🔥', name: 'Saturation (chaleur)', fields: [
        { k: 'mix', label: 'Dosage', min: 0, max: 1, step: 0.05, fmt: fPct },
        { k: 'driveDb', label: 'Poussée', min: 0, max: 24, step: 0.5, fmt: fDb }] },
    { id: 'reverb', icon: '🏛️', name: 'Réverb', fields: [
        { k: 'send', label: 'Quantité', min: 0, max: 1, step: 0.01, fmt: fPct },
        { k: 'roomSize', label: 'Taille de la pièce', min: 0, max: 1, step: 0.05, fmt: fPct },
        { k: 'damping', label: 'Aigus amortis', min: 0, max: 1, step: 0.05, fmt: fPct },
        { k: 'preDelayMs', label: 'Pré-délai', min: 0, max: 200, step: 1, fmt: fMs }] },
    { id: 'delay', icon: '🔁', name: 'Écho (délai)', fields: [
        { k: 'send', label: 'Quantité', min: 0, max: 1, step: 0.01, fmt: fPct },
        { k: 'feedback', label: 'Répétitions', min: 0, max: 0.9, step: 0.05, fmt: fPct },
        { k: 'noteBeats', label: 'Durée', min: 0.25, max: 1, step: 0.25, fmt: fNote }] },
    { id: 'stereo', icon: '↔️', name: 'Placement stéréo', noToggle: true, fields: [
        { k: 'pan', label: 'Gauche / droite', min: -1, max: 1, step: 0.05, fmt: (v) => Math.abs(v) < 0.025 ? 'centre' : `${Math.round(Math.abs(v) * 100)} % ${v < 0 ? 'gauche' : 'droite'}` },
        { k: 'width', label: 'Largeur', min: 0, max: 1, step: 0.05, fmt: fPct }] },
];
const fxUi = { trackId: 0, open: '', rows: new Map() };
// Valeurs affichées d'un effet : ce que le moteur a appliqué, recouvert par les réglages à la main pas encore retraités.
const fxNow = (t, id) => ({ ...(t.processed?.report?.fx?.[id] || {}), ...(t.fx?.[id] || {}) });
const fxPre = (t, id) => t.processed?.report?.preset?.[id] || {};
function fxIsModified(t, id) {
    const o = t.fx?.[id], pre = fxPre(t, id);
    return !!o && Object.keys(o).some((k) => typeof o[k] === 'boolean' ? o[k] !== !!pre[k] : Math.abs(o[k] - (pre[k] ?? 0)) > 1e-6);
}
// Retire de t.fx ce qui est revenu à la valeur du pré-réglage (rien à garder ni à envoyer au moteur).
function fxPrune(t) {
    for (const id of Object.keys(t.fx || {})) {
        const pre = fxPre(t, id);
        for (const k of Object.keys(t.fx[id])) {
            const v = t.fx[id][k];
            if (k in pre && (typeof v === 'boolean' ? v === !!pre[k] : Math.abs(v - pre[k]) <= 1e-6)) delete t.fx[id][k];
        }
        if (!Object.keys(t.fx[id]).length) delete t.fx[id];
    }
}
function fxChanged(t, delayMs) {
    fxPrune(t);
    markDirty();
    fxRefresh();
    clearTimeout(t.fxTimer);
    t.fxTimer = setTimeout(() => { log('info', `« ${t.name} » : réglages d'effets changés → ${JSON.stringify(t.fx)}`); queueProcess(t); }, delayMs);
}
function fxSummary(def, v) {
    return def.fields.slice(0, 3).filter((f) => v[f.k] != null).map((f) => `${f.label.toLowerCase()} ${f.fmt(v[f.k])}`).join(' · ');
}
// Construit le tableau (force : piste ou effet ouvert changé) ; sinon met seulement à jour les valeurs affichées, pour
// ne pas détruire le curseur que la main est en train de tirer.
function renderFx(force = false) {
    const t = findTrack(state.selectedId);
    ui.fxResetAll.disabled = !(t && t.fx && Object.keys(t.fx).length);
    if (!t) { ui.fxTitle.textContent = 'Effets de la piste'; ui.fxList.replaceChildren(); fxUi.trackId = 0; return; }
    ui.fxTitle.textContent = `Effets de « ${t.name} »`;
    const rep = t.processed?.report;
    const msg = !t.take ? 'Pas encore de prise sur cette piste : enregistre ou importe une voix, ses effets s\'afficheront ici.'
        : t.noFx ? 'Piste « sans effet » : elle est jouée telle quelle (seul son volume est réglé). Clique le bouton FX de la piste pour lui appliquer les effets du style, puis règle-les ici.'
        : !rep?.fx ? 'Traitement de la piste en cours… les effets s\'affichent dès qu\'il est fini.'
        : `Pré-réglage : style ${styleName(t.styleId)}, ${roleLabel(t.roleId)}, ajusté à la prise.${t.status === 'busy' ? ' ⏳ Application des nouveaux réglages…' : ''} Coche / décoche un effet ; clique sur sa ligne pour ouvrir ses réglages. Chaque changement s'entend pendant « ▶ Mix ».`;
    ui.fxInfo.textContent = msg;
    if (!t.take || t.noFx || !rep?.fx) { ui.fxList.replaceChildren(); fxUi.trackId = 0; fxUi.rows.clear(); return; }
    if (!force && fxUi.trackId === t.id && fxUi.rows.size) { fxRefresh(); return; }
    fxUi.trackId = t.id; fxUi.rows.clear();
    ui.fxList.replaceChildren(...FX_DEFS.map((def) => {
        const open = fxUi.open === def.id;
        const chk = def.noToggle ? null : el('input', { type: 'checkbox', title: 'Effet allumé / éteint',
            onclick: (e) => e.stopPropagation(),
            onchange: (e) => { t.fx = t.fx || {}; t.fx[def.id] = { ...(t.fx[def.id] || {}), on: e.target.checked }; fxChanged(t, 50); } });
        const sum = el('span', { class: 'fxsum' }), mod = el('span', { class: 'fxmod', textContent: 'modifié', hidden: true });
        const line = el('div', { class: 'fxline', title: 'Ouvrir / fermer les réglages de cet effet',
            onclick: () => { fxUi.open = open ? '' : def.id; renderFx(true); } },
            chk, el('span', { class: 'fxicon', textContent: def.icon }), el('span', { class: 'fxname', textContent: def.name }), sum, mod);
        const inputs = new Map();
        const body = !open ? null : el('div', { class: 'fxbody' }, ...def.fields.map((f) => {
            const val = el('b'), pre = el('span', { class: 'pre' });
            const inp = el('input', { type: 'range', min: f.min, max: f.max, step: f.step,
                oninput: (e) => { t.fx = t.fx || {}; t.fx[def.id] = { ...(t.fx[def.id] || {}), [f.k]: Number(e.target.value) }; val.textContent = f.fmt(Number(e.target.value)); fxChanged(t, 350); },
                onchange: () => fxChanged(t, 30) });
            inputs.set(f.k, { inp, val, pre, f });
            return el('div', { class: 'fxfield' }, el('label', {}, el('span', { textContent: f.label }), val), inp, pre);
        }), el('button', { class: 'fxreset', textContent: '↺ Pré-réglage de cet effet', title: 'Efface les réglages faits à la main sur cet effet',
            onclick: () => { if (t.fx) delete t.fx[def.id]; fxChanged(t, 30); renderFx(true); } }));
        const row = el('div', { class: 'fxrow' + (open ? ' open' : '') }, line, body);
        row.dataset.fx = def.id;
        fxUi.rows.set(def.id, { row, chk, sum, mod, inputs, def });
        return row;
    }));
    fxRefresh();
}
function fxRefresh() {
    const t = findTrack(state.selectedId);
    if (!t || fxUi.trackId !== t.id) return;
    ui.fxResetAll.disabled = !(t.fx && Object.keys(t.fx).length);
    for (const [id, r] of fxUi.rows) {
        const v = fxNow(t, id), pre = fxPre(t, id), on = r.def.noToggle ? true : !!v.on;
        if (r.chk && document.activeElement !== r.chk) r.chk.checked = on;
        r.row.classList.toggle('off', !on);
        r.sum.textContent = on ? fxSummary(r.def, v) : 'éteint';
        r.mod.hidden = !fxIsModified(t, id);
        for (const { inp, val, pre: preEl, f } of r.inputs.values()) {
            if (document.activeElement !== inp) inp.value = v[f.k] ?? f.min;
            val.textContent = v[f.k] != null ? f.fmt(v[f.k]) : '—';
            preEl.textContent = pre[f.k] != null ? `pré-réglage : ${f.fmt(pre[f.k])}` : '';
        }
    }
}
ui.fxResetAll.addEventListener('click', () => {
    const t = findTrack(state.selectedId);
    if (!t) return;
    t.fx = {};
    log('info', `« ${t.name} » : tous les effets remis au pré-réglage`);
    fxChanged(t, 30);
    renderFx(true);
});
// Lecture « Mix » en cours quand une piste vient d'être retraitée : son nouveau son remplace l'ancien à la position
// courante (volume de la piste ramené à 0 en 30 ms, échange, remonté en 30 ms), sans arrêter la lecture.
async function liveRefresh(t, token) {
    const p = state.player;
    if (!p || p.mode !== 'mix' || token !== t.token || !t.processed || !findTrack(t.id)) return;
    try {
        await ensureBalance();
        if (state.player !== p || token !== t.token) return;
        liveGains();
        swapTrackSource(p, t);
        log('info', `« ${t.name} » : nouveau réglage appliqué pendant la lecture`);
    } catch (err) { log('error', `« ${t.name} » : échange pendant la lecture impossible : ${err.message}`); }
}
function swapTrackSource(p, t) {
    const ctx = audioContext(), n = p.nodes.find((x) => x.key === t.id), a = trackAudio(t, p.mode);
    if (!n || !a) return;   // piste absente de cette lecture (finie avant le point de départ) : rien à échanger
    const now = ctx.currentTime, at = now + 0.03, pos = p.fromSec + (at - p.t0), g = n.gain.gain;
    const src = ctx.createBufferSource();
    src.buffer = makeBuffer(a.left, a.right);
    src.connect(n.gain);
    g.cancelScheduledValues(now); g.setValueAtTime(g.value, now); g.linearRampToValueAtTime(0, at);
    try { n.src.stop(at); } catch (_) { /* déjà arrêtée */ }
    const off = pos - t.take.startSec;
    if (off < 0) src.start(at - off, 0);
    else if (off < src.buffer.duration) src.start(at, off);
    g.setValueAtTime(0, at);
    g.linearRampToValueAtTime(audible(t) ? dbg(trackGainDb(t, p.mode)) : 0, at + 0.03);
    n.src = src;
    n.swaps = (n.swaps || 0) + 1;
}

// Équilibre automatique (moteur) : gain par piste pour « Mix ». Les faders s'ajoutent ensuite (non comptés ici).
async function ensureBalance() {
    if (!state.balanceDirty && state.balance) return state.balance;
    await state.jobs;
    const list = state.tracks.filter((t) => t.take && !t.mute);
    if (list.length === 0) { state.balance = { gains: new Map(), items: new Map() }; state.balanceDirty = false; return state.balance; }
    const sr = list[0].take.sampleRate;
    const tracks = list.map((t) => {
        const L = t.processed ? t.processed.left : t.take.mono, R = t.processed ? t.processed.right : t.take.mono;
        return { key: t.id, left: L.slice(), right: R.slice(), startSec: t.take.startSec, roleId: t.roleId, volumeDb: 0 };
    });
    const leadStyle = state.tracks.find((t) => t.roleId === 'lead')?.styleId || list[0].styleId;
    const r = await call('balance', {
        instruL: state.instru ? state.instru.left.slice() : null, instruR: state.instru ? state.instru.right.slice() : null,
        sampleRate: sr, styleId: leadStyle, tracks,
    });
    const gains = new Map(), items = new Map();
    for (const it of r.report.tracks) { gains.set(it.key, it.gainDb); items.set(it.key, it); }
    state.balance = { gains, items, report: r.report };
    state.balanceDirty = false;
    log('info', `Équilibre : voix / instru ${r.report.vocalGainDb.toFixed(1)} dB` + (r.report.report ? ` ; ${r.report.report.replace(/\n/g, ' | ')}` : ''));
    for (const t of state.tracks) updateRow(t);
    if (!state.player) restMeters();
    return state.balance;
}

// ------------------------------------------------------------------ lecture
const dbg = (db) => Math.pow(10, db / 20);
function audible(obj) {
    const anySolo = state.instruTrack.solo || state.tracks.some((t) => t.solo);
    return !obj.mute && (!anySolo || obj.solo);
}
// Gain final d'une piste (dB) : équilibre auto (Mix seulement) + fader.
function trackGainDb(t, mode) {
    // Mix : équilibre calculé sur les pistes traitées. Brut + « Égaliser » : équilibre calculé sur les prises brutes
    // (mêmes règles par type, aucun effet). Brut sans « Égaliser » : la prise telle quelle.
    const auto = mode === 'mix' ? (state.balance?.gains.get(t.id) ?? 0)
        : (rawLevelOn() ? (state.balanceRaw?.gains.get(t.id) ?? 0) : 0);
    return auto + t.volumeDb;
}
function trackAudio(t, mode) {
    if (!t.take) return null;
    if (mode === 'mix' && t.processed) return { left: t.processed.left, right: t.processed.right };
    return { left: t.take.mono, right: t.take.mono };
}
function stopPlayback() {
    const p = state.player;
    if (!p) return;
    for (const n of p.nodes) { try { n.src.stop(); } catch (_) { /* déjà arrêté */ } }
    cancelAnimationFrame(p.raf);
    state.player = null;
    drawMeter(ui.meterOut, 0, 0);
    for (const r of ui.tracks.querySelectorAll('.track')) if (r._meter && !(state.rec && r.dataset.id === String(state.armedId))) drawMeter(r._meter, 0, 0);
    restMeters();
}
// Témoin de saturation de la sortie : si ce qui part vers la carte son dépasse le maximum (1,0), le son est écrêté
// (craquements). Compté pendant la lecture, affiché en rouge dans la barre de lecture, noté dans le journal.
const clipWatch = { n: 0, maxDb: -120, mode: '' };
function clipReset(mode) { clipWatch.n = 0; clipWatch.maxDb = -120; clipWatch.mode = mode; ui.clipInfo.hidden = true; }
function clipCheck(peak) {
    if (peak < 1.0) return;
    const db = 20 * Math.log10(peak);
    if (clipWatch.n === 0) log('warn', `Sortie saturée pendant la lecture (${clipWatch.mode}) : crête +${db.toFixed(1)} dB au-dessus du maximum`);
    ++clipWatch.n; clipWatch.maxDb = Math.max(clipWatch.maxDb, db);
    ui.clipInfo.hidden = false;
    ui.clipInfo.textContent = `⚠ sortie saturée ×${clipWatch.n} (+${clipWatch.maxDb.toFixed(1)} dB)`;
}
// Lecture en direct : une source par piste (gain + vumètre), puis un limiteur de sécurité commun.
// exceptId : piste en cours d'enregistrement (pas rejouée). startAt : instant (ctx) du début, par défaut tout de suite.
function play(mode, fromSec = state.playFromSec, { exceptId = 0, startAt = 0 } = {}) {
    stopPlayback();
    const ctx = audioContext();
    const t0 = startAt || ctx.currentTime + 0.05;
    // Aucun traitement sur la sortie (ni compresseur ni limiteur) : l'instru sort telle qu'elle a été importée. Si la
    // somme instru + voix dépasse le maximum, seul le volume général baisse (gain pur, sans effet sur le son).
    const master = ctx.createGain();
    const head = headroomGain(mode, exceptId, ctx.sampleRate);
    master.gain.value = head.gain;
    master.connect(ctx.destination);
    const outAn = ctx.createAnalyser(); outAn.fftSize = 1024; master.connect(outAn);
    const nodes = [];
    const addSource = (key, left, right, startSec, gainDb, meterEl) => {
        const end = startSec + left.length / ctx.sampleRate;
        if (end <= fromSec) return;
        const src = ctx.createBufferSource();
        src.buffer = makeBuffer(left, right);
        const g = ctx.createGain(); g.gain.value = dbg(gainDb);
        const an = ctx.createAnalyser(); an.fftSize = 1024;
        src.connect(g); g.connect(master); g.connect(an);
        if (startSec >= fromSec) src.start(t0 + (startSec - fromSec), 0);
        else src.start(t0, fromSec - startSec);
        const tr = key ? state.tracks.find((x) => x.id === key) : null;
        nodes.push({ key, src, gain: g, an, meterEl, hold: 0, holdUntil: 0, mark: tr && mode === 'mix' ? mixLevelDb(tr) : null });
    };
    if (state.instru && audible(state.instruTrack))
        addSource(0, state.instru.left, state.instru.right, 0, state.instruTrack.volumeDb, rowOf(0)?._meter);
    for (const t of state.tracks) {
        if (t.id === exceptId || !audible(t)) continue;
        const a = trackAudio(t, mode);
        if (a) addSource(t.id, a.left, a.right, t.take.startSec, trackGainDb(t, mode), rowOf(t.id)?._meter);
    }
    const player = { mode, nodes, t0, fromSec, raf: 0, outAn, headDb: head.db, master, exceptId };
    clipReset(mode === 'mix' ? 'Mix' : 'Brut');
    state.player = player;
    const buf = new Float32Array(1024);
    const peakOf = (an) => { an.getFloatTimeDomainData(buf); let p = 0; for (let i = 0; i < buf.length; ++i) p = Math.max(p, Math.abs(buf[i])); return p; };
    const total = songSeconds();
    const tick = () => {
        if (state.player !== player) return;
        const pos = fromSec + Math.max(0, ctx.currentTime - t0);
        setPlayhead(Math.min(pos, total));
        const now = performance.now();
        for (const n of nodes) {
            if (!n.meterEl) continue;
            const p = peakOf(n.an);
            if (p >= n.hold || now > n.holdUntil) { n.hold = p; n.holdUntil = now + 1500; }
            drawMeter(n.meterEl, p, n.hold, n.mark);
        }
        const outPeak = peakOf(outAn);
        clipCheck(outPeak);
        drawMeter(ui.meterOut, outPeak, 0);
        if (pos > total + 0.2 && !state.rec) { stopPlayback(); state.playFromSec = 0; setPlayhead(0); return; }
        player.raf = requestAnimationFrame(tick);
    };
    player.raf = requestAnimationFrame(tick);
    return player;
}
// Volume général : 1 (rien) tant que la somme jouée ne dépasse pas -0,3 dBFS ; sinon baisse pure de ce qu'il faut.
function headroomGain(mode, exceptId, sr) {
    const mix = renderPlayed(mode, exceptId, sr);
    let peak = 0;
    for (let i = 0; i < mix.left.length; ++i) { const a = Math.abs(mix.left[i]), b = Math.abs(mix.right[i]); if (a > peak) peak = a; if (b > peak) peak = b; }
    const ceil = Math.pow(10, -0.3 / 20);
    const gain = peak > ceil ? ceil / peak : 1;
    const db = 20 * Math.log10(gain);
    if (gain < 1) log('info', `Volume général baissé de ${(-db).toFixed(1)} dB (crête de la somme ${(20 * Math.log10(peak)).toFixed(1)} dBFS) : aucun effet sur le son de l'instru`);
    return { gain, db, peakDb: 20 * Math.log10(peak + 1e-12) };
}
// Fader / muet / solo pendant la lecture : gains mis à jour en direct.
function liveGains() {
    const p = state.player;
    if (!p) return;
    for (const n of p.nodes) {
        if (n.key === 0) { n.gain.gain.value = audible(state.instruTrack) ? dbg(state.instruTrack.volumeDb) : 0; continue; }
        const t = findTrack(n.key);
        if (t) n.gain.gain.value = audible(t) ? dbg(trackGainDb(t, p.mode)) : 0;
    }
    // Le volume général (marge contre la saturation) dépend de ce qui est écouté : il était calculé une seule fois au
    // lancement. Lecture lancée avec une piste en solo, puis solo retiré (ou piste réactivée, curseur monté) pendant
    // la lecture → la somme dépassait le maximum et la sortie saturait (craquements quand le niveau monte).
    // Recalcul 120 ms après le dernier changement, appliqué en douceur.
    clearTimeout(liveGains.timer);
    liveGains.timer = setTimeout(() => {
        const q = state.player;
        if (!q || q !== p || !q.master) return;
        const ctx = audioContext(), head = headroomGain(q.mode, q.exceptId, ctx.sampleRate);
        if (Math.abs(head.db - q.headDb) > 0.05) {
            q.master.gain.setTargetAtTime(head.gain, ctx.currentTime, 0.03);
            log('info', `Volume général ajusté pendant la lecture : ${head.db.toFixed(1)} dB (avant ${q.headDb.toFixed(1)} dB)`);
            q.headDb = head.db;
        }
    }, 120);
}
function onMuteSolo() {
    state.balanceDirty = true;   // une piste muette ne compte pas dans l'équilibre
    liveGains();
    refreshAudibility();
    markDirty();
}
// « Tout écouter » : retire tous les muets et solos.
function listenAll() {
    state.instruTrack.mute = state.instruTrack.solo = false;
    for (const t of state.tracks) t.mute = t.solo = false;
    renderTracks();
    onMuteSolo();
    setStatus('Toutes les pistes sont écoutées.');
}
// Bouton « ⚖ Égaliser » : volumes égalisés sur le son BRUT, sans aucun effet. Mêmes règles que le Mix (voix principales
// toutes au même niveau, backs / ambiance à leur place selon leur type, voix par rapport à l'instru), mais mesuré sur
// les prises telles quelles. Le résultat (un gain par piste) sert à la lecture « ▶ Brut » ; rien n'est modifié dans
// les sons. state.rawLevelOn : égalisation demandée (gardée avec le projet) ; state.balanceRaw : gains calculés pour
// les pistes d'une signature donnée (recalculés si les pistes ont changé).
const rawLevelOn = () => !!state.rawLevelOn;
const rawSig = () => state.tracks.filter((t) => t.take && !t.mute).map((t) => `${t.id}:${t.roleId}:${t.take.audioId}:${t.take.startSec.toFixed(3)}`).join('|') + `#${state.instru?.audioId || ''}`;
const rawLevelFresh = () => !!state.balanceRaw && state.balanceRaw.sig === rawSig();
async function ensureRawBalance(onStep = null) {
    const list = state.tracks.filter((t) => t.take && !t.mute);
    const sig = rawSig();
    if (state.balanceRaw && state.balanceRaw.sig === sig) return state.balanceRaw;
    if (list.length === 0) { state.balanceRaw = { gains: new Map(), items: new Map(), sig }; return state.balanceRaw; }
    const sr = list[0].take.sampleRate;
    const tracks = list.map((t) => ({ key: t.id, left: t.take.mono.slice(), right: t.take.mono.slice(), startSec: t.take.startSec, roleId: t.roleId, volumeDb: 0 }));
    const leadStyle = state.tracks.find((t) => t.roleId === 'lead')?.styleId || list[0].styleId;
    onStep?.(`mesure de ${list.length} piste(s)…`);
    const r = await call('balance', {
        instruL: state.instru ? state.instru.left.slice() : null, instruR: state.instru ? state.instru.right.slice() : null,
        sampleRate: sr, styleId: leadStyle, tracks,
    });
    const gains = new Map(), items = new Map();
    for (const it of r.report.tracks) { gains.set(it.key, it.gainDb); items.set(it.key, it); }
    state.balanceRaw = { gains, items, report: r.report, sig };
    log('info', `Volumes égalisés (brut, sans effet) : voix / instru ${r.report.vocalGainDb.toFixed(1)} dB ; ` +
        list.map((t) => `${t.name} ${gains.get(t.id) >= 0 ? '+' : ''}${(gains.get(t.id) ?? 0).toFixed(1)} dB`).join(', '));
    return state.balanceRaw;
}
function refreshLevelBtn() {
    const on = rawLevelOn(), fresh = on && rawLevelFresh();
    ui.levelBtn.classList.toggle('on', fresh);
    ui.levelBtn.classList.toggle('stale', on && !fresh);
    ui.levelBtn.textContent = fresh ? '⚖ Égalisé ✓' : on ? '⚖ Égaliser (à refaire)' : '⚖ Égaliser';
}
// Appui : lance l'égalisation (ou la refait si les pistes ont changé) ; appui quand c'est déjà égalisé : volumes d'origine.
async function levelRaw() {
    if (rawLevelOn() && rawLevelFresh()) {
        state.rawLevelOn = false;
        log('info', 'Égalisation retirée : volumes d\'origine en lecture brute');
        setStatus('Égalisation retirée : « ▶ Brut » joue de nouveau les prises avec leurs volumes d\'origine.');
    } else {
        const list = state.tracks.filter((t) => t.take && !t.mute);
        if (!list.length) { setStatus('Rien à égaliser : aucune piste avec une prise.'); return; }
        ui.levelBtn.disabled = true; ui.levelBtn.textContent = '⚖ Égalisation…';
        const t0 = performance.now();
        try {
            setStatus(`Égalisation des volumes sur le son brut (aucun effet) : mesure de ${list.length} piste(s)…`);
            const b = await ensureRawBalance();
            state.rawLevelOn = true;
            // Résultat annoncé piste par piste (type, niveau mesuré, réglage de volume).
            for (const t of list) {
                const g = b.gains.get(t.id) ?? 0, it = b.items.get(t.id);
                setStatus(`Égalisation : « ${t.name} » (${roleLabel(t.roleId)}) ${it?.lufs > -90 ? it.lufs.toFixed(1) + ' LUFS' : 'silence'} → volume ${g >= 0 ? '+' : ''}${g.toFixed(1)} dB`);
                updateRow(t);
                await new Promise((r) => setTimeout(r, 180));
            }
            setStatus(`Volumes égalisés sur ${list.length} piste(s) en ${((performance.now() - t0) / 1000).toFixed(1)} s, sans aucun effet : chaque piste est à son niveau selon son type. Écoute avec « ▶ Brut ».`);
        } catch (err) { setStatus('Égalisation impossible : ' + err.message); log('error', 'Égalisation : ' + err.message); }
        finally { ui.levelBtn.disabled = false; }
    }
    refreshLevelBtn();
    for (const t of state.tracks) updateRow(t);
    if (state.player?.mode === 'raw') liveGains();
    markDirty();
}
async function startPlay(mode) {
    try {
        if (mode === 'mix') { setStatus('Équilibre des pistes…'); await ensureBalance(); }
        else if (rawLevelOn()) { setStatus('Égalisation des volumes (sans effet)…'); await ensureRawBalance(); refreshLevelBtn(); }
        const p = play(mode);
        const head = p.headDb < -0.05 ? ` Volume général −${(-p.headDb).toFixed(1)} dB pour ne pas saturer (instru intacte).` : '';
        setStatus((mode === 'mix'
            ? 'Lecture du mix : instru d\'origine, intacte + chaque piste traitée (style et type), équilibrées.'
            : rawLevelOn() ? 'Lecture brute, volumes égalisés : aucune piste n\'est modifiée (aucun effet), seul son volume est réglé selon son type.'
            : 'Lecture brute : instru d\'origine + prises sans effet, volumes d\'origine. « ⚖ Égaliser » règle les volumes sans ajouter d\'effet.') + head);
    } catch (err) { setStatus('Lecture impossible : ' + err.message); log('error', err.message); }
}
ui.playBtn.addEventListener('click', () => startPlay('mix'));
ui.playRawBtn.addEventListener('click', () => startPlay('raw'));
ui.levelBtn.addEventListener('click', levelRaw);
ui.stopPlayBtn.addEventListener('click', () => { stopPlayback(); setStatus('Lecture arrêtée.'); });

// Ce que la page joue (somme instru + pistes avec leurs gains), sur la grille du morceau : référence pour retirer de
// la prise tout ce que le micro capte des haut-parleurs (instru ET voix déjà enregistrées).
function renderPlayed(mode, exceptId, sr) {
    const n = Math.ceil(songSeconds() * sr) + sr;
    const L = new Float32Array(n), R = new Float32Array(n);
    const add = (left, right, startSec, gainDb) => {
        const g = dbg(gainDb), o = Math.round(startSec * sr);
        for (let i = 0; i < left.length && o + i < n; ++i) { L[o + i] += left[i] * g; R[o + i] += right[i] * g; }
    };
    if (state.instru && audible(state.instruTrack)) add(state.instru.left, state.instru.right, 0, state.instruTrack.volumeDb);
    for (const t of state.tracks) {
        if (t.id === exceptId || !audible(t)) continue;
        const a = trackAudio(t, mode);
        if (a) add(a.left, a.right, t.take.startSec, trackGainDb(t, mode));
    }
    return { left: L, right: R };
}

// ------------------------------------------------------------------ instru, démo
async function loadInstruFile(file) {
    if (!file) return;
    try {
        setStatus('Lecture du fichier…');
        const buf = await decodeFile(file);
        const { left, right } = channels(buf);
        await setInstru(left, right, buf.sampleRate, file.name);
        setStatus(`Instru analysée : ${state.instru.analysis.key}, ${state.instru.analysis.bpm.toFixed(1)} BPM. Arme une piste (●) puis REC.`);
    } catch (err) { setStatus('Instru illisible : ' + err.message); log('error', err.message); }
}
async function setInstru(left, right, sampleRate, name) {
    stopPlayback();
    state.instru = { left, right, sampleRate, seconds: left.length / sampleRate, name, audioId: `i${Date.now().toString(36)}` };
    state.balanceDirty = true;
    markDirty();
    setStatus('Analyse de l\'instru (tonalité, tempo, structure)…');
    const r = await call('analyze', { left: left.slice(), right: right.slice(), sampleRate });
    state.instru.analysis = r;
    const secs = (r.sections || []).map((s) => `${s.label} ${fmt(s.start)}–${fmt(s.end)}`).join(' · ');
    log('info', `Instru : ${name} · ${fmt(state.instru.seconds)} · ${r.key} · ${r.bpm.toFixed(1)} BPM · ${r.lufs.toFixed(1)} LUFS · crête ${r.peakDb.toFixed(1)} dBFS` + (secs ? ` · ${secs}` : ''));
    renderTracks();
    reprocessAll();   // la gamme et le tempo de l'instru servent au traitement des voix
}
// Démo : instru et voix synthétiques du moteur sur deux pistes (principale + back), pour essayer sans fichier.
async function loadDemo() {
    try {
        const ctx = audioContext();
        setStatus('Fabrication de la démo (instru La mineur 100 BPM + deux voix)…');
        const bars = 16;
        const i = await call('demoInstru', { sampleRate: ctx.sampleRate, bars });
        await setInstru(i.left, i.right, ctx.sampleRate, 'Instru de démo');
        const v = await call('demoVoice', { sampleRate: ctx.sampleRate, bars });
        const lead = state.tracks.find((t) => t.roleId === 'lead' && !t.take) || addTrack('lead', 'Voix principale');
        addTake(lead, { mono: v.left, sampleRate: ctx.sampleRate, startSec: 0, note: 'voix de démo, légèrement fausse exprès' });
        let back = state.tracks.find((t) => t !== lead && !t.take);
        if (!back) back = addTrack('manual_back', 'Seconde voix');
        back.roleId = 'manual_back';
        addTake(back, { mono: v.left.slice(), sampleRate: ctx.sampleRate, startSec: 0, note: 'même voix de démo, en back' });
        renderTracks();
        queueProcess(lead); queueProcess(back);
        setStatus(`Démo prête : ${state.instru.analysis.key}, ${state.instru.analysis.bpm.toFixed(1)} BPM, deux pistes voix (principale + back) en traitement.`);
    } catch (err) { setStatus('Démo impossible : ' + err.message); log('error', err.message); }
}

// ------------------------------------------------------------------ ajout de piste, import d'une voix
ui.addTrackBtn.addEventListener('click', () => {
    const t = addTrack(ui.addRole.value);
    state.armedId = t.id;
    state.selectedId = t.id;
    renderTracks();
    setStatus(`Piste « ${t.name} » ajoutée (${roleLabel(t.roleId)}) et armée : REC pour enregistrer dessus.`);
});
async function importVoice(t, file) {
    if (!file) return;
    try {
        setStatus(`Import sur « ${t.name} »…`);
        const buf = await decodeFile(file);
        t.status = 'isolating'; updateRow(t);
        const isoRes = await maybeIsolate(toMono(buf), buf.sampleRate);
        addTake(t, { mono: isoRes.mono, sampleRate: buf.sampleRate, startSec: 0, note: `${file.name} · ${isoRes.note}` });
        renderTracks();
        setStatus(`Voix importée sur « ${t.name} » : ${isoRes.note}. Traitement par son style…`);
        queueProcess(t);
    } catch (err) { t.status = 'error'; updateRow(t); setStatus('Voix illisible : ' + err.message); log('error', err.message); }
}
// ------------------------------------------------------------------ audio
function audioContext() {
    if (!state.ctx) {
        // ?svRate=48000 : fréquence imposée (essais : la plupart des téléphones et des PC sont à 48 kHz, la CI à 44,1 kHz).
        const forced = Number(new URLSearchParams(location.search).get('svRate'));
        state.ctx = new (window.AudioContext || window.webkitAudioContext)({ latencyHint: 'interactive', ...(forced > 0 ? { sampleRate: forced } : {}) });
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
// Niveau de la piste au Mix (sonie mesurée là où elle chante + gain d'équilibre + curseur), en LUFS : même valeur pour
// toutes les pistes d'un même type une fois équilibrées. null tant que l'équilibre n'est pas calculé.
function mixLevelDb(t) {
    if (!state.balance || state.balanceDirty) return null;
    const it = state.balance.items?.get(t.id), g = state.balance.gains.get(t.id);
    if (!it || g == null || !(it.lufs > -90)) return null;
    return it.lufs + g + t.volumeDb;
}
// mark (dB, facultatif) : repère bleu = niveau de la piste au Mix ; aligné d'une piste à l'autre quand elles sont égales.
function drawMeter(canvas, peak, hold, mark = null) {
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
    if (mark != null && Number.isFinite(mark)) { g.fillStyle = '#4cc9f0'; g.fillRect(x(mark) - 2, 0, 4, h); }
    canvas._mark = mark;
}
// Vumètres au repos : barre vide + repère de niveau au Mix (visible sans lancer la lecture).
function restMeters() {
    for (const t of state.tracks) { const m = rowOf(t.id)?._meter; if (m && !(state.rec && t.id === state.armedId)) drawMeter(m, 0, 0, mixLevelDb(t)); }
}
// ------------------------------------------------------------------ prise
// Capture micro : AudioWorklet dans le même graphe que l'instru → place de la prise connue à l'échantillon près.
// Aucun traitement du navigateur (ni annulation d'écho, ni réduction de bruit, ni gain auto) : c'est le moteur qui
// retire ensuite l'instru captée par le micro (haut-parleurs) et qui mesure le décalage réel (latence aller-retour).
async function ensureRecorderWorklet(ctx) {
    if (!state.workletReady) {
        await ctx.audioWorklet.addModule('./recorder-worklet.js');
        state.workletReady = true;
    }
}
// Latence annoncée par le navigateur (sortie + traitement + entrée), utilisée seulement si aucune musique n'est captée
// (casque) : sinon le décalage est mesuré sur la prise elle-même.
function announcedLatencySec(ctx, track) {
    const out = (ctx.outputLatency || 0) + (ctx.baseLatency || 0);
    let inp = 0;
    try { inp = track?.getSettings?.().latency || 0; } catch (_) { /* non fourni */ }
    return out + inp;
}


// REC sur la piste armée. On entend l'instru et les autres pistes (mix) ; tout ce qui est joué sert de référence pour
// le retirer de la prise si le micro le capte (haut-parleurs), puis l'IA retire le reste (musique extérieure, bruits).
// Explication et marche à suivre pour chaque refus d'accès au micro (noms d'erreur standard de getUserMedia).
function micErrorMessage(err) {
    const android = /Android/i.test(navigator.userAgent), ios = /iPhone|iPad/i.test(navigator.userAgent);
    switch (err?.name) {
        case 'NotAllowedError':
        case 'PermissionDeniedError':
        case 'SecurityError':
            return 'accès au micro refusé. Touche le cadenas (ou ⓘ) à gauche de l\'adresse > Autorisations > Micro > Autoriser, puis recharge la page.'
                + (android ? ' Si c\'est déjà autorisé : Paramètres du téléphone > Applications > Chrome > Autorisations > Micro > Autoriser.' : '')
                + (ios ? ' Sur iPhone : Réglages > Safari > Micro > Autoriser.' : '');
        case 'NotFoundError':
        case 'DevicesNotFoundError':
            return 'aucun micro trouvé : branche un micro (ou un casque avec micro) puis réessaie.';
        case 'NotReadableError':
        case 'TrackStartError':
        case 'AbortError':
            return 'le micro est déjà utilisé par une autre application (appel, dictaphone, autre onglet, logiciel StudioVoix PC…) : ferme-la puis réessaie.';
        case 'OverconstrainedError':
            return 'le micro refuse les réglages demandés (' + (err.constraint || '?') + ').';
        case 'TypeError':
            return 'le navigateur ne donne pas accès au micro sur cette page (page non sécurisée ou navigateur trop ancien).';
        default:
            return (err?.name ? err.name + ' : ' : '') + (err?.message || String(err));
    }
}
// Ouvre le micro sans traitement du navigateur ; si l'appareil refuse ces réglages (certains téléphones), second essai
// avec les réglages par défaut du navigateur (annulation d'écho / réduction de bruit possibles), signalé.
async function openMic() {
    if (!navigator.mediaDevices?.getUserMedia) { const e = new Error('getUserMedia absent'); e.name = 'TypeError'; throw e; }
    try {
        if (navigator.permissions?.query) {
            const p = await navigator.permissions.query({ name: 'microphone' }).catch(() => null);
            if (p) log('info', `Autorisation du micro (navigateur) : ${p.state}`);
        }
    } catch (_) { /* information seulement */ }
    try {
        return { stream: await navigator.mediaDevices.getUserMedia({
            audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1 },
        }), fallback: false };
    } catch (err) {
        log('error', `Micro : ${err.name || 'erreur'} : ${err.message || ''}`);
        if (!['NotReadableError', 'OverconstrainedError', 'AbortError', 'TrackStartError'].includes(err.name)) throw err;
        log('warn', 'Micro : second essai avec les réglages par défaut du navigateur');
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        return { stream, fallback: true };
    }
}

ui.recBtn.addEventListener('click', async () => {
    let step = 'ouverture du micro';
    let mic = null;
    try {
        let t = findTrack(state.armedId);
        if (!t) { t = addTrack(state.tracks.some((x) => x.roleId === 'lead') ? ui.addRole.value : 'lead'); state.armedId = t.id; renderTracks(); }
        const ctx = audioContext();
        step = 'chargement de l\'enregistreur';
        await ensureRecorderWorklet(ctx);
        // L'IA n'est PAS préparée pendant la prise (téléchargement et calcul lourds : la prise saccadait sur téléphone).
        step = 'équilibre des pistes';
        await ensureBalance();   // ce qu'on entend pendant la prise = le mix des autres pistes
        // Micro ouvert juste avant la lecture (comme avant : le faux micro des essais démarre à l'ouverture).
        try { mic = await openMic(); }
        catch (err) {
            setStatus('Micro indisponible : ' + micErrorMessage(err));
            log('error', `Micro indisponible (${err.name || '?'}) : ${err.message || err} ; navigateur : ${navigator.userAgent}`);
            return;
        }
        const stream = mic.stream;
        const track = stream.getAudioTracks()[0];
        log('info', `Micro ouvert : « ${track?.label || 'sans nom'} »` + (mic.fallback ? ' (réglages par défaut du navigateur : traitement possible)' : '')
                    + ` ; réglages ${JSON.stringify(track?.getSettings?.() || {})}`);
        step = 'branchement du micro';
        const src = ctx.createMediaStreamSource(stream);
        const rec = new AudioWorkletNode(ctx, 'studiovoix-recorder', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1] });
        const sink = ctx.createGain(); sink.gain.value = 0;   // le nœud doit être relié à la sortie pour tourner ; muet
        src.connect(rec).connect(sink).connect(ctx.destination);
        const row = rowOf(t.id);
        if (row?._meter) startMeter(src, row._meter);
        const chunks = [];
        let firstFrame = -1;
        rec.port.onmessage = (e) => {
            if (e.data.type === 'chunk') {
                if (firstFrame < 0) firstFrame = e.data.frame;
                chunks.push(e.data.data);
            } else if (e.data.type === 'peak') {
                livePeak(t, e.data);
            } else if (e.data.type === 'done') {
                finishRecording({ t, stream, src, rec, sink, chunks, firstFrame, track, meterEl: row?._meter });
            }
        };
        // Compte à rebours AVANT la musique (clics seuls), puis la lecture démarre à la position choisie.
        const bpm = state.instru?.analysis?.bpm || 100;
        const bars = Number(ui.countIn.value || 0);
        const countSec = bars * 4 * 60 / bpm;
        const t0 = ctx.currentTime + 0.15;
        for (let i = 0; i < bars * 4; ++i) {
            const o = ctx.createOscillator(), g = ctx.createGain();
            const tt = t0 + i * 60 / bpm;
            o.frequency.value = i % 4 === 0 ? 1500 : 1000;
            g.gain.setValueAtTime(0.25, tt); g.gain.exponentialRampToValueAtTime(0.001, tt + 0.05);
            o.connect(g).connect(ctx.destination); o.start(tt); o.stop(tt + 0.06);
        }
        const songStart = t0 + countSec, fromSec = state.playFromSec;
        state.rec = { node: rec, songStartCtx: songStart, fromSec, sampleRate: ctx.sampleRate, trackId: t.id, mode: 'mix', micFallback: mic.fallback,
                      inLatency: Number(track?.getSettings?.().latency) || 0, total: songSeconds() };
        liveStart(t);
        play('mix', fromSec, { exceptId: t.id, startAt: songStart });
        setStatus((bars > 0 ? `Enregistrement sur « ${t.name} »… ${bars} mesure(s) de clics à ${bpm.toFixed(0)} BPM, puis la musique : chante.`
                            : `Enregistrement sur « ${t.name} »… chante.`) + ' Stop pour finir.');
        ui.recBtn.disabled = true; ui.recBtn.classList.add('on'); ui.stopBtn.disabled = false;
        log('info', `REC sur « ${t.name} » (${roleLabel(t.roleId)}) depuis ${fromSec.toFixed(2)} s ; latence annoncée ${(announcedLatencySec(ctx, track) * 1000).toFixed(0)} ms (sortie ${((ctx.outputLatency || 0) * 1000).toFixed(0)}, traitement ${((ctx.baseLatency || 0) * 1000).toFixed(0)})`);
    } catch (err) {
        mic?.stream.getTracks().forEach((x) => x.stop());
        setStatus(`REC impossible (${step}) : ${err.message || err}`);
        log('error', `REC impossible (${step}) : ${err.name || ''} ${err.message || err}`);
        ui.recBtn.disabled = false; ui.recBtn.classList.remove('on');
    }
});
ui.stopBtn.addEventListener('click', () => {
    if (state.rec?.node) state.rec.node.port.postMessage('stop');
    stopPlayback();
    ui.stopBtn.disabled = true;
});
async function finishRecording({ t, stream, src, rec, sink, chunks, firstFrame, track, meterEl }) {
    const info = state.rec;
    try {
        const ctx = audioContext();
        const fallback = announcedLatencySec(ctx, track);
        stream.getTracks().forEach((x) => x.stop());
        try { src.disconnect(); rec.disconnect(); sink.disconnect(); } catch (_) { /* déjà déconnecté */ }
        if (meterEl) stopMeter(meterEl);
        const total = chunks.reduce((n, c) => n + c.length, 0);
        if (total === 0 || firstFrame < 0) throw new Error('aucun échantillon reçu du micro');
        const raw = new Float32Array(total);
        let o = 0;
        for (const c of chunks) { raw.set(c, o); o += c.length; }
        const rawMic = raw.slice();   // micro tel quel (pour comparer avec la prise nettoyée : « Micro brut »)
        const sr = info.sampleRate;
        // Temps du morceau au moment où le premier échantillon a été écrit (négatif pendant les clics).
        const recOffsetSec = firstFrame / sr - info.songStartCtx + info.fromSec;
        setStatus('Nettoyage de la prise (musique des haut-parleurs captée par le micro, décalage)…');
        const ref = renderPlayed(info.mode, t.id, sr);
        const r = await call('cleanTake', {
            rec: raw, instruL: ref.left, instruR: ref.right, sampleRate: sr, recOffsetSec, fallbackLatencySec: fallback,
        }, [raw.buffer, ref.left.buffer, ref.right.buffer]);
        const rep = r.report;
        const nudge = Number(ui.latencyMs.value || 0) / 1000;   // ajustement fin manuel (0 par défaut)
        let startSec = rep.startSec - nudge;
        let mono = r.left;
        let rawCut = rawMic.subarray(0, mono.length);
        if (startSec < 0) {   // ce qui précède le début du morceau (clics, attente) est coupé
            const cut = Math.min(mono.length, Math.round(-startSec * sr));
            mono = mono.slice(cut);
            rawCut = rawCut.subarray(cut);
            startSec = 0;
        }
        t.status = 'isolating'; updateRow(t);
        const isoRes = await maybeIsolate(mono, sr);
        mono = isoRes.mono;
        const lat = `${Math.round(rep.latencyMs)} ms ${rep.latencyMeasured ? 'mesuré' : 'annoncé (casque)'}`;
        const bleed = rep.bleedDetected
            ? `musique captée ${rep.bleedBeforeDb.toFixed(0)} dB → retirée (${rep.bleedAfterDb.toFixed(0)} dB)`
            : 'aucune musique captée (casque)';
        const note = `${bleed} · ${isoRes.note} · décalage ${lat}, compensé` + (info.micFallback ? ' · ⚠ micro ouvert avec les réglages du navigateur (traitement possible)' : '');
        info.trackId = -1;   // fin de la forme d'onde en direct : la piste se redessine avec la prise nettoyée
        addTake(t, { mono, sampleRate: sr, startSec, note, raw: rawCut.slice() });
        log('info', `Prise sur « ${t.name} » : ${rep.describe} ; début ${startSec.toFixed(3)} s ; ${isoRes.note}`);
        renderTracks();
        setStatus(`Prise enregistrée sur « ${t.name} » : voix seule, calée sur la musique (${note}). Traitement par son style…`);
        queueProcess(t);
    } catch (err) { if (info) info.trackId = -1; setStatus('Prise impossible : ' + err.message); log('error', err.message); t.status = t.take ? 'raw' : 'vide'; updateRow(t); }
    state.rec = null;
    ui.recBtn.classList.remove('on');
    refreshButtons();
}

// ------------------------------------------------------------------ export
// Export : instru + pistes audibles (traitées, équilibrées, faders), limiteur -1 dBTP du moteur, WAV 16 bits.
ui.exportBtn.addEventListener('click', async () => {
    try {
        ui.exportBtn.disabled = true;
        setStatus('Export : équilibre des pistes, somme, limiteur…');
        await ensureBalance();
        const sr = state.instru?.sampleRate || state.tracks.find((t) => t.take)?.take.sampleRate || audioContext().sampleRate;
        const mix = renderPlayed('mix', 0, sr);
        const n = Math.ceil(songSeconds() * sr);
        // Pas de limiteur : l'instru reste telle quelle ; si la somme dépasse -0,3 dBFS, gain pur sur tout le mix.
        const L = mix.left.subarray(0, n), R = mix.right.subarray(0, n);
        let peak = 0;
        for (let i = 0; i < n; ++i) { const a = Math.abs(L[i]), b = Math.abs(R[i]); if (a > peak) peak = a; if (b > peak) peak = b; }
        const ceil = Math.pow(10, -0.3 / 20), g = peak > ceil ? ceil / peak : 1;
        if (g < 1) for (let i = 0; i < n; ++i) { L[i] *= g; R[i] *= g; }
        const wav = encodeWav16(L, R, sr);
        const r = { report: { lufs: NaN, limiterGrDb: 0, gainDb: 20 * Math.log10(g) } };
        const a = document.createElement('a');
        a.href = URL.createObjectURL(new Blob([wav], { type: 'audio/wav' }));
        a.download = 'StudioVoix-mix.wav';
        document.body.appendChild(a); a.click(); a.remove();
        const nTracks = state.tracks.filter((t) => t.take && audible(t)).length;
        const gtxt = r.report.gainDb < -0.05 ? `volume général −${(-r.report.gainDb).toFixed(1)} dB pour ne pas saturer` : 'volume d\'origine';
        log('info', `Export : ${nTracks} piste(s) voix + instru intacte (aucun limiteur), crête ${(20 * Math.log10(peak + 1e-12)).toFixed(1)} dBFS, ${gtxt}`);
        setStatus(`WAV exporté (16 bits, ${sr} Hz) : instru intacte + ${nTracks} piste(s) voix, ${gtxt}.`);
    } catch (err) { setStatus('Export impossible : ' + err.message); log('error', err.message); }
    refreshButtons();
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

// Vumètre du micro pendant la prise (sur l'en-tête de la piste armée).
function startMeter(node, canvas) {
    const an = audioContext().createAnalyser();
    an.fftSize = 1024;
    node.connect(an);
    const data = new Float32Array(an.fftSize);
    let hold = 0, holdUntil = 0;
    const tick = () => {
        an.getFloatTimeDomainData(data);
        let peak = 0;
        for (let i = 0; i < data.length; ++i) peak = Math.max(peak, Math.abs(data[i]));
        const now = performance.now();
        if (peak >= hold || now > holdUntil) { hold = peak; holdUntil = now + 1500; }
        drawMeter(canvas, peak, hold);
        canvas._raf = requestAnimationFrame(tick);
    };
    stopMeter(canvas);
    canvas._raf = requestAnimationFrame(tick);
}
function stopMeter(canvas) { if (canvas._raf) cancelAnimationFrame(canvas._raf); canvas._raf = 0; drawMeter(canvas, 0, 0); }

// Vitesse mesurée de cet appareil (ms par morceau d'IA, par modèle), gardée d'une visite à l'autre : sert à annoncer
// la durée d'une séparation avant de la lancer.
function sepSpeedLoad() { try { return JSON.parse(localStorage.getItem('sv-sep-speed') || '{}'); } catch { return {}; } }
function sepSpeedSave(key, ms) {
    const sp = sepSpeedLoad();
    sp[key] = sp[key] ? 0.8 * sp[key] + 0.2 * ms : ms;
    try { localStorage.setItem('sv-sep-speed', JSON.stringify(sp)); } catch (e) { log('warn', `vitesse non gardée : ${e.message}`); }
}
const fmtLong = (sec) => sec >= 3600 ? `${Math.floor(sec / 3600)} h ${String(Math.round((sec % 3600) / 60)).padStart(2, '0')}` : `${Math.max(1, Math.round(sec / 60))} min`;
function sepEstimate() {
    if (!ui.sepEst) return;
    if (!state.instru || state.separating) { ui.sepEst.textContent = ''; return; }
    const chunks = Math.ceil(state.instru.seconds * 44100 / Math.floor((1 - SEP_OVERLAP) * 1024 * 255)) + 1;
    const sp = sepSpeedLoad();
    const keys = ['voc', ...(ui.sepLeadBack.checked ? ['kara'] : []), ...(ui.sepAmbiance.checked ? ['reverb'] : [])];
    if (!sp.voc) { ui.sepEst.textContent = `Durée : environ ${chunks} morceaux de calcul par étape ; le temps exact s'affiche après le 1er morceau (puis il est retenu pour cet appareil).`; return; }
    const dn = ui.sepDenoise.checked ? 2 : 1;   // finition soignée : deux calculs par morceau
    const ms = dn * keys.reduce((a, k) => a + (sp[k] || sp.voc) * chunks * (k === 'kara' ? 0.8 : 1), 0);   // backs : passages sans voix sautés
    const fast = sp.voc * chunks;
    ui.sepEst.textContent = `Durée estimée sur cet appareil : ~${fmtLong(ms / 1000)} (${keys.length} étape${keys.length > 1 ? 's' : ''})` +
        (keys.length > 1 ? ` — plus rapide : décocher « Voix principale / backs » → ~${fmtLong(fast / 1000)} (instru + voix seulement).` : '.') +
        ` Garde la page ouverte, écran allumé.`;
}
function refreshButtons() {
    sepEstimate();
    const anyTake = state.tracks.some((t) => t.take);
    ui.recBtn.disabled = !state.ready || !!state.rec;
    ui.addTrackBtn.disabled = !state.ready;
    const demo = document.getElementById('demoBtn');
    if (demo) demo.disabled = !state.ready;
    ui.playBtn.disabled = !(state.instru || anyTake);
    ui.playRawBtn.disabled = !(state.instru || anyTake);
    ui.levelBtn.disabled = !anyTake || !state.ready;
    refreshLevelBtn();
    ui.exportBtn.disabled = !(anyTake || state.instru);
    ui.stemsBtn.disabled = !(anyTake || state.instru);
    ui.finalMixBtn.disabled = !state.ready || !(anyTake || state.instru) || !!state.rec;
    ui.sepBtn.disabled = !state.ready || !state.instru || !!state.rec || state.isolating;
}

// ------------------------------------------------------------------ « Séparer » une chanson en pistes
// Chanson avec voix posée sur la piste Instru → IA (modèles MDX-Net, isolate.js) :
//  1) voix = modèle « voix » ; instru = chanson − voix (là où personne ne chante, l'instru est l'original : pas de trou) ;
//  2) backs = modèle « karaoké » appliqué aux voix ; voix principale = voix − backs ;
//  3) (expérimental) ambiance = modèle « réverb » appliqué à la voix principale ; voix sèche = voix principale − ambiance ;
//  4) voix principale coupée par chanteur s'ils alternent (empreinte de voix, singers.js).
// Chaque partie arrive sur sa piste avec son type, « sans effet » (déjà produite), prête pour « Mixer la chanson ».
async function resampleStereo(L, R, fromSr, toSr) {
    if (fromSr === toSr) return { left: L.slice(), right: R.slice() };
    const t0 = performance.now();
    const left = await resampleSincAsync(L, fromSr, toSr), right = await resampleSincAsync(R, fromSr, toSr);
    log('info', `rééchantillonnage ${fromSr} → ${toSr} Hz (sinc) : ${(L.length / fromSr).toFixed(0)} s de son en ${Math.round(performance.now() - t0)} ms`);
    return { left, right };
}
// Réglages de calcul de « Séparer » : recouvrement des morceaux et saut des morceaux sans signal (les passages sans
// voix à l'étape backs ne passent pas dans l'IA). ?svSepOverlap=… pour les mesures A/B.
const SEP_OVERLAP = (() => { const v = parseFloat(new URLSearchParams(location.search).get('svSepOverlap')); return Number.isFinite(v) ? v : 0.25; })();
const SEP_OPTS = { voc: { overlap: SEP_OVERLAP, skipBelowDb: -60 }, kara: { overlap: SEP_OVERLAP, skipBelowDb: -45 }, reverb: { overlap: SEP_OVERLAP, skipBelowDb: -50 } };
const SEP_MODELS = { voc: 'voix / instru', kara: 'voix principale / backs', reverb: 'ambiance', spk: 'chanteurs' };
const rmsDbSt = (L, R) => { let e = 0; for (let i = 0; i < L.length; ++i) e += L[i] * L[i] + R[i] * R[i]; return 10 * Math.log10(e / Math.max(1, 2 * L.length) + 1e-20); };
const toMonoLR = (L, R) => { const m = new Float32Array(L.length); for (let i = 0; i < m.length; ++i) m[i] = 0.5 * (L[i] + R[i]); return m; };
// Progression visible de « Séparer » : étape, barre globale, temps écoulé / restant, roue qui tourne tant que le
// calcul vit, alerte si rien n'avance depuis longtemps. Mise à jour à chaque message du worker + chaque seconde.
const sepRun = { t0: 0, steps: 1, step: 1, label: '', frac: 0, last: 0, timer: 0 };
function sepSet(step, label, frac) {
    if (step != null) { sepRun.step = step; Object.assign(sepRun, { cDone: 0, cTotal: 0, cLast: performance.now() }); }
    if (label != null) sepRun.label = label;
    if (step != null && label != null) sepRun.stepLabel = label;   // étiquette de l'étape, reprise par les messages du worker
    if (frac != null) sepRun.frac = Math.min(1, Math.max(0, frac));
    sepRun.last = performance.now();
    sepRender();
}
// L'IA traite la chanson par morceaux d'environ 6 s ; un morceau = un seul calcul du modèle (15 s sur PC, bien plus
// sur téléphone), sans avancée intermédiaire possible. On affiche donc le compteur de morceaux, la durée mesurée par
// morceau, et entre deux morceaux une avancée estimée d'après cette durée (plafonnée à 90 % du morceau).
function sepChunk(done, total, skipped = false, global = false) {
    const now = performance.now();
    if (sepRun.seg && !global) {   // morceau d'une tranche → compte sur l'étape entière
        done = Math.min(sepRun.seg.n * sepRun.seg.per - 1, sepRun.seg.i * sepRun.seg.per + done);
        total = sepRun.seg.n * sepRun.seg.per;
    }
    const dt = now - (sepRun.cLast || now);
    if (skipped) sepRun.cSkipped = (sepRun.cSkipped || 0) + 1;   // morceau sans signal : instantané, ne fausse pas la durée mesurée
    else {
        sepRun.cDur = sepRun.cDur && done > 1 ? 0.6 * sepRun.cDur + 0.4 * dt : dt;   // 1er morceau : inclut le chargement
        if (done > 1 && sepRun.key) sepSpeedSave(sepRun.key, ui.sepDenoise.checked ? dt / 2 : dt);   // vitesse gardée pour un seul calcul par morceau
    }
    Object.assign(sepRun, { cDone: done, cTotal: total, cLast: now, last: now });
    if (/1er morceau en cours/.test(ui.sepSub.textContent)) ui.sepSub.textContent = ui.sepSub.textContent.replace(/, 1er morceau en cours…/, '');   // ne pas laisser croire qu'on est toujours au 1er
    if (done === total) sepRun.label = `${sepRun.stepLabel} — finition de l'étape…`;
    if (done === 1 || done === total) log('info', `Séparation : morceau ${done}/${total} en ${(dt / 1000).toFixed(1)} s (${iso.backend || '?'})`);
    sepRender();
}
function sepRender() {
    if (!state.separating) return;
    const now = performance.now();
    if (sepRun.cTotal && sepRun.cDone < sepRun.cTotal) {
        // Courbe qui ralentit sans jamais atteindre la fin du morceau : 60 % à la durée prévue, 82 % au double.
        const part = sepRun.cDur ? 0.95 * (1 - Math.exp(-(now - sepRun.cLast) / sepRun.cDur)) : 0;
        sepRun.frac = (sepRun.cDone + part) / sepRun.cTotal;
        sepRun.label = `${sepRun.stepLabel} — morceau ${sepRun.cDone + 1}/${sepRun.cTotal} de la chanson (~${Math.max(1, Math.round(sepRun.cDur / 1000))} s par morceau${iso.backend ? ', ' + iso.backend : ''})`;
    } else if (sepRun.isModel && sepRun.cTotal === 0 && !/téléchargement du/.test(sepRun.label)) {
        // 1er morceau (durée encore inconnue) : avancée lente estimée (au plus la moitié d'un morceau sur ~1 min),
        // pour montrer que le calcul vit ; la vraie mesure arrive avec le 1er morceau fini.
        if (now - sepRun.last > 3000) sepRun.label = `${sepRun.stepLabel} — 1er morceau en cours (démarrage de l'IA, le plus long)`;
        sepRun.frac = 0.02 * (1 - Math.exp(-(now - sepRun.last) / 30000));
    }
    const overall = Math.min(1, (sepRun.step - 1 + sepRun.frac) / sepRun.steps);
    const el = (now - sepRun.t0) / 1000, idle = (now - sepRun.last) / 1000;
    // « bloqué ? » seulement si le morceau dure bien plus que prévu (ou 60 s sans aucune mesure).
    const slow = sepRun.cDur ? idle > Math.max(20, 2.5 * sepRun.cDur / 1000) : idle > 60;
    const pct = (Math.floor(overall * 1000) / 10).toFixed(1).replace('.', ',');   // au dixième : bouge même sur une longue chanson
    ui.sepStep.textContent = sepRun.label;
    ui.sepPct.textContent = `${pct} %`;
    ui.sepBar.value = Math.round(overall * 1000);
    let t = `En cours depuis ${fmt(el)}`;
    if (overall > 0.04) t += ` — reste environ ${fmt(Math.max(1, el / overall - el))}`;
    if (slow) t += ` — plus lent que prévu, le calcul continue (dernier morceau fini il y a ${Math.round(idle)} s)`;
    ui.sepTime.textContent = t;
    ui.sepProg.classList.toggle('stalled', slow);
    document.title = `${pct} % — Séparation — StudioVoix`;
    sepKeepAliveUpdate(pct);
    setStatus(`Séparation en cours : ${sepRun.label} — ${pct} % (ne ferme pas la page)`);
}
function sepBegin(steps) {
    Object.assign(sepRun, { cSkipped: 0, cDone: 0, cTotal: 0, cDur: 0, cLast: performance.now(), cancel: false, t0: performance.now(), steps, step: 1, label: 'Préparation de la chanson…', frac: 0, last: performance.now() });
    sepRun.title = document.title;
    ui.sepProg.hidden = false; ui.sepSub.textContent = '';
    ui.sepBtn.textContent = '⏳ Séparation en cours…';
    ui.sepProg.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    sepRun.timer = setInterval(sepRender, 500);
    window.addEventListener('beforeunload', sepLeaveGuard);
    document.addEventListener('visibilitychange', sepVisibility);
    sepKeepAliveStart();
    sepWakeLock();
    sepRender();
}
function sepEnd() {
    clearInterval(sepRun.timer); sepRun.timer = 0;
    ui.sepProg.hidden = true; ui.sepProg.classList.remove('stalled');
    ui.sepBtn.textContent = '✂ Séparer la chanson';
    document.title = sepRun.title || 'StudioVoix Web';
    window.removeEventListener('beforeunload', sepLeaveGuard);
    document.removeEventListener('visibilitychange', sepVisibility);
    sepKeepAliveStop();
    if (sepRun.wake && !sepRun.wake.released) sepRun.wake.release().catch((e) => log('warn', `écran : ${e.message}`));
    sepRun.wake = null;
}
// Arrêt demandé entre deux étapes (hors calcul IA, que cancelIsolation coupe directement).
function sepCheck() { if (sepRun.cancel) { const e = new Error('séparation arrêtée'); e.skipped = true; throw e; } }
// Écran gardé allumé pendant « Séparer » : sur téléphone, l'écran qui s'éteint met la page en veille et le calcul
// s'arrête (ou la page est fermée par le système). Repris au retour sur la page (le navigateur le relâche en arrière-plan).
async function sepWakeLock() {
    if (!state.separating || !('wakeLock' in navigator) || document.visibilityState !== 'visible') return;
    try {
        sepRun.wake = await navigator.wakeLock.request('screen');
        log('info', 'écran gardé allumé pendant la séparation');
        sepRun.wake.addEventListener?.('release', () => log('info', 'écran : maintien allumé relâché'));
    } catch (e) { log('warn', `écran non gardé allumé (${e.message}) : garde la page ouverte au premier plan`); }
}
function sepVisibility() {
    if (!state.separating) return;
    if (document.visibilityState === 'visible') { if (!sepRun.wake || sepRun.wake.released) sepWakeLock(); }
    else log('info', `page en arrière-plan pendant la séparation : ${sepRun.keep && !sepRun.keep.paused ? 'son de veille actif, le calcul continue' : 'sans son de veille, le téléphone peut geler la page'}`);
}
// Travail en arrière-plan / écran éteint : Android gèle les pages muettes en arrière-plan (calcul arrêté), mais laisse
// tourner celles qui jouent du son (comme un lecteur de musique). Pendant « Séparer », la page joue donc en boucle un
// son de veille : 30 Hz à -46 dBFS (sous ce que reproduit un haut-parleur de téléphone, inaudible au casque à volume
// normal) et affiche la progression dans la notification multimédia (Media Session).
let keepAliveUrl = '';
function keepAliveWav() {
    if (keepAliveUrl) return keepAliveUrl;
    const sr = 8000, n = sr * 4, amp = Math.pow(10, -46 / 20) * 32767;
    const buf = new ArrayBuffer(44 + 2 * n), v = new DataView(buf);
    const str = (o, t) => { for (let i = 0; i < t.length; ++i) v.setUint8(o + i, t.charCodeAt(i)); };
    str(0, 'RIFF'); v.setUint32(4, 36 + 2 * n, true); str(8, 'WAVE'); str(12, 'fmt '); v.setUint32(16, 16, true);
    v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, sr, true); v.setUint32(28, 2 * sr, true);
    v.setUint16(32, 2, true); v.setUint16(34, 16, true); str(36, 'data'); v.setUint32(40, 2 * n, true);
    for (let i = 0; i < n; ++i) v.setInt16(44 + 2 * i, Math.round(amp * Math.sin(2 * Math.PI * 30 * i / sr)), true);   // 4 s = 120 périodes : boucle sans clic
    keepAliveUrl = URL.createObjectURL(new Blob([buf], { type: 'audio/wav' }));
    return keepAliveUrl;
}
function sepKeepAliveStart() {
    try {
        const a = sepRun.keep || (sepRun.keep = new Audio());
        a.src = keepAliveWav(); a.loop = true; a.volume = 1;
        a.play().then(() => log('info', 'arrière-plan : son de veille actif (la séparation continue écran éteint)'))
            .catch((e) => log('warn', `arrière-plan : son de veille refusé (${e.message}) : garde l'écran allumé`));
        if ('mediaSession' in navigator) {
            navigator.mediaSession.metadata = new MediaMetadata({ title: 'Séparation en cours', artist: 'StudioVoix', album: 'IA' });
            // « Pause » dans la notification : on relance le son de veille (sinon la page serait gelée et le calcul arrêté).
            navigator.mediaSession.setActionHandler('pause', () => { log('warn', 'pause demandée dans la notification : la séparation continue (Arrêter depuis la page)'); a.play().catch(() => {}); });
            navigator.mediaSession.setActionHandler('play', () => a.play().catch(() => {}));
        }
    } catch (e) { log('warn', `arrière-plan indisponible : ${e.message}`); }
}
function sepKeepAliveUpdate(pct) {
    if (!('mediaSession' in navigator) || !navigator.mediaSession.metadata) return;
    const now = performance.now();
    if (now - (sepRun.mediaAt || 0) < 4000) return;
    sepRun.mediaAt = now;
    try { navigator.mediaSession.metadata = new MediaMetadata({ title: `Séparation ${pct} %`, artist: 'StudioVoix', album: sepRun.label || 'IA' }); }
    catch (e) { /* métadonnées refusées : sans effet sur le calcul */ }
}
function sepKeepAliveStop() {
    try {
        if (sepRun.keep) { sepRun.keep.pause(); sepRun.keep.removeAttribute('src'); sepRun.keep.load(); }
        if ('mediaSession' in navigator) {
            navigator.mediaSession.metadata = null;
            navigator.mediaSession.setActionHandler('pause', null); navigator.mediaSession.setActionHandler('play', null);
        }
        log('info', 'arrière-plan : son de veille arrêté');
    } catch (e) { log('warn', `arrière-plan : ${e.message}`); }
}
function sepLeaveGuard(e) { e.preventDefault(); e.returnValue = ''; }   // quitter la page = calcul perdu : le navigateur demande
// Reprise fine : chaque étape est calculée par tranches de 40 s (+ 2 s de marge de chaque côté, fondu de 0,5 s entre
// tranches), et chaque tranche finie est gardée tout de suite (IndexedDB, magasin « meta », clés « sep:… »). Si le
// téléphone ferme la page (veille, mémoire), la relance reprend à la tranche en cours. Moins de mémoire aussi : l'IA ne
// voit jamais plus de 44 s à la fois. Une seule chanson gardée à la fois ; tout est effacé après réussite.
const SEG_CORE = 40 * 44100, SEG_MARGIN = 2 * 44100, SEG_FADE = Math.round(0.5 * 44100);
const SEP_PREFIX = 'sep:';
async function sepDb(fn) {
    const db = await openDb();
    try { return await fn(db); } finally { db.close(); }
}
async function sepCacheGet(id, part) {
    try {
        const c = await sepDb((db) => idb(db, 'meta', 'readonly', (st) => st.get(`${SEP_PREFIX}${id}:${part}`)));
        if (c && c.left?.length) return c;
    } catch (e) { log('warn', `reprise de la séparation indisponible : ${e.message}`); }
    return null;
}
async function sepCachePut(id, part, left, right) {
    try { await sepDb((db) => idb(db, 'meta', 'readwrite', (st) => st.put({ left, right }, `${SEP_PREFIX}${id}:${part}`))); }
    catch (e) { log('warn', `tranche non gardée pour la reprise (${e.message}) : une coupure obligerait à la refaire`); }
}
// Efface les tranches gardées (toutes, ou toutes sauf celles de la chanson keepId).
async function sepCacheClear(keepId = null) {
    try {
        await sepDb(async (db) => {
            const keys = await idb(db, 'meta', 'readonly', (st) => st.getAllKeys());
            const old = (keys || []).filter((k) => typeof k === 'string' && k.startsWith(SEP_PREFIX) && !(keepId && k.startsWith(`${SEP_PREFIX}${keepId}:`)));
            if (old.length) await idb(db, 'meta', 'readwrite', (st) => { for (const k of old) st.delete(k); });
            if (old.length) log('info', `reprise : ${old.length} tranche(s) d'une ancienne séparation effacée(s)`);
        });
    } catch (e) { log('warn', `nettoyage de la reprise : ${e.message}`); }
}
// Une étape IA complète, tranche par tranche, avec reprise. Même normalisation (crête du morceau entier) pour toutes
// les tranches, pour que l'IA voie le même niveau qu'en un seul bloc.
async function sepStep(cacheId, key, L, R, step, steps) {
    const n = L.length, nSeg = Math.max(1, Math.ceil(n / SEG_CORE));
    let peak = 0;
    for (let i = 0; i < n; ++i) { const a = Math.abs(L[i]), b = Math.abs(R[i]); if (a > peak) peak = a; if (b > peak) peak = b; }
    sepCheck();
    sepSet(step, `Étape ${step}/${steps} : ${SEP_MODELS[key]}`, 0);
    sepRun.isModel = true; sepRun.key = key;
    const chunkStep = Math.floor((1 - SEP_OVERLAP) * 1024 * 255);
    sepRun.seg = { i: 0, n: nSeg, per: Math.ceil((Math.min(n, SEG_CORE) + 2 * SEG_MARGIN + 2560 + 261120) / chunkStep) };
    log('info', `Séparation, étape ${step}/${steps} : ${SEP_MODELS[key]} — ${nSeg} tranche(s) de 40 s`);
    const outL = new Float32Array(n), outR = new Float32Array(n), wsum = new Float32Array(n);
    let reused = 0, secs = 0;
    for (let i = 0; i < nSeg; ++i) {
        sepCheck();
        const a = i * SEG_CORE, b = Math.min(n, a + SEG_CORE);
        const s0 = Math.max(0, a - SEG_MARGIN), s1 = Math.min(n, b + SEG_MARGIN);
        sepRun.seg.i = i;
        let y = await sepCacheGet(cacheId, `${key}#${i}`);
        if (y && y.left.length === s1 - s0) {
            ++reused;
            sepChunk((i + 1) * sepRun.seg.per, nSeg * sepRun.seg.per, true, true);   // reprise : avancée sans calcul
        } else {
            const r = await isoCall('isolate', { model: key, left: L.slice(s0, s1), right: R.slice(s0, s1), release: false, opts: { ...(SEP_OPTS[key] || {}), peak, denoise: ui.sepDenoise.checked } });
            iso.backend = r.backend; secs += r.seconds;
            y = { left: r.left, right: r.right };
            await sepCachePut(cacheId, `${key}#${i}`, y.left, y.right);
        }
        // Fondu entre tranches : poids 1 sur [a, b), rampes de 0,5 s dans les marges.
        for (let t = s0; t < s1; ++t) {
            let w = 1;
            if (t < a) w = (t - (a - SEG_FADE)) / SEG_FADE;
            else if (t >= b) w = (b + SEG_FADE - t) / SEG_FADE;
            if (w <= 0) continue;
            if (w > 1) w = 1;
            const j = t - s0;
            outL[t] += y.left[j] * w; outR[t] += y.right[j] * w; wsum[t] += w;
        }
    }
    for (let t = 0; t < n; ++t) { const w = wsum[t]; if (w > 0) { outL[t] /= w; outR[t] /= w; } }
    sepRun.seg = null;
    if (key !== 'voc') await isoCall('release', { model: key }).catch((e) => log('warn', `libération ${key} : ${e.message}`));
    log('info', `Séparation ${SEP_MODELS[key]} : ${nSeg} tranche(s), ${reused} reprise(s) sans calcul, ${secs.toFixed(1)} s de calcul sur ${iso.backend || '?'}`);
    return { left: outL, right: outR };
}
async function separateSong() {
    if (!state.instru) return;
    const comp = { voc: 1.021, kara: 1.065, reverb: 1.035 };   // = MODELS[*].compensate (isolate.js)
    const doKara = ui.sepLeadBack.checked, doRev = ui.sepAmbiance.checked, doSing = ui.sepSingers.checked;
    const steps = 1 + (doKara ? 1 : 0) + (doRev ? 1 : 0) + (doSing ? 1 : 0);
    const t0 = performance.now();
    stopPlayback();
    ui.sepBtn.disabled = true; state.isolating = true; state.separating = true;
    sepBegin(steps);
    try {
        const src = state.instru, sr = src.sampleRate;
        const song = await resampleStereo(src.left, src.right, sr, 44100);
        // 1) voix / instru
        const cacheId = `${src.audioId}|${SEP_OVERLAP}|${song.left.length}|${ui.sepDenoise.checked ? 'dn' : 'std'}`;
        await sepCacheClear(cacheId);   // une seule chanson gardée
        const v = await sepStep(cacheId, 'voc', song.left, song.right, 1, steps);
        const VL = v.left.map((x) => x * comp.voc), VR = v.right.map((x) => x * comp.voc);
        // L'instru est calculée plus bas, à la fréquence d'origine : morceau d'origine − voix (jamais rééchantillonnée).
        let leadL = VL, leadR = VR, backL = null, backR = null, ambL = null, ambR = null, step = 1;
        // 2) voix principale / backs
        if (doKara) {
            const k = await sepStep(cacheId, 'kara', VL, VR, ++step, steps);
            backL = k.left.map((x) => x * comp.kara); backR = k.right.map((x) => x * comp.kara);
            leadL = VL.map((x, i) => x - backL[i]); leadR = VR.map((x, i) => x - backR[i]);
            // Voix doublée / à plusieurs couches (vu sur de vrais morceaux) : le modèle classe toute la voix en « backs »
            // et il ne reste rien en voix principale. Dans ce cas la voix entière est gardée comme voix principale.
            const leadDb = rmsDbSt(leadL, leadR), backDb = rmsDbSt(backL, backR);
            if (leadDb < backDb - 12) {
                log('warn', `Séparation : voix principale presque vide (${leadDb.toFixed(1)} dB contre ${backDb.toFixed(1)} dB en backs) → toute la voix est gardée en voix principale (voix doublée ou en chœur)`);
                leadL = VL; leadR = VR; backL = null; backR = null;
            } else log('info', `Séparation : voix principale ${leadDb.toFixed(1)} dB, backs ${backDb.toFixed(1)} dB`);
        }
        // 3) ambiance (expérimental)
        if (doRev) {
            const rv = await sepStep(cacheId, 'reverb', leadL, leadR, ++step, steps);
            ambL = rv.left.map((x) => x * comp.reverb); ambR = rv.right.map((x) => x * comp.reverb);
            leadL = leadL.map((x, i) => x - ambL[i]); leadR = leadR.map((x, i) => x - ambR[i]);
        }
        // retour à la fréquence du projet
        sepCheck();
        sepRun.isModel = false;
        sepSet(null, 'Assemblage des pistes…', 1); sepRun.stepLabel = 'Assemblage des pistes';
        const back44 = async (L, R) => (L ? await resampleStereo(L, R, 44100, sr) : null);
        const vocSr = await back44(VL, VR), lead = await back44(leadL, leadR), backs = await back44(backL, backR), amb = await back44(ambL, ambR);
        const fit = (x) => { const o = new Float32Array(src.left.length); o.set(x.subarray(0, o.length)); return o; };
        // Instru = morceau d'origine − voix, à la fréquence d'origine : là où personne ne chante, c'est l'original au bit près.
        const vl = fit(vocSr.left), vr = fit(vocSr.right);
        const I = { left: src.left.map((x, i) => x - vl[i]), right: src.right.map((x, i) => x - vr[i]) };
        // 4) chanteurs
        const leadMono = fit(toMonoLR(lead.left, lead.right));
        let parts = [{ name: 'Voix principale (séparée)', mono: leadMono }], singersNote = '';
        if (doSing) {
            sepCheck();
            sepSet(steps, `Étape ${steps}/${steps} : repérage des chanteurs (empreinte de voix)`, 0);
            log('info', `Séparation, étape ${steps}/${steps} : chanteurs`);
            const embed = async (feats, frames) => (await isoCall('embed', { model: 'spk', feats, frames }, [feats.buffer])).emb;
            const res = await findSingers(leadMono, sr, embed, { onProgress: (d, t) => sepSet(null, null, d / Math.max(1, t)) });
            await isoCall('release', { model: 'spk' }).catch(() => {});
            singersNote = res.why;
            log('info', `Chanteurs : ${res.why}`);
            // Une piste par voix repérée (2, 3… autant qu'il y en a).
            if (res.singers >= 2) parts = Array.from({ length: res.singers }, (_, k) => ({ name: `Chanteur ${k + 1} (séparé)`, mono: keepPhrases(leadMono, sr, res.phrases, k) }));
        }
        // Pistes : l'instru séparée remplace la chanson (l'original reste gardé pour « Rétablir »).
        const original = state.instru.original || { left: src.left, right: src.right, name: src.name };
        state.instru.left = fit(I.left); state.instru.right = fit(I.right);
        state.instru.original = original;
        state.instru.name = original.name.replace(/\.[^.]+$/, '') + ' (instru séparée)';
        state.instru.audioId = `i${Date.now().toString(36)}`;
        const made = [];
        const mk = (name, roleId, mono) => {
            if (rmsDbSt(mono, mono) < -55) { log('info', `${name} : rien de repéré (sous -55 dBFS), pas de piste`); return; }
            const t = addTrack(roleId, name);
            t.noFx = true;
            t.locked = true;   // calée sur l'instru : pas de déplacement par accident
            t.styleId = state.tracks.find((x) => x.roleId === 'lead' && x !== t)?.styleId || t.styleId;
            addTake(t, { mono, sampleRate: sr, startSec: 0, note: 'séparée de la chanson', label: 'Séparée' });
            made.push(`${name} (${roleLabel(roleId)})`);
        };
        // pistes vides laissées par défaut au démarrage : retirées pour ne pas encombrer
        state.tracks = state.tracks.filter((t) => t.take || t.name !== 'Voix principale');
        for (const p of parts) mk(p.name, 'lead', p.mono);
        if (backs) mk('Backs (séparés)', 'manual_back', fit(toMonoLR(backs.left, backs.right)));
        if (amb) mk('Ambiance (séparée)', 'ambiance', fit(toMonoLR(amb.left, amb.right)));
        state.armedId = 0; state.balanceDirty = true;
        markDirty();
        renderTracks();
        const sec = (performance.now() - t0) / 1000;
        ui.sepInfo.textContent = `Séparée en ${fmt(sec)} : instru + ${made.length} piste(s) — ${made.join(', ') || 'aucune voix repérée'}` +
            (singersNote ? `\nChanteurs : ${singersNote}` : '') + `\nL'original est gardé : « Rétablir le morceau » pour revenir en arrière.`;
        log('info', `Séparation terminée en ${sec.toFixed(1)} s : ${made.join(', ')}`);
        sepCacheClear();
        setStatus(`Chanson séparée : instru seule sur la piste Instru, ${made.length} piste(s) de voix (sans effet, à leur type). « Mixer la chanson » quand tout est prêt.`);
    } catch (err) {
        if (err.skipped) { setStatus('Séparation arrêtée à la demande : rien n\'a été changé.'); ui.sepInfo.textContent = 'Séparation arrêtée : rien n\'a été changé.'; }
        else { setStatus('Séparation impossible : ' + err.message); ui.sepInfo.textContent = 'Séparation impossible : ' + err.message; log('error', 'Séparation : ' + err.message); }
    } finally {
        state.isolating = false; state.separating = false; iso.t0 = 0;
        sepEnd();
        refreshButtons();
    }
}
ui.sepBtn.addEventListener('click', separateSong);
for (const c of [ui.sepLeadBack, ui.sepAmbiance, ui.sepSingers, ui.sepDenoise]) c.addEventListener('change', sepEstimate);
ui.sepStopBtn.addEventListener('click', () => {
    if (!state.separating) return;
    if (!confirm('Arrêter la séparation ? Le calcul en cours est perdu, la chanson reste comme avant.')) return;
    log('warn', 'Séparation arrêtée par l\'utilisateur');
    sepRun.cancel = true;
    ui.sepStep.textContent = 'Arrêt en cours…';
    cancelIsolation();
});
function restoreOriginalSong() {
    const o = state.instru?.original;
    if (!o) return;
    if (!confirm('Rétablir le morceau d\'origine sur la piste Instru ? (les pistes séparées restent ; supprime-les si besoin)')) return;
    state.instru.left = o.left; state.instru.right = o.right; state.instru.name = o.name; state.instru.original = null;
    state.instru.audioId = `i${Date.now().toString(36)}`;
    state.balanceDirty = true; markDirty(); renderTracks();
    setStatus('Morceau d\'origine rétabli sur la piste Instru.');
}

// ------------------------------------------------------------------ mixage final (« Mixer la chanson »)
// Quand tout est enregistré : le moteur met chaque piste à sa place selon son type, soude les voix (bus voix), pose
// les voix sur l'instru (sonie visée par le style, creux de l'instru sous la voix si coché) puis masterise (cohésion,
// couleur du style, limiteur, sonie de la destination). Résultat : une seule chanson stéréo.
ui.finalMixBtn.addEventListener('click', async () => {
    try {
        stopPlayback();
        ui.finalMixBtn.disabled = true;
        setStatus('Mixage de la chanson : attente des traitements en cours…');
        await state.jobs;
        // Tout doit être en place : une piste encore brute (jamais traitée, ou réglage changé) est traitée d'abord.
        const pending = state.tracks.filter((t) => t.take && audible(t) && !t.noFx && (!t.processed || t.status === 'busy'));
        if (pending.length) {
            setStatus(`Mixage de la chanson : traitement d'abord de ${pending.map((t) => '« ' + t.name + ' »').join(', ')} (style et type)…`);
            for (const t of pending) if (!t.processed) queueProcess(t);
            await state.jobs;
        }
        const list = state.tracks.filter((t) => t.take && audible(t));
        if (!state.instru && !list.length) throw new Error('rien à mixer (ni instru ni prise)');
        const sr = state.instru?.sampleRate || list[0].take.sampleRate;
        const unprocessed = list.filter((t) => !t.processed && !t.noFx).map((t) => t.name);   // « sans effet » : brut voulu
        setStatus(`Mixage de la chanson : ${list.length} piste(s) voix + instru, mastering ${ui.finalTarget.selectedOptions[0].textContent}…`);
        const t0 = performance.now();
        const leadStyle = state.tracks.find((t) => t.roleId === 'lead')?.styleId || list[0]?.styleId || 'rap_conscient';
        const r = await call('finalMix', {
            instruL: state.instru && audible(state.instruTrack) ? state.instru.left.slice() : null,
            instruR: state.instru && audible(state.instruTrack) ? state.instru.right.slice() : null,
            sampleRate: sr, styleId: leadStyle, targetId: ui.finalTarget.value, duckingDb: ui.finalDuck.checked ? 2.5 : 0,
            tracks: list.map((t) => {
                const a = trackAudio(t, 'mix');
                return { key: t.id, left: a.left.slice(), right: a.right.slice(), startSec: t.take.startSec, roleId: t.roleId, volumeDb: t.volumeDb };
            }),
        });
        const rep = r.report;
        state.finalMix = { left: r.left, right: r.right, sampleRate: sr, report: rep, stale: false };
        const lines = rep.tracks.map((x) => {
            const t = findTrack(x.key);
            return `${t ? t.name : '#' + x.key} (${roleLabel(t?.roleId)}) : ${x.placeLu ? x.placeLu + ' LU sous la principale, ' : ''}${x.gainDb >= 0 ? '+' : ''}${x.gainDb.toFixed(1)} dB`;
        });
        ui.finalInfo.classList.remove('stale');
        ui.finalInfo.textContent =
            `Chanson mixée en ${((performance.now() - t0) / 1000).toFixed(1)} s — style ${rep.style}, ${rep.target} :\n` +
            `• Voix : ${lines.join(' · ') || 'aucune'}\n` +
            `• Voix soudées ensemble : compression ${rep.busGrDb.toFixed(1)} dB en moyenne${rep.busGrMaxDb != null ? `, ${rep.busGrMaxDb.toFixed(1)} dB au plus fort` : ''} (rattrapage +${rep.busMakeupDb.toFixed(1)} dB)\n` +
            `• Instru : ${rep.duckingDb > 0 ? `place faite à la voix (creux jusqu'à ${rep.duckingDb.toFixed(1)} dB vers 2,5 kHz quand la voix chante)` : 'telle quelle'}\n` +
            `• Mastering : couleur du style (graves ${rep.lowShelfDb >= 0 ? '+' : ''}${rep.lowShelfDb} dB, aigus ${rep.highShelfDb >= 0 ? '+' : ''}${rep.highShelfDb} dB), ` +
            `${rep.inputLufs.toFixed(1)} → ${rep.outputLufs.toFixed(1)} LUFS, crête ${rep.truePeakDb.toFixed(1)} dBTP, limiteur ${rep.limiterGrDb.toFixed(1)} dB` +
            (unprocessed.length ? `\n⚠ Pistes sans traitement (brutes) : ${unprocessed.join(', ')}` : '');
        ui.finalPlayRow.hidden = false;
        log('info', `Mixage final : ${rep.inputLufs.toFixed(1)} -> ${rep.outputLufs.toFixed(1)} LUFS, crête ${rep.truePeakDb.toFixed(1)} dBTP`);
        playFinal(state.playFromSec, true);
        setStatus('Chanson mixée, lecture en cours : « ▶ Avant mixage » pour comparer, puis « Exporter la chanson mixée ».');
    } catch (err) { setStatus('Mixage impossible : ' + err.message); log('error', 'Mixage final : ' + err.message); }
    refreshButtons();
});
function playFinal(fromSec = state.playFromSec, quiet = false) {
    const f = state.finalMix;
    if (!f) return;
    stopPlayback();
    const ctx = audioContext();
    const src = ctx.createBufferSource();
    src.buffer = makeBuffer(f.left, f.right);
    const outAn = ctx.createAnalyser(); outAn.fftSize = 1024;
    src.connect(ctx.destination); src.connect(outAn);
    const t0 = ctx.currentTime + 0.05;
    const from = Math.min(fromSec, Math.max(0, f.left.length / f.sampleRate - 0.5));
    src.start(t0, from);
    const player = { mode: 'final', nodes: [{ key: -2, src }], t0, fromSec: from, raf: 0, outAn };
    state.player = player;
    const buf = new Float32Array(1024);
    const tick = () => {
        if (state.player !== player) return;
        setPlayhead(from + ctx.currentTime - t0);
        outAn.getFloatTimeDomainData(buf);
        let p = 0; for (let i = 0; i < buf.length; ++i) p = Math.max(p, Math.abs(buf[i]));
        clipCheck(p);
        drawMeter(ui.meterOut, p, 0);
        player.raf = requestAnimationFrame(tick);
    };
    clipReset('Chanson mixée');
    player.raf = requestAnimationFrame(tick);
    src.onended = () => { if (state.player === player) { stopPlayback(); setStatus('Fin de la chanson mixée.'); } };
    if (!quiet) setStatus('Lecture de la chanson mixée' + (f.stale ? ' (⚠ le projet a changé depuis : re-mixe pour l\'avoir à jour)' : '') + '.');
}
ui.playFinalBtn.addEventListener('click', () => playFinal());
ui.playBeforeBtn.addEventListener('click', () => startPlay('mix'));
ui.exportFinalBtn.addEventListener('click', () => {
    const f = state.finalMix;
    if (!f) return;
    const wav = encodeWav16(f.left, f.right, f.sampleRate);
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([wav], { type: 'audio/wav' }));
    a.download = 'StudioVoix-chanson-mixee.wav';
    document.body.appendChild(a); a.click(); a.remove();
    log('info', `Export de la chanson mixée : ${f.report.outputLufs.toFixed(1)} LUFS, crête ${f.report.truePeakDb.toFixed(1)} dBTP`);
    setStatus(`Chanson mixée exportée (WAV 16 bits, ${f.sampleRate} Hz, ${f.report.outputLufs.toFixed(1)} LUFS).`);
});
ui.finalTarget.addEventListener('change', markDirty);
ui.finalDuck.addEventListener('change', markDirty);

// Export des pistes séparées : un WAV par piste audible (traitée et équilibrée comme dans le mix), même longueur.
ui.stemsBtn.addEventListener('click', async () => {
    try {
        ui.stemsBtn.disabled = true;
        setStatus('Export des pistes séparées…');
        await ensureBalance();
        const sr = state.instru?.sampleRate || state.tracks.find((t) => t.take)?.take.sampleRate || audioContext().sampleRate;
        const n = Math.ceil(songSeconds() * sr);
        const files = [];
        const stem = (name, left, right, startSec, gainDb) => {
            const L = new Float32Array(n), R = new Float32Array(n), g = dbg(gainDb), o = Math.round(startSec * sr);
            for (let i = 0; i < left.length && o + i < n; ++i) { L[o + i] = left[i] * g; R[o + i] = right[i] * g; }
            files.push({ name, wav: encodeWav16(L, R, sr) });
        };
        if (state.instru && audible(state.instruTrack)) stem('00-Instru', state.instru.left, state.instru.right, 0, state.instruTrack.volumeDb);
        state.tracks.forEach((t, i) => {
            const a = audible(t) ? trackAudio(t, 'mix') : null;
            if (a) stem(`${String(i + 1).padStart(2, '0')}-${t.name.replace(/[^\w\u00C0-\u017F-]+/g, '_')}`, a.left, a.right, t.take.startSec, trackGainDb(t, 'mix'));
        });
        for (const f of files) {
            const a = document.createElement('a');
            a.href = URL.createObjectURL(new Blob([f.wav], { type: 'audio/wav' }));
            a.download = `StudioVoix-${f.name}.wav`;
            document.body.appendChild(a); a.click(); a.remove();
            await new Promise((r) => setTimeout(r, 250));   // les navigateurs bloquent les rafales de téléchargements
        }
        log('info', `Export pistes séparées : ${files.map((f) => f.name).join(', ')}`);
        setStatus(`${files.length} piste(s) exportée(s) séparément (WAV 16 bits, ${sr} Hz, même longueur, à poser à 0:00).`);
    } catch (err) { setStatus('Export impossible : ' + err.message); log('error', err.message); }
    refreshButtons();
});

ui.allBtn.addEventListener('click', listenAll);
ui.skipIsoBtn.addEventListener('click', cancelIsolation);
// Barre d'espace : lecture du mix / arrêt (sauf dans un champ de saisie).
document.addEventListener('keydown', (e) => {
    if (e.code !== 'Space' || e.repeat || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(e.target.tagName)) return;
    e.preventDefault();
    if (state.rec) return;
    if (state.player) { stopPlayback(); setStatus('Lecture arrêtée.'); } else if (!ui.playBtn.disabled) startPlay('mix');
});

// ------------------------------------------------------------------ sauvegarde automatique (navigateur)
// Le projet (instru, prises, réglages des pistes) est gardé dans IndexedDB : rien n'est perdu si la page se ferme.
// Les sons sont écrits une seule fois (clé = audioId) ; les réglages à chaque changement (1 s après le dernier).
const DB_NAME = 'studiovoix', DB_VERSION = 1;
function openDb() {
    return new Promise((resolve, reject) => {
        if (!window.indexedDB) { reject(new Error('IndexedDB indisponible')); return; }
        const rq = indexedDB.open(DB_NAME, DB_VERSION);
        rq.onupgradeneeded = () => { const db = rq.result; db.createObjectStore('meta'); db.createObjectStore('audio'); };
        rq.onsuccess = () => resolve(rq.result);
        rq.onerror = () => reject(rq.error || new Error('ouverture IndexedDB impossible'));
    });
}
function idb(db, store, mode, fn) {
    return new Promise((resolve, reject) => {
        const tx = db.transaction(store, mode);
        const out = fn(tx.objectStore(store));
        tx.oncomplete = () => resolve(out && 'result' in out ? out.result : undefined);
        tx.onerror = () => reject(tx.error || new Error('IndexedDB : écriture refusée'));
        tx.onabort = () => reject(tx.error || new Error('IndexedDB : transaction annulée (espace plein ?)'));
    });
}
let saveTimer = 0, savedAudio = new Set();
function markDirty() {
    if (state.finalMix && !state.finalMix.stale) {
        state.finalMix.stale = true;
        ui.finalInfo.classList.add('stale');
        ui.finalInfo.textContent = '⚠ Le projet a changé depuis le mixage : clique « Mixer la chanson » pour le refaire. ' + ui.finalInfo.textContent;
    }
    if (!state.player && !state.restoring) restMeters();   // repères de niveau : effacés si l'équilibre n'est plus à jour
    if (ui.levelBtn) refreshLevelBtn();                     // « Égalisé ✓ » seulement tant que les pistes n'ont pas changé
    if (state.restoring) return;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => saveProject().catch((err) => {
        log('warn', 'Sauvegarde automatique impossible : ' + err.message);
        ui.saveInfo.textContent = '⚠ sauvegarde impossible';
    }), 1000);
}
async function saveProject() {
    const t0 = performance.now();
    const db = await openDb();
    const audio = [];
    if (state.instru) audio.push([state.instru.audioId + 'L', state.instru.left], [state.instru.audioId + 'R', state.instru.right]);
    for (const t of state.tracks) for (const k of t.takes) audio.push([k.audioId, k.mono]);
    const fresh = audio.filter(([id]) => !savedAudio.has(id));
    if (fresh.length) await idb(db, 'audio', 'readwrite', (st) => { for (const [id, data] of fresh) st.put(data, id); });
    for (const [id] of fresh) savedAudio.add(id);
    const meta = {
        version: 1, savedAt: Date.now(), nextTrackId: state.nextTrackId, armedId: state.armedId, rawLevelOn: !!state.rawLevelOn,
        instru: state.instru ? { audioId: state.instru.audioId, sampleRate: state.instru.sampleRate, name: state.instru.name } : null,
        instruTrack: state.instruTrack,
        tracks: state.tracks.map((t) => ({
            id: t.id, name: t.name, roleId: t.roleId, styleId: t.styleId, volumeDb: t.volumeDb, mute: t.mute, solo: t.solo, noFx: !!t.noFx, locked: !!t.locked, fx: t.fx || {},
            active: t.takes.indexOf(t.take),
            takes: t.takes.map((k) => ({ audioId: k.audioId, sampleRate: k.sampleRate, startSec: k.startSec, note: k.note || '', label: k.label })),
        })),
    };
    await idb(db, 'meta', 'readwrite', (st) => st.put(meta, 'project'));
    // Sons qui ne servent plus (piste supprimée, nouvelle instru) : effacés.
    const keep = new Set(audio.map(([id]) => id));
    const keys = await idb(db, 'audio', 'readonly', (st) => st.getAllKeys());
    const stale = (keys || []).filter((k) => !keep.has(k));
    if (stale.length) { await idb(db, 'audio', 'readwrite', (st) => { for (const k of stale) st.delete(k); }); for (const k of stale) savedAudio.delete(k); }
    db.close();
    ui.saveInfo.textContent = `Sauvegardé ${new Date().toLocaleTimeString()}`;
    log('info', `Projet sauvegardé dans le navigateur (${fresh.length} son(s) écrit(s), ${stale.length} effacé(s)) en ${Math.round(performance.now() - t0)} ms`);
}
async function restoreProject() {
    let db;
    try { db = await openDb(); } catch (err) { log('warn', 'Pas de sauvegarde possible : ' + err.message); ui.saveInfo.textContent = 'sauvegarde indisponible'; return false; }
    try {
        const meta = await idb(db, 'meta', 'readonly', (st) => st.get('project'));
        if (!meta || meta.version !== 1 || (!meta.instru && !meta.tracks?.some((t) => t.takes.length))) return false;
        state.restoring = true;
        const get = (id) => idb(db, 'audio', 'readonly', (st) => st.get(id));
        setStatus('Reprise du projet gardé dans le navigateur…');
        state.instruTrack = { ...state.instruTrack, ...meta.instruTrack };
        state.rawLevelOn = !!meta.rawLevelOn;   // « Égaliser » demandé : les gains sont recalculés à la première lecture brute
        state.nextTrackId = meta.nextTrackId;
        state.tracks = [];
        for (const m of meta.tracks) {
            const t = { id: m.id, name: m.name, roleId: m.roleId, styleId: m.styleId, volumeDb: m.volumeDb, mute: m.mute, solo: m.solo, noFx: !!m.noFx, fx: m.fx && typeof m.fx === 'object' ? m.fx : {}, locked: m.locked ?? !!m.noFx,   // anciens projets : pistes séparées verrouillées
                        take: null, takes: [], processed: null, status: 'vide', token: 0 };
            for (const k of m.takes) {
                const mono = await get(k.audioId);
                if (!(mono instanceof Float32Array)) { log('warn', `« ${m.name} » : ${k.label} introuvable dans la sauvegarde`); continue; }
                t.takes.push({ ...k, mono });
                savedAudio.add(k.audioId);
            }
            t.take = t.takes[m.active] || t.takes[t.takes.length - 1] || null;
            if (t.take) t.status = 'raw';
            state.tracks.push(t);
        }
        state.armedId = meta.armedId;
        if (meta.instru) {
            const L = await get(meta.instru.audioId + 'L'), R = await get(meta.instru.audioId + 'R');
            if (L instanceof Float32Array && R instanceof Float32Array) {
                await setInstru(L, R, meta.instru.sampleRate, meta.instru.name);
                state.instru.audioId = meta.instru.audioId;
                savedAudio.add(meta.instru.audioId + 'L'); savedAudio.add(meta.instru.audioId + 'R');
            } else log('warn', 'Instru introuvable dans la sauvegarde');
        }
        renderTracks();
        reprocessAll();
        const n = state.tracks.filter((t) => t.take).length;
        log('info', `Projet repris : ${meta.instru ? meta.instru.name : 'sans instru'}, ${state.tracks.length} piste(s), ${n} avec prise (sauvegarde du ${new Date(meta.savedAt).toLocaleString()})`);
        setStatus(`Projet repris (sauvegarde du ${new Date(meta.savedAt).toLocaleString()}) : ${state.tracks.length} piste(s), retraitement des prises…`);
        ui.saveInfo.textContent = 'Projet repris';
        return true;
    } catch (err) {
        log('error', 'Reprise du projet impossible : ' + err.message);
        return false;
    } finally { state.restoring = false; db.close(); }
}
ui.newBtn.addEventListener('click', async () => {
    if (!confirm('Nouveau projet : l\'instru et toutes les pistes du projet actuel seront effacées (exporte d\'abord si besoin). Continuer ?')) return;
    stopPlayback();
    state.instru = null;
    state.instruTrack = { volumeDb: 0, mute: false, solo: false };
    state.tracks = []; state.nextTrackId = 1; state.armedId = 0; state.selectedId = 0;
    state.balance = null; state.balanceDirty = true; state.playFromSec = 0;
    addTrack('lead', 'Voix principale');
    renderTracks();
    setPlayhead(0);
    await saveProject().catch((err) => log('warn', err.message));
    log('info', 'Nouveau projet');
    setStatus('Nouveau projet : importe une instru, arme une piste (●) puis REC.');
});

drawMeter(ui.meterOut, 0, 0);
setPlayhead(0);
setStatus('Chargement du moteur…');
window.__svSep = sepRun;   // tests : état de la séparation (son de veille, tranches)
window.__studiovoix = state;   // lecture seule par les tests de bout en bout (vérification des prises)
startWorker();
