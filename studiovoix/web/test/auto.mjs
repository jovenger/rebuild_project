// Essai de page du « studio automatique » (Chromium sans écran, Playwright) : toute piste de voix qui arrive est corrigée
// d'office en « correction seule » (volume régulier, résonances, compression, justesse ; aucune couleur de style), le
// style reste un choix à la main, piste par piste.
//   node web/test/auto.mjs <url> [voix.wav]
// Sans fichier de voix, l'import (b) est sauté. SHOT_DIR = dossier où poser une capture du panneau d'une piste en
// Correction (auto-<appareil>.png). DEVICE = appareil Playwright (ex. « Pixel 7 »).
// Contrôles : a) démo → pistes en Correction, traitées sans geste, rapport « correction », pas de traîne ; ligne
// d'avancement ; « ▶ Mix » joue le son corrigé, équilibré ; ce qui a été fait est affiché ; b) voix importée → idem ;
// c) choix manuel : style → mode Style (traîne de réverb), « Sans effet » → son brut, retour en Correction, réglage à
// la main en Correction, « Voix lissée » ; d) « Corriger toutes les pistes » / « Tout sans effet » ; e) inspection en
// mode Correction ; f) sauvegarde : le mode survit au rechargement, un projet d'avant (sans mode) garde son comportement ;
// g) écarts par type : le curseur déplace les backs dans l'équilibre, survit au rechargement, « Valeurs d'origine ».
// La séparation et la prise au micro sont vérifiées par e2e.mjs (mêmes contrôles « Correction » après l'arrivée).
import { createRequire } from 'node:module';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium, devices } = require('playwright');

