// Essai de propreté de la chaîne d'effets (moteur WASM, dans la page) : « la voix craque quand le niveau monte, une fois
// les effets mis ». Une note tenue parfaitement propre, par passages à des niveaux connus (+0, +6, +12, +18 dB au-dessus
// du niveau courant), traverse chaque style, avec et sans « Voix lissée ». La saleté = part de l'énergie qui n'est PAS sur
// les harmoniques de la note (craquements, gigue, bruit de modulation), mesurée au milieu de chaque passage.
// Avant correction (autotune posé à l'échantillon entier, dé-écrêtage des crêtes fortes, débruitage qui apprenait le
// chant doux comme du bruit) : jusqu'à -23 dB au-dessus de 2 kHz. Exigé ici : -55 dB partout, pour tous les styles.
//   node web/test/clean.mjs <url> [style ...]
import { createRequire } from 'node:module';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium } = require('playwright');

const [url, ...only] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/clean.mjs <url> [style ...]'); process.exit(2); }
const LIMIT_DB = Number(process.env.MAX_DIRT_DB || -55);
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
let failed = false;
try {
    const page = await browser.newPage();
    page.on('pageerror', (e) => console.log(stamp(), 'PAGEERROR', e.message));
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });

    await page.evaluate(() => {
        const st = window.__studiovoix, sr = 44100;
        const call = (cmd, payload) => new Promise((resolve, reject) => {
            const id = 8000000 + Math.floor(Math.random() * 1e6);
            const on = (e) => { if (e.data?.id !== id) return; st.worker.removeEventListener('message', on); e.data.ok ? resolve(e.data) : reject(new Error(e.data.error)); };
            st.worker.addEventListener('message', on);
            st.worker.postMessage({ id, cmd, ...payload });
        });
        const LEVELS = [0, 0, 6, 0, 12, 0, 18, 0, 12, 0, 0], PH = 1.4, GAP = 0.4;
        // Note tenue : 30 harmoniques, un formant vers 2,8 kHz ; chaque passage a son niveau.
        const tone = (f0) => {
            const n = Math.round(LEVELS.length * (PH + GAP) * sr), x = new Float32Array(n), base = 0.9 * Math.pow(10, -18 / 20) / 2.2;
            LEVELS.forEach((db, k) => {
                const a = Math.round(k * (PH + GAP) * sr), len = Math.round(PH * sr), g = base * Math.pow(10, db / 20), fade = Math.round(0.02 * sr);
                for (let i = 0; i < len; ++i) {
                    const ph = 2 * Math.PI * f0 * i / sr;
                    let v = 0;
                    for (let h = 1; h <= 30 && h * f0 < 9000; ++h) v += Math.sin(h * ph + h * h * 0.7) / h * (1 + 1.5 * Math.exp(-Math.pow((h * f0 - 2800) / 900, 2)));
                    x[a + i] = g * v * Math.min(1, i / fade, (len - 1 - i) / fade);
                }
            });
            return x;
        };
        const fft = (re, im) => {
            const n = re.length;
            for (let i = 1, j = 0; i < n; ++i) { let b = n >> 1; for (; j & b; b >>= 1) j ^= b; j ^= b; if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; } }
            for (let len = 2; len <= n; len <<= 1) {
                const ang = -2 * Math.PI / len, wr = Math.cos(ang), wi = Math.sin(ang);
                for (let i = 0; i < n; i += len) { let cr = 1, ci = 0; for (let k = 0; k < len / 2; ++k) { const a = i + k, b = a + len / 2, xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr; re[b] = re[a] - xr; im[b] = im[a] - xi; re[a] += xr; im[a] += xi; const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t; } }
            }
        };
        // Saleté du passage k : énergie hors des harmoniques / énergie sur les harmoniques (dB), sur 0,74 s au milieu.
        const dirt = (x, k) => {
            const N = 32768, a = Math.round((k * (PH + GAP) + 0.45) * sr), re = new Float64Array(N), im = new Float64Array(N);
            for (let i = 0; i < N; ++i) { const u = 2 * Math.PI * i / (N - 1); re[i] = (x[a + i] || 0) * (0.35875 - 0.48829 * Math.cos(u) + 0.14128 * Math.cos(2 * u) - 0.01168 * Math.cos(3 * u)); }
            fft(re, im);
            const p = new Float64Array(N / 2); for (let i = 0; i < N / 2; ++i) p[i] = re[i] * re[i] + im[i] * im[i] + 1e-300;
            const bin = sr / N; let b0 = 0, m = 0;
            for (let i = Math.round(120 / bin); i < Math.round(330 / bin); ++i) if (p[i] > m) { m = p[i]; b0 = i; }
            const d = 0.5 * (Math.log(p[b0 - 1]) - Math.log(p[b0 + 1])) / (Math.log(p[b0 - 1]) - 2 * Math.log(p[b0]) + Math.log(p[b0 + 1]));
            const f0 = (b0 + d) * bin, isHarm = new Uint8Array(N / 2);
            for (let h = 1; h * f0 < 16000; ++h) { const c = Math.round(h * f0 / bin), w = 6 + Math.ceil(h * 0.15); for (let i = Math.max(1, c - w); i <= Math.min(N / 2 - 1, c + w); ++i) isHarm[i] = 1; }
            let harm = 0, rest = 0, harmHi = 0, restHi = 0;
            for (let i = Math.round(60 / bin); i < Math.round(16000 / bin); ++i) { const hi = i * bin > 2000; if (isHarm[i]) { harm += p[i]; if (hi) harmHi += p[i]; } else { rest += p[i]; if (hi) restHi += p[i]; } }
            return { f0, all: 10 * Math.log10(rest / harm), hi: 10 * Math.log10(restHi / harmHi) };
        };
        window.__clean = async (cfg) => {
            const x = tone(cfg.f0);
            await call('setContext', { root: 9, minor: true, bpm: 100, firstBeatSec: 0, useScale: true });
            let y = x, cents = 0;
            if (cfg.style) {
                const r = await call('processVoice', { mono: x.slice(), sampleRate: sr, styleId: cfg.style, roleId: 'lead', cleaning: true, useScale: true, startSec: 0, fx: cfg.fx || null, gentle: !!cfg.gentle });
                y = new Float32Array(x.length); for (let i = 0; i < x.length; ++i) y[i] = 0.5 * (r.left[i] + r.right[i]);
                cents = r.report.meanCorrectionCents;
            }
            const d = LEVELS.map((_, k) => dirt(y, k));
            return { worst: Math.max(...d.map((v) => Math.max(v.all, v.hi))), worstLoud: Math.max(...d.filter((_, k) => LEVELS[k] > 0).map((v) => Math.max(v.all, v.hi))), f0: d[1].f0, cents };
        };
    });
    const run = (cfg) => page.evaluate((cfg) => window.__clean(cfg), cfg);
    const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };

    // 0) L'instrument de mesure : la note brute est propre (sinon l'essai ne prouve rien).
    const raw = await run({ f0: 200 });
    check('note d\'essai brute', raw.worst < -85, `saleté ${raw.worst.toFixed(0)} dB`);

    // 1) L'autotune seul, sur une note fausse de 35 cents (200 Hz, entre sol et sol dièse) : il corrige vraiment, et proprement.
    const off = Object.fromEntries(['clean', 'leveler', 'timing', 'eq', 'resonance', 'comp', 'comp2', 'deEss', 'sat', 'reverb', 'delay'].map((id) => [id, { on: false }]));
    const tuned = await run({ f0: 200, style: 'rap_conscient', fx: { ...off, pitch: { on: true, amount: 1, retuneMs: 20 } } });
    check('autotune seul : la note est corrigée', Math.abs(tuned.f0 - 196) < 1.0 && tuned.cents > 20, `200,0 Hz → ${tuned.f0.toFixed(1)} Hz (sol = 196,0), correction moyenne ${tuned.cents.toFixed(0)} cents`);
    check('autotune seul : propre', tuned.worst < LIMIT_DB, `saleté ${tuned.worst.toFixed(0)} dB (limite ${LIMIT_DB})`);
    // Note déjà juste : le son d'origine passe tel quel.
    const kept = await run({ f0: 196, style: 'rap_conscient', fx: { ...off, pitch: { on: true } } });
    check('autotune seul, note déjà juste : son d\'origine intact', kept.worst < -85, `saleté ${kept.worst.toFixed(0)} dB`);

    // 2) Chaque style, sans et avec « Voix lissée », sur la note fausse (l'autotune travaille) : propre à tous les niveaux.
    //    Réverb et écho sont éteints pour la mesure : ce sont des filtres linéaires (ils ne peuvent pas craquer), mais
    //    leurs résonances propres et l'écho des attaques tombent hors des harmoniques et fausseraient la mesure
    //    (cloud rap : -44 dB avec la réverb seule, par construction).
    const noSpace = { reverb: { on: false }, delay: { on: false } };
    const styles = only.length ? only : await page.evaluate(() => window.__studiovoix.styles.flatMap((g) => g.styles.map((s) => s.id)));
    let worst = { v: -200, name: '' };
    for (const style of styles) {
        const a = await run({ f0: 200, style, fx: noSpace }), b = await run({ f0: 200, style, gentle: true, fx: noSpace });
        const w = Math.max(a.worst, b.worst);
        if (w > worst.v) worst = { v: w, name: style };
        if (w >= LIMIT_DB || only.length) check(`style ${style}`, w < LIMIT_DB, `saleté ${a.worst.toFixed(0)} dB (passages forts ${a.worstLoud.toFixed(0)}) ; lissé ${b.worst.toFixed(0)} dB (forts ${b.worstLoud.toFixed(0)})`);
    }
    check(`${styles.length} styles, avec et sans « Voix lissée »`, worst.v < LIMIT_DB, `pire saleté ${worst.v.toFixed(0)} dB (${worst.name}) ; limite ${LIMIT_DB} dB`);
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
