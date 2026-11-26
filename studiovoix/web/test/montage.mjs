// Essai des outils de montage de StudioVoix Web dans la page (Chromium sans écran, Playwright), avec la démo intégrée.
// Chaque outil est lancé par les vrais boutons et gestes de la page ; après chaque geste, le rendu de la piste
// (take.mono, startSec) est comparé à un rendu attendu refait ici à partir du son d'origine, et la lecture « Mix »
// rendue hors ligne (piste seule en solo) est mesurée dans la zone touchée.
//   node web/test/montage.mjs <url> [capture.png]
//   DEVICE="Pixel 7" node web/test/montage.mjs <url> [capture.png]   → mêmes gestes au doigt (toucher, glisser)
import { createRequire } from 'node:module';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium, devices } = require('playwright');

const [url, shot] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/montage.mjs <url> [capture.png]'); process.exit(2); }
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
let bad = 0;
function check(name, ok, detail = '') {
    console.log(`${stamp()} ${ok ? 'OK   ' : 'ÉCHEC'} ${name}${detail ? ' — ' + detail : ''}`);
    if (!ok) ++bad;
    return ok;
}
const device = process.env.DEVICE ? devices[process.env.DEVICE] : null;
if (process.env.DEVICE && !device) throw new Error('appareil inconnu : ' + process.env.DEVICE);
const touch = !!device?.hasTouch;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
const page = await (await browser.newContext({ ...(device || {}) })).newPage();
const cdp = touch ? await page.context().newCDPSession(page) : null;
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));

// ---- gestes
const view = () => page.evaluate(() => {
    const st = window.__studiovoix, m = st.montage;
    let end = st.instru ? st.instru.seconds : 0;
    for (const t of st.tracks) if (t.take) end = Math.max(end, t.take.startSec + t.take.mono.length / t.take.sampleRate);
    const total = Math.max(end, 10);
    return { start: m.start, dur: total / m.zoom, total, zoom: m.zoom, head: m.head };
});
async function lanePoint(id, sec) {
    const lane = page.locator(`.track[data-id="${id}"] .lane`);
    await lane.evaluate((e) => e.scrollIntoView({ block: 'center' }));
    const b = await lane.boundingBox(), v = await view();
    return { x: b.x + (sec - v.start) / v.dur * b.width, y: b.y + b.height / 2, b, v };
}
async function tapXY(x, y) { if (touch) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y); }
const menuOpen = () => page.evaluate(() => !document.getElementById('clipMenu').hidden);
async function closeMenu() {   // par le vrai bouton ✕ du menu
    if (!(await menuOpen())) return;
    const l = page.locator('#clipClose');
    if (touch) await l.tap(); else await l.click();
}
async function tapSec(id, sec) { await closeMenu(); const p = await lanePoint(id, sec); await tapXY(p.x, p.y); return p; }
// Menu du bout à l'instant sec de la piste id : clic droit à la souris, appui long (0,75 s) au doigt.
async function openMenuAt(id, sec) {
    await closeMenu();
    const p = await lanePoint(id, sec);
    if (!touch) await page.mouse.click(p.x, p.y, { button: 'right' });
    else {
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.x, y: p.y }] });
        await page.waitForTimeout(750);
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await page.waitForTimeout(250);   // le doigt vient de se lever : le menu n'écoute les touchers qu'un instant après
    }
    try { await page.waitForFunction(() => !document.getElementById('clipMenu').hidden, null, { timeout: 3000 }); } catch (err) {
        const seen = await page.evaluate(() => ({ status: document.getElementById('status').textContent, sel: window.__studiovoix.montage.sel, journal: [...document.querySelectorAll('#log div')].map((d) => d.textContent).filter((x) => !/\[moteur\]/.test(x)).slice(0, 8) }));
        throw new Error(`menu du bout non ouvert (piste ${id}, ${sec.toFixed(2)} s, point ${p.x.toFixed(0)},${p.y.toFixed(0)}) : ${JSON.stringify(seen)}`);
    }
    return p;
}
// Milieu du bout sélectionné (pour y ouvrir son menu).
const selCentre = () => page.evaluate(() => {
    const st = window.__studiovoix, m = st.montage, t = st.tracks.find((x) => x.id === m.sel.trackId), k = t?.take;
    if (!k) return null;
    const c = k.clips ? k.clips.find((x) => x.id === m.sel.clipId) : { at: k.startSec, len: k.mono.length };
    return c ? { id: t.id, sec: c.at + c.len / k.sampleRate / 2 } : null;
});
// Un bouton ou une liste de la page. Ceux du menu du bout (#clip…) : le menu est d'abord ouvert par un clic droit (ou
// un appui long) sur le bout sélectionné, s'il ne l'est pas déjà.
async function target(sel) {
    const inMenu = /^#clip/.test(sel);
    if (!inMenu) await closeMenu();
    else if (!(await menuOpen())) {
        const c = await selCentre();
        if (!c) throw new Error('aucun bout sélectionné : impossible d\'ouvrir le menu pour ' + sel);
        await openMenuAt(c.id, c.sec);
    }
    const l = page.locator(sel).first();
    if (!inMenu) await l.evaluate((e) => e.scrollIntoView({ block: 'center' }));
    return l;
}
async function press(sel) { const l = await target(sel); if (touch) await l.tap(); else await l.click(); }
async function choose(sel, value) { const l = await target(sel); await l.selectOption(String(value)); }
// Glisser de (x, y) à (x + dx, y + dy) : souris, ou doigt (événements tactiles de Chromium) en affichage téléphone.
// holdMs : doigt maintenu avant de bouger (nécessaire pour emmener un bout vers une autre piste). midway : contrôle fait
// pendant le glissement, avant de lâcher.
async function dragXY(x, y, dx, dy = 0, { holdMs = 0, midway = null } = {}) {
    await closeMenu();
    const steps = 8;
    let seen = null;
    if (!touch) {
        await page.mouse.move(x, y); await page.mouse.down();
        for (let k = 1; k <= steps; ++k) await page.mouse.move(x + dx * k / steps, y + dy * k / steps);
        if (midway) seen = await midway();
        await page.mouse.up();
        return seen;
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    if (holdMs) await page.waitForTimeout(holdMs);
    for (let k = 1; k <= steps; ++k) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + dx * k / steps, y: y + dy * k / steps }] }); await page.waitForTimeout(16); }
    if (midway) seen = await midway();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    return seen;
}
// Glisser le bout placé à l'instant sec de la piste `from` jusqu'à la ligne de la piste `to` (0 : piste instru), avec un
// écart horizontal de dx pixels. Rend ce qu'on voit pendant le glissement (ligne visée, ombre du bout).
async function dragToTrack(from, sec, to, dx) {
    const p = await lanePoint(from, sec);
    const tb = await page.locator(`.track[data-id="${to}"] .lane`).boundingBox();
    return { p, seen: await dragXY(p.x, p.y, dx, tb.y + tb.height / 2 - p.y, { holdMs: 320, midway: () => page.evaluate((to) => {
        const lane = document.querySelector(`.track[data-id="${to}"] .lane`), g = document.querySelector('.clipghost');
        return { drop: lane.classList.contains('drop'), nodrop: lane.classList.contains('nodrop'), ghostHere: !!g && g.parentElement === lane, scrollY: window.scrollY };
    }, to) }) };
}
const settled = () => page.waitForFunction(() => document.body.dataset.busy === '0' && window.__studiovoix.tracks.every((t) => !t.take || t.processed || t.noFx), null, { timeout: 180000 });
// Attend une sauvegarde postérieure à la ligne de journal `after` (le journal est récent en haut et plafonné à 200
// lignes : on compare des places, pas un nombre de lignes).
const waitSave = (after) => page.waitForFunction((src) => {
    const lines = [...document.querySelectorAll('#log div')].map((d) => d.textContent), re = new RegExp(src);
    const iSave = lines.findIndex((x) => /Projet sauvegardé/.test(x)), iMark = lines.findIndex((x) => re.test(x));
    return iSave >= 0 && iMark >= 0 && iSave < iMark;
}, after.source, { timeout: 30000 });
const status = () => page.textContent('#status');
const logTop = () => page.evaluate(() => document.querySelector('#log div')?.textContent || '');
const lastLog = (re) => page.evaluate((src) => [...document.querySelectorAll('#log div')].map((d) => d.textContent).find((x) => new RegExp(src).test(x)) || '', re.source);
const info = (i) => page.evaluate((i) => window.__mt.info(i), i);
const cmp = (i, name, ops, tol = 0) => page.evaluate(([i, name, ops, tol]) => window.__mt.cmp(i, name, ops, tol), [i, name, ops, tol]);
const mixKeep = (name) => page.evaluate((name) => window.__mt.mixKeep(name), name);
const mixCmp = (name, a, b) => page.evaluate(([name, a, b]) => window.__mt.mixCmp(name, a, b), [name, a, b]);
const undoLeft = () => page.evaluate(() => window.__studiovoix.montage.undo.length);
const dB = (v) => `${v.toFixed(1)} dB`;

