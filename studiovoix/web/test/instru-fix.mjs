// Essai de page des réglages de base de l'instru avant le mixage (Chromium sans écran, Playwright) :
//  A. bouton « Instru : telle quelle / corrigée » de la piste Instru (éteint par défaut) : allumé, le moteur corrige
//     l'instru (écrêtage, bruit, niveau, limiteur ; aucune couleur) ; la version corrigée est gardée à côté de
//     l'original, jamais modifié ; tout ce qui joue ou mixe l'instru prend la version corrigée ; la séparation et la
//     sauvegarde gardent l'original ; seul l'état du bouton est gardé avec le projet ;
//  B. curseur « Voix principale devant l'instru » du bloc « Écarts par type » : il déplace l'écart voix / instru dans
//     l'équilibre (« ▶ Mix ») et dans « Mixer la chanson », survit au rechargement, « Valeurs d'origine » le remet.
//   node web/test/instru-fix.mjs <url> [chanson.wav]
// chanson.wav (facultatif) : une vraie instru, corrigée en fin d'essai (durée du calcul, niveaux, mémoire).
// SEP_SONG=<chanson.wav> (facultatif, long) : vraie séparation (« Très rapide ») avec le bouton allumé — elle doit
// travailler sur l'original. DEVICE = appareil Playwright (ex. « Pixel 7 ») : mêmes contrôles, gestes au doigt.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium, devices } = require('playwright');

const [url, realSong = ''] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/instru-fix.mjs <url> [chanson.wav]'); process.exit(2); }
const sepSong = process.env.SEP_SONG || '';
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
let failed = false;
const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };
const device = process.env.DEVICE ? devices[process.env.DEVICE] : null;
if (process.env.DEVICE && !device) throw new Error('appareil inconnu : ' + process.env.DEVICE);
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'svinstru-'));

