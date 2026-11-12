// StudioVoix Web : studio multipiste. Micro et lecture par Web Audio, moteur C++ (WebAssembly) dans un Web Worker,
// isolation de la voix (IA) dans un second worker.
// Pistes : l'instru en haut (jouée telle quelle, jamais modifiée), puis autant de pistes voix que voulu. Chaque piste
// a son nom, son type (voix principale, back, ambiance, doublage…) et son style : sa prise est traitée par la chaîne
// du style réglée pour ce type et d'après la mesure de la prise ; le mix équilibre les pistes entre elles selon leur
// type (back -7 LU sous la principale, ambiance -14 LU…) puis l'ensemble des voix par rapport à l'instru.

const $ = (id) => document.getElementById(id);
const ui = {
    status: $('status'), log: $('log'), version: $('version'), tracks: $('tracks'), report: $('report'),
    recBtn: $('recBtn'), stopBtn: $('stopBtn'), playBtn: $('playBtn'), playRawBtn: $('playRawBtn'), stopPlayBtn: $('stopPlayBtn'),
    exportBtn: $('exportBtn'), meterOut: $('meterOut'), time: $('time'),
    addTrackBtn: $('addTrackBtn'), addRole: $('addRole'),
    countIn: $('countIn'), latencyMs: $('latencyMs'), isolateVoice: $('isolateVoice'), isolateInfo: $('isolateInfo'),
    useScale: $('useScale'), cleaning: $('cleaning'),
};

