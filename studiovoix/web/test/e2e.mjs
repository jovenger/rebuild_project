// Test de bout en bout de StudioVoix Web (Chromium sans écran, Playwright) :
// page servie en local, instru et voix importées par les champs fichier, style appliqué, mix exporté en WAV.
//   node web/test/e2e.mjs <url> <instru.wav> <voix.wav> [capture.png]
import { statSync } from 'node:fs';
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
const t0 = Date.now();
const stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined,
                                        args: ['--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ acceptDownloads: true });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
try {
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Moteur prêt'), null, { timeout: 60000 });
    console.log(stamp(), 'moteur prêt :', await page.textContent('#version'));

    if (instru && voice) {
        await page.setInputFiles('#instruFile', instru);
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Instru analysée'), null, { timeout: 120000 });
        console.log(stamp(), await page.textContent('#status'));
        await page.setInputFiles('#voiceFile', voice);
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Voix importée'), null, { timeout: 60000 });
        console.log(stamp(), await page.textContent('#status'));
    } else {
        await page.click('#demoBtn');
        await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Démo prête'), null, { timeout: 180000 });
        console.log(stamp(), await page.textContent('#status'));
    }

    await page.selectOption('#style', 'rap_conscient');
    await page.click('#processBtn');
    await page.waitForFunction(() => document.getElementById('status').textContent.startsWith('Voix traitée'), null, { timeout: 300000 });
    console.log(stamp(), await page.textContent('#status'));
    const report = await page.textContent('#report');
    console.log(report.split('\n').slice(0, 3).join('\n'));
    if (!report.includes('Chaîne appliquée')) throw new Error('rapport incomplet');

    const [download] = await Promise.all([page.waitForEvent('download', { timeout: 60000 }), page.click('#exportBtn')]);
    const path = await download.path();
    const size = statSync(path).size;
    console.log(stamp(), `export ${download.suggestedFilename()} : ${size} octets`);
    if (size < 1000) throw new Error('WAV exporté trop petit');

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
