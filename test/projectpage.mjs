// Essai de page du projet en fichier : « Enregistrer le projet » puis « Ouvrir un projet » redonnent le même projet au
// bit près (pistes, types, cadenas, place des prises, sons, instru) ; un fichier abîmé, tronqué ou étranger est refusé
// avec un message clair et le projet en cours ne change pas.
//   node web/test/projectpage.mjs <url> [dossier de travail]
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium, devices } = require('playwright');

const [url, workArg] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/projectpage.mjs <url> [dossier de travail]'); process.exit(2); }
const work = workArg || fs.mkdtempSync(path.join(os.tmpdir(), 'svproj-'));
fs.mkdirSync(work, { recursive: true });
const device = process.env.DEVICE ? devices[process.env.DEVICE] : null;
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
let failed = false;
const check = (name, ok, detail) => { console.log(stamp(), ok ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!ok) failed = true; };

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
try {
    const ctx = await browser.newContext({ ...(device || {}), acceptDownloads: true });
    const page = await ctx.newPage();
    page.on('pageerror', (e) => { console.log(stamp(), 'PAGEERROR', e.message); failed = true; });
    const dialogs = [];
    let answer = true;
    page.on('dialog', async (d) => { dialogs.push({ type: d.type(), text: d.message() }); if (d.type() === 'confirm' && !answer) await d.dismiss(); else await d.accept(); });
    const ready = () => page.waitForFunction(() => window.__studiovoix?.ready && document.getElementById('status').textContent.length > 0 && window.__studiovoix.tracks.length > 0, null, { timeout: 120000 });
    const settled = () => page.waitForFunction(() => { const s = window.__studiovoix; return document.body.dataset.busy === '0' && s.tracks.every((t) => !t.take || t.noFx || (t.processed && t.status === 'done')); }, null, { timeout: 180000 });
    // Empreinte du projet : tout ce qui doit survivre, sons compris (somme FNV des octets).
    const snapshot = () => page.evaluate(() => {
        const fnv = (a) => { const b = new Uint8Array(a.buffer, a.byteOffset, a.byteLength); let h = 0x811c9dc5; for (let i = 0; i < b.length; ++i) { h ^= b[i]; h = Math.imul(h, 0x01000193) >>> 0; } return `${a.length}:${h.toString(16)}`; };
        const s = window.__studiovoix;
        return JSON.stringify({
            roleOffsets: s.roleOffsets || {},
            instru: s.instru ? { name: s.instru.name, sr: s.instru.sampleRate, l: fnv(s.instru.left), r: fnv(s.instru.right) } : null,
            tracks: s.tracks.map((t) => ({ name: t.name, role: t.roleId, style: t.styleId, vol: t.volumeDb, mute: !!t.mute, noFx: !!t.noFx, correction: !!t.correction, smooth: !!t.smooth, locked: !!t.locked, fx: t.fx || {},
                active: t.takes.indexOf(t.take), takes: t.takes.map((k) => ({ sr: k.sampleRate, at: k.startSec, label: k.label, mono: fnv(k.mono),
                    clips: k.clips ? k.clips.map((c) => [c.off, c.len, c.at, c.gainDb, !!c.mute, !!c.rev, c.fadeIn, c.fadeOut]) : null })) })),
        });
    });
    const storeKeys = () => page.evaluate(() => new Promise((resolve, reject) => { const rq = indexedDB.open('studiovoix', 1); rq.onerror = () => reject(rq.error); rq.onsuccess = () => { const db = rq.result, k = db.transaction('audio').objectStore('audio').getAllKeys(); k.onsuccess = () => { db.close(); resolve(k.result); }; k.onerror = () => reject(k.error); }; }));

    await page.goto(url, { waitUntil: 'load' });
    await ready();
    // Un projet avec de quoi vérifier : la démo (instru + deux voix), une piste verrouillée, un volume changé, une prise déplacée.
    await page.click('#demoBtn');
    await page.waitForFunction(() => window.__studiovoix.instru && window.__studiovoix.tracks.filter((t) => t.take).length >= 2, null, { timeout: 120000 });
    await settled();
    await page.evaluate(() => {
        const s = window.__studiovoix;
        document.querySelector(`#tracks .track[data-id="${s.tracks[0].id}"] .lock`).click();
    });
    await page.evaluate(() => { const s = window.__studiovoix; s.tracks[1].take.startSec = 0.37; s.tracks[1].volumeDb = -3; });
    // Un mode par piste (piste 1 : Correction, mode de départ ; piste 2 : Style, choisi à la main) et un écart par type réglé.
    await page.evaluate(() => { const sel = document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[1].id}"] select.style`); sel.value = 'trap'; sel.dispatchEvent(new Event('change', { bubbles: true })); });
    await page.evaluate(() => { const r = document.querySelector('#roleList input[data-role="manual_back"]'); if (r) { r.value = '-11'; r.dispatchEvent(new Event('input', { bubbles: true })); r.dispatchEvent(new Event('change', { bubbles: true })); } });
    await page.evaluate(() => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[1].id}"] .lock`).click());   // un geste réel : marque le projet à sauvegarder
    await page.evaluate(() => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[1].id}"] .lock`).click());
    await settled();
    // Montage : la prise de la piste 2 est coupée en deux (clic sur la prise pour y placer le curseur, puis « ✂ Couper »),
    // et le second bout est mis en muet par l'état de la page : les bouts doivent revenir tels quels.
    const laneEl = page.locator(`#tracks .track[data-id="${await page.evaluate(() => window.__studiovoix.tracks[1].id)}"] .lane`);
    await laneEl.scrollIntoViewIfNeeded();   // sur téléphone la ligne de la piste 2 est sous le bas de l'écran
    const lane = await laneEl.boundingBox();
    if (device?.hasTouch) await page.touchscreen.tap(lane.x + lane.width * 0.4, lane.y + lane.height / 2);
    else await page.mouse.click(lane.x + lane.width * 0.4, lane.y + lane.height / 2);
    await page.locator('#cutBtn').scrollIntoViewIfNeeded();
    await (device?.hasTouch ? page.tap('#cutBtn') : page.click('#cutBtn'));
    await page.waitForFunction(() => window.__studiovoix.tracks[1].take.clips?.length === 2, null, { timeout: 30000 });
    await settled();
    await page.waitForTimeout(1500);   // sauvegarde automatique
    const before = await snapshot();
    const b = JSON.parse(before);
    check('projet de départ', b.tracks.length >= 2 && b.instru && b.tracks[0].locked && b.tracks[1].takes[0].at === 0.37 && b.tracks[0].correction && !b.tracks[1].correction && b.tracks[1].style === 'trap' && b.roleOffsets.manual_back === -11 && b.tracks[1].takes[0].clips?.length === 2, `${b.tracks.length} pistes, instru « ${b.instru?.name} », piste 1 verrouillée : ${b.tracks[0].locked} et en Correction : ${b.tracks[0].correction}, piste 2 en Style ${b.tracks[1].style}, prise 2 à ${b.tracks[1].takes[0].at} s, écart des backs ${b.roleOffsets.manual_back} LU, prise 2 montée en ${b.tracks[1].takes[0].clips?.length} bouts`);

    // 1) Enregistrer le projet dans un fichier.
    const [download] = await Promise.all([page.waitForEvent('download', { timeout: 120000 }), page.click('#projSaveBtn')]);
    const file = path.join(work, 'projet.studiovoix');
    await download.saveAs(file);
    const bytes = fs.readFileSync(file);
    check('fichier enregistré', bytes.length > 100000 && bytes.subarray(0, 8).toString('latin1') === 'SVPROJ1\n' && /\.studiovoix$/.test(download.suggestedFilename()), `« ${download.suggestedFilename()} », ${(bytes.length / 1048576).toFixed(1)} Mo`);
    const status1 = await page.evaluate(() => document.getElementById('status').textContent);
    check('message d\'enregistrement', /Projet enregistré/.test(status1), status1.slice(0, 110));
    check('enregistrer ne change pas le projet', (await snapshot()) === before, 'empreinte identique');

    // 2) Fichiers refusés : le projet en cours ne change pas, rien ne traîne dans la sauvegarde.
    const refuse = async (name, data, want) => {
        const f = path.join(work, `mauvais-${name.replace(/[^a-z]+/g, '-')}.studiovoix`);
        fs.writeFileSync(f, data);
        dialogs.length = 0;
        await page.setInputFiles('#projFile', f);
        await page.waitForFunction(() => /impossible/.test(document.getElementById('status').textContent), null, { timeout: 60000 });
        const alertText = dialogs.find((d) => d.type === 'alert')?.text || '';
        const keys = await storeKeys();
        check(`refus : ${name}`, want.test(alertText) && (await snapshot()) === before && !keys.some((k) => String(k).startsWith('imp:')) && !dialogs.some((d) => d.type === 'confirm'),
            `« ${alertText.replace(/\s+/g, ' ').slice(0, 150)} » ; projet inchangé, ${keys.length} sons en sauvegarde`);
        await page.evaluate(() => { document.getElementById('status').textContent = '…'; });
    };
    const bad = Buffer.from(bytes); bad[bytes.length - 1000] ^= 1;
    await refuse('un son abîmé', bad, /abîmé/);
    await refuse('fichier tronqué', bytes.subarray(0, bytes.length - 4096), /tronqué/);
    await refuse('autre type de fichier', Buffer.from('RIFF....WAVEfmt et la suite, ce n\'est pas un projet'), /signature/);
    await refuse('fichier vide', Buffer.alloc(0), /trop court/);

    // 3) Ouverture abandonnée à la question : rien ne change.
    answer = false; dialogs.length = 0;
    await page.setInputFiles('#projFile', file);
    await page.waitForFunction(() => /abandonnée/.test(document.getElementById('status').textContent), null, { timeout: 60000 });
    check('ouverture abandonnée : projet inchangé', (await snapshot()) === before && dialogs.some((d) => d.type === 'confirm' && /sera remplacé/.test(d.text)), dialogs.find((d) => d.type === 'confirm')?.text.replace(/\s+/g, ' ').slice(0, 140));
    answer = true;

    // 4) Nouveau projet (tout effacé), puis ouverture du fichier : le projet revient à l'identique.
    await page.click('#newBtn');
    await page.waitForFunction(() => !window.__studiovoix.instru && window.__studiovoix.tracks.every((t) => !t.take), null, { timeout: 60000 });
    check('projet effacé avant l\'ouverture', (await snapshot()) !== before, 'page vide');
    await page.waitForTimeout(1500);   // sauvegarde automatique de la page vide
    await Promise.all([page.waitForEvent('load', { timeout: 120000 }), page.setInputFiles('#projFile', file)]);
    await ready();
    await page.waitForFunction(() => window.__studiovoix.instru && window.__studiovoix.tracks.some((t) => t.take), null, { timeout: 120000 });
    await settled();
    const after = await snapshot();
    check('projet rouvert à l\'identique (pistes, cadenas, places, sons au bit près)', after === before, after === before ? `${b.tracks.length} pistes, ${b.tracks.reduce((n, t) => n + t.takes.length, 0)} prises, instru` : `avant ${before.slice(0, 300)} … après ${after.slice(0, 300)}`);
    const keys = await storeKeys();
    check('aucun son provisoire laissé dans la sauvegarde', !keys.some((k) => String(k).startsWith('imp:')), `${keys.length} sons`);
    // 5) Le projet rouvert se joue et se traite (pistes traitées après rechargement).
    const done = await page.evaluate(() => window.__studiovoix.tracks.filter((t) => t.take && !t.noFx).every((t) => t.processed && t.status === 'done'));
    check('pistes du projet rouvert traitées', done, 'toutes les pistes avec effet ont leur son traité');
    // 6) Second aller-retour : le fichier réenregistré contient les mêmes sons.
    const [d2] = await Promise.all([page.waitForEvent('download', { timeout: 120000 }), page.click('#projSaveBtn')]);
    const file2 = path.join(work, 'projet2.studiovoix');
    await d2.saveAs(file2);
    const b2 = fs.readFileSync(file2);
    check('réenregistré : même taille de sons', Math.abs(b2.length - bytes.length) < 4096, `${bytes.length} puis ${b2.length} octets`);
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