const [url, voiceFile = process.env.VOICE_FILE || ''] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/auto.mjs <url> [voix.wav]'); process.exit(2); }
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
let failed = false;
const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };
const device = process.env.DEVICE ? devices[process.env.DEVICE] : null;
if (process.env.DEVICE && !device) throw new Error('appareil inconnu : ' + process.env.DEVICE);

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
try {
    const page = await (await browser.newContext({ acceptDownloads: true, ...(device || {}) })).newPage();
    const errors = [];
    page.on('pageerror', (e) => { console.log(stamp(), 'PAGEERROR', e.message); errors.push(String(e)); });
    page.on('console', (m) => { if (m.type() === 'error' && !/favicon/i.test(m.text())) errors.push(m.text()); });
    page.on('dialog', (d) => d.accept().catch(() => {}));
    const ready = async () => {
        for (let k = 0; k < 20; ++k) { try { if (await page.evaluate(() => window.crossOriginIsolated === true)) break; } catch (_) { /* rechargement en cours */ } await page.waitForTimeout(500); }
        await page.waitForFunction(() => window.__studiovoix?.ready && window.__studiovoix.tracks.length > 0, null, { timeout: 120000 });
    };
    await page.goto(url, { waitUntil: 'load' });
    await ready();
    // Journal de la page, du plus ancien au plus récent.
    const logLines = () => page.$$eval('#log div', (els) => els.map((x) => x.textContent).reverse());
    const idle = () => page.waitForFunction(() => { const s = window.__studiovoix; return document.body.dataset.busy === '0' && s.tracks.every((t) => !t.take || t.noFx || (t.processed && t.status === 'done')); }, null, { timeout: 600000 });
    // État d'une piste : mode, rapport du moteur, traîne après la fin de la prise (crête de 0,25 s après la fin jusqu'au bout).
    const snap = (k) => page.evaluate((k) => {
        const S = window.__studiovoix, t = S.tracks[k], r = t.processed?.report, row = document.querySelector(`#tracks .track[data-id="${t.id}"]`);
        let tailDb = null, extraSec = null;
        if (t.processed) {
            const L = t.processed.left, R = t.processed.right, sr = t.take.sampleRate, n0 = t.take.mono.length + Math.round(0.25 * sr);
            let m = 0; for (let i = n0; i < L.length; ++i) m = Math.max(m, Math.abs(L[i]), Math.abs(R[i]));
            tailDb = 20 * Math.log10(m + 1e-12); extraSec = (L.length - t.take.mono.length) / sr;
        }
        return { id: t.id, name: t.name, role: t.roleId, styleId: t.styleId, noFx: !!t.noFx, correction: !!t.correction, smooth: !!t.smooth, locked: !!t.locked, status: t.status, has: !!t.processed,
            mode: r?.mode, repStyleId: r?.styleId, repStyle: r?.style, gentle: r?.gentle, fitNotes: r?.fitNotes, found: r?.found, tailDb, extraSec,
            on: r ? Object.fromEntries(['reverb', 'delay', 'sat', 'timing', 'pitch', 'comp', 'leveler', 'resonance'].map((id) => [id, !!r.fx?.[id]?.on])) : null,
            badge: row?.querySelector('.badge')?.textContent, btn: row?.querySelector('button.tog.fx')?.textContent, info: row?.querySelector('.tinfo')?.textContent,
            styleUnused: row?.querySelector('select.style')?.classList.contains('unused') };
    }, k);
    const selectRow = (k) => page.evaluate((k) => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[k].id}"] .head`).click(), k);
    const fmtDb = (v) => (v == null ? '—' : `${v.toFixed(0)} dB`);
    const isCorrected = (s) => !s.noFx && s.correction && s.has && s.status === 'done' && s.mode === 'correction' && s.repStyleId === 'correction'
        && !s.on.reverb && !s.on.delay && !s.on.sat && !s.on.timing && s.tailDb < -90 && s.badge === 'corrigée';
    const describe = (s) => `« ${s.name} » : mode ${s.noFx ? 'sans effet' : s.correction ? 'correction' : 'style'}, rapport ${s.mode || '—'} (${s.repStyle || '—'}), traîne ${fmtDb(s.tailDb)}, réverb ${s.on?.reverb ? 'oui' : 'non'}, écho ${s.on?.delay ? 'oui' : 'non'}, saturation ${s.on?.sat ? 'oui' : 'non'}, pastille « ${s.badge} »`;
    // Lecture « ▶ Mix » : ce que joue chaque piste (son corrigé ou brut) et son niveau, puis arrêt.
    const playMix = async () => {
        await page.click('#playBtn');
        await page.waitForFunction(() => window.__studiovoix.player?.mode === 'mix' && !window.__studiovoix.balanceDirty, null, { timeout: 120000 });
        const r = await page.evaluate(() => {
            const S = window.__studiovoix;
            return S.player.nodes.filter((n) => n.key).map((n) => {
                const t = S.tracks.find((x) => x.id === n.key), b = n.src.buffer.getChannelData(0), it = S.balance.items.get(t.id), g = S.balance.gains.get(t.id);
                const same = (x) => { if (!x || x.length !== b.length) return false; for (let i = 0; i < b.length; i += 97) if (b[i] !== x[i]) return false; return true; };
                return { name: t.name, role: t.roleId, playsProcessed: same(t.processed?.left), playsRaw: same(t.take.mono), gainDb: 20 * Math.log10(n.gain.gain.value + 1e-12), autoDb: g, level: it.lufs + g + t.volumeDb, lufs: it.lufs };
            });
        });
        await page.click('#stopPlayBtn');
        return r;
    };

    // ------------------------------------------------------------------ a) démo : correction d'office, sans geste
    // Tout ce qu'affichent la ligne d'avancement et la barre d'état pendant la file est noté.
    await page.evaluate(() => {
        window.__seen = { auto: [], status: [] };
        const watch = (id, key) => new MutationObserver(() => { const v = document.getElementById(id).textContent; if (v && window.__seen[key].at(-1) !== v) window.__seen[key].push(v); }).observe(document.getElementById(id), { childList: true, characterData: true, subtree: true });
        watch('autoLine', 'auto'); watch('status', 'status');
    });
    const start0 = await snap(0);
    check('piste de départ : mode Correction, style non appliqué', start0.correction && !start0.noFx && start0.btn === 'Corrigé' && /correction seule, style non appliqué/.test(start0.info) && start0.styleUnused, `bouton « ${start0.btn} » ; ${start0.info}`);
    const tDemo = Date.now();
    await page.click('#demoBtn');
    await page.waitForFunction(() => window.__studiovoix.tracks.length >= 2 && window.__studiovoix.tracks.every((t) => t.take), null, { timeout: 180000 });
    await idle();
    const demo = [await snap(0), await snap(1)];
    for (const s of demo) check(`démo : ${s.name} corrigée d'office (aucun geste)`, isCorrected(s), describe(s));
    check('démo : pas de traîne après la prise (son traité = prise + silence numérique)', demo.every((s) => s.tailDb < -90 && s.extraSec <= 3.01), demo.map((s) => `${s.name} : ${s.extraSec.toFixed(2)} s après la prise, crête ${fmtDb(s.tailDb)}`).join(' ; '));
    const seen = await page.evaluate(() => window.__seen);
    const prog = seen.auto.filter((l) => /Correction automatique : \d+ \/ \d+ piste/.test(l));
    console.log(stamp(), 'ligne d\'avancement vue :', prog.map((l) => l.slice(0, 70)).join('  →  '));
    check('ligne d\'avancement : « Correction automatique : n / 2 pistes » pendant la file, puis finie', prog.some((l) => /⏳ Correction automatique : [01] \/ 2 pistes/.test(l)) && /^✓ Correction automatique : 2 \/ 2 pistes/.test(prog.at(-1) || ''), `${prog.length} états ; dernier : ${(prog.at(-1) || '').slice(0, 60)}`);
    check('barre d\'état : avancement de la correction', seen.status.some((l) => /Correction automatique : \d \/ 2 pistes — « .* » .*en cours/.test(l)), (seen.status.find((l) => /Correction automatique/.test(l)) || '').slice(0, 110));
    const lg = await logLines();
    const starts = lg.filter((l) => /mode de départ « Correction »/.test(l)), runs = lg.filter((l) => /correction automatique lancée/.test(l)), ends = lg.filter((l) => /correction automatique finie en \d+ ms — décisions du moteur : /.test(l));
    check('journal : mode de départ, correction lancée, finie avec les décisions du moteur', starts.length >= 2 && runs.length >= 2 && ends.length >= 2, `${starts.length} départ(s), ${runs.length} lancée(s), ${ends.length} finie(s)`);
    console.log(stamp(), '   ', (ends.at(-1) || '').replace(/^[\d:]+(\s[AP]M)?\s+/, '').slice(0, 420));
    console.log(stamp(), `démo corrigée en ${((Date.now() - tDemo) / 1000).toFixed(1)} s (fabrication + analyse de l'instru + 2 pistes)`);

    // Ce qui a été fait est visible : panneau de la piste (décisions, constats, réglages), compte rendu.
    await selectRow(0);
    await page.waitForFunction(() => document.querySelectorAll('#fxList .fxrow').length >= 12 && !document.getElementById('fxDone').hidden, null, { timeout: 10000 });
    const panel = await page.evaluate(() => ({ on: [...document.querySelectorAll('#fxMode button.on')].map((b) => b.dataset.mode).join(), buttons: [...document.querySelectorAll('#fxMode button')].map((b) => b.textContent).join(' / '),
        done: document.getElementById('fxDone').textContent, info: document.getElementById('fxInfo').textContent, report: document.getElementById('report').textContent,
        rows: Object.fromEntries([...document.querySelectorAll('#fxList .fxrow')].map((r) => [r.dataset.fx, { off: r.classList.contains('off'), sum: r.querySelector('.fxsum').textContent }])) }));
    check('panneau : trois modes, « Correction » actif', panel.buttons === 'Sans effet / Correction / Style' && panel.on === 'correction', `${panel.buttons} ; actif : ${panel.on}`);
    check('panneau : décisions du moteur et constats affichés', panel.done.includes('• ' + demo[0].fitNotes.split(/\n| ; /)[0].trim()) && /Mesuré sur la prise/.test(panel.done) && /aucune réverb, aucun écho, aucune saturation/.test(panel.done), panel.done.replace(/\n/g, ' | ').slice(0, 300));
    check('panneau : dit que le style n\'est pas appliqué', /n'est PAS appliqué/.test(panel.info) && /Correction/.test(panel.info), panel.info.slice(0, 150));
    check('tableau des effets : réglages décidés, couleur éteinte', panel.rows.reverb?.off && panel.rows.delay?.off && panel.rows.sat?.off && !panel.rows.comp?.off && !!panel.rows.comp?.sum, `compresseur : ${panel.rows.comp?.sum} ; réverb ${panel.rows.reverb?.sum}, écho ${panel.rows.delay?.sum}, saturation ${panel.rows.sat?.sum}`);
    check('compte rendu de la piste : correction, décisions, constats, chaîne', /correction automatique seule/.test(panel.report) && panel.report.includes('Mesuré sur la prise') && panel.report.includes('Chaîne appliquée'), panel.report.split('\n')[0].slice(0, 170));
    if (process.env.SHOT_DIR) {
        const shot = `${process.env.SHOT_DIR}/auto-${device ? 'telephone' : 'pc'}.png`;
        await page.locator('#fxPanel').scrollIntoViewIfNeeded();
        await page.locator('#fxPanel').screenshot({ path: shot });
        await page.screenshot({ path: shot.replace('.png', '-page.png'), fullPage: true });
        console.log(stamp(), 'captures :', shot, 'et', shot.replace('.png', '-page.png'));
    }

    // « ▶ Mix » sans autre geste : son corrigé, équilibré (back 7 LU sous la voix principale).
    const mix0 = await playMix();
    const lead0 = mix0.find((x) => x.role === 'lead'), back0 = mix0.find((x) => x.role === 'manual_back');
    check('« ▶ Mix » joue les pistes corrigées et équilibrées', mix0.length === 2 && mix0.every((x) => x.playsProcessed && Math.abs(x.gainDb - x.autoDb) < 0.1) && Math.abs(lead0.level - back0.level - 7) < 1,
        mix0.map((x) => `${x.name} : son ${x.playsProcessed ? 'corrigé' : x.playsRaw ? 'BRUT' : '?'}, ${x.lufs.toFixed(1)} → ${x.level.toFixed(1)} LUFS`).join(' ; ') + ` ; back ${(lead0.level - back0.level).toFixed(1)} LU dessous`);

    // ------------------------------------------------------------------ b) voix importée : correction d'office
    let nTracks = 2;
    if (voiceFile) {
        await page.click('details.more > summary'); await page.uncheck('#isolateVoice');   // l'isolation IA n'est pas le sujet
        await page.selectOption('#addRole', 'manual_back'); await page.click('#addTrackBtn');
        const tImp = Date.now();
        await page.locator('input.voiceFile').last().setInputFiles(voiceFile);
        await page.waitForFunction(() => window.__studiovoix.tracks.at(-1).take, null, { timeout: 300000 });
        await idle();
        const imp = await snap(2);
        const impSec = await page.evaluate(() => { const k = window.__studiovoix.tracks[2].take; return k.mono.length / k.sampleRate; });
        check('voix importée : corrigée d\'office (aucun geste)', isCorrected(imp), describe(imp));
        const impMs = Number(((await logLines()).filter((l) => l.includes(`« ${imp.name} » : correction automatique finie`)).at(-1) || '').match(/finie en (\d+) ms/)?.[1]);
        console.log(stamp(), `voix importée de ${impSec.toFixed(1)} s : correction en ${impMs} ms (import compris : ${((Date.now() - tImp) / 1000).toFixed(1)} s)`);
        nTracks = 3;
    } else console.log(stamp(), 'b) voix importée : SAUTÉ (pas de fichier de voix en argument)');

    // ------------------------------------------------------------------ c) choix manuel
    // Style choisi dans la liste de la piste → mode Style, effets du style (traîne de réverb).
    await page.selectOption('.track[data-id="1"] select.style', 'trap');
    await idle();
    const sty = await snap(0);
    check('style choisi à la main → mode Style, effets du style', !sty.noFx && !sty.correction && sty.mode === 'style' && sty.repStyle === 'Trap' && sty.on.reverb && sty.tailDb > -70 && sty.btn === 'Lissé' && !sty.styleUnused && !/non appliqué/.test(sty.info), describe(sty) + ` ; bouton « ${sty.btn} »`);
    const others = await Promise.all([...Array(nTracks - 1)].map((_, k) => snap(k + 1)));
    check('les autres pistes restent en Correction (rien ne passe en Style tout seul)', others.every(isCorrected), others.map((s) => `${s.name} : ${s.mode}`).join(' ; '));
    check('journal : passage en Style', (await logLines()).some((l) => /passage en mode « Style » : effets du style Trap.*style choisi à la main/.test(l)), 'ligne « passage en mode « Style » … style choisi à la main »');
    await selectRow(0);
    check('panneau : « Style » actif', await page.evaluate(() => [...document.querySelectorAll('#fxMode button.on')].map((b) => b.dataset.mode).join() === 'style' && document.getElementById('fxDone').hidden), 'bouton Style marqué, bloc « correction automatique » masqué');
    // « Sans effet » → son brut
    await page.click('#fxMode button[data-mode="none"]');
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0]; return t.noFx && !t.processed && document.body.dataset.busy === '0'; }, null, { timeout: 60000 });
    const none = await snap(0), mixNone = await playMix();
    check('« Sans effet » → son brut', none.noFx && !none.has && none.badge === 'sans effet' && none.btn === 'Brut' && mixNone.find((x) => x.name === none.name).playsRaw, `pastille « ${none.badge} », bouton « ${none.btn} », « ▶ Mix » joue ${mixNone.find((x) => x.name === none.name).playsRaw ? 'la prise brute' : 'AUTRE CHOSE'}`);
    // Retour en Correction : le style choisi est gardé, mais plus appliqué
    await page.click('#fxMode button[data-mode="correction"]');
    await idle();
    const again = await snap(0);
    check('retour en « Correction » (style gardé, non appliqué)', isCorrected(again) && again.styleId === 'trap' && again.styleUnused && /correction seule, style non appliqué/.test(again.info), describe(again) + ` ; ${again.info.slice(0, 80)}`);
    // Réglage à la main en Correction : réverb allumée → traîne ; « Pré-réglage » → plus de traîne
    await page.waitForFunction(() => document.querySelectorAll('#fxList .fxrow').length >= 12, null, { timeout: 10000 });
    await page.locator('#fxList .fxrow[data-fx="reverb"] .fxline').click();
    await page.locator('#fxList .fxrow[data-fx="reverb"] input[type=checkbox]').check();
    await page.locator('#fxList .fxrow[data-fx="reverb"] .fxfield input[type=range]').first().evaluate((e) => { e.value = '0.3'; e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); });
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0], rv = t.processed?.report?.fx?.reverb; return t.status === 'done' && rv?.on === true && Math.abs(rv.send - 0.3) < 0.011 && document.body.dataset.busy === '0'; }, null, { timeout: 120000 });
    const hand = await snap(0);
    check('Correction : réverb allumée et réglée à 30 % à la main → appliquée', hand.correction && hand.mode === 'correction' && hand.on.reverb && hand.tailDb > again.tailDb + 40 && hand.tailDb > -90 && await page.locator('#fxList .fxrow[data-fx="reverb"] .fxmod').isVisible(), `traîne ${fmtDb(hand.tailDb)} (sans réverb : ${fmtDb(again.tailDb)}), ligne Réverb marquée « modifié »`);
    await page.click('#fxResetAll');
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0]; return t.status === 'done' && t.processed?.report?.fx?.reverb?.on === false && document.body.dataset.busy === '0'; }, null, { timeout: 120000 });
    check('Correction : « Pré-réglage » → de nouveau sans couleur', isCorrected(await snap(0)), describe(await snap(0)));
    // « Voix lissée » : bascule à part, la piste reste en Correction
    const sm0 = await snap(0);
    await page.click('#fxSmooth');
    await page.waitForFunction((was) => { const t = window.__studiovoix.tracks[0]; return t.smooth !== was && t.status === 'done' && t.processed?.report?.gentle === t.smooth && document.body.dataset.busy === '0'; }, sm0.smooth, { timeout: 120000 });
    const sm1 = await snap(0);
    check('« Voix lissée » en Correction : bascule, la piste reste en Correction', sm1.smooth !== sm0.smooth && sm1.gentle === sm1.smooth && isCorrected(sm1), `lissée ${sm0.smooth ? 'oui' : 'non'} → ${sm1.smooth ? 'oui' : 'non'} ; rapport ${sm1.mode}`);
    await page.click('#fxSmooth'); await idle();
    // Bouton « Style » du panneau → mode Style
    await page.click('#fxMode button[data-mode="style"]'); await idle();
    const sty2 = await snap(0);
    check('bouton « Style » → mode Style', !sty2.correction && sty2.mode === 'style' && sty2.repStyle === 'Trap' && sty2.on.reverb, describe(sty2));

    // ------------------------------------------------------------------ d) « Corriger toutes les pistes » / « Tout sans effet »
    await page.evaluate(() => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[1].id}"] button.tog.fx`).click());   // piste 2 : Corrigé → Lissé (Style)
    await idle();
    const pre = await Promise.all([...Array(nTracks)].map((_, k) => snap(k)));
    check('avant « Corriger toutes les pistes » : deux pistes en Style', pre[0].mode === 'style' && pre[1].mode === 'style' && pre[1].btn === 'Lissé', pre.map((s) => `${s.name} : ${s.mode}`).join(' ; '));
    await page.evaluate(() => { window.__seen.auto.length = 0; });
    await page.click('#correctAllBtn');
    await idle();
    const all = await Promise.all([...Array(nTracks)].map((_, k) => snap(k)));
    check('« Corriger toutes les pistes » : toutes en Correction, retraitées', all.every(isCorrected), all.map(describe).join(' || ').slice(0, 400));
    const prog2 = (await page.evaluate(() => window.__seen.auto)).filter((l) => /Correction automatique : \d+ \/ \d+ piste/.test(l));
    console.log(stamp(), 'ligne d\'avancement vue :', prog2.map((l) => l.slice(0, 48)).join('  →  '));
    check(`ligne d'avancement : 0 → ${nTracks} / ${nTracks} pistes`, [...Array(nTracks)].every((_, k) => prog2.some((l) => l.includes(`Correction automatique : ${k} / ${nTracks} pistes`))) && (prog2.at(-1) || '').startsWith(`✓ Correction automatique : ${nTracks} / ${nTracks} pistes`), `${prog2.length} états ; dernier : ${(prog2.at(-1) || '').slice(0, 50)}`);
    await page.click('#rawAllBtn');
    await page.waitForFunction(() => window.__studiovoix.tracks.every((t) => t.noFx && !t.processed) && document.body.dataset.busy === '0', null, { timeout: 60000 });
    check('« Tout sans effet » : toutes les pistes brutes', (await Promise.all([...Array(nTracks)].map((_, k) => snap(k)))).every((s) => s.noFx && !s.has && s.badge === 'sans effet'), 'pastilles « sans effet »');
    await page.click('#correctAllBtn'); await idle();
    check('« Corriger toutes les pistes » après « Tout sans effet »', (await Promise.all([...Array(nTracks)].map((_, k) => snap(k)))).every(isCorrected), 'toutes corrigées');

    // ------------------------------------------------------------------ e) inspection en mode Correction
    await selectRow(1);
    await page.click('#inspectBtn');
    await page.waitForFunction(() => !window.__studiovoix.inspecting && window.__studiovoix.tracks[1].inspect && !window.__studiovoix.tracks[1].inspect.stale, null, { timeout: 240000 });
    const rows = await page.evaluate(() => [...document.querySelectorAll('#inspectBox .finding')].map((f) => ({ level: f.className.replace('finding', '').trim(), text: f.querySelector('.txt').textContent })));
    rows.forEach((r) => console.log(stamp(), `   [${r.level}] ${r.text.slice(0, 220)}`));
    const insLog = (await logLines()).filter((l) => /Inspection de « .* » \(mode Correction/.test(l));
    check('inspection en mode Correction : mesure faite avec la correction seule', rows.length >= 1 && !rows.some((r) => /impossible/i.test(r.text)) && rows.some((r) => r.level === 'ok' || r.level === 'warn' || r.level === 'bad') && insLog.length >= 1 && !/distorsion de la saturation/.test(rows.map((r) => r.text).join(' ')),
        `${rows.length} constat(s) : ${rows.map((r) => r.level).join(', ')} ; journal : ${(insLog.at(-1) || '').replace(/^[\d:]+(\s[AP]M)?\s+/, '').slice(0, 150)}`);

    // ------------------------------------------------------------------ f) sauvegarde : le mode survit au rechargement
    // Une sauvegarde plus récente que le geste : lue dans la sauvegarde elle-même (date `savedAt` des métadonnées). Compter
    // les lignes « Projet sauvegardé » du journal ne suffit pas : le journal est plafonné à 200 lignes, une ligne ancienne
    // sort quand la nouvelle entre et le compte ne bouge plus (échec vu en CI, pas en local).
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
    const modes = () => page.evaluate(() => window.__studiovoix.tracks.map((t) => `${t.name}=${t.noFx ? 'none' : t.correction ? 'correction' : 'style'}/${t.processed?.report?.mode || 'brut'}`).join(' ; '));
    // piste 1 : Style ; piste 2 : Correction ; piste 3 (si importée) : Sans effet
    await page.selectOption('.track[data-id="1"] select.style', 'pop'); await idle();
    await waitSave(async () => { if (nTracks >= 3) { await selectRow(2); await page.click('#fxMode button[data-mode="none"]'); } else await page.evaluate(() => document.querySelector('#tracks .track input.name').dispatchEvent(new Event('change'))); });
    await idle();
    const want = nTracks >= 3 ? ['style/style', 'correction/correction', 'none/brut'] : ['style/style', 'correction/correction'];
    const before = await modes();
    check('avant rechargement : un mode différent par piste', before.split(' ; ').every((m, k) => m.endsWith('=' + want[k])), before);
    await page.reload({ waitUntil: 'load' }); await ready();
    await page.waitForFunction((n) => window.__studiovoix.tracks.length === n && window.__studiovoix.tracks.every((t) => t.take), nTracks, { timeout: 120000 });
    await idle();
    const after = await modes();
    check('après rechargement : mode de chaque piste gardé, son retraité dans ce mode', after === before, after);
    // Projet d'avant (sans mode enregistré) : le champ est retiré de la sauvegarde, puis la page est rechargée.
    await page.waitForTimeout(1200);   // laisse passer une sauvegarde automatique en attente (elle réécrirait le champ)
    const stripped = await page.evaluate(() => new Promise((resolve, reject) => {
        const rq = indexedDB.open('studiovoix', 1);
        rq.onerror = () => reject(rq.error);
        rq.onsuccess = () => {
            const db = rq.result, tx = db.transaction('meta', 'readwrite'), st = tx.objectStore('meta'), g = st.get('project');
            g.onsuccess = () => { const meta = g.result, had = meta.tracks.map((t) => t.mode); for (const t of meta.tracks) delete t.mode; st.put(meta, 'project'); tx.oncomplete = () => { db.close(); resolve(had); }; };
            tx.onerror = () => reject(tx.error);
        };
    }));
    await page.reload({ waitUntil: 'load' }); await ready();
    await page.waitForFunction((n) => window.__studiovoix.tracks.length === n && window.__studiovoix.tracks.every((t) => t.take), nTracks, { timeout: 120000 });
    await idle();
    const old = await modes();
    const wantOld = nTracks >= 3 ? ['style/style', 'style/style', 'none/brut'] : ['style/style', 'style/style'];
    check('projet d\'avant (sans mode enregistré) : Style ou Sans effet, comme avant', old.split(' ; ').every((m, k) => m.endsWith('=' + wantOld[k])) && (await logLines()).some((l) => /projet d'avant le mode « Correction » : comportement d'avant gardé/.test(l)), `modes retirés de la sauvegarde (${stripped.join(', ')}) → ${old}`);
    const oldRep = await snap(1);
    check('projet d\'avant : la piste sans mode est traitée par son style (son d\'avant)', oldRep.mode === 'style' && oldRep.repStyleId !== 'correction' && oldRep.badge !== 'corrigée', describe(oldRep));
    // Une piste ajoutée ensuite à ce projet naît en Correction
    await page.click('#addTrackBtn');
    const fresh = await snap(nTracks);
    check('piste ajoutée à un projet d\'avant : mode Correction', fresh.correction && !fresh.noFx && fresh.btn === 'Corrigé', `bouton « ${fresh.btn} »`);
    await page.evaluate(() => { const t = window.__studiovoix.tracks.at(-1); document.querySelector(`.track[data-id="${t.id}"] button.x`).click(); });

    // ------------------------------------------------------------------ g) écarts de volume par type
    await page.click('#correctAllBtn'); await idle();
    const levels = async () => { const m = await playMix(), lead = m.find((x) => x.role === 'lead'), backs = m.filter((x) => x.role === 'manual_back'); return { gap: lead.level - backs[0].level, gains: m.map((x) => x.autoDb), n: m.length }; };
    const base = await levels();
    await page.click('#roleBox > summary');
    const roleUi = await page.evaluate(() => [...document.querySelectorAll('#roleList .rolerow')].map((r) => { const i = r.querySelector('input[type=range]'); return { role: i.dataset.role, name: r.querySelector('span').textContent, value: Number(i.value), min: Number(i.min), max: Number(i.max), step: Number(i.step), pre: r.querySelector('.pre').textContent }; }));
    const backUi = roleUi.find((r) => r.role === 'manual_back');
    check('« Écarts par type » : un curseur par type réglable (−24 à 0, pas de 0,5), valeur d\'origine rappelée', roleUi.length >= 3 && !!backUi && roleUi.every((r) => r.min === -24 && r.max === 0 && r.step === 0.5 && /valeur d'origine : -?\d/.test(r.pre)) && !roleUi.some((r) => r.role === 'lead' || r.role === 'instru') && backUi.value === -7 && await page.isDisabled('#roleResetBtn'),
        roleUi.map((r) => `${r.name} ${r.value} LU`).join(', '));
    check('équilibre d\'origine : back 7 LU sous la voix principale', Math.abs(base.gap - 7) < 1, `${base.gap.toFixed(1)} LU`);
    const setSlider = (role, v) => page.locator(`#roleList input[data-role="${role}"]`).evaluate((e, v) => { e.value = String(v); e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); }, v);
    await waitSave(async () => { await setSlider('manual_back', -12); await page.waitForFunction(() => window.__studiovoix.roles.find((r) => r.id === 'manual_back').placeLu === -12 && window.__studiovoix.balanceDirty, null, { timeout: 10000 }); });
    const moved = await levels();
    check('curseur des backs à −12 LU : équilibre marqué à refaire, backs 12 LU dessous au Mix', Math.abs(moved.gap - 12) < 1 && !(await page.isDisabled('#roleResetBtn')) && /modifié/.test(await page.locator('#roleList .rolerow', { has: page.locator('input[data-role="manual_back"]') }).locator('.pre').textContent()),
        `écart ${base.gap.toFixed(1)} → ${moved.gap.toFixed(1)} LU`);
    // « Valeurs d'origine » : même son, même équilibre qu'au départ
    await page.click('#roleResetBtn');
    await page.waitForFunction(() => window.__studiovoix.roles.every((r) => r.placeLu === r.defaultPlaceLu) && window.__studiovoix.balanceDirty, null, { timeout: 10000 });
    const back = await levels();
    check('« Valeurs d\'origine » : ancien résultat', back.gains.length === base.gains.length && back.gains.every((g, k) => Math.abs(g - base.gains[k]) < 0.01) && Number(await page.locator('#roleList input[data-role="manual_back"]').inputValue()) === -7 && await page.isDisabled('#roleResetBtn'),
        `écart ${back.gap.toFixed(1)} LU ; gains ${back.gains.map((g) => g.toFixed(2)).join(', ')} (départ ${base.gains.map((g) => g.toFixed(2)).join(', ')})`);
    // Réglage gardé avec le projet : après rechargement, il est renvoyé au moteur (dont l'état repart de l'origine)
    await waitSave(async () => { await setSlider('manual_back', -12); await page.waitForFunction(() => window.__studiovoix.roles.find((r) => r.id === 'manual_back').placeLu === -12, null, { timeout: 10000 }); });
    await page.reload({ waitUntil: 'load' }); await ready();
    await page.waitForFunction((n) => window.__studiovoix.tracks.length === n && window.__studiovoix.tracks.every((t) => t.take), nTracks, { timeout: 120000 });
    await idle();
    const kept = await page.evaluate(() => ({ engine: window.__studiovoix.roles.find((r) => r.id === 'manual_back').placeLu, slider: Number(document.querySelector('#roleList input[data-role="manual_back"]').value), saved: JSON.stringify(window.__studiovoix.roleOffsets) }));
    const movedAgain = await levels();
    check('après rechargement : écart gardé, renvoyé au moteur, même équilibre', kept.engine === -12 && kept.slider === -12 && Math.abs(movedAgain.gap - moved.gap) < 0.3 && (await logLines()).some((l) => /Écarts par type repris de la sauvegarde : Voix back -12,0 LU/.test(l)), `moteur ${kept.engine} LU, curseur ${kept.slider} LU, gardé ${kept.saved}, écart au Mix ${movedAgain.gap.toFixed(1)} LU`);
    await waitSave(async () => { await page.click('#roleBox > summary'); await page.click('#roleResetBtn'); });   // projet laissé aux valeurs d'origine

    check('aucune erreur dans la console de la page', errors.length === 0, errors.length ? errors.join(' | ').slice(0, 400) : 'aucune');
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
