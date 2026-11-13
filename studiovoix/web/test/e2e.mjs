// Test de bout en bout de StudioVoix Web (Chromium sans écran, Playwright) :
// page servie en local, instru et voix importées par les champs fichier, style appliqué, mix exporté en WAV.
//   node web/test/e2e.mjs <url> <instru.wav> <voix.wav> [capture.png]
import { statSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

// Playwright : dossier node_modules local (CI) ou global (PLAYWRIGHT_DIR = sortie de `npm root -g`).
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium } = require('playwright');

// Sans fichiers (ou « - »), la démo intégrée du moteur sert d'instru et de voix.
const [url, instruArg, voiceArg, shot] = process.argv.slice(2);
if (!url) {
    console.error('usage : node web/test/e2e.mjs <url> [instru.wav|-] [voix.wav|-] [capture.png]');
    process.exit(2);
}
const instru = instruArg && instruArg !== '-' ? instruArg : null;
const voice = voiceArg && voiceArg !== '-' ? voiceArg : null;
// Prise au micro simulée : MIC_FILE = WAV joué par le faux micro de Chromium (voix + instru « captée »). Avec une instru
// (instruArg), la page enregistre REC_SECONDS s au micro au lieu d'importer la voix.
const micFile = process.env.MIC_FILE || '';
const recSeconds = Number(process.env.REC_SECONDS || 12);
// VOICE_REF = voix seule telle qu'elle est dans MIC_FILE (make_fake_mic.py --voice) : mesure de ce qui reste dans la
// prise après nettoyage + isolation IA (SDR, résidus pendant les silences). MIN_SDR_DB = seuil d'échec.
const voiceRef = process.env.VOICE_REF || '';
const minSdrDb = Number(process.env.MIN_SDR_DB || 10);

