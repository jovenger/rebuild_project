// Essai de l'inspection de piste (« le programme détecte lui-même ce qui ne va pas et dit quoi faire ») :
//  1. les mesures seules (inspect.js) : un son identique = 0 dB de saleté, un égaliseur ne compte pas, du bruit ajouté
//     compte, des plateaux = écrêtage ;
//  2. dans la page, sur la démo : une piste saine sort « rien d'anormal » ; un effet qui salit (simulé par
//     ?svTestDirt=comp) est nommé, son bouton l'éteint et l'inspection suivante est propre ; une prise saturée est
//     signalée ; « Inspecter les pistes » liste toutes les pistes.
//   node web/test/inspect.mjs <url>          (VOICE_WAV=fichier : inspecte en plus cette voix, sans rien exiger)
import { createRequire } from 'node:module';
import { voiceDirt, clipRuns, loudestWindow } from '../inspect.js';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);

const [url] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/inspect.mjs <url>'); process.exit(2); }
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
let failed = false;
const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };

// ---------------------------------------------------------------- 1) les mesures seules
{
    const sr = 44100, n = 8 * sr, x = new Float32Array(n);
    // voix de synthèse : note qui glisse (150 → 220 Hz, vibrato), 25 harmoniques, niveau qui monte par paliers
    let ph = 0;
    for (let i = 0; i < n; ++i) {
        const t = i / sr, f = 150 + 70 * (t / 8) + 3 * Math.sin(2 * Math.PI * 5.5 * t);
        ph += 2 * Math.PI * f / sr;
        let v = 0; for (let h = 1; h <= 25; ++h) v += Math.sin(h * ph + h) / h * (1 + 1.2 * Math.exp(-Math.pow((h * f - 2600) / 800, 2)));
        x[i] = 0.08 * (1 + Math.floor(t / 2)) * v;
    }
    const same = voiceDirt(x, x, sr);
    check('son identique : aucune saleté', Math.abs(same.high) < 0.01 && Math.abs(same.low) < 0.01 && same.frames > 100, `aigus ${same.high.toFixed(2)} dB, graves ${same.low.toFixed(2)} dB, ${same.frames} trames`);
    // égaliseur (linéaire) : +6 dB d'aigus par un filtre en étagère simple
    const eq = new Float32Array(n); { let lp = 0; const c = Math.exp(-2 * Math.PI * 3000 / sr); for (let i = 0; i < n; ++i) { lp = (1 - c) * x[i] + c * lp; eq[i] = lp + 2 * (x[i] - lp); } }
    const dEq = voiceDirt(x, eq, sr);
    check('égaliseur seul : sous le seuil d\'alerte (1 dB)', Math.abs(dEq.high) < 1 && Math.abs(dEq.low) < 1, `aigus ${dEq.high.toFixed(2)} dB, graves ${dEq.low.toFixed(2)} dB`);
    // craquements : bruit large bande à -20 dB sous le signal
    let e = 0; for (let i = 0; i < n; ++i) e += x[i] * x[i];
    const a = Math.sqrt(e / n) * 0.1 * Math.sqrt(3), dirty = new Float32Array(n);
    let seed = 7; for (let i = 0; i < n; ++i) { seed = (seed * 1103515245 + 12345) & 0x7fffffff; dirty[i] = x[i] + a * (seed / 0x3fffffff - 1); }
    const dN = voiceDirt(x, dirty, sr);
    check('bruit ajouté (-20 dB) : compté', dN.high > 3 && dN.high > dN.low && dN.high > 4 * Math.abs(dEq.high), `aigus +${dN.high.toFixed(1)} dB, graves +${dN.low.toFixed(1)} dB`);
    // écrêtage
    const clipped = Float32Array.from(x, (v) => Math.max(-0.5, Math.min(0.5, v * 3)));
    check('plateaux : écrêtage vu', clipRuns(clipped).runs > 50 && clipRuns(x).runs === 0, `${clipRuns(clipped).runs} plateaux sur le son écrêté, ${clipRuns(x).runs} sur le son sain`);
    check('passage le plus fort', Math.abs(loudestWindow(x, sr, 2) / sr - 6) < 0.3, `trouvé à ${(loudestWindow(x, sr, 2) / sr).toFixed(2)} s (attendu 6 s)`);
}