try {
    await page.goto(url, { waitUntil: 'load' });
    for (let k = 0; k < 20; ++k) {   // coi-serviceworker recharge la page une fois (isolement) : attendre la page isolée
        try { if (await page.evaluate(() => window.crossOriginIsolated === true)) break; } catch (_) { /* rechargement en cours */ }
        await page.waitForTimeout(500);
    }
    await page.waitForLoadState('load');
    await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Moteur prêt'), null, { timeout: 60000 });
    console.log(stamp(), `moteur prêt (${device ? process.env.DEVICE + ', au doigt' : 'ordinateur, à la souris'})`);
    await press('#demoBtn');
    await page.waitForFunction(() => window.__studiovoix.tracks.length >= 2 && window.__studiovoix.tracks.every((t) => t.take), null, { timeout: 180000 });
    await settled();

    // Outils de mesure dans la page (les sons restent dans la page : seuls des nombres reviennent ici).
    await page.evaluate(() => {
        const st = window.__studiovoix, T = (i) => st.tracks[i];
        const hash = (x) => { const v = new Int32Array(x.buffer, x.byteOffset, x.length); let h = 2166136261; for (let i = 0; i < v.length; ++i) { h ^= v[i]; h = Math.imul(h, 16777619); } return h >>> 0; };
        const rms = (x, a, b) => { let e = 0; a = Math.max(0, a); b = Math.min(x.length, b); for (let i = a; i < b; ++i) e += x[i] * x[i]; return Math.sqrt(e / Math.max(1, b - a)); };
        const db = (v) => 20 * Math.log10(v + 1e-12);
        const fadeW = (i, n) => 0.5 - 0.5 * Math.cos(Math.PI * (i + 0.5) / n);
        const grow = (x, n) => { if (n <= x.length) return x; const y = new Float32Array(n); y.set(x); return y; };
        window.__mt = {
            keep: {}, mixes: {},
            save(name, i) { this.keep[name] = T(i).take.mono.slice(); },
            info(i) {
                const t = T(i), k = t.take;
                return { id: t.id, name: t.name, locked: !!t.locked, takes: t.takes.length, hasTake: !!k, n: k ? k.mono.length : 0, startSec: k ? k.startSec : 0, sr: k ? k.sampleRate : 0,
                    clips: k?.clips ? k.clips.map((c) => ({ ...c })) : null, hash: k ? hash(k.mono) : 0, same: k ? Object.keys(this.keep).filter((n) => this.keep[n] === k.mono || (this.keep[n].length === k.mono.length && hash(this.keep[n]) === hash(k.mono))) : [] };
            },
            // Rendu attendu : son gardé `name`, puis opérations simples (indices en échantillons), comparé à la prise de la piste i.
            cmp(i, name, ops, tol) {
                let x = this.keep[name].slice();
                for (const [op, ...p] of ops) {
                    if (op === 'zero') x.fill(0, p[0], p[1]);
                    else if (op === 'gain') { const g = Math.pow(10, p[2] / 20); for (let j = p[0]; j < p[1]; ++j) x[j] = x[j] * g; }
                    else if (op === 'rev') x.subarray(p[0], p[1]).reverse();
                    else if (op === 'add') { const s = this.keep[p[0]]; x = grow(x, p[3] + (p[2] - p[1])); for (let j = 0; j < p[2] - p[1]; ++j) x[p[3] + j] += s[p[1] + j]; }
                    else if (op === 'fadeIn') { for (let j = 0; j < p[1]; ++j) x[p[0] + j] = x[p[0] + j] * fadeW(j, p[1]); }
                    else if (op === 'fadeOut') { for (let j = 0; j < p[1]; ++j) x[p[0] - p[1] + j] = x[p[0] - p[1] + j] * (1 - fadeW(j, p[1])); }
                    else if (op === 'shift') { const y = new Float32Array(x.length + p[1]); y.set(x.subarray(0, p[0])); y.set(x.subarray(p[0]), p[0] + p[1]); x = y; }
                    else if (op === 'cut') x = x.slice(p[0], p[1]);
                    else throw new Error('opération inconnue : ' + op);
                }
                const got = T(i).take.mono;
                let max = 0;
                for (let j = 0; j < Math.min(x.length, got.length); ++j) { const d = Math.abs(x[j] - got[j]); if (d > max) max = d; }
                return { ok: x.length === got.length && max <= tol, max, got: got.length, want: x.length };
            },
            mix() { const sr = st.tracks.find((t) => t.take)?.take.sampleRate || 44100; return { x: window.__svRenderPlayed('mix', 0, sr).left, sr }; },
            mixKeep(name) { this.mixes[name] = this.mix().x.slice(); },
            // Lecture « Mix » rendue hors ligne, zone [a, b] s : niveau avant, niveau maintenant, niveau de la différence.
            mixCmp(name, a, b) {
                const m = this.mix(), old = this.mixes[name], A = Math.round(a * m.sr), B = Math.round(b * m.sr);
                const diff = new Float32Array(Math.max(0, B - A));
                for (let j = 0; j < diff.length; ++j) diff[j] = (m.x[A + j] || 0) - (old[A + j] || 0);
                return { beforeDb: db(rms(old, A, B)), nowDb: db(rms(m.x, A, B)), diffDb: db(rms(diff, 0, diff.length)) };
            },
            rms(i, a, b) { return rms(T(i).take.mono, a, b); },
            rmsKeep(name, a, b) { return rms(this.keep[name], a, b); },
        };
    });
    const A = await info(0), B = await info(1);   // A : voix principale ; B : seconde voix
    const sr = A.sr, S = (sec) => Math.round(sec * sr);
    await page.evaluate(() => { window.__mt.save('A', 0); window.__mt.save('B', 1); });
    console.log(stamp(), `démo : « ${A.name} » ${(A.n / sr).toFixed(1)} s à ${A.startSec} s, « ${B.name} » ${(B.n / sr).toFixed(1)} s ; ${sr} Hz`);
    check('départ : prises sans liste de bouts (un seul bout implicite)', A.clips === null && B.clips === null && A.startSec === 0);
    // Piste A seule en solo (vrai bouton S) : la lecture « Mix » rendue hors ligne ne contient qu'elle.
    await press(`.track[data-id="${A.id}"] button.tog.s`);
    await mixKeep('depart');

    // ---- 1. sélection au toucher, barre permanente, menu du bout
    const p12 = await tapSec(A.id, 12);
    const sel1 = await page.evaluate(() => ({ ...window.__studiovoix.montage.sel, head: window.__studiovoix.montage.head, menu: !document.getElementById('clipMenu').hidden, title: document.getElementById('clipTitle').textContent, selTrack: window.__studiovoix.selectedId }));
    check(`toucher un bout le sélectionne (${touch ? 'doigt' : 'souris'}), sans ouvrir de menu`, sel1.trackId === A.id && !sel1.menu && /Bout 1 sur 1/.test(sel1.title) && sel1.selTrack === A.id, sel1.title);
    check('toucher place aussi le curseur à cet endroit', Math.abs(sel1.head - 12) < 2 * p12.v.dur / p12.b.width, `curseur à ${sel1.head.toFixed(3)} s`);
    {
        const measure = (css) => page.evaluate((css) => {
            const vw = document.documentElement.clientWidth, vh = window.innerHeight;
            return [...document.querySelectorAll(css)].map((e) => { const r = e.getBoundingClientRect(); return { id: e.id || e.className, text: e.textContent.trim().slice(0, 24), w: r.width, h: r.height, left: r.left, right: r.right, top: r.top, bottom: r.bottom, vw, vh, shown: r.width > 0 && r.height > 0 }; });
        }, css);
        const bar = await measure('#editBar button');
        check('barre permanente : seulement Couper, Annuler, Rétablir et le zoom − / +', bar.length === 5 && bar.map((b) => b.text).join(' | ') === '✂ Couper | ↶ Annuler | ↷ Rétablir | 🔍 − | 🔍 +' && bar.every((b) => b.shown && b.h >= 40 && b.left >= -0.5 && b.right <= b.vw + 0.5), bar.map((b) => `${b.text} ${b.w.toFixed(0)}×${b.h.toFixed(0)}`).join(' ; '));
        const hs = await page.evaluate(() => [...document.querySelectorAll('.trimh')].map((e) => { const r = e.getBoundingClientRect(); return { w: r.width, h: r.height, hidden: e.hidden }; }));
        check('poignées pour rogner : deux, larges d\'au moins 30 px', hs.length === 2 && hs.every((h) => !h.hidden && h.w >= 30 && h.h >= 40), hs.map((h) => `${h.w.toFixed(0)}×${h.h.toFixed(0)} px`).join(', '));
        await openMenuAt(A.id, 8);
        const items = await measure('#clipMenu button, #clipMenu select'), box = (await measure('#clipMenu'))[0];
        const first = await page.evaluate(() => document.querySelector('#clipMenu > button').id);
        const low = items.filter((b) => !b.shown || b.h < 40), out = items.filter((b) => b.left < -0.5 || b.right > b.vw + 0.5);
        check(`${touch ? 'appui long' : 'clic droit'} sur un bout : son menu s'ouvre, « Supprimer » en premier`, first === 'clipDel' && /Supprimer/.test(items.find((b) => b.id === 'clipDel')?.text || '') && /Bout 1 sur 1/.test(await page.textContent('#clipTitle')), `${items.length} commandes : ${items.map((b) => b.text).filter(Boolean).join(' · ')}`);
        check('menu du bout : commandes hautes d\'au moins 40 px, rien ne déborde de l\'écran', items.length >= 17 && low.length === 0 && out.length === 0 && box.left >= 0 && box.right <= box.vw && box.top >= 0 && box.bottom <= box.vh, low.length || out.length ? [...low, ...out].map((b) => `${b.id} ${b.w.toFixed(0)}×${b.h.toFixed(0)}`).join(', ') : `menu ${box.w.toFixed(0)}×${box.h.toFixed(0)} px dans un écran de ${box.vw}×${box.vh} ; hauteur min ${Math.min(...items.map((b) => b.h)).toFixed(0)} px`);
        check('le menu place le curseur à l\'endroit visé', Math.abs((await view()).head - 8) < 2 * p12.v.dur / p12.b.width, `curseur à ${(await view()).head.toFixed(3)} s`);
        await page.keyboard.press('Escape');
        check('Échap ferme le menu', !(await menuOpen()));
        await tapSec(A.id, 12);
    }

    // ---- 2. couper au curseur (deux fois) : rendu inchangé au bit près
    await press('#cutBtn');
    let a = await info(0);
    const s1 = a.clips?.[0]?.len || 0;
    check(`bouton « ✂ Couper » ${touch ? 'au doigt' : 'à la souris'} : deux bouts, coupe à l'endroit du curseur`, a.clips?.length === 2 && Math.abs(s1 / sr - sel1.head) < 1 / sr && a.clips[1].off === s1 && Math.abs(a.clips[1].at - s1 / sr) < 1e-9, `coupe à ${(s1 / sr).toFixed(3)} s ; ${await status()}`);
    let r = await cmp(0, 'A', []);
    check('couper : rendu de la piste identique au son d\'origine, au bit près', r.ok && a.startSec === 0, `écart max ${r.max}`);
    check('couper : journal (geste, piste, bout, instant)', /Montage — « .+ » : couper, bout 1\/1 \(0:00\.00 → .+\), au curseur, à 0:1[12]\.\d\d/.test(await lastLog(/Montage — /)), await lastLog(/Montage — /));
    await waitSave(/Montage — « .+ » : couper/);
    check('couper : aucun son réécrit dans la sauvegarde (les sources sont écrites une seule fois)', /\(0 son\(s\) écrit/.test(await lastLog(/Projet sauvegardé/)), await lastLog(/Projet sauvegardé/));
    await tapSec(A.id, 20);
    await press('#cutBtn');
    a = await info(0);
    const s2 = (a.clips?.[0]?.len || 0) + (a.clips?.[1]?.len || 0);
    r = await cmp(0, 'A', []);
    check('seconde coupe : trois bouts, rendu toujours identique au bit près', a.clips?.length === 3 && r.ok && Math.abs(s2 / sr - 20) < 0.2, `bouts : 0 → ${(s1 / sr).toFixed(2)} → ${(s2 / sr).toFixed(2)} → ${(A.n / sr).toFixed(2)} s`);
    await settled();
    let m = await mixCmp('depart', 0, A.n / sr);
    check('couper : la lecture « Mix » ne change pas', m.diffDb < m.beforeDb - 40, `différence ${dB(m.diffDb)} pour un mix à ${dB(m.beforeDb)}`);
    const mid = (s1 + s2) / 2 / sr, zA = s1 / sr + 4, zB = s2 / sr - 0.5;   // zone de mesure du mix : loin du début du bout (traîne des effets)

    // ---- 3. muet sur un seul bout, annuler, rétablir
    await tapSec(A.id, mid);
    check('toucher le bout du milieu le sélectionne', /Bout 2 sur 3/.test(await page.textContent('#clipTitle')), await page.textContent('#clipTitle'));
    await press('#clipMute');
    r = await cmp(0, 'A', [['zero', s1, s2]]);
    check('muet : silence sur le bout, le reste au bit près', r.ok && (await info(0)).clips[1].mute === true, `écart max ${r.max}`);
    await settled();
    m = await mixCmp('depart', zA, zB);
    check('muet : la lecture « Mix » se tait sur le bout', m.nowDb < m.beforeDb - 20, `mix de ${zA.toFixed(1)} à ${zB.toFixed(1)} s : ${dB(m.beforeDb)} → ${dB(m.nowDb)}`);
    if (shot) {   // captures : bout sélectionné (contour jaune, poignées) et muet, barre permanente ; puis son menu ouvert
        await page.locator('#editBar').evaluate((e) => e.scrollIntoView({ block: 'start' }));
        await page.screenshot({ path: shot });
        await openMenuAt(A.id, mid);
        await page.screenshot({ path: shot.replace(/\.png$/, '-menu.png') });
        await closeMenu();
        console.log(stamp(), 'captures :', shot, 'et', shot.replace(/\.png$/, '-menu.png'));
    }
    await press('#editBar .mtUndo');
    r = await cmp(0, 'A', []);
    check('annuler le muet : rendu d\'origine au bit près, trois bouts', r.ok && (await info(0)).clips.length === 3 && /Montage — annulé : muet \(« .+ »\)/.test(await lastLog(/Montage — annulé/)), await lastLog(/Montage — annulé/));
    await press('#editBar .mtRedo');
    r = await cmp(0, 'A', [['zero', s1, s2]]);
    check('rétablir : le bout est de nouveau muet', r.ok, await status());
    await press('#editBar .mtUndo');
    await settled();
    m = await mixCmp('depart', 0, A.n / sr);
    check('annuler encore : la lecture « Mix » revient', (await cmp(0, 'A', [])).ok && m.diffDb < m.beforeDb - 40, `différence ${dB(m.diffDb)}`);

    // ---- 3 bis. trois bouts → clic droit (appui long) sur celui du milieu → Supprimer ; touche Suppr ; « Couper ici »
    {
        const before = await info(0);
        await openMenuAt(A.id, mid);
        await press('#clipDel');
        a = await info(0);
        r = await cmp(0, 'A', [['zero', s1, s2]]);
        const still = a.clips?.length === 2 && JSON.stringify(a.clips[0]) === JSON.stringify(before.clips[0]) && JSON.stringify(a.clips[1]) === JSON.stringify(before.clips[2]);
        check(`deux coupes = trois bouts ; ${touch ? 'appui long' : 'clic droit'} sur celui du milieu → Supprimer : son son a disparu du rendu, les deux autres n'ont pas bougé`, r.ok && still && !(await menuOpen()), `bouts restants : 0 → ${(a.clips[0].len / sr).toFixed(2)} s et ${a.clips[1].at.toFixed(2)} → ${(a.clips[1].at + a.clips[1].len / sr).toFixed(2)} s ; écart max ${r.max}`);
        await settled();
        m = await mixCmp('depart', zA, zB);
        check('supprimer le bout du milieu : la lecture « Mix » se tait à sa place', m.nowDb < m.beforeDb - 20, `${dB(m.beforeDb)} → ${dB(m.nowDb)}`);
        await press('#editBar .mtUndo');
        check('annuler la suppression : trois bouts, rendu d\'origine au bit près', (await info(0)).clips.length === 3 && (await cmp(0, 'A', [])).ok);
        await tapSec(A.id, mid);
        await page.keyboard.press('Delete');
        a = await info(0);
        check('touche Suppr sur le bout sélectionné : il est supprimé', a.clips?.length === 2 && (await cmp(0, 'A', [['zero', s1, s2]])).ok, await lastLog(/Montage — /));
        await press('#editBar .mtUndo');
        await openMenuAt(A.id, 6);
        await press('#clipCut');
        a = await info(0);
        const lw = (await page.locator(`.track[data-id="${A.id}"] .lane`).boundingBox()).width;
        check('menu → « Couper ici » : coupe à l\'endroit du clic, rendu inchangé', a.clips?.length === 4 && Math.abs(a.clips[0].len / sr - 6) < 2 * (await view()).dur / lw && (await cmp(0, 'A', [])).ok, `coupe à ${(a.clips[0].len / sr).toFixed(3)} s`);
        await press('#editBar .mtUndo');
        await tapSec(A.id, mid);
    }

    // ---- 4. gain du bout (avant les effets)
    for (let k = 0; k < 6; ++k) await press('#clipGainDown');
    r = await cmp(0, 'A', [['gain', s1, s2, -6]]);
    const ratio = await page.evaluate(([a, b]) => window.__mt.rms(0, a, b) / window.__mt.rmsKeep('A', a, b), [s1, s2]);
    check('gain −6 dB sur le bout : niveau ÷ 2 sur le bout, le reste au bit près', r.ok && Math.abs(ratio - 0.5012) < 1e-3 && (await info(0)).clips[1].gainDb === -6, `rapport ${ratio.toFixed(4)} ; ${await page.textContent('#clipGain')}`);
    await settled();
    m = await mixCmp('depart', zA, zB);
    check('gain : la lecture « Mix » change sur le bout (traitement refait sur le nouveau rendu)', m.diffDb > m.beforeDb - 45, `mix ${dB(m.beforeDb)} → ${dB(m.nowDb)}, différence ${dB(m.diffDb)} : la chaîne d'effets de la piste (niveleur, compression) rattrape presque tout le gain du bout`);
    {   // même bout, piste en « Brut » (aucun effet) : le gain du bout s'entend tel quel dans le mix
        // Le bouton d'effets de la piste fait le tour des modes (Brut → Corrigé → Lissé → Style) : on appuie jusqu'à
        // « Brut », puis jusqu'au mode de départ (quel qu'il soit : « Corrigé » pour une nouvelle piste).
        const modeOf = () => page.evaluate(() => { const t = window.__studiovoix.tracks[0]; return t.noFx ? 'none' : t.correction ? (t.smooth ? 'correction, voix lissée' : 'correction') : t.smooth ? 'smooth' : 'style'; });
        const mode0 = await modeOf();
        for (let k = 0; k < 4 && (await modeOf()) !== 'none'; ++k) await press(`.track[data-id="${A.id}"] button.tog.fx`);
        await settled();
        const raw = await page.evaluate(([a, b]) => ({ noFx: !!window.__studiovoix.tracks[0].noFx, refDb: 20 * Math.log10(window.__mt.rmsKeep('A', a, b)) }), [s1, s2]);
        const mm = await mixCmp('depart', s1 / sr, s2 / sr);
        check('gain, piste sans effet (« Brut ») : la lecture « Mix » baisse de 6 dB sur le bout', raw.noFx && Math.abs(mm.nowDb - (raw.refDb - 6)) < 0.05, `bout d'origine ${dB(raw.refDb)}, dans le mix ${dB(mm.nowDb)}`);
        for (let k = 0; k < 4 && (await modeOf()) !== mode0; ++k) await press(`.track[data-id="${A.id}"] button.tog.fx`);   // retour au mode de départ
        await settled();
        check('retour au mode d\'effets de départ', (await modeOf()) === mode0, mode0);
    }
    for (let k = 0; k < 6; ++k) await press('#editBar .mtUndo');
    check('annuler 6 fois : rendu d\'origine au bit près', (await cmp(0, 'A', [])).ok);

    // ---- 5. inverser
    await press('#clipRev');
    r = await cmp(0, 'A', [['rev', s1, s2]]);
    check('inverser : le bout est lu à l\'envers, le reste au bit près', r.ok && (await info(0)).clips[1].rev === true, `écart max ${r.max}`);
    await settled();
    m = await mixCmp('depart', zA, zB);
    check('inverser : la lecture « Mix » change sur le bout', m.diffDb > m.beforeDb - 20, `différence ${dB(m.diffDb)} pour un mix à ${dB(m.beforeDb)}`);
    await press('#clipRev');
    check('inverser deux fois : rendu d\'origine au bit près', (await cmp(0, 'A', [])).ok);
    await press('#editBar .mtUndo'); await press('#editBar .mtUndo');

    // ---- 6. dupliquer, supprimer
    await press('#clipDup');
    a = await info(0);
    r = await cmp(0, 'A', [['add', 'A', s1, s2, s2]]);
    check('dupliquer : la copie joue juste après (elle s\'ajoute au bout suivant)', a.clips?.length === 4 && r.ok && /Bout 4 sur 4/.test(await page.textContent('#clipTitle')), `écart max ${r.max} ; ${await page.textContent('#clipTitle')}`);
    await settled();
    m = await mixCmp('depart', s2 / sr + 1, s2 / sr + 6);
    check('dupliquer : la lecture « Mix » contient la copie', m.diffDb > m.beforeDb - 20, `différence ${dB(m.diffDb)} pour un mix à ${dB(m.beforeDb)}`);
    await press('#clipDel');
    a = await info(0);
    check('supprimer le bout (la copie) : rendu d\'origine au bit près, trois bouts', a.clips?.length === 3 && (await cmp(0, 'A', [])).ok && await page.evaluate(() => document.getElementById('clipMenu').hidden), await status());

    // ---- 7. fondus d'entrée et de sortie
    await tapSec(A.id, mid);
    await choose('#clipFadeIn', 0.5);
    await choose('#clipFadeOut', 0.25);
    r = await cmp(0, 'A', [['fadeIn', s1, S(0.5)], ['fadeOut', s2, S(0.25)]], 1e-6);
    a = await info(0);
    check('fondus d\'entrée 0,5 s et de sortie 0,25 s : courbe attendue, le reste intact', r.ok && a.clips[1].fadeIn === 0.5 && a.clips[1].fadeOut === 0.25, `écart max ${r.max.toExponential(1)} (tolérance 1e-6)`);
    await press('#editBar .mtUndo'); await press('#editBar .mtUndo');

    // ---- 8. rogner : poignée (glisser), réglage fin, re-dérouler
    {
        const before = (await info(0)).clips[1];
        const h = page.locator(`.track[data-id="${A.id}"] .trimh.end`);
        await h.evaluate((e) => e.scrollIntoView({ block: 'center' }));
        const hb = await h.boundingBox(), v = await view(), lw = (await page.locator(`.track[data-id="${A.id}"] .lane`).boundingBox()).width;
        const dx = -Math.round(lw * 0.08);
        await dragXY(hb.x + hb.width / 2, hb.y + hb.height / 2, dx);
        a = await info(0);
        const c = a.clips[1], cut = before.len - c.len, wantCut = -dx / lw * v.dur * sr;
        r = await cmp(0, 'A', [['zero', s1 + c.len, s2]]);
        check(`rogner la fin par la poignée (${touch ? 'doigt' : 'souris'}) : le bout raccourcit, silence à la place, source intacte`, r.ok && cut > 0 && Math.abs(cut - wantCut) < 3 * v.dur / lw * sr && c.off === before.off, `fin amenée de ${(s2 / sr).toFixed(2)} à ${((s1 + c.len) / sr).toFixed(2)} s`);
        await press('#clipTrimE1'); await press('#clipTrimE1'); await press('#clipTrimE1');
        const c3 = (await info(0)).clips[1];
        check('réglage fin : trois pas de 10 ms re-déroulent la fin de 30 ms', c3.len - c.len === 3 * S(0.01), `${c3.len - c.len} échantillons`);
        await press('#clipTrimS1');
        const c4 = (await info(0)).clips[1];
        r = await cmp(0, 'A', [['zero', s1, s1 + S(0.01)], ['zero', s1 + c3.len, s2]]);
        check('réglage fin du début : 10 ms rognés, le son ne bouge pas dans le temps', r.ok && c4.off === before.off + S(0.01) && c4.len === c3.len - S(0.01), `écart max ${r.max}`);
        const sb = await page.locator(`.track[data-id="${A.id}"] .trimh.start`).boundingBox();
        await dragXY(sb.x + sb.width / 2, sb.y + sb.height / 2, Math.round(lw * 0.03));
        const c5 = (await info(0)).clips[1];
        check('rogner le début par la poignée', c5.len < c4.len && c5.off > c4.off && c5.off + c5.len === c4.off + c4.len, `début amené à ${(c5.at).toFixed(2)} s`);
        const left = await undoLeft();
        for (let k = 0; k < 6; ++k) await press('#editBar .mtUndo');
        check('annuler les 6 gestes de rognage : rendu d\'origine au bit près', (await cmp(0, 'A', [])).ok && (await undoLeft()) === left - 6 && (await info(0)).clips[1].len === before.len);
    }

    // ---- 9. fondu croisé sur une coupe : le son d'origine revient
    await tapSec(A.id, 5);
    await press('#clipXfade');
    a = await info(0);
    r = await cmp(0, 'A', [], 1e-6);
    check('fondu croisé sur la coupe (les deux bords re-déroulés, fondus complémentaires) : son d\'origine', r.ok && a.clips[0].fadeOut > 0.02 && Math.abs(a.clips[0].fadeOut - a.clips[1].fadeIn) < 1e-12 && a.clips[0].len > s1, `fondu ${(a.clips[0].fadeOut * 1000).toFixed(1)} ms, écart max ${r.max.toExponential(1)} (tolérance 1e-6) ; ${await status()}`);
    await press('#editBar .mtUndo');

    // ---- 10. glisser un bout : il se déplace dans le temps
    {
        const p = await lanePoint(A.id, (s2 + A.n) / 2 / sr);
        const dx = Math.round(p.b.width * 0.06);
        await dragXY(p.x, p.y, dx);
        a = await info(0);
        const moved = Math.round(a.clips[2].at * sr) - s2, want = dx / p.b.width * p.v.dur * sr;
        r = await cmp(0, 'A', [['shift', s2, moved]]);
        check(`glisser le dernier bout (${touch ? 'doigt' : 'souris'}) : même son, plus tard, le reste en place`, r.ok && moved > 0 && Math.abs(moved - want) < 3 * p.v.dur / p.b.width * sr && a.startSec === 0, `déplacé de ${(moved / sr).toFixed(3)} s ; ${await status()}`);
        await settled();
        m = await mixCmp('depart', s2 / sr + 0.5, s2 / sr + 6);
        check('glisser : la lecture « Mix » change après le bout déplacé', m.diffDb > m.beforeDb - 20, `différence ${dB(m.diffDb)} pour un mix à ${dB(m.beforeDb)}`);
        await press('#editBar .mtUndo');
        check('annuler le glissement : rendu d\'origine au bit près', (await cmp(0, 'A', [])).ok);
    }

    // ---- 11. envoyer vers une autre piste en gardant la place
    // La seconde piste (même voix de démo) est d'abord décalée en glissant sa prise entière, comme avant le montage :
    // sinon le bout arriverait sur un son identique au sien (simple doublement, rattrapé par les effets de la piste).
    let b;
    {
        const left = await undoLeft(), pb = await lanePoint(B.id, 10);
        await dragXY(pb.x, pb.y, Math.round(pb.b.width * 0.05));
        b = await info(1);
        check(`glisser une prise sans montage (${touch ? 'doigt' : 'souris'}) : elle se déplace d'un bloc, sans liste de bouts, geste annulable`, b.clips === null && b.startSec > 1 && b.hash === B.hash && (await undoLeft()) === left + 1, `prise déplacée à ${b.startSec.toFixed(3)} s`);
    }
    const startB = b.startSec;
    await tapSec(A.id, mid);
    await choose('#clipSend', B.id);
    a = await info(0);
    b = await info(1);
    r = await cmp(0, 'A', [['zero', s1, s2]]);
    const rb = await cmp(1, 'B', [['add', 'A', s1, s2, Math.round((s1 / sr - startB) * sr)]]);
    check('envoyer vers la piste voisine : le bout quitte sa piste…', a.clips?.length === 2 && r.ok, `écart max ${r.max}`);
    check('… et arrive sur l\'autre au même instant du morceau', b.clips?.length === 2 && rb.ok && Math.abs(b.clips[1].at - s1 / sr) < 1e-9 && b.startSec === startB, `bout posé à ${b.clips?.[1]?.at.toFixed(3)} s sur « ${B.name} » (prise à ${startB.toFixed(3)} s) ; écart max ${rb.max}`);
    await settled();
    m = await mixCmp('depart', zA, zB);
    check('envoyer : la lecture « Mix » de la piste de départ se tait sur le bout', m.nowDb < m.beforeDb - 20, `${dB(m.beforeDb)} → ${dB(m.nowDb)}`);
    await press(`.track[data-id="${A.id}"] button.tog.s`); await press(`.track[data-id="${B.id}"] button.tog.s`);   // solo : piste B seule
    const mB1 = await page.evaluate(() => { const x = window.__mt.mix(); window.__mt.mixes.B1 = x.x.slice(); return true; });
    await press('#editBar .mtUndo');
    a = await info(0); b = await info(1);
    check('annuler l\'envoi : les deux pistes reviennent au bit près (la seconde sans liste de bouts)', (await cmp(0, 'A', [])).ok && (await cmp(1, 'B', [])).ok && b.clips === null && a.clips.length === 3 && mB1);
    await settled();
    m = await mixCmp('B1', zA, zB);
    check('envoyer : la lecture « Mix » de la piste d\'arrivée contenait le bout', m.diffDb > m.nowDb - 20, `piste d'arrivée, avec le bout ${dB(m.beforeDb)}, sans ${dB(m.nowDb)}, différence ${dB(m.diffDb)}`);
    await press('#editBar .mtUndo');
    b = await info(1);
    check('annuler le glissement de la prise : elle revient à sa place', b.clips === null && b.startSec === 0 && b.hash === B.hash, `prise à ${b.startSec} s`);
    await settled();
    await mixKeep('B0');   // seconde piste seule, à sa place d'origine

    // ---- 11 bis. glisser un bout d'une piste à l'autre (le geste principal), place dans le temps gardée
    {
        // écart horizontal de 5 px (moins que le seuil de 12 px) : le bout garde sa place exacte dans le temps
        let d = await dragToTrack(A.id, mid, B.id, 5);
        a = await info(0); b = await info(1);
        r = await cmp(0, 'A', [['zero', s1, s2]]);
        let rB = await cmp(1, 'B', [['add', 'A', s1, s2, s1]]);
        check(`glisser un bout vers une autre piste (${touch ? 'doigt maintenu' : 'souris'}) : pendant le geste, la ligne visée est mise en évidence et l'ombre du bout y est`, d.seen.drop && d.seen.ghostHere && !d.seen.nodrop, JSON.stringify(d.seen));
        check('… lâché : il quitte sa piste et arrive sur l\'autre, à la même place exacte dans le temps (écart de 5 px ignoré)', a.clips?.length === 2 && r.ok && b.clips?.length === 2 && rB.ok && b.clips[1].at === s1 / sr, `bout à ${b.clips?.[1]?.at} s sur « ${B.name} » ; écart max ${rB.max} ; ${await lastLog(/Montage — /)}`);
        check('… plus de mise en évidence ni d\'ombre après le geste', await page.evaluate(() => !document.querySelector('.lane.drop, .lane.nodrop, .clipghost')));
        await press('#editBar .mtUndo');
        check('annuler : les deux pistes reviennent au bit près', (await cmp(0, 'A', [])).ok && (await cmp(1, 'B', [])).ok && (await info(1)).clips === null && (await info(0)).clips.length === 3);
        // écart horizontal de 8 % de la largeur : le bout change de piste ET de place dans le temps
        const dxBig = Math.round(d.p.b.width * 0.08);
        d = await dragToTrack(A.id, mid, B.id, dxBig);
        b = await info(1);
        const at2 = b.clips?.[1]?.at ?? -1, want2 = s1 / sr + dxBig / d.p.b.width * d.p.v.dur;
        rB = await cmp(1, 'B', [['add', 'A', s1, s2, Math.round(at2 * sr)]]);
        check('glisser plus loin : le bout change de piste et suit aussi le pointeur dans le temps', b.clips?.length === 2 && rB.ok && Math.abs(at2 - want2) < 3 * d.p.v.dur / d.p.b.width && (await info(0)).clips.length === 2, `posé à ${at2.toFixed(3)} s (attendu ${want2.toFixed(3)})`);
        await press('#editBar .mtUndo');
        // lâcher sur une piste verrouillée : refusé, le bout revient
        await press(`.track[data-id="${B.id}"] button.tog.lock`);
        const left = await undoLeft();
        d = await dragToTrack(A.id, mid, B.id, 5);
        let st = await status();
        check('lâcher sur une piste verrouillée : ligne en rouge, le bout revient à sa place, avec un message', d.seen.nodrop && !d.seen.drop && /verrouillée/.test(st) && /revient à sa place/.test(st) && (await cmp(0, 'A', [])).ok && (await info(0)).clips.length === 3 && (await info(1)).clips === null && (await undoLeft()) === left, st);
        await press(`.track[data-id="${B.id}"] button.tog.lock`);
        // lâcher hors des pistes de voix (ici : la piste instru)
        d = await dragToTrack(A.id, mid, 0, 5);
        st = await status();
        check('lâcher hors des pistes de voix : le bout revient à sa place, avec un message', /revient à sa place/.test(st) && (await cmp(0, 'A', [])).ok && (await info(0)).clips.length === 3 && (await undoLeft()) === left, st);
        // une prise entière (sans montage) se glisse aussi vers une autre piste
        d = await dragToTrack(B.id, 10, A.id, 5);
        a = await info(0); b = await info(1);
        r = await cmp(0, 'A', [['add', 'B', 0, B.n, 0]]);
        check('glisser une prise entière vers une autre piste : elle y arrive à la même place, sa piste se vide', a.clips?.length === 4 && r.ok && !b.hasTake, `« ${B.name} » : ${b.hasTake ? 'a encore une prise' : 'vide'} ; écart max ${r.max}`);
        await press('#editBar .mtUndo');
        b = await info(1);
        check('annuler : la prise revient sur sa piste, au bit près', b.hasTake && b.clips === null && b.hash === B.hash && b.startSec === 0 && (await cmp(0, 'A', [])).ok);
        await settled();
    }

    // ---- 12. copier / coller à l'endroit visé (menu ouvert à côté d'un bout : « Coller ici » seulement)
    await tapSec(A.id, mid);
    await press('#clipCopy');
    {   // un bout est copié : ouvrir le menu (le doigt se relève au-dessus de ses commandes) ne doit rien déclencher
        const left = await undoLeft();
        await openMenuAt(A.id, mid);
        const st = await page.evaluate(() => ({ open: !document.getElementById('clipMenu').hidden, paste: !document.getElementById('clipPaste').disabled }));
        check(`ouvrir le menu par ${touch ? 'appui long' : 'clic droit'} ne déclenche aucune commande (rien ne s'applique tout seul)`, st.open && st.paste && (await undoLeft()) === left && (await info(0)).clips.length === 3 && (await cmp(0, 'A', [])).ok);
        await closeMenu();
    }
    await openMenuAt(B.id, 30);
    const pasteAt = await page.evaluate(() => window.__studiovoix.montage.menuAt);
    const shown = await page.evaluate(() => [...document.querySelectorAll('#clipMenu button, #clipMenu select')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => e.id));
    check('menu ouvert à côté d\'un bout : seulement « Coller ici » (et ✕)', shown.join(',') === 'clipClose,clipPaste', shown.join(','));
    await press('#clipPaste');
    b = await info(1);
    const rp = await cmp(1, 'B', [['add', 'A', s1, s2, Math.round(pasteAt * sr)]]);
    check('copier, puis « Coller ici » sur une autre piste : le bout s\'y ajoute à l\'endroit visé, l\'original reste', b.clips?.length === 2 && rp.ok && (await cmp(0, 'A', [])).ok && (await info(0)).clips.length === 3, `collé à ${pasteAt.toFixed(3)} s ; écart max ${rp.max} ; ${await status()}`);
    await settled();
    m = await mixCmp('B0', 31.5, 36);
    check('coller : la lecture « Mix » contient le bout collé', m.nowDb > m.beforeDb + 20 && m.diffDb > m.nowDb - 6, `mix de 31,5 à 36 s : ${dB(m.beforeDb)} → ${dB(m.nowDb)}`);
    await press('#editBar .mtUndo');
    check('annuler le collage : seconde piste d\'origine au bit près', (await cmp(1, 'B', [])).ok && (await info(1)).clips === null);
    await press(`.track[data-id="${B.id}"] button.tog.s`); await press(`.track[data-id="${A.id}"] button.tog.s`);   // solo : piste A seule

    // ---- 13. piste verrouillée : aucun geste de montage ne passe
    {
        await press(`.track[data-id="${A.id}"] button.tog.lock`);
        const before = await info(0), left = await undoLeft();
        const p = await tapSec(A.id, mid);
        const refused = [];
        const tryIt = async (name, fn) => { await page.evaluate(() => { document.getElementById('status').textContent = ''; }); await fn(); const st = await status(); if (!/verrouillée/.test(st)) refused.push(`${name} : « ${st} »`); };
        await tryIt('couper', () => press('#cutBtn'));
        await tryIt('dupliquer', () => press('#clipDup'));
        await tryIt('muet', () => press('#clipMute'));
        await tryIt('inverser', () => press('#clipRev'));
        await tryIt('gain', () => press('#clipGainUp'));
        await tryIt('fondu', () => choose('#clipFadeIn', 0.1));
        await tryIt('fondu croisé', () => press('#clipXfade'));
        await tryIt('rogner', () => press('#clipTrimE0'));
        await tryIt('fusionner', () => press('#clipMerge'));
        await tryIt('supprimer', () => press('#clipDel'));
        await tryIt('envoyer', () => choose('#clipSend', B.id));
        await tryIt('glisser', async () => { const q = await lanePoint(A.id, mid); await dragXY(q.x, q.y, 60); });
        await press('#clipCopy');   // copier ne change rien : permis ; coller sur la piste verrouillée : refusé
        await tryIt('coller', async () => { await openMenuAt(A.id, mid); await press('#clipPaste'); });
        await tryIt('glisser vers une autre piste', () => dragToTrack(A.id, mid, B.id, 5));
        await tryIt('touche Suppr', async () => { await tapSec(A.id, mid); await page.evaluate(() => { document.getElementById('status').textContent = ''; }); await page.keyboard.press('Delete'); });
        const after = await info(0), handles = await page.locator(`.track[data-id="${A.id}"] .trimh`).count();
        check('piste verrouillée : 15 gestes refusés avec le message du cadenas', refused.length === 0, refused.join(' | ') || 'couper, dupliquer, muet, inverser, gain, fondu, fondu croisé, rogner, fusionner, supprimer, envoyer, glisser, coller, glisser vers une autre piste, touche Suppr');
        check('piste verrouillée : rien n\'a changé (bouts, rendu, pile d\'annulation), pas de poignées', JSON.stringify(after.clips) === JSON.stringify(before.clips) && after.hash === before.hash && (await undoLeft()) === left && handles === 0 && (await info(1)).clips === null);
        await press(`.track[data-id="${A.id}"] button.tog.lock`);
        check('piste déverrouillée : les poignées reviennent', !(await info(0)).locked && (await page.locator(`.track[data-id="${A.id}"] .trimh`).count()) === 2);
    }

    // ---- 14. zoom : la coupe suit la vue, la tête de lecture reste juste, défilement
    {
        await tapSec(A.id, 6);
        await press('#zoomInBtn'); await press('#zoomInBtn');
        let v = await view();
        const slider = await page.evaluate(() => !document.getElementById('viewPos').hidden);
        check('zoom ×4 autour du curseur : un quart du morceau visible, curseur de défilement affiché', v.zoom === 4 && Math.abs(v.dur - v.total / 4) < 1e-9 && v.start <= 6 && v.start + v.dur >= 6 && slider, `vue de ${v.start.toFixed(2)} à ${(v.start + v.dur).toFixed(2)} s ; ${await page.textContent('#zoomInfo')}`);
        const want = v.start + v.dur * 0.5;
        const p = await tapSec(A.id, want);
        v = await view();
        const pos = await page.evaluate(() => parseFloat(document.getElementById('tracks').style.getPropertyValue('--pos')));
        check('zoom : toucher le milieu de la vue place le curseur au bon instant, trait blanc au milieu', Math.abs(v.head - want) < 2 * v.dur / p.b.width && Math.abs(pos - 50) < 1, `curseur ${v.head.toFixed(3)} s (attendu ${want.toFixed(3)}), trait à ${pos.toFixed(1)} %`);
        await press('#cutBtn');
        a = await info(0);
        check('zoom : couper au curseur coupe au bon endroit, rendu inchangé', a.clips.length === 4 && Math.abs(a.clips[0].len / sr - want) < 2 * v.dur / p.b.width && (await cmp(0, 'A', [])).ok, `coupe à ${(a.clips[0].len / sr).toFixed(3)} s`);
        await press('#editBar .mtUndo');
        await page.locator('#viewPos').evaluate((e) => { e.value = '1000'; e.dispatchEvent(new Event('input', { bubbles: true })); });
        v = await view();
        const hidden = await page.evaluate(() => parseFloat(document.getElementById('tracks').style.getPropertyValue('--pos')));
        check('défilement à fond : fin du morceau visible, trait blanc hors de la vue caché', Math.abs(v.start + v.dur - v.total) < 1e-6 && (hidden < 0 || hidden > 100), `vue de ${v.start.toFixed(2)} à ${(v.start + v.dur).toFixed(2)} s`);
        // lecture : la vue revient sur la tête et la suit
        await press('#playRawBtn');
        await page.waitForTimeout(700);
        v = await view();
        const follow = await page.evaluate(() => parseFloat(document.getElementById('tracks').style.getPropertyValue('--pos')));
        await press('#stopPlayBtn');
        check('lecture en vue zoomée : la vue suit la tête de lecture', v.head >= v.start && v.head <= v.start + v.dur && follow >= 0 && follow <= 100, `tête à ${v.head.toFixed(2)} s, vue de ${v.start.toFixed(2)} à ${(v.start + v.dur).toFixed(2)} s`);
        await press('#zoomOutBtn'); await press('#zoomOutBtn');
        v = await view();
        check('dézoom : retour à la vue entière', v.zoom === 1 && v.start === 0 && await page.evaluate(() => document.getElementById('viewPos').hidden && document.getElementById('zoomOutBtn').disabled));
    }

    // ---- 15. fusionner
    await tapSec(A.id, mid);
    for (let k = 0; k < 3; ++k) await press('#clipGainDown');
    await press('#clipRev');
    await page.waitForTimeout(1500);   // la sauvegarde des gestes précédents est passée : la suivante est celle de la fusion
    const beforeMerge = await info(0);
    await press('#clipMerge');
    a = await info(0);
    r = await cmp(0, 'A', [['rev', s1, s2], ['gain', s1, s2, -3]]);
    check('fusionner : un seul bout, même rendu au bit près, nouvelle source', a.clips?.length === 1 && a.hash === beforeMerge.hash && r.ok && a.clips[0].src !== beforeMerge.clips[0].src && a.clips[0].len === a.n, `${beforeMerge.clips.length} bouts → 1 ; ${await status()}`);
    await waitSave(/Montage — « .+ » : fusionner/);
    check('fusionner : le bloc fusionné est écrit une fois dans la sauvegarde', /\(1 son\(s\) écrit/.test(await lastLog(/Projet sauvegardé/)), await lastLog(/Projet sauvegardé/));

    // ---- 16. au moins 20 gestes annulables, puis retour à l'état de départ au bit près
    await press('#editBar .mtUndo');   // annule la fusion : trois bouts
    await tapSec(A.id, mid);
    for (let k = 0; k < 22; ++k) await press('#clipMute');
    const deep = await undoLeft();
    for (let k = 0; k < 22; ++k) await press('#editBar .mtUndo');
    r = await cmp(0, 'A', [['rev', s1, s2], ['gain', s1, s2, -3]]);
    check('22 gestes à la suite puis 22 « Annuler » : état d\'avant retrouvé au bit près', deep >= 22 && r.ok && (await undoLeft()) === deep - 22, `pile : ${deep} gestes gardés`);
    let n = 0;
    while (await page.evaluate(() => !document.querySelector('#editBar .mtUndo').disabled) && n < 60) { await press('#editBar .mtUndo'); ++n; }
    a = await info(0); b = await info(1);
    check('tout annuler : état de départ au bit près (sons, places, plus aucune liste de bouts)', a.clips === null && b.clips === null && (await cmp(0, 'A', [])).ok && (await cmp(1, 'B', [])).ok && a.startSec === 0 && a.hash === A.hash && b.hash === B.hash && a.same.includes('A'), `${n} « Annuler » de plus ; ${await status()}`);
    await settled();
    m = await mixCmp('depart', 0, A.n / sr);
    check('tout annuler : la lecture « Mix » est celle du départ', m.diffDb < m.beforeDb - 40, `différence ${dB(m.diffDb)} pour un mix à ${dB(m.beforeDb)}`);
    n = 0;
    while (await page.evaluate(() => !document.querySelector('#editBar .mtRedo').disabled) && n < 80) { await press('#editBar .mtRedo'); ++n; }
    a = await info(0);
    check('tout rétablir : le dernier état revient', a.clips?.length === 3 && (await cmp(0, 'A', [['rev', s1, s2], ['gain', s1, s2, -3]])).ok, `${n} « Rétablir »`);

    // ---- 17. sauvegarde : après rechargement, les bouts reviennent à l'identique
    {
        // État varié : bout du milieu à −3 dB et inversé (déjà), fondu d'entrée, premier bout muet, dernier bout avec fondu de
        // sortie et déplacé, plus une copie du bout du milieu collée sur la seconde piste (source partagée entre deux pistes).
        await tapSec(A.id, mid);
        await choose('#clipFadeIn', 0.1);
        await press('#clipCopy');
        await openMenuAt(B.id, 31);
        await press('#clipPaste');
        await tapSec(A.id, 5);
        await press('#clipMute');
        await tapSec(A.id, (s2 + A.n) / 2 / sr);
        await choose('#clipFadeOut', 0.25);
        const p = await lanePoint(A.id, (s2 + A.n) / 2 / sr);
        await dragXY(p.x, p.y, Math.round(p.b.width * 0.04));
        check('avant la sauvegarde : le dernier bout a bien été déplacé', (await info(0)).clips[2].at > s2 / sr + 0.5, `dernier bout à ${(await info(0)).clips[2].at.toFixed(3)} s`);
        // Piste neuve, vide : y envoyer le bout collé sur la seconde piste (elle reçoit une prise « Montage »), puis
        // supprimer ce seul bout (la prise disparaît, la piste redevient vide) et annuler.
        const pasteB = (await info(1)).clips[1].at, moved = [['rev', s1, s2], ['gain', s1, s2, -3], ['fadeIn', s1, S(0.1)], ['cut', s1, s2]];
        await press('#addTrackBtn');
        const C0 = await info(2);
        await tapSec(B.id, pasteB + 2);
        await choose('#clipSend', C0.id);
        let c = await info(2);
        b = await info(1);
        let rc = await cmp(2, 'A', moved, 1e-6);
        check('envoyer vers une piste vide : elle reçoit une prise « Montage » avec le bout au même instant ; la piste de départ retrouve son son', !C0.hasTake && c.hasTake && c.clips?.length === 1 && rc.ok && Math.abs(c.startSec - pasteB) < 1e-9 && b.clips?.length === 1 && (await cmp(1, 'B', [])).ok, `« ${c.name} » : bout à ${c.startSec.toFixed(3)} s, écart max ${rc.max.toExponential(1)} (tolérance 1e-6)`);
        await tapSec(C0.id, pasteB + 2);
        await press('#clipDel');
        c = await info(2);
        check('supprimer le seul bout d\'une piste : la prise disparaît, la piste est vide', !c.hasTake && c.takes === 0, await lastLog(/Montage — /));
        await press('#editBar .mtUndo');
        c = await info(2);
        rc = await cmp(2, 'A', moved, 1e-6);
        check('annuler : la prise et son bout reviennent', c.hasTake && c.takes === 1 && c.clips?.length === 1 && rc.ok);
        await page.evaluate(() => document.querySelector('#tracks .track input.name').dispatchEvent(new Event('change')));   // « projet modifié » : une sauvegarde de plus, postérieure à tous les gestes
        await waitSave(/Piste renommée/);
        const before = [await info(0), await info(1), await info(2)];
        const keys = await page.evaluate(() => new Promise((res, rej) => { const rq = indexedDB.open('studiovoix'); rq.onerror = () => rej(rq.error); rq.onsuccess = () => { const q = rq.result.transaction('audio').objectStore('audio').getAllKeys(); q.onsuccess = () => { rq.result.close(); res(q.result); }; q.onerror = () => rej(q.error); }; }));
        const srcs = [...new Set(before.flatMap((x) => x.clips.map((c) => c.src)))];
        check('sauvegarde : les sons source des bouts sont dans le magasin « audio », un par identifiant', srcs.every((s) => keys.includes(s)) && before[0].clips.length === 3 && before[1].clips.length === 1 && before[2].clips.length === 1, `${srcs.length} source(s) pour ${before.reduce((n, x) => n + x.clips.length, 0)} bouts sur 3 pistes ; clés du magasin : ${keys.join(', ')}`);
        await page.reload({ waitUntil: 'load' });
        await page.waitForFunction(() => window.__studiovoix?.ready && window.__studiovoix.instru && window.__studiovoix.tracks.length >= 3 && window.__studiovoix.tracks.every((t) => t.take) && [...document.querySelectorAll('#log div')].some((d) => /Projet repris/.test(d.textContent)), null, { timeout: 120000 });
        await settled();
        const after = await page.evaluate(() => {
            const hash = (x) => { const v = new Int32Array(x.buffer, x.byteOffset, x.length); let h = 2166136261; for (let i = 0; i < v.length; ++i) { h ^= v[i]; h = Math.imul(h, 16777619); } return h >>> 0; };
            return window.__studiovoix.tracks.map((t) => ({ clips: t.take.clips ? t.take.clips.map((c) => ({ ...c })) : null, hash: hash(t.take.mono), n: t.take.mono.length, startSec: t.take.startSec, undo: window.__studiovoix.montage.undo.length }));
        });
        const sameClips = after.length === 3 && [0, 1, 2].every((i) => JSON.stringify(after[i].clips) === JSON.stringify(before[i].clips));
        check('après rechargement : bouts retrouvés à l\'identique (places, zones, gains, muets, inversions, fondus)', sameClips, sameClips ? JSON.stringify(after[0].clips.map((c) => ({ at: +c.at.toFixed(3), len: c.len, gainDb: c.gainDb, mute: c.mute, rev: c.rev, fadeIn: c.fadeIn, fadeOut: c.fadeOut }))) : `avant ${JSON.stringify(before[0].clips)} après ${JSON.stringify(after[0].clips)}`);
        check('après rechargement : rendu des trois pistes identique au bit près, même place', after.length === 3 && [0, 1, 2].every((i) => after[i].hash === before[i].hash && after[i].n === before[i].n && after[i].startSec === before[i].startSec), after.map((x, i) => `piste ${i + 1} : ${x.n} échantillons à ${x.startSec.toFixed(3)} s`).join(' ; '));
        // le montage continue après rechargement : re-dérouler le début rogné par le fondu croisé n'existe pas ici, on coupe et on annule
        await tapSec(A.id, mid);
        await press('#cutBtn');
        const cutAgain = await page.evaluate(() => window.__studiovoix.tracks[0].take.clips.length);
        await press('#editBar .mtUndo');
        const back = await page.evaluate(() => { const x = window.__studiovoix.tracks[0].take.mono, v = new Int32Array(x.buffer, x.byteOffset, x.length); let h = 2166136261; for (let i = 0; i < v.length; ++i) { h ^= v[i]; h = Math.imul(h, 16777619); } return h >>> 0; });
        check('après rechargement : on peut encore couper, puis annuler', cutAgain === 4 && back === before[0].hash, `${cutAgain} bouts après la coupe`);
    }

    const fatal = errors.filter((e) => !/favicon/i.test(e));
    check('aucune erreur dans la console de la page', fatal.length === 0, fatal.join(' | ').slice(0, 600));
} catch (err) {
    ++bad;
    console.error(stamp(), 'ÉCHEC :', err.stack || err.message);
    console.error('statut :', await page.textContent('#status').catch(() => '?'));
    console.error('journal :', (await page.textContent('#log').catch(() => '')).slice(0, 1500));
} finally {
    await browser.close();
}
console.log(bad ? `${stamp()} ÉCHEC : ${bad} contrôle(s) en échec` : `${stamp()} OK : montage, tous les contrôles passent (${touch ? 'au doigt, ' + process.env.DEVICE : 'à la souris'})`);
process.exit(bad ? 1 : 0);