// SEP_SONG = chanson avec voix (WAV) : essai de « Séparer la chanson » ; TRUTH_INSTRU = vraie instru (WAV stéréo 16 bits)
// pour mesurer l'instru séparée ; MIN_INSTRU_SDR_DB = seuil d'échec.
const sepSong = process.env.SEP_SONG || '';
function readWavStereo(path) {
    const b = readFileSync(path);
    let o = 12, ch = 0;
    while (o + 8 <= b.length) {
        const id = b.toString('ascii', o, o + 4), size = b.readUInt32LE(o + 4);
        if (id === 'fmt ') ch = b.readUInt16LE(o + 10);
        if (id === 'data') {
            const n = Math.floor(size / 2 / ch), l = new Float32Array(n), r = new Float32Array(n);
            for (let i = 0; i < n; ++i) { l[i] = b.readInt16LE(o + 8 + i * 2 * ch) / 32768; r[i] = b.readInt16LE(o + 8 + (i * ch + (ch > 1 ? 1 : 0)) * 2) / 32768; }
            return { l, r };
        }
        o += 8 + size + (size & 1);
    }
    throw new Error(path + ' : pas de données');
}
function readWavMono(path) {
    const b = readFileSync(path);
    if (b.toString('ascii', 0, 4) !== 'RIFF' || b.toString('ascii', 8, 12) !== 'WAVE') throw new Error(path + ' : pas un WAV');
    let o = 12, sr = 0, ch = 0, bits = 0;
    while (o + 8 <= b.length) {
        const id = b.toString('ascii', o, o + 4), size = b.readUInt32LE(o + 4);
        if (id === 'fmt ') { ch = b.readUInt16LE(o + 10); sr = b.readUInt32LE(o + 12); bits = b.readUInt16LE(o + 22); }
        if (id === 'data') {
            if (bits !== 16) throw new Error(path + ' : 16 bits attendus');
            const n = Math.floor(size / 2 / ch), x = new Float32Array(n);
            for (let i = 0; i < n; ++i) x[i] = b.readInt16LE(o + 8 + i * 2 * ch) / 32768;
            return { x, sr };
        }
        o += 8 + size + (size & 1);
    }
    throw new Error(path + ' : pas de données');
}
// Prise (sortie de la page) comparée à la vraie voix : recalage (le faux micro boucle, départ inconnu), gain par
// moindres carrés, puis SDR = voix / (tout le reste) et niveau du reste là où la voix se tait.
function measureTake(take, sr, ref) {
    const r = new Float32Array(Math.round(ref.x.length * sr / ref.sr));
    for (let i = 0; i < r.length; ++i) { const p = i * ref.sr / sr, j = Math.floor(p), f = p - j; r[i] = (ref.x[j] || 0) + f * ((ref.x[j + 1] || 0) - (ref.x[j] || 0)); }
    const L = r.length, at = (k) => r[((k % L) + L) % L];
    const hop = Math.round(sr / 100), env = (x, len) => { const e = new Float64Array(Math.floor(len / hop)); for (let f = 0; f < e.length; ++f) { let s = 0; for (let i = 0; i < hop; ++i) { const v = x(f * hop + i); s += v * v; } e[f] = Math.sqrt(s / hop); } return e; };
    const et = env((i) => take[i] || 0, take.length), er = env(at, L);
    let best = 0, bestC = -Infinity;
    for (let lag = 0; lag < er.length; ++lag) { let c = 0; for (let f = 0; f < et.length; ++f) c += et[f] * er[(f + lag) % er.length]; if (c > bestC) { bestC = c; best = lag; } }
    let fine = best * hop, fineC = -Infinity;
    for (let d = -hop * 2; d <= hop * 2; ++d) { let c = 0; const base = best * hop + d; for (let i = 0; i < take.length; i += 2) c += take[i] * at(base + i); if (c > fineC) { fineC = c; fine = base; } }
    let tv = 0, vv = 0; for (let i = 0; i < take.length; ++i) { const v = at(fine + i); tv += take[i] * v; vv += v * v; }
    const g = tv / Math.max(1e-12, vv);
    let es = 0, ee = 0, quietE = 0, quietN = 0, loudE = 0, loudN = 0;
    const thr = Math.max(...er) * 0.01;   // voix à -40 dB sous son maximum : « silence »
    for (let i = 0; i < take.length; ++i) {
        const s = g * at(fine + i), e = take[i] - s; es += s * s; ee += e * e;
        const fr = Math.floor((((fine + i) % L) + L) % L / hop);
        if ((er[fr] || 0) < thr) { quietE += take[i] * take[i]; quietN++; } else { loudE += take[i] * take[i]; loudN++; }
    }
    const db = (x) => 10 * Math.log10(x + 1e-20);
    return { sdrDb: db(es) - db(ee), gain: g, quietVsVoiceDb: quietN && loudN ? db(quietE / quietN) - db(loudE / loudN) : NaN, quietSec: quietN / sr };
}
const t0 = Date.now();
const stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
const launchArgs = ['--autoplay-policy=no-user-gesture-required'];
if (micFile) launchArgs.push('--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream');
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: launchArgs });
// DEVICE = appareil Playwright (ex. « Pixel 7 ») : essai de la page en affichage téléphone.
const { devices } = require('playwright');
const device = process.env.DEVICE ? devices[process.env.DEVICE] : null;
if (process.env.DEVICE && !device) throw new Error('appareil inconnu : ' + process.env.DEVICE);
const page = await (await browser.newContext({ acceptDownloads: true, ...(device || {}) })).newPage();
// Faux micro calé sur la lecture : le faux périphérique de Chromium (--use-file-for-fake-audio-capture) lit son fichier
// en boucle à partir d'un instant qui ne dépend pas de la page ; à la 2e prise, la musique « captée » qu'il contient
// n'était plus calée sur la lecture (échecs intermittents : SDR 0,5 dB, builds 99 et local). Un vrai micro capte
// toujours ce qui sort au même moment. Ici, getUserMedia rend un flux tiré de MIC_FILE, démarré exactement au début du
// morceau (state.rec.songStartCtx) : instant 0 du fichier = instant 0 de l'instru, comme le suppose make_fake_mic.py.
if (micFile) {
    const micB64 = readFileSync(micFile).toString('base64');
    await page.exposeFunction('__fakeMicWav', () => micB64);
    await page.addInitScript(() => {
        const md = navigator.mediaDevices;
        if (!md) return;
        md.getUserMedia = async () => {
            const st = window.__studiovoix, ctx = st?.ctx;
            if (!ctx) throw new Error('faux micro : AudioContext absent');
            const bin = atob(await window.__fakeMicWav()), bytes = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; ++i) bytes[i] = bin.charCodeAt(i);
            const buf = await ctx.decodeAudioData(bytes.buffer);
            const src = ctx.createBufferSource(), dest = ctx.createMediaStreamDestination();
            src.buffer = buf; src.loop = true; src.connect(dest);
            const t0 = ctx.currentTime;
            const arm = () => {
                const at = st.rec?.songStartCtx;
                if (at) { src.start(Math.max(ctx.currentTime, at)); console.log(`faux micro démarré au début du morceau (${(at - t0).toFixed(3)} s après l'ouverture)`); }
                else if (ctx.currentTime - t0 < 10) setTimeout(arm, 2);
                else src.start();
            };
            arm();
            const stream = dest.stream;
            const stop = stream.getTracks()[0].stop.bind(stream.getTracks()[0]);
            stream.getTracks()[0].stop = () => { try { src.stop(); } catch (_) { /* déjà arrêté */ } stop(); };
            return stream;
        };
    });
}
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
try {
    await page.goto(url, { waitUntil: 'load' });
    // coi-serviceworker recharge la page une fois à la première visite (isolement COOP/COEP) : attendre la page isolée.
    for (let k = 0; k < 20; ++k) {
        try {
            if (await page.evaluate(() => window.crossOriginIsolated === true)) break;
        } catch (_) { /* rechargement en cours */ }
        await page.waitForTimeout(500);
    }
    await page.waitForLoadState('load');
    console.log(stamp(), 'page isolée (multi-cœur pour l\'IA) :', await page.evaluate(() => window.crossOriginIsolated));
    await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Moteur prêt'), null, { timeout: 60000 });
    console.log(stamp(), 'moteur prêt :', await page.textContent('#version'));

    const tracksDone = (n) => page.waitForFunction((n) => document.body.dataset.busy === '0'
        && window.__studiovoix.tracks.filter((t) => t.take && t.processed).length >= n, n, { timeout: 900000 });
    const trackInfo = (id) => page.textContent(`.track[data-id="${id}"] .tinfo`);

    // Prise au micro sur la piste armée ; retourne l'id de la piste.
    async function recordTake(label) {
        const before = await page.evaluate(() => window.__studiovoix.armedId);
        await page.click('#recBtn');
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Enregistrement'), null, { timeout: 60000 });
        console.log(stamp(), `REC (${label}) en cours sur la piste ${before}…`);
        await page.waitForTimeout(Math.min(4000, recSeconds * 1000));
        // Forme d'onde en direct : la piste armée se dessine pendant la prise (pixels rouges sur sa ligne de temps).
        const live = await page.evaluate((id) => {
            const c = document.querySelector(`.track[data-id="${id}"] .lane canvas`);
            const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
            let red = 0;
            for (let i = 0; i < d.length; i += 4) if (d[i] > 200 && d[i + 1] < 100 && d[i + 2] < 110) ++red;
            return red;
        }, before);
        console.log(stamp(), `forme d'onde en direct : ${live} pixels dessinés après 4 s`);
        if (live < 50) throw new Error('forme d\'onde en direct absente pendant la prise');
        await page.waitForTimeout(Math.max(0, recSeconds * 1000 - 4000));
        await page.click('#stopBtn');
        await page.waitForFunction((id) => {
            const st = document.getElementById('status').textContent;
            const t = window.__studiovoix.tracks.find((x) => x.id === id);
            return st.startsWith('Prise impossible') || (t && t.take && window.__studiovoix.rec === null);
        }, before, { timeout: 900000 });
        const st = await page.textContent('#status');
        if (st.startsWith('Prise impossible')) throw new Error('prise au micro en échec : ' + st);
        const info = await trackInfo(before);
        console.log(stamp(), `piste ${before} :`, info);
        const bgLine = ((await page.textContent('#log')).match(/Fond sonore de la prise[^)]*\)/) || [''])[0];
        console.log(stamp(), bgLine);
        if (process.env.EXPECT_BLEED === '1' && !/retirée/.test(info)) throw new Error('musique captée non détectée / non retirée');
        if (process.env.EXPECT_ISOLATION === '1' && !/voix isolée par IA/.test(info)) throw new Error('isolation IA non appliquée');
        if (process.env.EXPECT_ISOLATION === '0' && !/IA non nécessaire/.test(info)) throw new Error('IA lancée alors que la prise était déjà propre');
        if (voiceRef) {
            const take = await page.evaluate((id) => { const t = window.__studiovoix.tracks.find((x) => x.id === id); return { x: Array.from(t.take.mono), sr: t.take.sampleRate }; }, before);
            const ref = readWavMono(voiceRef), mic = readWavMono(micFile);
            const m0 = measureTake(mic.x.subarray(0, Math.min(mic.x.length, Math.round(take.x.length * mic.sr / take.sr))), mic.sr, ref);
            console.log(stamp(), `micro avant traitement : SDR ${m0.sdrDb.toFixed(1)} dB, pendant les silences de la voix ${m0.quietVsVoiceDb.toFixed(1)} dB sous la voix`);
            const m = measureTake(Float32Array.from(take.x), take.sr, ref);
            console.log(stamp(), `mesure de la prise : SDR ${m.sdrDb.toFixed(1)} dB (voix / tout le reste), pendant les silences de la voix (${m.quietSec.toFixed(1)} s) ${m.quietVsVoiceDb.toFixed(1)} dB sous la voix, gain ${m.gain.toFixed(2)}`);
            if (!(m.sdrDb >= minSdrDb)) throw new Error(`prise pas assez propre : SDR ${m.sdrDb.toFixed(1)} dB < ${minSdrDb} dB`);
        }
        return before;
    }

    let expected = 1;
    if (sepSong) {
        await page.setInputFiles('#instruFile', sepSong);
        await page.waitForFunction(() => window.__studiovoix.instru?.analysis, null, { timeout: 120000 });
        if (process.env.EXPECT_RESUME === '1') {
            // Coupure en pleine séparation (page rechargée à l'étape 2), puis relance : l'étape 1 doit être reprise, pas refaite.
            page.on('dialog', (d) => d.accept().catch(() => {}));   // « quitter la page ? » pendant le calcul
            await page.click('#sepBtn');
            await page.waitForFunction(() => /Étape 2\//.test(document.getElementById('sepStep').textContent), null, { timeout: 900000 });
            console.log(stamp(), 'coupure simulée : rechargement de la page pendant l\'étape 2');
            await page.reload({ waitUntil: 'load' });
            await page.waitForFunction(() => window.__studiovoix?.instru && !document.getElementById('sepBtn').disabled, null, { timeout: 180000 });
            await page.waitForTimeout(1500);
        }
        await page.click('#sepBtn');
        // Progression visible pendant tout le calcul : bloc affiché, roue, % qui monte, temps écoulé, bouton Arrêter.
        await page.waitForSelector('#sepProg:not([hidden])', { timeout: 5000 });
        const seen = [];
        const tSep = Date.now();
        for (;;) {
            const snap = await page.evaluate(() => ({
                done: /Chanson séparée|Séparation impossible|Séparation arrêtée/.test(document.getElementById('status').textContent),
                shown: !document.getElementById('sepProg').hidden,
                stop: !!document.getElementById('sepStopBtn').offsetParent,
                pct: parseFloat(document.getElementById('sepPct').textContent.replace(',', '.')),
                step: document.getElementById('sepStep').textContent,
                time: document.getElementById('sepTime').textContent,
                title: document.title,
                keep: !!(window.__svSep?.keep && !window.__svSep.keep.paused),
            }));
            if (snap.done) break;
            if (Date.now() - tSep > 1200000) throw new Error('séparation trop longue');
            if (!snap.shown || !snap.stop) throw new Error('séparation en cours sans progression visible ou sans bouton Arrêter');
            if (process.env.SEP_SHOT && !seen.shot && snap.pct >= 40) { seen.shot = true; await page.locator('.sepcard').screenshot({ path: process.env.SEP_SHOT }); }
            if (!seen.length || seen.at(-1).pct !== snap.pct || seen.at(-1).step !== snap.step) {
                snap.at = Date.now();
                seen.push(snap);
                console.log(stamp(), `progression : ${snap.pct} % — ${snap.step} — ${snap.time} | onglet « ${snap.title} »`);
            }
            await page.waitForTimeout(1000);
        }
        const pcts = seen.map((x) => x.pct).filter(Number.isFinite);
        if (new Set(pcts).size < 5) throw new Error(`progression trop pauvre : ${pcts.join(', ')}`);
        for (let i = 1; i < pcts.length; ++i) if (pcts[i] < pcts[i - 1]) throw new Error(`progression qui recule : ${pcts.join(', ')}`);
        if (!seen.some((x) => /En cours depuis/.test(x.time))) throw new Error('temps écoulé jamais affiché');
        const keepShare = seen.filter((x) => x.keep).length / Math.max(1, seen.length);
        console.log(stamp(), `son de veille (arrière-plan) actif sur ${(100 * keepShare).toFixed(0)} % des relevés`);
        if (keepShare < 0.8) throw new Error('son de veille absent pendant la séparation : le téléphone gèlerait la page écran éteint');
        if (!seen.some((x) => /morceau \d+\/\d+/.test(x.step))) throw new Error('compteur de morceaux jamais affiché');
        if (process.env.EXPECT_RESUME === '1') {
            const jl = await page.textContent('#log');
            if (!/voix \/ instru : \d+ tranche\(s\), [1-9]\d* reprise/.test(jl)) throw new Error('reprise : étape 1 recalculée au lieu d\'être relue');
            console.log(stamp(), 'reprise après coupure : étape 1 relue sans recalcul');
        }
        // Plus long écart sans changement visible du % pendant le calcul (doit rester court grâce à l'estimation).
        let gap = 0;
        for (let i = 1; i < seen.length; ++i) gap = Math.max(gap, seen[i].at - seen[i - 1].at);
        console.log(stamp(), `progression : ${seen.length} changements, plus long écart sans changement ${(gap / 1000).toFixed(1)} s`);
        if (process.env.MAX_SEP_GAP_S && gap > 1000 * Number(process.env.MAX_SEP_GAP_S)) throw new Error(`progression immobile ${(gap / 1000).toFixed(0)} s`);
        if (await page.isVisible('#sepProg')) throw new Error('bloc de progression encore affiché après la séparation');
        const st = await page.textContent('#status');
        console.log(stamp(), st);
        console.log(stamp(), (await page.textContent('#sepInfo')).replace(/\n/g, ' | '));
        if (!st.startsWith('Chanson séparée')) throw new Error('séparation en échec');
        if (process.env.EXPECT_GPU_FALLBACK === '1') {
            const fb = await page.evaluate(() => ({ ban: localStorage.getItem('sv-no-webgpu'), log: document.getElementById('log').textContent }));
            console.log(stamp(), `repli carte graphique → processeur : mémorisé « ${fb.ban} », journal ${/relancée sur le processeur/.test(fb.log) ? 'OK' : 'ABSENT'}`);
            if (fb.ban !== 'timeout' || !/relancée sur le processeur/.test(fb.log)) throw new Error('repli carte graphique bloquée → processeur non fait');
        }
        const tracks = await page.evaluate(() => window.__studiovoix.tracks.map((t) => `${t.name}|${t.roleId}|${t.noFx ? 'sansFX' : 'FX'}`));
        console.log(stamp(), 'pistes :', tracks.join(' ; '));
        if (!tracks.some((t) => /lead\|sansFX/.test(t))) throw new Error('aucune piste de voix principale créée');
        if (!(await page.evaluate(() => window.__studiovoix.tracks.every((t) => t.locked)))) throw new Error('pistes séparées non verrouillées d\'office');
        if (process.env.EXPECT_BACKS === '1' && !tracks.some((t) => /manual_back/.test(t))) throw new Error('aucune piste de backs créée');
        if (process.env.EXPECT_SINGERS && tracks.filter((t) => /^Chanteur/.test(t)).length !== Number(process.env.EXPECT_SINGERS))
            throw new Error(`nombre de chanteurs ${tracks.filter((t) => /^Chanteur/.test(t)).length} au lieu de ${process.env.EXPECT_SINGERS}`);
        if (process.env.TRUTH_INSTRU) {
            const truth = readWavStereo(process.env.TRUTH_INSTRU), song = readWavStereo(sepSong);
            const got = await page.evaluate(() => ({ l: Array.from(window.__studiovoix.instru.left), r: Array.from(window.__studiovoix.instru.right) }));
            const n = Math.min(truth.l.length, got.l.length);
            const sdr = (ref, est) => { let a = 0, e = 0; for (const c of ['l', 'r']) for (let i = 0; i < n; ++i) { a += ref[c][i] ** 2; e += (ref[c][i] - est[c][i]) ** 2; } return 10 * Math.log10(a / Math.max(1e-20, e)); };
            const before = sdr(truth, song), after = sdr(truth, got);
            console.log(stamp(), `instru séparée : SDR ${after.toFixed(1)} dB (chanson brute : ${before.toFixed(1)} dB)`);
            // Aigus seuls (dérivée seconde ≈ passe-haut) : un rééchantillonnage médiocre s'y voit, pas sur le SDR global.
            const hp = (x) => { const y = new Float32Array(x.length); for (let i = 2; i < x.length; ++i) y[i] = x[i] - 2 * x[i - 1] + x[i - 2]; return y; };
            const hi = sdr({ l: hp(truth.l), r: hp(truth.r) }, { l: hp(got.l), r: hp(got.r) });
            console.log(stamp(), `instru séparée, aigus seuls : SDR ${hi.toFixed(1)} dB`);
            if (process.env.MIN_INSTRU_HF_SDR_DB && !(hi >= Number(process.env.MIN_INSTRU_HF_SDR_DB))) throw new Error(`aigus de l'instru séparée abîmés : ${hi.toFixed(1)} dB`);
            // Là où personne ne chante (voix vraie = chanson − instru vraie, muette), l'instru séparée doit être la chanson
            // d'origine : mesure de l'écart dans les aigus sur ces passages (rééchantillonnage, bruit du modèle).
            const fr = Math.round(0.05 * 44100), sh = hp(song.l), gh = hp(got.l);
            let eZ = 0, sZ = 0, nz = 0;
            for (let a = 0; a + fr <= n; a += fr) {
                let v = 0; for (let i = a; i < a + fr; ++i) v += (song.l[i] - truth.l[i]) ** 2;
                if (v / fr > 1e-8) continue;   // la voix chante dans cette trame
                for (let i = a + 2; i < a + fr; ++i) { eZ += (gh[i] - sh[i]) ** 2; sZ += sh[i] ** 2; }
                ++nz;
            }
            const quietHf = 10 * Math.log10(eZ / Math.max(1e-20, sZ) + 1e-20);
            console.log(stamp(), `passages sans voix (${nz} trames) : écart instru séparée / chanson d'origine dans les aigus ${quietHf.toFixed(1)} dB`);
            if (process.env.MAX_QUIET_HF_DB && !(quietHf <= Number(process.env.MAX_QUIET_HF_DB))) throw new Error(`instru modifiée là où personne ne chante : ${quietHf.toFixed(1)} dB dans les aigus`);
            if (!(after >= Number(process.env.MIN_INSTRU_SDR_DB || 10))) throw new Error(`instru séparée pas assez propre : ${after.toFixed(1)} dB`);
        }
        // Mixage final de la chanson reconstruite, puis fin de l'essai.
        await page.click('#finalMixBtn');
        await page.waitForFunction(() => (window.__studiovoix.finalMix && !window.__studiovoix.finalMix.stale) || /Mixage impossible/.test(document.getElementById('status').textContent), null, { timeout: 300000 });
        const rep = await page.evaluate(() => window.__studiovoix.finalMix?.report);
        if (!rep) throw new Error('mixage final après séparation en échec : ' + await page.textContent('#status'));
        console.log(stamp(), `chanson remixée : ${rep.outputLufs.toFixed(1)} LUFS, crête ${rep.truePeakDb.toFixed(1)} dBTP`);
        // Équilibre des pistes séparées : toutes les voix principales au même niveau au Mix, backs 7 LU dessous.
        await page.click('#playBtn');
        await page.waitForFunction(() => window.__studiovoix.balance?.gains?.size >= 1 && !window.__studiovoix.balanceDirty, null, { timeout: 120000 });
        const lv = await page.evaluate(() => window.__studiovoix.tracks.filter((t) => t.take).map((t) => {
            const it = window.__studiovoix.balance.items.get(t.id), g = window.__studiovoix.balance.gains.get(t.id);
            return { name: t.name, role: t.roleId, before: it.lufs, level: it.lufs + g + t.volumeDb };
        }));
        console.log(stamp(), 'niveau au Mix des pistes séparées :', lv.map((x) => `${x.name} ${x.before.toFixed(1)} → ${x.level.toFixed(1)} LUFS`).join(' ; '));
        const leads = lv.filter((x) => x.role === 'lead').map((x) => x.level), backsLv = lv.filter((x) => x.role === 'manual_back').map((x) => x.level);
        if (leads.length > 1 && Math.max(...leads) - Math.min(...leads) > 0.3) throw new Error('voix principales séparées pas au même niveau au Mix');
        if (backsLv.length && leads.length && Math.abs(leads[0] - backsLv[0] - 7) > 1) throw new Error(`backs séparés mal placés : ${(leads[0] - backsLv[0]).toFixed(1)} LU sous la voix principale (visé 7)`);
        await page.click('#stopPlayBtn');
        const clock = await page.textContent('#time');
        if (!/^\d+:\d\d\.\d$/.test(clock)) throw new Error(`compteur de temps invalide : « ${clock} »`);
        const fin = await page.textContent('#finalInfo');
        if (/sans traitement/.test(fin)) throw new Error('mixage final : pistes séparées « sans effet » signalées comme brutes : ' + fin);
        const isoTxt = await page.textContent('#isolateInfo');
        if (/Téléchargement/.test(isoTxt)) throw new Error('carte Enregistrement : progression de la séparation restée affichée : ' + isoTxt);
        if (shot) await page.screenshot({ path: shot, fullPage: true });
        const fatal = errors.filter((e) => !/favicon/i.test(e));
        if (fatal.length) { console.error('erreurs console :', fatal.join('\n')); process.exitCode = 1; } else console.log(stamp(), 'OK');
        await browser.close();
        process.exit(process.exitCode || 0);
    }
    if (instru && micFile) {
        await page.setInputFiles('#instruFile', instru);
        await page.waitForFunction(() => window.__studiovoix.instru?.analysis, null, { timeout: 120000 });
        console.log(stamp(), 'instru :', await page.textContent('.track[data-id="0"] .tinfo'));
        await page.fill('#countIn', '0');
        await recordTake('voix principale');
        // Seconde piste (back) : on entend l'instru ET la voix principale pendant la prise ; les deux doivent être
        // retirées de la prise (référence = tout ce qui est joué), puis l'IA retire la radio.
        await page.selectOption('#addRole', 'manual_back');
        await page.click('#addTrackBtn');
        // Le faux micro rejoue la même voix (même fichier, à l'échantillon près) que la piste 1 : si la piste 1 jouait
        // pendant cette prise, elle serait dans la référence de retrait et la voix se retirerait elle-même (artefact du
        // test : un vrai back n'est jamais identique à la voix principale). Piste 1 en muet : on vérifie aussi M.
        await page.click('.track[data-id="1"] .tog.m');
        const listen = await page.textContent('#listen');
        console.log(stamp(), 'piste 1 en muet :', listen);
        if (!/Écoute : 1 piste\(s\) sur 2/.test(listen)) throw new Error('muet sans effet sur l\'écoute : ' + listen);
        await recordTake('seconde voix (back)');
        await page.click('.track[data-id="1"] .tog.m');
        if ((await page.textContent('#listen')) !== 'Écoute : tout') throw new Error('muet non retiré');
        // « Micro brut » : ce que le micro a capté avant nettoyage, pour comparer.
        await page.click('.track[data-id="1"] button.raw');
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Micro brut'), null, { timeout: 10000 });
        console.log(stamp(), 'micro brut :', (await page.textContent('#status')).slice(0, 60));
        await page.click('#stopPlayBtn');
        // Solo de la piste 2 : seule elle s'entend.
        await page.click('.track[data-id="2"] .tog.s');
        console.log(stamp(), 'solo piste 2 :', await page.textContent('#listen'));
        await page.click('#allBtn');
        if ((await page.textContent('#listen')) !== 'Écoute : tout') throw new Error('« Tout écouter » sans effet');
        expected = 2;
    } else if (instru && voice) {
        await page.setInputFiles('#instruFile', instru);
        await page.waitForFunction(() => window.__studiovoix.instru?.analysis, null, { timeout: 120000 });
        await page.setInputFiles('.track[data-id="1"] input.voiceFile', voice);
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Voix importée')
                                         || window.__studiovoix.tracks[0]?.take, null, { timeout: 900000 });
        console.log(stamp(), await page.textContent('#status'));
    } else {
        await page.click('#demoBtn');
        await page.waitForFunction(() => window.__studiovoix.tracks.length >= 2 && window.__studiovoix.tracks.every((t) => t.take), null, { timeout: 180000 });
        expected = 2;
    }
    await tracksDone(expected);
    console.log(stamp(), 'pistes traitées :', await page.textContent('#status'));

    // Changement de style sur la piste 1 → retraitement de cette piste seule.
    await page.selectOption('.track[data-id="1"] select.style', 'trap');
    await page.waitForFunction(() => document.body.dataset.busy === '0' && window.__studiovoix.tracks[0].processed?.report.style === 'Trap', null, { timeout: 300000 });
    const reports = await page.evaluate(() => window.__studiovoix.tracks.filter((t) => t.processed).map((t) => `${t.name} : ${t.processed.report.role} / ${t.processed.report.style}`));
    console.log(stamp(), 'traitements :', reports.join(' ; '));
    if (expected >= 2 && !reports.some((r) => r.includes('Back'))) throw new Error('seconde piste non traitée en back');

    await page.click('.track[data-id="1"] .head');
    const report = await page.textContent('#report');
    console.log(report.split('\n').slice(0, 2).join('\n'));
    if (!report.includes('Chaîne appliquée')) throw new Error('rapport incomplet');

    await page.click('#playBtn');
    await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Lecture du mix'), null, { timeout: 120000 });
    const infos = await page.$$eval('.track .tinfo', (e) => e.map((x) => x.textContent));
    console.log(stamp(), 'pistes :', infos.join(' || '));
    if (expected >= 2 && !infos.slice(1).every((i) => /mix [+-]\d/.test(i))) throw new Error('équilibre des pistes absent');
    await page.waitForTimeout(1500);
    await page.click('#stopPlayBtn');

    const [download] = await Promise.all([page.waitForEvent('download', { timeout: 120000 }), page.click('#exportBtn')]);
    const path = await download.path();
    const size = statSync(path).size;
    console.log(stamp(), `export ${download.suggestedFilename()} : ${size} octets ; ${await page.textContent('#status')}`);
    if (size < 1000) throw new Error('WAV exporté trop petit');

    // Mixage final : une seule chanson, sonie de la destination (Spotify -14 LUFS), crête sous -1 dBTP.
    {
        await page.click('#finalMixBtn');
        await page.waitForFunction(() => (window.__studiovoix.finalMix && !window.__studiovoix.finalMix.stale)
                                         || /Mixage impossible/.test(document.getElementById('status').textContent), null, { timeout: 300000 });
        const st = await page.textContent('#status');
        if (!st.startsWith('Chanson mixée')) throw new Error('mixage final en échec : ' + st);
        const rep = await page.evaluate(() => window.__studiovoix.finalMix.report);
        console.log(stamp(), `chanson mixée : ${rep.inputLufs.toFixed(1)} -> ${rep.outputLufs.toFixed(1)} LUFS, crête ${rep.truePeakDb.toFixed(1)} dBTP, voix ${rep.vocalGainDb.toFixed(1)} dB, bus -${rep.busGrDb.toFixed(1)} dB, creux ${rep.duckingDb} dB`);
        console.log((await page.textContent('#finalInfo')).split('\n').slice(0, 3).join('\n'));
        if (Math.abs(rep.outputLufs - rep.targetLufs) > 1.0) throw new Error(`sonie finale ${rep.outputLufs.toFixed(1)} LUFS, visée ${rep.targetLufs}`);
        if (rep.truePeakDb > -0.9) throw new Error(`crête finale ${rep.truePeakDb.toFixed(1)} dBTP > -1`);
        await page.click('#stopPlayBtn');
        const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 60000 }), page.click('#exportFinalBtn')]);
        const sz = statSync(await dl.path()).size;
        console.log(stamp(), `export ${dl.suggestedFilename()} : ${sz} octets`);
        if (sz < 1000) throw new Error('chanson mixée exportée trop petite');
    }

    // Instru intacte : voix coupées, l'export doit être l'instru d'origine à l'échantillon près (aucun limiteur,
    // aucun compresseur ; seul un gain pur est permis si la somme dépassait -0,3 dBFS, ce qui n'est pas le cas ici).
    {
        const ids = await page.evaluate(() => window.__studiovoix.tracks.filter((t) => t.take && !t.mute).map((t) => t.id));
        for (const id of ids) await page.click(`.track[data-id="${id}"] .tog.m`);
        const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 120000 }), page.click('#exportBtn')]);
        const b = readFileSync(await dl.path());
        const ref = await page.evaluate(() => {
            const L = window.__studiovoix.instru.left, R = window.__studiovoix.instru.right, out = [];
            let peak = 0;
            for (let i = 0; i < L.length; ++i) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
            for (let i = 0; i < L.length; i += 331) out.push([i, L[i], R[i]]);
            return { pts: out, peak, n: L.length };
        });
        let maxErr = 0;
        for (const [i, l, r] of ref.pts) {
            const o = 44 + i * 4;
            if (o + 4 > b.length) { maxErr = Infinity; break; }
            maxErr = Math.max(maxErr, Math.abs(b.readInt16LE(o) / 32767 - Math.max(-1, Math.min(1, l))), Math.abs(b.readInt16LE(o + 2) / 32767 - Math.max(-1, Math.min(1, r))));
        }
        console.log(stamp(), `instru seule exportée : écart max ${maxErr.toExponential(1)} sur ${ref.pts.length} points (crête instru ${(20 * Math.log10(ref.peak)).toFixed(1)} dBFS)`);
        if (ref.peak < Math.pow(10, -0.3 / 20) && !(maxErr <= 1.5 / 32767)) throw new Error('instru modifiée à l\'export');
        for (const id of ids) await page.click(`.track[data-id="${id}"] .tog.m`);
    }

    // Sauvegarde automatique : après rechargement, le projet (instru, pistes, prises, réglages) revient.
    if (!micFile) {
        const before = await page.evaluate(() => window.__studiovoix.tracks.map((t) => `${t.name}|${t.roleId}|${t.styleId}|${t.takes.length}`).join(';'));
        await page.waitForFunction(() => /Sauvegardé/.test(document.getElementById('saveInfo').textContent), null, { timeout: 30000 });
        await page.reload({ waitUntil: 'load' });
        await page.waitForFunction(() => window.__studiovoix?.ready && window.__studiovoix.instru && window.__studiovoix.tracks.length > 0
                                         && window.__studiovoix.tracks.every((t) => t.take), null, { timeout: 120000 });
        await tracksDone(expected);
        const after = await page.evaluate(() => window.__studiovoix.tracks.map((t) => `${t.name}|${t.roleId}|${t.styleId}|${t.takes.length}`).join(';'));
        console.log(stamp(), 'projet repris après rechargement :', after);
        if (after !== before) throw new Error(`projet repris différent : ${after} au lieu de ${before}`);
    }

    // Tableau des effets : pré-réglage affiché, effet éteint puis réglé à la main PENDANT la lecture « Mix » (le son de la
    // piste est remplacé sans arrêter la lecture), retour au pré-réglage.
    {
        const idx = await page.evaluate(() => window.__studiovoix.tracks.findIndex((t) => t.take && !t.noFx && t.processed?.report?.fx));
        if (idx >= 0) {
            // Sélection par l'en-tête lui-même (un clic au centre tomberait sur un de ses boutons).
            await page.evaluate((i) => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[i].id}"] .head`).click(), idx);
            await page.waitForFunction(() => document.querySelectorAll('#fxList .fxrow').length >= 12, null, { timeout: 10000 });
            const snap = () => page.evaluate((i) => {
                const t = window.__studiovoix.tracks[i], L = t.processed.left, n0 = t.take.mono.length;
                let tail = 0; for (let k = n0; k < L.length; ++k) tail += L[k] * L[k];   // traîne après la fin de la prise = réverb + écho
                const n = window.__studiovoix.player?.nodes.find((x) => x.key === t.id);
                return { fx: t.processed.report.fx, preset: t.processed.report.preset, tailDb: 10 * Math.log10(tail / Math.max(1, L.length - n0) + 1e-20), status: t.status, mine: t.fx, swaps: n?.swaps || 0, playing: !!window.__studiovoix.player };
            }, idx);
            const settled = (pred) => page.waitForFunction(([i, src]) => { const t = window.__studiovoix.tracks[i]; return t.status === 'done' && t.processed?.report?.fx && new Function('fx', 'return ' + src)(t.processed.report.fx); }, [idx, pred], { timeout: 120000 });
            const base = await snap();
            console.log(stamp(), `effets (pré-réglage) : réverb ${base.fx.reverb.on ? Math.round(base.fx.reverb.send * 100) + ' %' : 'éteinte'}, écho ${base.fx.delay.on ? Math.round(base.fx.delay.send * 100) + ' %' : 'éteint'}, compresseur ${base.fx.comp.ratio.toFixed(1)}:1, traîne ${base.tailDb.toFixed(1)} dB`);
            await page.click('#playBtn');
            await page.waitForFunction(() => window.__studiovoix.player?.mode === 'mix', null, { timeout: 60000 });
            // 1) réverb et écho éteints par leur case
            for (const id of ['reverb', 'delay']) {
                const c = page.locator(`#fxList .fxrow[data-fx="${id}"] input[type=checkbox]`);
                if (await c.isChecked()) await c.uncheck(); else { await c.check(); await c.uncheck(); }
            }
            await settled('fx.reverb.on === false && fx.delay.on === false');
            await page.waitForFunction((i) => (window.__studiovoix.player?.nodes.find((x) => x.key === window.__studiovoix.tracks[i].id)?.swaps || 0) >= 1, idx, { timeout: 30000 });
            const off = await snap();
            if (!off.playing) throw new Error('effets : la lecture s\'est arrêtée pendant le changement de réglage');
            if (!(off.tailDb < -90)) throw new Error(`effets : réverb et écho éteints mais il reste une traîne (${off.tailDb.toFixed(1)} dB)`);
            // 2) réverb remise et poussée à 60 % au curseur
            await page.locator('#fxList .fxrow[data-fx="reverb"] .fxline').click();
            await page.locator('#fxList .fxrow[data-fx="reverb"] input[type=checkbox]').check();
            const slider = page.locator('#fxList .fxrow[data-fx="reverb"] .fxfield input[type=range]').first();
            await slider.evaluate((e) => { e.value = '0.6'; e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); });
            await settled('fx.reverb.on === true && Math.abs(fx.reverb.send - 0.6) < 0.011');
            await page.waitForFunction(([i, k]) => (window.__studiovoix.player?.nodes.find((x) => x.key === window.__studiovoix.tracks[i].id)?.swaps || 0) > k, [idx, off.swaps], { timeout: 30000 });
            const big = await snap();
            if (!big.playing) throw new Error('effets : la lecture s\'est arrêtée pendant le réglage du curseur');
            if (!(big.tailDb > off.tailDb + 20)) throw new Error(`effets : réverb à 60 % sans traîne audible (${big.tailDb.toFixed(1)} dB)`);
            if (!(await page.locator('#fxList .fxrow[data-fx="reverb"] .fxmod').isVisible())) throw new Error('effets : la ligne Réverb n\'est pas marquée « modifié »');
            console.log(stamp(), `effets pendant la lecture : réverb + écho éteints → traîne ${off.tailDb.toFixed(1)} dB ; réverb à 60 % → traîne ${big.tailDb.toFixed(1)} dB ; ${big.swaps} échange(s) de son sans arrêt de la lecture`);
            // 3) retour au pré-réglage
            await page.click('#fxResetAll');
            await settled(`Math.abs(fx.reverb.send - ${base.preset.reverb.send}) < 1e-6 && fx.delay.on === ${base.preset.delay.on}`);
            const back = await snap();
            if (Object.keys(back.mine || {}).length) throw new Error('effets : des réglages à la main restent après « Tout remettre au pré-réglage »');
            if (Math.abs(back.tailDb - base.tailDb) > 0.5) throw new Error(`effets : retour au pré-réglage différent du départ (${back.tailDb.toFixed(1)} dB contre ${base.tailDb.toFixed(1)} dB)`);
            console.log(stamp(), `effets : retour au pré-réglage identique au départ (traîne ${back.tailDb.toFixed(1)} dB)`);
            await page.click('#stopPlayBtn');
        }
    }
    // Lecture brute avec « Égaliser » : seuls les volumes changent (gain par piste = équilibre calculé sur les prises
    // brutes) ; décoché pendant la lecture : retour aux volumes d'origine.
    if (await page.evaluate(() => window.__studiovoix.tracks.some((t) => t.take))) {
        await page.check('#rawLevel');
        await page.click('#playRawBtn');
        await page.waitForFunction(() => window.__studiovoix.player?.mode === 'raw' && window.__studiovoix.balanceRaw?.gains?.size >= 1, null, { timeout: 60000 });
        const read = () => page.evaluate(() => window.__studiovoix.player.nodes.filter((n) => n.key).map((n) => {
            const t = window.__studiovoix.tracks.find((x) => x.id === n.key);
            return { name: t.name, gainDb: 20 * Math.log10(n.gain.gain.value + 1e-12), want: (window.__studiovoix.balanceRaw.gains.get(t.id) ?? 0) + t.volumeDb, fader: t.volumeDb, lufs: window.__studiovoix.balanceRaw.items.get(t.id)?.lufs };
        }));
        const on = await read();
        if (!on.length || on.some((x) => Math.abs(x.gainDb - x.want) > 0.1)) throw new Error('brut égalisé : gain de piste différent de l\'équilibre brut : ' + JSON.stringify(on));
        console.log(stamp(), 'brut égalisé :', on.map((x) => `${x.name} ${x.lufs.toFixed(1)} LUFS → gain ${x.gainDb.toFixed(1)} dB`).join(' ; '));
        await page.uncheck('#rawLevel');
        await page.waitForTimeout(400);
        const off = await read();
        if (off.some((x) => Math.abs(x.gainDb - x.fader) > 0.1)) throw new Error('brut non égalisé : le gain devrait être le seul curseur : ' + JSON.stringify(off));
        await page.check('#rawLevel');
        await page.click('#stopPlayBtn');
    }
    // Cadenas de piste : verrouillée, glisser la prise ne la déplace pas ; déverrouillée, si.
    {
        const idx = await page.evaluate(() => window.__studiovoix.tracks.findIndex((t) => t.take));
        if (idx >= 0) {
            const info = () => page.evaluate((i) => { const t = window.__studiovoix.tracks[i], k = t.take; const total = Math.max(window.__studiovoix.instru?.seconds || 0, ...window.__studiovoix.tracks.filter((x) => x.take).map((x) => x.take.startSec + x.take.mono.length / x.take.sampleRate));
                return { locked: !!t.locked, start: k.startSec, len: k.mono.length / k.sampleRate, total }; }, idx);
            const drag = async () => {
                const lane = page.locator('#tracks .lane').nth(idx + 1);
                await lane.scrollIntoViewIfNeeded();
                const b = await lane.boundingBox(), st = await info();
                const x = b.x + Math.min(b.width - 80, Math.max(4, (st.start + st.len / 2) / st.total * b.width)), y = b.y + b.height / 2;
                await page.mouse.move(x, y); await page.mouse.down();
                for (let d = 10; d <= 60; d += 10) await page.mouse.move(x + d, y);
                await page.mouse.up();
                return (await info()).start;
            };
            const lockBtn = page.locator('#tracks button.tog.lock').nth(idx);
            let st = await info();
            if (!st.locked) await lockBtn.click();
            const s0 = (await info()).start, s1 = await drag();
            if (Math.abs(s1 - s0) > 1e-9) throw new Error(`cadenas : piste verrouillée déplacée de ${s0} à ${s1} s`);
            if (!/verrouillée/.test(await page.textContent('#status'))) throw new Error('cadenas : pas de message quand on tente de déplacer une piste verrouillée');
            await lockBtn.click();
            const s2 = await drag();
            if (Math.abs(s2 - s0) < 0.01) throw new Error('cadenas : piste déverrouillée non déplaçable');
            console.log(stamp(), `cadenas : verrouillée → reste à ${s0.toFixed(2)} s ; déverrouillée → déplacée à ${s2.toFixed(2)} s`);
            await page.evaluate(([i, v]) => { window.__studiovoix.tracks[i].take.startSec = v; }, [idx, s0]);
            await page.locator('#tracks button.tog.lock').nth(idx).click();   // re-verrouille
            if (!(await info()).locked) throw new Error('cadenas : re-verrouillage sans effet');
        }
    }
    {
        const clock = await page.textContent('#time');
        if (!/^\d+:\d\d\.\d$/.test(clock)) throw new Error(`compteur de temps invalide : « ${clock} »`);
    }
    if (shot) { await page.screenshot({ path: shot, fullPage: true }); console.log(stamp(), 'capture :', shot); }
    const fatal = errors.filter((e) => !/favicon/i.test(e));
    if (fatal.length) { console.error('erreurs console :', fatal.join('\n')); process.exitCode = 1; }
    else console.log(stamp(), 'OK');
} catch (err) {
    console.error(stamp(), 'ÉCHEC :', err.message);
    console.error('statut :', await page.textContent('#status').catch(() => '?'));
    console.error('journal :', (await page.textContent('#log').catch(() => '')).slice(0, 2000));
    process.exitCode = 1;
} finally {
    await browser.close();
}