const state = {
    ctx: null,             // AudioContext (créé au premier geste)
    worker: null, ready: false, pending: new Map(), nextId: 1,
    styles: [], roles: [],
    // Instru : { left, right, sampleRate, seconds, name, analysis } ; réglages de piste à part (existe sans fichier).
    instru: null,
    instruTrack: { volumeDb: 0, mute: false, solo: false },
    // Pistes voix : { id, name, roleId, styleId, volumeDb, mute, solo, take: { mono, sampleRate, startSec, note } | null,
    //                 processed: { left, right, report, key } | null, status, token }
    tracks: [], nextTrackId: 1, selectedId: 0, armedId: 0,
    balance: null, balanceDirty: true,   // gains par piste (dB) calculés par le moteur pour « Mix »
    jobs: Promise.resolve(), busy: 0,    // traitements en file (un à la fois, dans l'ordre)
    player: null,                        // lecture en cours : { mode, nodes, t0, fromSec, raf }
    playFromSec: 0,
    rec: null, workletReady: false, isolating: false,
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
            if (state.tracks.length === 0) addTrack('lead', 'Voix principale');
            renderTracks();
            setStatus('Moteur prêt. Pose une instru (piste Instru), arme une piste (●) puis REC.');
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
function isoWorker() {
    if (iso.worker) return iso.worker;
    iso.worker = new Worker('./isolate-worker.js', { type: 'module' });
    iso.worker.onmessage = (e) => {
        const m = e.data;
        if (m.type === 'log') { log(m.level, '[isolation] ' + m.msg); return; }
        if (m.type === 'progress') {
            const pct = Math.round(100 * m.done / Math.max(1, m.total));
            ui.isolateInfo.textContent = m.stage === 'download'
                ? `Téléchargement du modèle IA (une seule fois) : ${pct} % de ${(m.total / 1e6).toFixed(0)} Mo`
                : `Isolation de la voix : ${pct} %` + (iso.backend ? ` (${iso.backend})` : '');
            if (state.isolating) setStatus(ui.isolateInfo.textContent);
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
function isoCall(cmd, payload = {}, transfer = []) {
    const w = isoWorker();
    return new Promise((resolve, reject) => {
        const id = iso.nextId++;
        iso.pending.set(id, { resolve, reject });
        w.postMessage({ id, cmd, ...payload }, transfer);
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
    const n = Math.max(1, Math.round(data.length * toSr / fromSr));
    const off = new OfflineAudioContext(1, n, toSr);
    const b = off.createBuffer(1, data.length, fromSr);
    b.copyToChannel(data, 0);
    const s = off.createBufferSource(); s.buffer = b; s.connect(off.destination); s.start();
    return (await off.startRendering()).getChannelData(0).slice();
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
// Applique l'isolation si la case est cochée ; en cas d'échec, garde la prise telle quelle et le dit.
async function maybeIsolate(mono, sr) {
    if (!ui.isolateVoice.checked) return { mono, note: 'isolation IA désactivée' };
    state.isolating = true;
    setStatus('Isolation de la voix (IA) : seule la voix est gardée…');
    try {
        const r = await isolateVoice(mono, sr);
        ui.isolateInfo.textContent = `Dernière isolation : ${r.seconds.toFixed(0)} s sur ${r.backend}`;
        return { mono: r.mono, note: `voix isolée par IA (${r.removedDb.toFixed(1)} dB d'autres sons retirés)`, isolated: r };
    } catch (err) {
        log('error', 'Isolation IA impossible : ' + err.message);
        ui.isolateInfo.textContent = 'Isolation IA impossible : ' + err.message;
        return { mono, note: `⚠ isolation IA impossible (${err.message}) : prise gardée sans elle` };
    } finally { state.isolating = false; }
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
        volumeDb: 0, mute: false, solo: false, take: null, processed: null, status: 'vide', token: 0,
    };
    state.tracks.push(t);
    if (!state.armedId) state.armedId = t.id;
    log('info', `Piste ajoutée : « ${t.name} » (${roleLabel(roleId)}, ${styleName(t.styleId)})`);
    return t;
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
    refreshButtons();
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
function toggles(obj, onChange) {
    const m = el('button', { class: 'tog m' + (obj.mute ? ' on' : ''), textContent: 'M', title: 'Muet',
        onclick: (e) => { e.stopPropagation(); obj.mute = !obj.mute; e.target.classList.toggle('on', obj.mute); onChange(); } });
    const s = el('button', { class: 'tog s' + (obj.solo ? ' on' : ''), textContent: 'S', title: 'Solo',
        onclick: (e) => { e.stopPropagation(); obj.solo = !obj.solo; e.target.classList.toggle('on', obj.solo); onChange(); } });
    const v = el('input', { type: 'range', class: 'vol', min: -24, max: 12, step: 0.5, value: obj.volumeDb, title: `Volume ${obj.volumeDb} dB`,
        oninput: (e) => { obj.volumeDb = Number(e.target.value); e.target.title = `Volume ${obj.volumeDb} dB`; liveGains(); } });
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
        el('div', { class: 'r' }, ...toggles(state.instruTrack, onMuteSolo)),
        el('div', { class: 'tinfo', textContent: info, title: 'Jouée telle quelle, jamais modifiée' }));
    const lane = el('div', { class: 'lane' }, el('canvas'), state.instru ? null : el('div', { class: 'empty', textContent: 'Importe l\'instru (MP3, WAV…) : elle va seule sur cette piste' }));
    lane.addEventListener('click', seekFromLane);
    row.append(head, lane);
    row._lane = lane;
    return row;
}
function trackRow(t) {
    const row = el('div', { class: 'track' + (t.id === state.selectedId ? ' sel' : '') + (t.id === state.armedId ? ' armed' : ''), 'data-id': String(t.id) });
    const arm = el('button', { class: 'arm' + (t.id === state.armedId ? ' on' : ''), textContent: '●', title: 'Armer : le prochain REC enregistre sur cette piste',
        onclick: (e) => { e.stopPropagation(); state.armedId = t.id; renderTracks(); } });
    const name = el('input', { type: 'text', class: 'name', value: t.name, title: 'Nom de la piste (libre)',
        onchange: (e) => { t.name = e.target.value.trim() || t.name; log('info', `Piste renommée : « ${t.name} »`); } });
    const role = el('select', { class: 'role', title: 'Type de piste : règle la chaîne (effets) et la place dans le mix' });
    fillRoleSelect(role, t.roleId);
    role.addEventListener('change', () => { t.roleId = role.value; log('info', `« ${t.name} » : type ${roleLabel(t.roleId)}`); queueProcess(t); });
    const style = el('select', { class: 'style', title: 'Style de mixage de cette voix' });
    fillStyleSelect(style, t.styleId);
    style.addEventListener('change', () => { t.styleId = style.value; log('info', `« ${t.name} » : style ${styleName(t.styleId)}`); queueProcess(t); });
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
        el('div', { class: 'r' }, ...toggles(t, onMuteSolo), el('span', { class: 'file' }, el('button', { textContent: 'Importer', title: 'Importer une voix sur cette piste' }), file)),
        info);
    const lane = el('div', { class: 'lane' }, el('canvas'), t.take ? null : el('div', { class: 'empty', textContent: 'Arme la piste (●) puis REC, ou importe une voix' }));
    lane.addEventListener('click', seekFromLane);
    row.append(head, lane);
    row._lane = lane;
    return row;
}
function badgeText(t) {
    if (t.status === 'busy') return 'traitement…';
    if (t.status === 'isolating') return 'isolation IA…';
    if (t.processed) return 'traitée';
    if (t.take) return 'brute';
    return 'vide';
}
function trackInfo(t) {
    const g = state.balance?.gains.get(t.id);
    const parts = [`${roleLabel(t.roleId)} · ${styleName(t.styleId)}`];
    if (t.take) parts.push(`prise ${fmt(t.take.mono.length / t.take.sampleRate)} à ${fmt(t.take.startSec)}`);
    if (g != null && !state.balanceDirty) parts.push(`mix ${g >= 0 ? '+' : ''}${g.toFixed(1)} dB`);
    if (t.take?.note) parts.push(t.take.note);
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
    if (t.id === state.selectedId) showReport(t);
    refreshButtons();
}
function selectTrack(id) {
    state.selectedId = id;
    for (const r of ui.tracks.querySelectorAll('.track')) r.classList.toggle('sel', r.dataset.id === String(id));
    const t = findTrack(id);
    if (t) showReport(t);
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
function drawLane(row, t) {
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
function drawAllLanes() {
    const ir = rowOf(0);
    if (ir) drawLane(ir, null);
    for (const t of state.tracks) { const r = rowOf(t.id); if (r) drawLane(r, t); }
}
window.addEventListener('resize', () => drawAllLanes());

function seekFromLane(e) {
    const r = e.currentTarget.getBoundingClientRect();
    const sec = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * songSeconds();
    state.playFromSec = sec;
    setPlayhead(sec);
    if (state.player) play(state.player.mode, sec);
}
function setPlayhead(sec) {
    ui.tracks.style.setProperty('--pos', `${(sec / songSeconds()) * 100}%`);
    ui.time.textContent = `${Math.floor(sec / 60)}:${(sec % 60).toFixed(1).padStart(4, '0')}`;
}

// ------------------------------------------------------------------ traitement par piste (file d'attente)
function setBusy(delta) {
    state.busy += delta;
    document.body.dataset.busy = String(state.busy);
}
function queueProcess(t) {
    if (!t.take) { updateRow(t); return; }
    const token = ++t.token;
    t.status = 'busy';
    state.balanceDirty = true;
    updateRow(t);
    setBusy(1);
    state.jobs = state.jobs.then(() => processTrack(t, token)).catch((err) => log('error', err.message)).finally(() => setBusy(-1));
    return state.jobs;
}
async function processTrack(t, token) {
    if (token !== t.token || !findTrack(t.id) || !t.take) return;   // réglage changé entre-temps : seul le dernier compte
    const key = `${t.styleId}|${t.roleId}|${ui.cleaning.checked}|${ui.useScale.checked}`;
    const t0 = performance.now();
    setStatus(`Traitement de « ${t.name} » : ${roleLabel(t.roleId)}, style ${styleName(t.styleId)}…`);
    try {
        const r = await call('processVoice', {
            mono: t.take.mono.slice(), sampleRate: t.take.sampleRate, styleId: t.styleId, roleId: t.roleId,
            cleaning: ui.cleaning.checked, useScale: ui.useScale.checked,
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
    const auto = mode === 'mix' ? (state.balance?.gains.get(t.id) ?? 0) : 0;
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
}
// Lecture en direct : une source par piste (gain + vumètre), puis un limiteur de sécurité commun.
// exceptId : piste en cours d'enregistrement (pas rejouée). startAt : instant (ctx) du début, par défaut tout de suite.
function play(mode, fromSec = state.playFromSec, { exceptId = 0, startAt = 0 } = {}) {
    stopPlayback();
    const ctx = audioContext();
    const t0 = startAt || ctx.currentTime + 0.05;
    const master = ctx.createGain();
    const safety = ctx.createDynamicsCompressor();   // sécurité : n'agit qu'au-dessus de -1 dBFS
    safety.threshold.value = -1; safety.knee.value = 0; safety.ratio.value = 20; safety.attack.value = 0.002; safety.release.value = 0.1;
    master.connect(safety).connect(ctx.destination);
    const outAn = ctx.createAnalyser(); outAn.fftSize = 1024; safety.connect(outAn);
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
        nodes.push({ key, src, gain: g, an, meterEl, hold: 0, holdUntil: 0 });
    };
    if (state.instru && audible(state.instruTrack))
        addSource(0, state.instru.left, state.instru.right, 0, state.instruTrack.volumeDb, rowOf(0)?._meter);
    for (const t of state.tracks) {
        if (t.id === exceptId || !audible(t)) continue;
        const a = trackAudio(t, mode);
        if (a) addSource(t.id, a.left, a.right, t.take.startSec, trackGainDb(t, mode), rowOf(t.id)?._meter);
    }
    const player = { mode, nodes, t0, fromSec, raf: 0, outAn };
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
            drawMeter(n.meterEl, p, n.hold);
        }
        drawMeter(ui.meterOut, peakOf(outAn), 0);
        if (pos > total + 0.2 && !state.rec) { stopPlayback(); state.playFromSec = 0; setPlayhead(0); return; }
        player.raf = requestAnimationFrame(tick);
    };
    player.raf = requestAnimationFrame(tick);
    return player;
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
}
function onMuteSolo() {
    state.balanceDirty = true;   // une piste muette ne compte pas dans l'équilibre
    liveGains();
}
async function startPlay(mode) {
    try {
        if (mode === 'mix') { setStatus('Équilibre des pistes…'); await ensureBalance(); }
        play(mode);
        setStatus(mode === 'mix'
            ? 'Lecture du mix : instru d\'origine + chaque piste traitée (style et type), équilibrées.'
            : 'Lecture brute : instru d\'origine + prises sans effet (A/B).');
    } catch (err) { setStatus('Lecture impossible : ' + err.message); log('error', err.message); }
}
ui.playBtn.addEventListener('click', () => startPlay('mix'));
ui.playRawBtn.addEventListener('click', () => startPlay('raw'));
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
    state.instru = { left, right, sampleRate, seconds: left.length / sampleRate, name };
    state.balanceDirty = true;
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
        lead.take = { mono: v.left, sampleRate: ctx.sampleRate, startSec: 0, note: 'voix de démo, légèrement fausse exprès' };
        let back = state.tracks.find((t) => t !== lead && !t.take);
        if (!back) back = addTrack('manual_back', 'Seconde voix');
        back.roleId = 'manual_back';
        back.take = { mono: v.left.slice(), sampleRate: ctx.sampleRate, startSec: 0, note: 'même voix de démo, en back' };
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
        t.take = { mono: isoRes.mono, sampleRate: buf.sampleRate, startSec: 0, note: `${file.name} · ${isoRes.note}` };
        t.processed = null; t.status = 'raw';
        updateRow(t);
        setStatus(`Voix importée sur « ${t.name} » : ${isoRes.note}. Traitement par son style…`);
        queueProcess(t);
    } catch (err) { t.status = 'error'; updateRow(t); setStatus('Voix illisible : ' + err.message); log('error', err.message); }
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
ui.recBtn.addEventListener('click', async () => {
    try {
        let t = findTrack(state.armedId);
        if (!t) { t = addTrack(state.tracks.some((x) => x.roleId === 'lead') ? ui.addRole.value : 'lead'); state.armedId = t.id; renderTracks(); }
        if (t.take && !confirm(`La piste « ${t.name} » a déjà une prise : la remplacer ?\n(Pour garder les deux, ajoute une piste.)`)) return;
        const ctx = audioContext();
        await ensureRecorderWorklet(ctx);
        prepareIsolation();   // téléchargement / préparation du modèle pendant la prise
        await ensureBalance();   // ce qu'on entend pendant la prise = le mix des autres pistes
        const stream = await navigator.mediaDevices.getUserMedia({
            audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1, latency: 0 },
        });
        const track = stream.getAudioTracks()[0];
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
        state.rec = { node: rec, songStartCtx: songStart, fromSec, sampleRate: ctx.sampleRate, trackId: t.id, mode: 'mix' };
        play('mix', fromSec, { exceptId: t.id, startAt: songStart });
        setStatus((bars > 0 ? `Enregistrement sur « ${t.name} »… ${bars} mesure(s) de clics à ${bpm.toFixed(0)} BPM, puis la musique : chante.`
                            : `Enregistrement sur « ${t.name} »… chante.`) + ' Stop pour finir.');
        ui.recBtn.disabled = true; ui.recBtn.classList.add('on'); ui.stopBtn.disabled = false;
        log('info', `REC sur « ${t.name} » (${roleLabel(t.roleId)}) depuis ${fromSec.toFixed(2)} s ; latence annoncée ${(announcedLatencySec(ctx, track) * 1000).toFixed(0)} ms (sortie ${((ctx.outputLatency || 0) * 1000).toFixed(0)}, traitement ${((ctx.baseLatency || 0) * 1000).toFixed(0)})`);
    } catch (err) { setStatus('Micro indisponible : ' + err.message); log('error', err.message); ui.recBtn.disabled = false; ui.recBtn.classList.remove('on'); }
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
        if (startSec < 0) {   // ce qui précède le début du morceau (clics, attente) est coupé
            const cut = Math.min(mono.length, Math.round(-startSec * sr));
            mono = mono.slice(cut);
            startSec = 0;
        }
        t.status = 'isolating'; updateRow(t);
        const isoRes = await maybeIsolate(mono, sr);
        mono = isoRes.mono;
        const lat = `${Math.round(rep.latencyMs)} ms ${rep.latencyMeasured ? 'mesuré' : 'annoncé (casque)'}`;
        const bleed = rep.bleedDetected
            ? `musique captée ${rep.bleedBeforeDb.toFixed(0)} dB → retirée (${rep.bleedAfterDb.toFixed(0)} dB)`
            : 'aucune musique captée (casque)';
        const note = `${bleed} · ${isoRes.note} · décalage ${lat}, compensé`;
        t.take = { mono, sampleRate: sr, startSec, note, report: rep, isolation: isoRes.isolated || null };
        t.processed = null; t.status = 'raw';
        state.balanceDirty = true;
        log('info', `Prise sur « ${t.name} » : ${rep.describe} ; début ${startSec.toFixed(3)} s ; ${isoRes.note}`);
        renderTracks();
        setStatus(`Prise enregistrée sur « ${t.name} » : voix seule, calée sur la musique (${note}). Traitement par son style…`);
        queueProcess(t);
    } catch (err) { setStatus('Prise impossible : ' + err.message); log('error', err.message); t.status = t.take ? 'raw' : 'vide'; updateRow(t); }
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
        const r = await call('limit', { left: mix.left.subarray(0, n).slice(), right: mix.right.subarray(0, n).slice(), sampleRate: sr, ceilingDb: -1 });
        const wav = encodeWav16(r.left, r.right, sr);
        const a = document.createElement('a');
        a.href = URL.createObjectURL(new Blob([wav], { type: 'audio/wav' }));
        a.download = 'StudioVoix-mix.wav';
        document.body.appendChild(a); a.click(); a.remove();
        const nTracks = state.tracks.filter((t) => t.take && audible(t)).length;
        log('info', `Export : ${nTracks} piste(s) voix + instru, ${r.report.lufs.toFixed(1)} LUFS, limiteur ${r.report.limiterGrDb.toFixed(1)} dB`);
        setStatus(`WAV exporté (16 bits, ${sr} Hz) : instru + ${nTracks} piste(s) voix, ${r.report.lufs.toFixed(1)} LUFS.`);
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

function refreshButtons() {
    const anyTake = state.tracks.some((t) => t.take);
    ui.recBtn.disabled = !state.ready || !!state.rec;
    ui.addTrackBtn.disabled = !state.ready;
    const demo = document.getElementById('demoBtn');
    if (demo) demo.disabled = !state.ready;
    ui.playBtn.disabled = !(state.instru || anyTake);
    ui.playRawBtn.disabled = !(state.instru || anyTake);
    ui.exportBtn.disabled = !(anyTake || state.instru);
}

drawMeter(ui.meterOut, 0, 0);
setPlayhead(0);
setStatus('Chargement du moteur…');
window.__studiovoix = state;   // lecture seule par les tests de bout en bout (vérification des prises)
startWorker();