// ---------------------------------------------------------------- 2) dans la page
const { chromium } = require('playwright');
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
try {
    const page = await browser.newPage();
    page.on('pageerror', (err) => { console.log(stamp(), 'PAGEERROR', err.message); failed = true; });
    await page.goto(url + (url.includes('?') ? '&' : '?') + 'svTestDirt=comp', { waitUntil: 'load' });
    await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });
    await page.click('#demoBtn');
    const settled = () => page.waitForFunction(() => { const s = window.__studiovoix; return s.tracks.length >= 2 && s.tracks.every((t) => !t.take || t.noFx || (t.processed && t.status === 'done')) && document.body.dataset.busy === '0' && !s.inspecting; }, null, { timeout: 180000 });
    await settled();
    const sel = (k) => page.evaluate((k) => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks[k].id}"] .head`).click(), k);
    const inspect = async () => { await page.click('#inspectBtn'); await page.waitForFunction(() => !window.__studiovoix.inspecting && window.__studiovoix.tracks.some((t) => t.inspect && !t.inspect.stale), null, { timeout: 180000 }); await settled(); return page.evaluate(() => [...document.querySelectorAll('#inspectBox .finding')].map((f) => ({ level: f.className.replace('finding', '').trim(), text: f.querySelector('.txt').textContent, btn: f.querySelector('button')?.textContent || '' }))); };
    const show = (rows) => rows.forEach((r) => console.log(stamp(), `   [${r.level}] ${r.text.slice(0, 260)}${r.btn ? '  → bouton « ' + r.btn + ' »' : ''}`));

    // a) l'effet qui salit (simulé : compresseur) est nommé, avec son bouton
    await sel(0);
    let rows = await inspect(); show(rows);
    const hit = rows.find((r) => /Compresseur/.test(r.text) && /Éteindre/.test(r.btn));
    check('effet qui salit : nommé avec un bouton', !!hit && (hit.level === 'bad' || hit.level === 'warn'), hit ? hit.text.slice(0, 140) : 'aucun constat sur le compresseur');
    // b) le bouton l'éteint ; la piste est retraitée ; l'ancienne inspection est marquée périmée
    await page.locator('#inspectBox .finding button', { hasText: 'Compresseur' }).first().click();
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0]; return t.fx?.comp?.on === false && t.status === 'done' && t.processed?.report?.fx?.comp?.on === false && t.inspect?.stale; }, null, { timeout: 120000 });
    await settled();
    const stale = await page.textContent('#inspectBox');
    check('bouton : effet éteint, inspection à refaire', /relance/.test(stale), stale.slice(0, 120));
    // c) nouvelle inspection : plus rien
    rows = await inspect(); show(rows);
    check('après correction : rien d\'anormal', rows.some((r) => r.level === 'ok') && !rows.some((r) => r.level === 'warn' || r.level === 'bad'), rows.map((r) => r.level).join(', '));

    // d) prise saturée : signalée
    await sel(1);
    await page.evaluate(() => { const t = window.__studiovoix.tracks[1], m = t.take.mono; let pk = 0; for (const v of m) pk = Math.max(pk, Math.abs(v)); for (let i = 0; i < m.length; ++i) m[i] = Math.max(-0.6, Math.min(0.6, m[i] / pk * 1.5)); t.fx = { comp: { on: false } }; });
    rows = await inspect(); show(rows);
    check('prise saturée : signalée', rows.some((r) => r.level === 'bad' && /saturée/.test(r.text)), rows.map((r) => r.level).join(', '));

    // e) toutes les pistes
    await page.click('#inspectAllBtn');
    await page.waitForFunction(() => !window.__studiovoix.inspecting && window.__studiovoix.tracks.filter((t) => t.take).every((t) => t.inspect && !t.inspect.stale), null, { timeout: 240000 });
    const all = await page.evaluate(() => [...document.querySelectorAll('#inspectAllBox .finding')].map((f) => f.textContent));
    all.forEach((l) => console.log(stamp(), '   ', l.slice(0, 200)));
    const takes = await page.evaluate(() => window.__studiovoix.tracks.filter((t) => t.take).length);
    check('« Inspecter les pistes » : une ligne par piste', all.length === takes && takes >= 2, `${all.length} lignes pour ${takes} pistes`);

    // f) (facultatif, sans exigence) une vraie voix
    if (process.env.VOICE_WAV) {
        await page.goto(url, { waitUntil: 'load' });
        await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });
        await page.click('details.more > summary'); await page.uncheck('#isolateVoice').catch(() => {});
        await page.selectOption('#addRole', 'lead'); await page.click('#addTrackBtn');
        await page.locator('input.voiceFile').last().setInputFiles(process.env.VOICE_WAV);
        await page.waitForFunction(() => { const t = window.__studiovoix.tracks.at(-1); return t.take && t.processed && t.status === 'done'; }, null, { timeout: 300000 });
        await page.evaluate(() => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks.at(-1).id}"] .head`).click());
        const t1 = Date.now(); rows = await inspect(); console.log(stamp(), `vraie voix inspectée en ${((Date.now() - t1) / 1000).toFixed(1)} s`); show(rows);
        console.log(stamp(), (await page.textContent('#log')).split(/(?=\d+:\d+:\d+ [AP]M)/).filter((l) => /Inspection/.test(l)).map((l) => '   ' + l.slice(0, 260)).join('\n'));
    }
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