// Instru fabriquée : trop forte et écrêtée (plateaux à pleine échelle), stéréo (droite = 0,6 × gauche), un passage calme
// non écrêté (7 à 9 s : mesure de l'image stéréo), 1,5 s de silence à la fin (aucune traîne ne doit y apparaître).
function loudInstruWav(file, sr, gainDb, seed) {
    const nSound = Math.round(10.5 * sr), n = nSound + Math.round(1.5 * sr), g = Math.pow(10, gainDb / 20), beat = 0.6;
    let rnd = seed;
    const noise = () => { rnd = (Math.imul(rnd, 1664525) + 1013904223) >>> 0; return rnd / 2147483648 - 1; };
    const pcm = Buffer.alloc(44 + n * 4);
    pcm.write('RIFF', 0); pcm.writeUInt32LE(36 + n * 4, 4); pcm.write('WAVEfmt ', 8); pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20);
    pcm.writeUInt16LE(2, 22); pcm.writeUInt32LE(sr, 24); pcm.writeUInt32LE(sr * 4, 28); pcm.writeUInt16LE(4, 32); pcm.writeUInt16LE(16, 34);
    pcm.write('data', 36); pcm.writeUInt32LE(n * 4, 40);
    const q = (x) => Math.round(Math.max(-1, Math.min(1, x)) * 32767);
    for (let i = 0; i < nSound; ++i) {
        const t = i / sr, tb = t % beat, th = t % (beat / 2);
        const kick = Math.sin(2 * Math.PI * (55 + 60 * Math.exp(-tb * 30)) * tb) * Math.exp(-tb * 9);
        const hat = 0.25 * noise() * Math.exp(-th * 60);
        const chord = 0.22 * (Math.sin(2 * Math.PI * 220 * t) + Math.sin(2 * Math.PI * 261.63 * t) + Math.sin(2 * Math.PI * 329.63 * t)) * (0.7 + 0.3 * Math.sin(2 * Math.PI * 0.5 * t));
        const bass = 0.35 * Math.sin(2 * Math.PI * 55 * t);
        const x = (0.8 * kick + hat + chord + bass) * 0.6 * g * (t >= 7 && t < 9 ? 0.1 : 1) * Math.min(1, (nSound - i) / (0.02 * sr));
        pcm.writeInt16LE(q(x), 44 + i * 4); pcm.writeInt16LE(q(0.6 * x), 46 + i * 4);
    }
    fs.writeFileSync(file, pcm);
    return { seconds: n / sr, soundSec: nSound / sr };
}

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--autoplay-policy=no-user-gesture-required', '--enable-precise-memory-info'] });
try {
    const page = await (await browser.newContext({ acceptDownloads: true, ...(device || {}) })).newPage();
    const errors = [];
    page.on('pageerror', (e) => { console.log(stamp(), 'PAGEERROR', e.message); errors.push(String(e)); });
    page.on('console', (m) => { if (m.type() === 'error' && !/favicon/i.test(m.text())) errors.push(m.text()); });
    page.on('dialog', (d) => d.accept().catch(() => {}));
    // Outils de mesure dans la page (remis à chaque chargement) : égalité au bit près, empreinte, crête, niveau.
    await page.addInitScript(() => {
        const bits = (a) => new Uint32Array(a.buffer, a.byteOffset, a.length);
        window.__t = {
            eq(a, b, n = a?.length) { if (!a || !b || a.length < n || b.length < n) return false; const x = bits(a), y = bits(b); for (let i = 0; i < n; ++i) if (x[i] !== y[i]) return false; return true; },
            zeroFrom(a, from) { for (let i = from; i < a.length; ++i) if (a[i] !== 0) return false; return true; },
            fnv(a) { const b = new Uint8Array(a.buffer, a.byteOffset, a.byteLength); let h = 0x811c9dc5; for (let i = 0; i < b.length; ++i) { h ^= b[i]; h = Math.imul(h, 0x01000193) >>> 0; } return `${a.length}:${h.toString(16)}`; },
            peakDb(...arrs) { let m = 0; for (const a of arrs) for (let i = 0; i < a.length; ++i) { const v = Math.abs(a[i]); if (v > m) m = v; } return 20 * Math.log10(m + 1e-12); },
            rmsDb(a, from = 0, to = a.length) { let s = 0; for (let i = from; i < to; ++i) s += a[i] * a[i]; return 10 * Math.log10(s / Math.max(1, to - from) + 1e-20); },
            // Ce que la page joue (rendu hors ligne), une seule piste en solo : 0 = instru, sinon identifiant de piste.
            solo(mode, key) {
                const S = window.__studiovoix, objs = [S.instruTrack, ...S.tracks], keep = objs.map((o) => o.solo);
                for (const o of objs) o.solo = false;
                (key === 0 ? S.instruTrack : S.tracks.find((t) => t.id === key)).solo = true;
                try { return window.__svRenderPlayed(mode, 0, S.instru.sampleRate); } finally { objs.forEach((o, k) => { o.solo = keep[k]; }); }
            },
        };
    });
    const ready = async () => {
        for (let k = 0; k < 20; ++k) { try { if (await page.evaluate(() => window.crossOriginIsolated === true)) break; } catch (_) { /* rechargement en cours */ } await page.waitForTimeout(500); }
        await page.waitForFunction(() => window.__studiovoix?.ready && window.__studiovoix.tracks.length > 0, null, { timeout: 120000 });
    };
    const logLines = () => page.$$eval('#log div', (els) => els.map((x) => x.textContent).reverse());
    const idle = () => page.waitForFunction(() => { const s = window.__studiovoix; return (document.body.dataset.busy || '0') === '0' && s.tracks.every((t) => !t.take || t.noFx || (t.processed && t.status === 'done')); }, null, { timeout: 600000 });
    const fixReady = (timeout = 600000) => page.waitForFunction(() => { const S = window.__studiovoix; return S.instruFix && S.instru?.fixed && S.instru.fixed.audioId === S.instru.audioId && (document.body.dataset.busy || '0') === '0'; }, null, { timeout });
    const savedAt = () => page.evaluate(() => new Promise((resolve) => {
        const rq = indexedDB.open('studiovoix', 1);
        rq.onerror = () => resolve(0);
        rq.onsuccess = () => { const db = rq.result, g = db.transaction('meta').objectStore('meta').get('project'); g.onsuccess = () => { db.close(); resolve(g.result?.savedAt || 0); }; g.onerror = () => { db.close(); resolve(0); }; };
    }));
    const waitSave = async (act) => {
        const from = await page.evaluate(() => Date.now());
        await act();
        for (let k = 0; k < 150; ++k) { if ((await savedAt()) >= from) return; await page.waitForTimeout(200); }
        throw new Error('aucune sauvegarde du projet dans les 30 s qui suivent le geste');
    };
    const reload = async () => { await page.reload({ waitUntil: 'load' }); await ready(); await page.waitForFunction(() => window.__studiovoix.tracks.some((t) => t.take) && window.__studiovoix.instru?.analysis, null, { timeout: 120000 }); await idle(); };
    const press = (sel) => (device ? page.locator(sel).tap() : page.locator(sel).click());   // au doigt sur téléphone
    // État du bouton et de la piste Instru.
    const instruUi = () => page.evaluate(() => {
        const S = window.__studiovoix, b = document.getElementById('instruFixBtn'), box = b.getBoundingClientRect();
        return { text: b.textContent, on: b.classList.contains('on'), disabled: b.disabled, w: box.width, h: box.height, inView: box.left >= 0 && box.right <= window.innerWidth + 0.5,
            info: document.querySelector('.track[data-id="0"] .tinfo').textContent, flag: S.instruFix, hasFixed: !!S.instru?.fixed, status: document.getElementById('status').textContent };
    });
    // Rendu hors ligne de l'instru seule (« ▶ Brut » et « ▶ Mix ») comparé à l'original et à la version corrigée.
    const instruRender = () => page.evaluate(() => {
        const S = window.__studiovoix, T = window.__t, i = S.instru, n = i.left.length, f = i.fixed, a = window.__svInstru.audio(), src = window.__svInstru.source(), out = {};
        for (const mode of ['raw', 'mix']) {
            const r = T.solo(mode, 0);
            out[mode] = { orig: T.eq(r.left, i.left, n) && T.eq(r.right, i.right, n), fixed: !!f && T.eq(r.left, f.left, n) && T.eq(r.right, f.right, n), rest: T.zeroFrom(r.left, n) && T.zeroFrom(r.right, n) };
        }
        return { ...out, audioIsFixed: !!f && a.left === f.left && a.right === f.right, audioIsOrig: a.left === i.left && a.right === i.right, sourceIsOrig: src === i && src.left === i.left && src.right === i.right && (!f || src.left !== f.left),
            origHash: T.fnv(i.left) + '/' + T.fnv(i.right), fixedHash: f ? T.fnv(f.left) + '/' + T.fnv(f.right) : '', fixedDiffers: !!f && !T.eq(f.left, i.left, n),
            sameLen: !f || (f.left.length === n && f.right.length === n), fixedPeakDb: f ? T.peakDb(f.left, f.right) : null, origPeakDb: T.peakDb(i.left, i.right), report: f?.report || null, fixSec: f?.seconds ?? null, seconds: i.seconds, sr: i.sampleRate };
    });
    // Lecture réelle (« ▶ Mix » ou « ▶ Brut ») : ce que joue la source de l'instru, l'équilibre du moteur, puis arrêt.
    const playOnce = async (mode) => {
        await page.click(mode === 'mix' ? '#playBtn' : '#playRawBtn');
        await page.waitForFunction((mode) => window.__studiovoix.player?.mode === mode && (mode !== 'mix' || !window.__studiovoix.balanceDirty), mode, { timeout: 120000 });
        const r = await page.evaluate((mode) => {
            const S = window.__studiovoix, T = window.__t, node = S.player.nodes.find((n) => n.key === 0), i = S.instru, n = i.left.length, f = i.fixed;
            const b0 = node.src.buffer.getChannelData(0), b1 = node.src.buffer.getChannelData(1), rep = mode === 'mix' ? S.balance.report : null;
            const full = window.__svRenderPlayed(mode, 0, i.sampleRate);
            const lead = S.tracks.find((t) => t.roleId === 'lead' && t.take), back = S.tracks.find((t) => t.roleId !== 'lead' && t.take);
            const lv = (t) => { if (!t) return null; const r = T.solo(mode, t.id); return T.rmsDb(r.left); };
            return { playsOrig: T.eq(b0, i.left, n) && T.eq(b1, i.right, n), playsFixed: !!f && T.eq(b0, f.left, n) && T.eq(b1, f.right, n), mixHash: T.fnv(full.left) + '/' + T.fnv(full.right),
                leadDb: lv(lead), backDb: lv(back), gains: rep ? S.tracks.filter((t) => t.take).map((t) => S.balance.gains.get(t.id)) : [],
                rep: rep ? { vocalGainDb: rep.vocalGainDb, instruLufs: rep.instruLufs, leadLufs: rep.leadLufs, over: rep.vocalOverInstruLu, set: rep.vocalOverInstruSet, styleOver: rep.styleVocalOverInstruLu } : null,
                status: document.getElementById('status').textContent };
        }, mode);
        await page.click('#stopPlayBtn');
        return r;
    };
    // « Mixer la chanson » : rapport du moteur et texte affiché.
    const finalMix = async () => {
        await page.evaluate(() => { window.__fmBefore = window.__studiovoix.finalMix; });
        await page.click('#finalMixBtn');
        await page.waitForFunction(() => { const S = window.__studiovoix; return S.finalMix && S.finalMix !== window.__fmBefore && !S.finalMix.stale; }, null, { timeout: 300000 });
        const r = await page.evaluate(() => { const S = window.__studiovoix, r = S.finalMix.report; return { vocalGainDb: r.vocalGainDb, instruLufs: r.instruLufs, leadLufs: r.leadLufs, over: r.vocalOverInstruLu, set: r.vocalOverInstruSet, styleOver: r.styleVocalOverInstruLu, info: document.getElementById('finalInfo').textContent }; });
        await page.click('#stopPlayBtn');
        return r;
    };
    const gap = (r) => r.leadLufs + r.vocalGainDb - r.instruLufs;   // écart voix principale / instru mesuré par le moteur (LU)
    const f1 = (v) => (v == null ? '—' : v.toFixed(1)), f2 = (v) => (v == null ? '—' : v.toFixed(2));

    await page.goto(url, { waitUntil: 'load' });
    await ready();
    const empty = await instruUi();
    check('sans instru : bouton « Instru : telle quelle », éteint, inactif', empty.text === 'Instru : telle quelle' && !empty.on && empty.disabled && !empty.flag, `« ${empty.text} », ${empty.disabled ? 'inactif' : 'actif'}`);
    await page.click('#demoBtn');
    await page.waitForFunction(() => window.__studiovoix.tracks.length >= 2 && window.__studiovoix.tracks.every((t) => t.take), null, { timeout: 180000 });
    await idle();
    const sr = await page.evaluate(() => window.__studiovoix.instru.sampleRate);

    // ------------------------------------------------------------------ A1) éteint par défaut : le son d'avant
    const ui0 = await instruUi(), r0 = await instruRender();
    check('A : éteint par défaut (jamais allumé tout seul), bouton visible', !ui0.flag && !ui0.hasFixed && !ui0.on && !ui0.disabled && ui0.text === 'Instru : telle quelle' && ui0.inView && ui0.h >= 20,
        `« ${ui0.text} », ${ui0.w.toFixed(0)} × ${ui0.h.toFixed(0)} px ; ${ui0.info}`);
    check('A : éteint, « ▶ Brut » et « ▶ Mix » rendent l\'instru d\'origine au bit près', r0.raw.orig && r0.mix.orig && r0.raw.rest && r0.mix.rest && r0.audioIsOrig && r0.sourceIsOrig, `brut ${r0.raw.orig}, mix ${r0.mix.orig} ; instru ${f1(r0.seconds)} s, crête ${f2(r0.origPeakDb)} dBFS`);
    const base = await playOnce('mix'), baseRaw = await playOnce('raw');
    check('A : éteint, la lecture joue l\'instru d\'origine ; équilibre à la valeur du style', base.playsOrig && baseRaw.playsOrig && !base.rep.set && Math.abs(base.rep.over - base.rep.styleOver) < 1e-6 && Math.abs(gap(base.rep) - base.rep.styleOver) < 0.2,
        `écart voix / instru mesuré ${f2(gap(base.rep))} LU (style ${f1(base.rep.styleOver)}), gain voix ${f2(base.rep.vocalGainDb)} dB`);
    // Même équilibre que l'appel d'avant ce réglage (commande « balance » sans le champ vocalOverInstruLu).
    const legacy = await page.evaluate(async () => {
        const S = window.__studiovoix, list = S.tracks.filter((t) => t.take && !t.mute);
        const call = (cmd, payload) => new Promise((resolve, reject) => { const id = 9000000 + Math.floor(Math.random() * 1e6); const on = (e) => { if (e.data?.id !== id) return; S.worker.removeEventListener('message', on); e.data.ok ? resolve(e.data) : reject(new Error(e.data.error)); }; S.worker.addEventListener('message', on); S.worker.postMessage({ id, cmd, ...payload }); });
        const r = await call('balance', { instruL: S.instru.left.slice(), instruR: S.instru.right.slice(), sampleRate: S.instru.sampleRate, styleId: S.tracks.find((t) => t.roleId === 'lead').styleId,
            tracks: list.map((t) => ({ key: t.id, left: t.processed.left.slice(), right: t.processed.right.slice(), startSec: t.take.startSec, roleId: t.roleId, volumeDb: 0 })) });
        return list.map((t) => r.report.tracks.find((x) => x.key === t.id).gainDb);
    });
    check('A / B : sans réglage, même équilibre que l\'appel d\'avant (sans le nouveau champ)', legacy.length === base.gains.length && legacy.every((g, k) => Math.abs(g - base.gains[k]) < 1e-6), `gains ${base.gains.map(f2).join(' / ')} dB contre ${legacy.map(f2).join(' / ')} dB`);

    // ------------------------------------------------------------------ A2) allumé sur une instru PROPRE (démo) : rien n'est touché
    // Le réglage de base ne répare que l'écrêtage et ne baisse le niveau que si la crête dépasse −1 dBFS : l'instru de
    // démo (propre, crête −3 dBFS) doit ressortir identique au bit près, sans mémoire en plus.
    await press('#instruFixBtn');
    await fixReady();
    const ui1 = await instruUi(), r1 = await instruRender();
    const same1 = await page.evaluate(() => { const i = window.__studiovoix.instru; return { arrays: i.fixed?.left === i.left && i.fixed?.right === i.right, same: !!i.fixed?.same, changed: i.fixed?.report?.changed }; });
    check('A : allumé sur une instru propre, rien n\'est touché (même son au bit près, aucune mémoire en plus)', ui1.flag && same1.arrays && same1.same && same1.changed === false && r1.origHash === r0.origHash && r1.raw.orig && r1.mix.orig && r1.audioIsOrig,
        `rapport : changé ${same1.changed} ; version « corrigée » = les tableaux de l'original : ${same1.arrays} ; crête ${f2(r1.origPeakDb)} dBFS ; calcul ${f1(r1.fixSec)} s pour ${f1(r1.seconds)} s de son`);
    check('A : aucune couleur (ni réverb, ni écho, ni saturation)', r1.report.reverbSend === 0 && r1.report.delaySend === 0 && r1.report.satMix === 0, `réverb ${r1.report.reverbSend}, écho ${r1.report.delaySend}, saturation ${r1.report.satMix}`);
    const log1 = await logLines();
    check('A : instru propre, c\'est dit (bouton, ligne de la piste, journal avec la durée)', ui1.text === 'Instru : corrigée' && ui1.on && /rien à réparer/.test(ui1.info) && !/corrigée :/.test(ui1.info)
        && log1.some((l) => /Instru, réglage de base en \d+[.,]\d s .*rien à réparer.*l'original n'est pas modifié/.test(l)) && log1.some((l) => /\[moteur\] fixInstru : \d+ ms/.test(l)),
        `${ui1.info} | journal : ${(log1.find((l) => /Instru, réglage de base en/.test(l)) || '—').slice(0, 260)}`);
    const on = await playOnce('mix');
    check('A : instru propre, la lecture « ▶ Mix » est celle d\'avant, au bit près, et ne dit pas « instru corrigée »', on.playsOrig && on.mixHash === base.mixHash && !/instru corrigée/.test(on.status),
        `mix entier ${on.mixHash === base.mixHash ? 'identique à celui du départ' : 'DIFFÉRENT'} ; instru mesurée par l'équilibre ${f1(on.rep.instruLufs)} LUFS`);

    // ------------------------------------------------------------------ A3) éteint de nouveau
    await press('#instruFixBtn');
    await page.waitForFunction(() => !window.__studiovoix.instruFix && (document.body.dataset.busy || '0') === '0', null, { timeout: 30000 });
    const ui2 = await instruUi(), r2 = await instruRender(), off = await playOnce('mix');
    check('A : éteint de nouveau, toujours le son d\'avant au bit près (instru et mix entier)', !ui2.flag && !ui2.hasFixed && ui2.text === 'Instru : telle quelle' && r2.raw.orig && r2.mix.orig && r2.origHash === r0.origHash && off.playsOrig && off.mixHash === base.mixHash, `mix entier ${off.mixHash === base.mixHash ? 'identique à celui du départ' : 'DIFFÉRENT'} ; ${ui2.info}`);

    // ------------------------------------------------------------------ B) voix principale devant l'instru
    await page.click('#roleBox > summary');
    const vox = () => page.evaluate(() => {
        const S = window.__studiovoix, row = document.getElementById('voxInstruRow'), i = row.querySelector('input[type=range]'), box = i.getBoundingClientRect();
        return { label: row.querySelector('span').textContent, value: Number(i.value), min: Number(i.min), max: Number(i.max), step: Number(i.step), shown: row.querySelector('b').textContent, pre: row.querySelector('.pre').textContent,
            first: row.parentElement.querySelector('.rolerow') === row, state: S.vocalOverInstruLu, resetOff: document.getElementById('roleResetBtn').disabled, w: box.width, h: box.height, inView: box.left >= 0 && box.right <= window.innerWidth + 0.5, visible: box.width > 0 && box.height > 0 };
    });
    const setVox = (v) => page.locator('#voxInstru').evaluate((e, v) => { e.value = String(v); e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); }, v);
    const styleLu = base.rep.styleOver, vox0 = await vox();
    const styles = await page.evaluate(() => window.__studiovoix.styles.flatMap((g) => g.styles).map((s) => s.vocalOverInstruLu));
    check('B : ligne « Voix principale devant l\'instru » en tête du bloc, curseur par pas de 0,5, valeur du style rappelée', vox0.label === 'Voix principale devant l\'instru' && vox0.first && vox0.step === 0.5 && vox0.value === styleLu && vox0.state === null
        && /valeur du style .*: \+?-?\d/.test(vox0.pre) && !/modifié/.test(vox0.pre) && vox0.resetOff && vox0.visible && vox0.inView,
        `${vox0.min} à ${vox0.max} LU, valeur ${vox0.value} ; ${vox0.pre} ; curseur ${vox0.w.toFixed(0)} × ${vox0.h.toFixed(0)} px`);
    check('B : les bornes contiennent les valeurs des styles, avec de la marge', styles.length >= 33 && styles.every((v) => Number.isFinite(v) && v >= vox0.min + 2 && v <= vox0.max - 2), `${styles.length} styles de ${Math.min(...styles)} à ${Math.max(...styles)} LU ; bornes ${vox0.min} à ${vox0.max} LU`);
    const fmBase = await finalMix();
    check('B : sans réglage, « Mixer la chanson » vise la valeur du style', !fmBase.set && Math.abs(gap(fmBase) - styleLu) < 0.2, `écart mesuré ${f2(gap(fmBase))} LU (style ${f1(styleLu)}), gain voix ${f2(fmBase.vocalGainDb)} dB`);
    const WANT = 5;
    await waitSave(async () => { await setVox(WANT); await page.waitForFunction((w) => window.__studiovoix.vocalOverInstruLu === w && window.__studiovoix.balanceDirty, WANT, { timeout: 10000 }); });
    const vox1 = await vox(), moved = await playOnce('mix');
    check('B : curseur à +5 LU, l\'équilibre est marqué à refaire et l\'écart voix / instru vaut la valeur réglée (à 0,2 LU près)', moved.rep.set && Math.abs(gap(moved.rep) - WANT) < 0.2 && Math.abs((moved.leadDb - base.leadDb) - (WANT - styleLu)) < 0.2
        && Math.abs((moved.backDb - base.backDb) - (WANT - styleLu)) < 0.2 && moved.playsOrig && /modifié/.test(vox1.pre) && !vox1.resetOff,
        `écart mesuré par le moteur ${f2(gap(base.rep))} → ${f2(gap(moved.rep))} LU ; voix principale rendue ${(moved.leadDb - base.leadDb >= 0 ? '+' : '') + f2(moved.leadDb - base.leadDb)} dB (attendu ${(WANT - styleLu).toFixed(1)}), back ${f2(moved.backDb - base.backDb)} dB ; ${vox1.shown}`);
    const fmMoved = await finalMix();
    check('B : « Mixer la chanson » prend le même réglage (écart à 0,2 LU près)', fmMoved.set && Math.abs(fmMoved.over - WANT) < 1e-6 && Math.abs(gap(fmMoved) - WANT) < 0.2 && Math.abs((fmMoved.vocalGainDb - fmBase.vocalGainDb) - (WANT - styleLu)) < 0.2 && /Voix principale devant l'instru : \+5,0 LU \(réglée à la main/.test(fmMoved.info),
        `écart mesuré ${f2(gap(fmBase))} → ${f2(gap(fmMoved))} LU ; gain voix ${f2(fmBase.vocalGainDb)} → ${f2(fmMoved.vocalGainDb)} dB ; ${(fmMoved.info.split('\n').find((l) => /Voix principale devant/.test(l)) || '').slice(0, 110)}`);
    await reload();
    const vox2 = await vox(), again = await playOnce('mix');
    check('B : après rechargement, réglage gardé et repris (curseur, équilibre)', vox2.state === WANT && vox2.value === WANT && again.rep.set && Math.abs(gap(again.rep) - WANT) < 0.2 && Math.abs(again.leadDb - moved.leadDb) < 0.3
        && (await logLines()).some((l) => /voix principale devant l'instru : \+5,0 LU repris de la sauvegarde/.test(l)), `gardé ${vox2.state} LU, curseur ${vox2.value} ; écart mesuré ${f2(gap(again.rep))} LU`);
    await page.click('#roleBox > summary');
    await waitSave(() => press('#roleResetBtn'));
    await page.waitForFunction(() => window.__studiovoix.vocalOverInstruLu === null, null, { timeout: 10000 });
    const vox3 = await vox(), back = await playOnce('mix'), fmBack = await finalMix();
    check('B : « Valeurs d\'origine » redonne l\'ancien résultat (équilibre et « Mixer la chanson »)', vox3.state === null && vox3.value === styleLu && vox3.resetOff && !back.rep.set && back.gains.every((g, k) => Math.abs(g - base.gains[k]) < 0.01) && Math.abs(fmBack.vocalGainDb - fmBase.vocalGainDb) < 0.01,
        `gains ${back.gains.map(f2).join(' / ')} dB (départ ${base.gains.map(f2).join(' / ')}) ; « Mixer la chanson » : gain voix ${f2(fmBack.vocalGainDb)} dB (départ ${f2(fmBase.vocalGainDb)})`);
    // Geste réel sur le curseur (au doigt sur téléphone, à la souris sinon) : un appui aux trois quarts de sa largeur.
    await page.locator('#voxInstru').scrollIntoViewIfNeeded();
    const box = await page.locator('#voxInstru').boundingBox();
    if (device) await page.touchscreen.tap(box.x + box.width * 0.75, box.y + box.height / 2); else await page.mouse.click(box.x + box.width * 0.75, box.y + box.height / 2);
    await page.waitForFunction(() => window.__studiovoix.vocalOverInstruLu !== null, null, { timeout: 10000 }).catch(() => {});
    const vox4 = await vox();
    check(`B : curseur utilisable ${device ? 'au doigt' : 'à la souris'} (appui aux trois quarts de sa largeur)`, vox4.state !== null && Math.abs(vox4.state - 5) <= 1 && vox4.h >= 12 && vox4.w >= 100, `valeur ${vox4.state} LU ; curseur ${vox4.w.toFixed(0)} × ${vox4.h.toFixed(0)} px`);
    await waitSave(() => press('#roleResetBtn'));
    await page.waitForFunction(() => window.__studiovoix.vocalOverInstruLu === null, null, { timeout: 10000 });

    // ------------------------------------------------------------------ A4) instru fabriquée : trop forte et écrêtée
    const made = loudInstruWav(path.join(work, 'instru-forte.wav'), sr, 5, 1);
    await page.setInputFiles('#instruFile', path.join(work, 'instru-forte.wav'));
    await page.waitForFunction(() => window.__studiovoix.instru?.name === 'instru-forte.wav' && window.__studiovoix.instru.analysis, null, { timeout: 120000 });
    await idle();
    const m0 = await instruRender(), mUi0 = await instruUi();
    check('A : nouvelle instru (trop forte, écrêtée) : bouton toujours éteint, jouée telle quelle au bit près', !mUi0.flag && !mUi0.hasFixed && m0.raw.orig && m0.mix.orig, `crête ${f2(m0.origPeakDb)} dBFS, ${f1(m0.seconds)} s`);
    const baseM = await playOnce('mix');   // mix avec l'instru trop forte telle quelle, pour comparer
    await waitSave(async () => { await press('#instruFixBtn'); await fixReady(); });
    const m1 = await instruRender(), mUi1 = await instruUi();
    const shape = await page.evaluate((soundSec) => {
        const S = window.__studiovoix, T = window.__t, i = S.instru, f = i.fixed, s = i.sampleRate, flat = (a) => { let m = 0, n = 0; for (let k = 0; k < a.length; ++k) m = Math.max(m, Math.abs(a[k])); for (let k = 1; k < a.length; ++k) if (a[k] === a[k - 1] && Math.abs(a[k]) > 0.9 * m) ++n; return n; };
        const q0 = Math.round(7.4 * s), q1 = Math.round(8.6 * s), tail = Math.round((soundSec + 0.3) * s);
        return { flatBefore: flat(i.left), flatAfter: flat(f.left), imageBefore: T.rmsDb(i.left, q0, q1) - T.rmsDb(i.right, q0, q1), imageAfter: T.rmsDb(f.left, q0, q1) - T.rmsDb(f.right, q0, q1),
            tailDb: Math.max(T.peakDb(f.left.subarray(tail)), T.peakDb(f.right.subarray(tail))), tailBeforeDb: T.peakDb(i.left.subarray(tail)) };
    }, made.soundSec);
    check('A : instru fabriquée corrigée, original intact au bit près, rendu « Brut » et « Mix » = version corrigée', m1.origHash === m0.origHash && m1.fixedDiffers && m1.raw.fixed && m1.mix.fixed && m1.sourceIsOrig, `corrigée en ${f1(m1.fixSec)} s pour ${f1(m1.seconds)} s de son`);
    check('A : écrêtage réparé sur l\'instru fabriquée, crête ≤ −1 dBFS, dit dans la ligne de la piste', m1.report.clippedSamples > 0 && m1.report.clippedRepaired > 0 && shape.flatBefore > 100 && shape.flatAfter < shape.flatBefore / 10 && m1.fixedPeakDb <= -1 + 0.005 && /écrêtage réparé/.test(mUi1.info),
        `${m1.report.clippedSamples} échantillons écrêtés mesurés, ${m1.report.clippedRepaired} reconstruits ; plateaux ${shape.flatBefore} → ${shape.flatAfter} ; crête ${f2(m1.origPeakDb)} → ${f2(m1.fixedPeakDb)} dBFS ; ${f1(m1.report.lufsBefore)} → ${f1(m1.report.lufsAfter)} LUFS`);
    check('A : chemin exporté du moteur — image stéréo gardée, aucune traîne (ni réverb ni écho) dans le silence de fin', Math.abs(shape.imageAfter - shape.imageBefore) < 0.3 && shape.tailDb < -80 && m1.report.reverbSend === 0 && m1.report.delaySend === 0 && m1.report.satMix === 0,
        `gauche / droite ${f2(shape.imageBefore)} → ${f2(shape.imageAfter)} dB ; silence de fin ${f1(shape.tailDb)} dBFS (avant ${f1(shape.tailBeforeDb)})`);
    // Séparation d'une chanson : elle prend l'instru par instruSource() — l'original, jamais la version corrigée.
    check('A : la séparation et la sauvegarde prennent l\'original (fonction instruSource), pas la version corrigée', m1.sourceIsOrig && m1.audioIsFixed, `instruSource() = original : ${m1.sourceIsOrig} ; instruAudio() = corrigée : ${m1.audioIsFixed}`);
    console.log(stamp(), 'ligne de la piste Instru :', mUi1.info);
    // Tout ce qui joue ou mixe prend la version réparée : lecture, équilibre, « ⚖ Égaliser », « Mixer la chanson ».
    const logM = await logLines();
    check('A : ce qui a été fait est affiché (bouton, ligne de la piste) et au journal, avec la durée', mUi1.text === 'Instru : corrigée' && mUi1.on && /corrigée : .*écrêtage réparé.*crête .* dBFS.*niveau .* LUFS/.test(mUi1.info)
        && logM.some((l) => /Instru, réglage de base en \d+[.,]\d s .*écrêtage réparé.*ni égaliseur, ni débruitage, ni compression.*l'original n'est pas modifié/.test(l)),
        `${mUi1.info} | journal : ${(logM.find((l) => /Instru, réglage de base en .*écrêtage réparé/.test(l)) || '—').slice(0, 300)}`);
    check('A : le réglage de base ne fait que réparer l\'écrêtage et baisser le niveau (gain constant ≤ 0, niveau jamais remonté)', m1.report.changed === true && m1.report.gainDb <= 0 && m1.report.lufsAfter <= m1.report.lufsBefore + 0.05,
        `gain ${f2(m1.report.gainDb)} dB ; niveau ${f1(m1.report.lufsBefore)} → ${f1(m1.report.lufsAfter)} LUFS ; ${m1.report.clippedSharePct.toFixed(3)} % d'échantillons au sommet (réparé à partir de ${m1.report.clippedMinSharePct.toFixed(3)} %)`);
    const onM = await playOnce('mix'), onRawM = await playOnce('raw');
    check('A : allumé, la lecture « ▶ Mix » et « ▶ Brut » joue la version corrigée, équilibre refait sur elle', onM.playsFixed && onRawM.playsFixed && Math.abs(onM.rep.instruLufs - m1.report.lufsAfter) < 0.2 && onM.mixHash !== baseM.mixHash && /instru corrigée/.test(onM.status) && /instru corrigée/.test(onRawM.status),
        `instru mesurée par l'équilibre ${f1(onM.rep.instruLufs)} LUFS (corrigée ${f1(m1.report.lufsAfter)}, d'origine ${f1(m1.report.lufsBefore)}) ; écart voix / instru ${f2(gap(onM.rep))} LU`);
    await page.click('#levelBtn');   // « ⚖ Égaliser » (volumes sur le son brut) : mesuré sur la version corrigée, puis retiré
    await page.waitForFunction(() => window.__studiovoix.rawLevelOn && window.__studiovoix.balanceRaw?.report && !document.getElementById('levelBtn').disabled, null, { timeout: 60000 });
    const levLufs = await page.evaluate(() => window.__studiovoix.balanceRaw.report.instruLufs);
    await page.click('#levelBtn');
    await page.waitForFunction(() => !window.__studiovoix.rawLevelOn, null, { timeout: 10000 });
    check('A : allumé, « ⚖ Égaliser » mesure la version corrigée', Math.abs(levLufs - m1.report.lufsAfter) < 0.2, `instru ${f1(levLufs)} LUFS (corrigée ${f1(m1.report.lufsAfter)}, d'origine ${f1(m1.report.lufsBefore)})`);
    const fmOn = await finalMix();
    check('A : allumé, « Mixer la chanson » mixe la version corrigée', Math.abs(fmOn.instruLufs - m1.report.lufsAfter) < 0.2 && /Instru : corrigée avant le mix/.test(fmOn.info), `instru ${f1(fmOn.instruLufs)} LUFS ; ${(fmOn.info.split('\n').find((l) => /• Instru/.test(l)) || '').slice(0, 120)}`);
    // L'instru change pendant que le bouton est allumé : la version corrigée est refaite pour la nouvelle.
    loudInstruWav(path.join(work, 'instru-forte-2.wav'), sr, 3, 7);
    await page.setInputFiles('#instruFile', path.join(work, 'instru-forte-2.wav'));
    await page.waitForFunction(() => window.__studiovoix.instru?.name === 'instru-forte-2.wav' && window.__studiovoix.instru.analysis, null, { timeout: 120000 });
    await waitSave(async () => { await fixReady(); await idle(); });
    const m2 = await instruRender(), mUi2 = await instruUi();
    check('A : instru remplacée, bouton resté allumé : version corrigée refaite pour la nouvelle instru', mUi2.flag && mUi2.on && m2.fixedHash !== m1.fixedHash && m2.origHash !== m1.origHash && m2.raw.fixed && m2.mix.fixed, `corrigée en ${f1(m2.fixSec)} s ; ${f1(m2.report.lufsBefore)} → ${f1(m2.report.lufsAfter)} LUFS`);

    // ------------------------------------------------------------------ A5) rechargement, projet d'avant
    await waitSave(async () => { await setVox(3); await page.waitForFunction(() => window.__studiovoix.vocalOverInstruLu === 3, null, { timeout: 10000 }); });
    await page.waitForTimeout(1500);   // laisse passer la sauvegarde automatique
    await reload();
    await fixReady();
    const m3 = await instruRender(), mUi3 = await instruUi();
    check('A : après rechargement, bouton allumé repris, original sauvegardé tel quel, version corrigée refaite (la même)', mUi3.flag && mUi3.on && mUi3.text === 'Instru : corrigée' && m3.origHash === m2.origHash && m3.fixedHash === m2.fixedHash && m3.raw.fixed && m3.mix.fixed
        && (await logLines()).some((l) => /Instru : correction reprise de la sauvegarde/.test(l)), `original ${m3.origHash === m2.origHash ? 'identique' : 'DIFFÉRENT'}, corrigée ${m3.fixedHash === m2.fixedHash ? 'identique' : 'DIFFÉRENTE'} (refaite en ${f1(m3.fixSec)} s)`);
    await page.waitForTimeout(1500);   // laisse passer une sauvegarde automatique en attente (elle réécrirait les champs)
    const stripped = await page.evaluate(() => new Promise((resolve, reject) => {
        const rq = indexedDB.open('studiovoix', 1);
        rq.onerror = () => reject(rq.error);
        rq.onsuccess = () => {
            const db = rq.result, tx = db.transaction('meta', 'readwrite'), st = tx.objectStore('meta'), g = st.get('project');
            g.onsuccess = () => { const meta = g.result, had = { instruFix: meta.instruFix, vocalOverInstruLu: meta.vocalOverInstruLu }; delete meta.instruFix; delete meta.vocalOverInstruLu; st.put(meta, 'project'); tx.oncomplete = () => { db.close(); resolve(had); }; };
            tx.onerror = () => reject(tx.error);
        };
    }));
    await reload();
    const m4 = await instruRender(), mUi4 = await instruUi(), vox5 = await vox(), old = await playOnce('mix');
    check('A / B : projet d\'avant (sans ces champs) : instru telle quelle, écart du style', stripped.instruFix === true && stripped.vocalOverInstruLu === 3 && !mUi4.flag && !mUi4.hasFixed && mUi4.text === 'Instru : telle quelle' && m4.raw.orig && m4.mix.orig && m4.origHash === m2.origHash && vox5.state === null && !old.rep.set && old.playsOrig
        && (await logLines()).some((l) => /Instru : telle quelle \(projet d'avant ce réglage\) ; voix principale devant l'instru : valeur du style/.test(l)), `champs retirés de la sauvegarde (${JSON.stringify(stripped)}) → « ${mUi4.text} », écart ${f2(gap(old.rep))} LU (style ${f1(old.rep.styleOver)})`);

    // ------------------------------------------------------------------ facultatif : une vraie instru (durée, niveaux, mémoire)
    if (realSong) {
        const mem = async () => { try { return await page.evaluate(async () => (performance.measureUserAgentSpecificMemory ? (await performance.measureUserAgentSpecificMemory()).bytes : null)); } catch (_) { return null; } };
        await page.setInputFiles('#instruFile', realSong);
        await page.waitForFunction((n) => window.__studiovoix.instru?.name === n && window.__studiovoix.instru.analysis, path.basename(realSong), { timeout: 300000 });
        await idle();
        const s0 = await instruRender(), mem0 = await mem();
        await press('#instruFixBtn'); await fixReady(900000);
        const s1 = await instruRender(), sUi = await instruUi(), mem1 = await mem();
        // Une vraie instru déjà produite : soit rien n'est touché (propre, crête sous −1 dBFS : identique au bit près),
        // soit seuls l'écrêtage et le niveau le sont (crête ≤ −1 dBFS, niveau jamais remonté). Dans les deux cas l'original est intact.
        const rs = s1.report;
        check('vraie instru : original intact ; inchangée au bit près, ou seulement réparée / baissée (crête ≤ −1 dBFS, niveau jamais remonté)',
            s1.origHash === s0.origHash && (rs.changed ? (s1.raw.fixed && s1.mix.fixed && s1.fixedPeakDb <= -1 + 0.005 && rs.gainDb <= 0 && rs.lufsAfter <= rs.lufsBefore + 0.05) : (s1.raw.orig && s1.mix.orig)),
            `${path.basename(realSong)} : ${f1(s1.seconds)} s de son en ${f1(s1.fixSec)} s ; ${rs.changed ? 'changée' : 'inchangée'} ; ${rs.clippedSamples} échantillons au sommet (${rs.clippedSharePct.toFixed(4)} %, réparé à partir de ${rs.clippedMinSharePct.toFixed(3)} %), ${rs.clippedRepaired} reconstruits, gain ${f2(rs.gainDb)} dB ; ${f1(rs.lufsBefore)} → ${f1(rs.lufsAfter)} LUFS, crête ${f2(s1.origPeakDb)} → ${f2(s1.fixedPeakDb)} dBFS`);
        console.log(stamp(), 'vraie instru —', sUi.info);
        console.log(stamp(), `vraie instru — mémoire : ${rs.changed ? `version corrigée ${(s1.seconds * s1.sr * 8 / 1048576).toFixed(0)} Mo (2 canaux × 4 octets)` : 'aucune en plus (son inchangé)'}` + (mem0 != null && mem1 != null ? ` ; page + moteur mesurés ${(mem0 / 1048576).toFixed(0)} → ${(mem1 / 1048576).toFixed(0)} Mo` : ' ; mesure du navigateur indisponible'));
        await press('#instruFixBtn');
        await page.waitForFunction(() => !window.__studiovoix.instruFix && (document.body.dataset.busy || '0') === '0', null, { timeout: 30000 });
        const s2 = await instruRender(), mem2 = await mem();
        check('vraie instru : éteint, retour au bit près, mémoire libérée', s2.raw.orig && s2.mix.orig && !(await instruUi()).hasFixed, mem2 != null ? `page + moteur ${(mem2 / 1048576).toFixed(0)} Mo` : 'version corrigée retirée');
    }

    // ------------------------------------------------------------------ facultatif (long) : vraie séparation, bouton allumé
    if (sepSong) {
        await page.setInputFiles('#instruFile', sepSong);
        await page.waitForFunction((n) => window.__studiovoix.instru?.name === n && window.__studiovoix.instru.analysis, path.basename(sepSong), { timeout: 300000 });
        await idle();
        await press('#instruFixBtn'); await fixReady(900000);
        const p0 = await instruRender();
        await page.evaluate(() => { const i = window.__studiovoix.instru; window.__song = { left: i.left.slice(), right: i.right.slice(), fixedLeft: i.fixed.left.slice() }; });
        await page.check('#sepFast');
        await page.click('#sepBtn');
        await page.waitForFunction(() => window.__studiovoix.separating === true, null, { timeout: 60000 });
        const during = await page.evaluate(() => ({ hasFixed: !!window.__studiovoix.instru.fixed, info: document.querySelector('.track[data-id="0"] .tinfo').textContent }));
        await page.waitForFunction(() => window.__studiovoix.separating === false, null, { timeout: 1800000 });
        await fixReady(900000); await idle();
        const p1 = await page.evaluate(() => {
            const S = window.__studiovoix, T = window.__t, i = S.instru, o = i.original, w = window.__song; let same = 0, sameFixed = 0;
            for (let k = 0; k < i.left.length; ++k) { if (i.left[k] === w.left[k]) ++same; if (i.left[k] === w.fixedLeft[k]) ++sameFixed; }
            return { separated: !!o, keptOrig: !!o && T.eq(o.left, w.left) && T.eq(o.right, w.right), same, sameFixed, n: i.left.length, sr: i.sampleRate, tracks: S.tracks.filter((t) => t.take).map((t) => t.name), fixedForNew: i.fixed.audioId === i.audioId, name: i.name };
        });
        check('séparation réelle, bouton allumé : elle a travaillé sur l\'original (gardé au bit près ; l\'instru séparée reprend ses échantillons là où il n\'y a pas de voix, jamais ceux de la version corrigée)',
            p1.separated && p1.keptOrig && p1.same > p1.sr && p1.sameFixed < p1.same / 100 && !during.hasFixed && p1.fixedForNew,
            `${p1.name} ; ${(p1.same / p1.sr).toFixed(1)} s d'échantillons identiques à l'original, ${(p1.sameFixed / p1.sr).toFixed(2)} s identiques à la version corrigée ; pendant le calcul : ${during.info.split(' · ').at(-1)} ; pistes : ${p1.tracks.join(', ')}`);
        const p2 = await instruRender();
        check('séparation réelle : version corrigée refaite pour l\'instru séparée, jouée', p2.raw.fixed && p2.mix.fixed && p2.fixedHash !== p0.fixedHash, `refaite en ${f1(p2.fixSec)} s`);
        await page.evaluate(() => [...document.querySelectorAll('.track[data-id="0"] button')].find((b) => /Rétablir le morceau/.test(b.textContent)).click());
        await fixReady(900000);
        const p3 = await instruRender();
        check('« Rétablir le morceau » : original revenu au bit près, version corrigée refaite (la même qu\'avant la séparation)', p3.origHash === p0.origHash && p3.fixedHash === p0.fixedHash && p3.raw.fixed, `original ${p3.origHash === p0.origHash ? 'identique' : 'DIFFÉRENT'}, corrigée ${p3.fixedHash === p0.fixedHash ? 'identique' : 'DIFFÉRENTE'}`);
    }

    check('aucune erreur dans la console de la page', errors.length === 0, errors.length ? errors.join(' | ').slice(0, 400) : 'aucune');
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
    // Dossier de travail : seuls les deux fichiers fabriqués ici sont effacés, puis le dossier s'il est vide.
    for (const f of ['instru-forte.wav', 'instru-forte-2.wav']) { try { fs.unlinkSync(path.join(work, f)); } catch (_) { /* pas fabriqué */ } }
    try { fs.rmdirSync(work); } catch (_) { /* dossier non vide ou déjà parti */ }
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
