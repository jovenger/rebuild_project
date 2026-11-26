// Essai de l'inspection de piste (« le programme détecte lui-même ce qui ne va pas et dit quoi faire ») :
//  1. les mesures seules (inspect.js) : un son identique = 0 dB de saleté, un égaliseur ne compte pas, du bruit ajouté
//     compte, des plateaux = écrêtage ;
//  2. dans la page, sur la démo : une piste saine sort « rien d'anormal » ; un effet qui salit (simulé par
//     ?svTestDirt=comp) est nommé, son bouton l'éteint et l'inspection suivante est propre ; une prise saturée est
//     signalée ; « Inspecter les pistes » liste toutes les pistes ;
//  3. saturation et craquements : mesures seules sur des sons de synthèse (une saturation légère reste loin du seuil,
//     une saturation abusive le dépasse, un compresseur — gain lent — ne compte pas ; une voix propre avec consonnes
//     n'a aucun craquement, un saut, un échantillon faux et un trou insérés sont trouvés à leur instant) ; dans la
//     page : saturation au maximum signalée, nommée et éteinte par son bouton, réglages par défaut non signalés, un
//     craquement inséré dans la prise signalé avec son instant ;
//  4. faux trou corrigé : un son grave et faible qui traverse zéro en pente douce, sous une crête forte ailleurs (prise
//     micro avec de la basse captée), n'est pas un trou ; un vrai trou de 2 ms dans ce même son est trouvé.
//   node web/test/inspect.mjs <url>          (VOICE_WAV=fichier : inspecte en plus cette voix, sans rien exiger ;
//                                             REAL_VOICE=fichier WAV d'une vraie voix propre : mêmes contrôles de
//                                             saturation et de craquements sur cette voix, mesures seules et page)
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { voiceDirt, clipRuns, loudestWindow, addedDistortion, findCrackles, findDropouts } from '../inspect.js';
import { resampleSinc } from '../resample.js';
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
    // une note pure tenue à la crête n'est pas un écrêtage (son sommet arrondi reste lui aussi 3 échantillons à 0,5 % de la crête)
    { let worst = 0; for (const f of [55, 110, 220, 440, 880, 1760, 3520]) { const t = new Float32Array(sr); for (let k = 0; k < sr; ++k) t[k] = 0.9 * Math.sin(2 * Math.PI * f * k / sr + 0.3); worst = Math.max(worst, clipRuns(t).runs); }
      check('note pure non écrêtée : aucun plateau', worst === 0, `pire ${worst} plateau(x) de 55 à 3520 Hz`); }
    check('passage le plus fort', Math.abs(loudestWindow(x, sr, 2) / sr - 6) < 0.3, `trouvé à ${(loudestWindow(x, sr, 2) / sr).toFixed(2)} s (attendu 6 s)`);
}

// ---------------------------------------------------------------- 1 bis) saturation et craquements, mesures seules
// Mêmes seuils que la page (app.js : SAT_WARN_DB, CRACKLE).
const SAT_WARN_DB = -22, CRACKLE = { kSigma: 12, kIso: 6, minAmp: 0.02 };
// Discontinuités d'essai : saut (marche qui retombe en 10 ms), échantillon faux, trou à zéro.
const addStep = (y, sr, t, h) => { const n0 = Math.round(t * sr), end = Math.min(y.length, n0 + Math.round(0.06 * sr)); for (let i = n0; i < end; ++i) y[i] += h * Math.exp(-(i - n0) / (0.01 * sr)); };
const addHole = (y, sr, t, ms) => { const n0 = Math.round(t * sr), end = Math.min(y.length, n0 + Math.round(ms * sr / 1000)); for (let i = n0; i < end; ++i) y[i] = 0; };
const near = (list, sr, t, kind) => list.some((c) => Math.abs(c.at / sr - t) < 0.008 && (!kind || c.kind === kind));
for (const sr of [44100, 48000]) {
    // voix de synthèse « parlée-chantée » : syllabes de 0,35 s (note qui glisse, vibrato, 30 harmoniques, deux formants)
    // de niveaux différents, séparées par 0,2 s de silence que termine une consonne (bruit aigu à attaque de 1 ms).
    const n = 10 * sr, x = new Float32Array(n);
    let ph = 0, seed = 99, hp = 0, prev = 0;
    const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x3fffffff - 1; };
    for (let i = 0; i < n; ++i) {
        const t = i / sr, k = Math.floor(t / 0.55), u = t - k * 0.55;
        const f = (130 + 25 * (k % 5)) * (1 + 0.01 * Math.sin(2 * Math.PI * 5.5 * t)) + 20 * u;
        ph += 2 * Math.PI * f / sr;
        const env = u > 0 && u < 0.35 ? Math.pow(Math.sin(Math.PI * u / 0.35), 0.6) : 0, lvl = 0.5 + 0.5 * ((k * 7) % 4) / 3;
        let v = 0; for (let h = 1; h <= 30 && h * f < 0.45 * sr; ++h) v += Math.sin(h * ph + 0.9 * h * h) / h * (1 + 2 * Math.exp(-Math.pow((h * f - 700) / 300, 2)) + 1.5 * Math.exp(-Math.pow((h * f - 2600) / 700, 2)));
        const c = u > 0.49 && u < 0.53 ? Math.min(1, (u - 0.49) / 0.001) * Math.min(1, (0.53 - u) / 0.01) : 0;
        const w = rnd(); hp = 0.85 * (hp + w - prev); prev = w;
        x[i] = 0.12 * lvl * env * v + 0.05 * c * hp + 0.0005 * w;
    }
    const tag = `${sr / 1000} kHz`;
    // craquements
    const clean = findCrackles(x, sr, CRACKLE);
    check(`craquements, ${tag} : voix propre avec consonnes, aucun`, clean.length === 0, `${clean.length} trouvé(s)${clean.length ? ' à ' + clean.map((c) => (c.at / sr).toFixed(2) + ' s').join(', ') : ''}`);
    const y = x.slice();
    addStep(y, sr, 1.2, 0.1); addStep(y, sr, 3.45, -0.2); y[Math.round(5.1 * sr)] += 0.15; addHole(y, sr, 6.75, 3); addStep(y, sr, 8.65, 0.1);
    const got = findCrackles(y, sr, CRACKLE);
    check(`craquements, ${tag} : saut, échantillon faux, trou et saut dans un silence trouvés à leur instant`,
        got.length === 5 && near(got, sr, 1.2, 'clic') && near(got, sr, 3.45, 'clic') && near(got, sr, 5.1, 'clic') && near(got, sr, 6.75, 'trou') && near(got, sr, 8.65, 'clic'),
        got.map((c) => `${(c.at / sr).toFixed(3)} s ${c.kind}${c.kind === 'trou' ? ` ${c.ms.toFixed(1)} ms` : ` ${c.amp.toFixed(2)}`}`).join(' ; ') || 'rien');
    // saturation : tanh dosée, à niveau égal (comme le moteur) ; la référence est le son sans elle
    const rms = Math.sqrt(x.reduce((p, q) => p + q * q, 0) / n);
    const sat = (mix, driveDb) => { const d = Math.pow(10, driveDb / 20) / (4 * rms), w = Float32Array.from(x, (v) => Math.tanh(d * v)); const wr = Math.sqrt(w.reduce((p, q) => p + q * q, 0) / n); return Float32Array.from(x, (v, i) => (1 - mix) * v + mix * w[i] * rms / wr); };
    const same = addedDistortion(x, x, sr), slow = addedDistortion(x, Float32Array.from(x, (v, i) => v * (0.6 + 0.3 * Math.sin(2 * Math.PI * 1.5 * i / sr))), sr);
    const light = addedDistortion(x, sat(0.2, 2), sr), heavy = addedDistortion(x, sat(1, 24), sr);
    check(`distorsion, ${tag} : son identique et gain lent (compresseur) loin du seuil`, same.db <= -55 && slow.db < SAT_WARN_DB - 10 && same.frames > 100, `identique ${same.db.toFixed(1)} dB, gain qui varie de ±50 % à 1,5 Hz ${slow.db.toFixed(1)} dB (alerte à ${SAT_WARN_DB} dB)`);
    check(`distorsion, ${tag} : saturation légère sous le seuil, abusive au-dessus`, light.db < SAT_WARN_DB - 10 && heavy.db > SAT_WARN_DB + 6, `légère (20 %, +2 dB) ${light.db.toFixed(1)} dB ; abusive (100 %, +24 dB) ${heavy.db.toFixed(1)} dB`);
    // trous : une note forte (crête 0,5) puis, plus loin, un son grave et faible (55 Hz et son 3e harmonique, 0,05) dont
    // chaque passage à zéro est un palier : plus de 1 ms sous le seuil (un millième de la crête), puis une remontée
    // douce. L'ancienne règle (niveau moyen des 1,5 ms voisines seulement) y voyait des trous ; il n'y en a aucun.
    const low = new Float32Array(4 * sr);
    for (let i = 0; i < low.length; ++i) {
        const t = i / sr;
        if (t > 0.2 && t < 1.2) { const ph = 2 * Math.PI * 220 * t; let v = 0; for (let h = 1; h <= 8; ++h) v += Math.sin(h * ph + h) / h; low[i] = 0.5 / 1.9 * v * Math.min(1, (t - 0.2) / 0.05, (1.2 - t) / 0.05); }
        if (t > 1.6 && t < 3.6) { const th = 2 * Math.PI * 55 * (t - 1.6); low[i] = 0.04 * (Math.sin(th) - Math.sin(3 * th) / 3) * Math.min(1, (t - 1.6) / 0.1, (3.6 - t) / 0.1); }
    }
    const oldHoles = findDropouts(low, sr, { jump: 0 }), lowCr = findCrackles(low, sr, CRACKLE);
    check(`trous, ${tag} : son grave faible qui traverse zéro lentement, sous une crête forte ailleurs — aucun trou`, oldHoles.length >= 10 && lowCr.length === 0, `${lowCr.length} défaut(s) trouvé(s) ; l'ancienne règle y voyait ${oldHoles.length} trous`);
    const tHole = 1.6 + 40.25 / 55 - 0.001, holed = low.slice(); addHole(holed, sr, tHole, 2);
    const holeCr = findCrackles(holed, sr, CRACKLE);
    check(`trous, ${tag} : vrai trou de 2 ms dans ce même son — trouvé`, holeCr.length === 1 && holeCr[0].kind === 'trou' && near(holeCr, sr, tHole, 'trou') && Math.abs(holeCr[0].ms - 2) < 0.3, holeCr.map((c) => `${(c.at / sr).toFixed(4)} s ${c.kind} ${c.ms.toFixed(2)} ms`).join(' ; ') || 'rien');
}
// Vraie voix (facultatif) : REAL_VOICE = WAV d'une voix propre. Aucun craquement à l'état d'origine (un toléré), et les
// discontinuités insérées dans la voix sont trouvées à 80 % au moins.
const readWav = (path) => {
    const b = readFileSync(path); let o = 12, fmt = null, data = null;
    if (b.toString('ascii', 0, 4) !== 'RIFF' || b.toString('ascii', 8, 12) !== 'WAVE') throw new Error(`${path} : pas un fichier WAV`);
    while (o + 8 <= b.length) { const id = b.toString('ascii', o, o + 4), sz = b.readUInt32LE(o + 4); if (id === 'fmt ') fmt = { tag: b.readUInt16LE(o + 8), ch: b.readUInt16LE(o + 10), sr: b.readUInt32LE(o + 12), bits: b.readUInt16LE(o + 22) }; if (id === 'data') data = b.subarray(o + 8, Math.min(b.length, o + 8 + sz)); o += 8 + sz + (sz & 1); }
    if (!fmt || !data || !fmt.ch || ![16, 24, 32].includes(fmt.bits)) throw new Error(`${path} : format WAV non lu`);
    const bytes = fmt.bits / 8, n = Math.floor(data.length / (bytes * fmt.ch)), x = new Float32Array(n);
    for (let i = 0; i < n; ++i) { let v = 0; for (let c = 0; c < fmt.ch; ++c) { const q = (i * fmt.ch + c) * bytes; v += fmt.tag === 3 ? data.readFloatLE(q) : bytes === 2 ? data.readInt16LE(q) / 32768 : bytes === 3 ? data.readIntLE(q, 3) / 8388608 : data.readInt32LE(q) / 2147483648; } x[i] = v / fmt.ch; }
    return { x, sr: fmt.sr };
};
if (process.env.REAL_VOICE) {
    try {
        const w = readWav(process.env.REAL_VOICE), sr = w.sr < 32000 ? 44100 : w.sr, x = w.sr === sr ? w.x : resampleSinc(w.x, w.sr, sr);
        const raw = findCrackles(x, sr, CRACKLE);
        check('vraie voix : pas de craquement à l\'état d\'origine (un toléré)', raw.length <= 1, `${raw.length} sur ${(x.length / sr).toFixed(1)} s${raw.length ? ' à ' + raw.map((c) => (c.at / sr).toFixed(2) + ' s').join(', ') : ''} (${w.sr} Hz${w.sr === sr ? '' : ' → ' + sr + ' Hz'})`);
        // instants dans la voix : tous les 0,35 s, là où le niveau dépasse 10 % du niveau le plus fort
        let top = 0; const lv = (t) => { let e = 0; const a = Math.round(t * sr); for (let i = a - 256; i < a + 256; ++i) e += (x[i] || 0) ** 2; return Math.sqrt(e / 512); };
        const times = []; for (let t = 0.3; t < x.length / sr - 0.3; t += 0.35) { times.push(t); top = Math.max(top, lv(t)); }
        const inVoice = times.filter((t) => lv(t) > 0.1 * top);
        for (const [name, put, kind] of [['sauts de 0,1', (y, t) => addStep(y, sr, t, 0.1), 'clic'], ['trous de 2 ms', (y, t) => addHole(y, sr, t, 2), '']]) {
            const y = x.slice(); inVoice.forEach((t) => put(y, t));
            const got = findCrackles(y, sr, CRACKLE), hit = inVoice.filter((t) => near(got, sr, t, kind) || got.some((c) => c.at / sr <= t + 0.008 && c.end / sr >= t - 0.008)).length;
            check(`vraie voix : ${name} insérés dans la voix, trouvés à 80 % au moins`, inVoice.length >= 5 && hit >= 0.8 * inVoice.length, `${hit} sur ${inVoice.length}`);
        }
    } catch (err) { check('vraie voix : lecture du fichier', false, err.message); }
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

    // 0) mode « Correction » (mode de départ de toute piste : correction seule, sans couleur de style) : l'inspection
    //    rejoue le moteur avec la correction seule, essaie les mêmes effets un par un et nomme celui qui salit.
    await sel(0);
    const mode0 = await page.evaluate(() => { const t = window.__studiovoix.tracks[0], r = t.processed?.report; return { correction: !!t.correction && !t.noFx, mode: r?.mode, sat: !!r?.fx?.sat?.on, comp: !!r?.fx?.comp?.on }; });
    check('démo : piste en mode Correction avant l\'inspection', mode0.correction && mode0.mode === 'correction' && !mode0.sat && mode0.comp, JSON.stringify(mode0));
    let rows = await inspect(); show(rows);
    const hitC = rows.find((r) => /Compresseur/.test(r.text) && /Éteindre/.test(r.btn));
    const logC = (await page.$$eval('#log div', (els) => els.map((x) => x.textContent))).filter((l) => /Inspection de « .* » \(mode Correction/.test(l));
    check('mode Correction : effet qui salit nommé avec un bouton, sans mesure de saturation (éteinte)', !!hitC && (hitC.level === 'bad' || hitC.level === 'warn') && logC.length >= 1 && !rows.some((r) => /saturation/i.test(r.text)),
        hitC ? `${hitC.text.slice(0, 140)} ; journal : ${logC.length} ligne(s) « mode Correction »` : 'aucun constat sur le compresseur');
    // La suite contrôle l'inspection des effets d'un style (saturation comprise) : la piste est passée en mode Style à
    // la main (bouton « Style » du tableau des effets), comme le fait l'utilisateur.
    await page.click('#fxMode button[data-mode="style"]');
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0]; return !t.correction && !t.noFx && t.status === 'done' && t.processed?.report?.mode === 'style'; }, null, { timeout: 120000 });
    await settled();

    // a) l'effet qui salit (simulé : compresseur) est nommé, avec son bouton
    await sel(0);
    rows = await inspect(); show(rows);
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

    const okRow = rows.find((r) => r.level === 'ok');
    check('réglages par défaut : saturation mesurée, pas signalée ; aucun craquement', !!okRow && /distorsion de la saturation -\d+ dB/.test(okRow.text) && /aucun craquement/.test(okRow.text) && !rows.some((r) => /déforme|La prise craque/.test(r.text)), okRow ? okRow.text.slice(0, 220) : 'pas de constat « rien d\'anormal »');

    // g) saturation au maximum : signalée, nommée, son bouton l'éteint
    const setFx = (k, fx) => page.evaluate(([k, fx]) => { const t = window.__studiovoix.tracks[k]; t.fx = { ...(t.fx || {}), ...fx }; }, [k, fx]);
    await setFx(0, { sat: { on: true, mix: 1, driveDb: 24 } });
    rows = await inspect(); show(rows);
    const satRow = rows.find((r) => /Saturation/.test(r.text) && /déforme/.test(r.text));
    check('saturation au maximum : signalée et nommée, avec son bouton', !!satRow && (satRow.level === 'bad' || satRow.level === 'warn') && /Éteindre « Saturation/.test(satRow.btn), satRow ? `[${satRow.level}] ${satRow.text.slice(0, 150)} → « ${satRow.btn} »` : 'aucun constat sur la saturation');
    await page.locator('#inspectBox .finding button', { hasText: 'Saturation' }).first().click();
    await page.waitForFunction(() => { const t = window.__studiovoix.tracks[0]; return t.fx?.sat?.on === false && t.status === 'done' && t.processed?.report?.fx?.sat?.on === false && t.inspect?.stale; }, null, { timeout: 120000 });
    await settled();
    rows = await inspect(); show(rows);
    check('saturation éteinte par le bouton : plus rien d\'anormal', rows.some((r) => r.level === 'ok') && !rows.some((r) => r.level === 'warn' || r.level === 'bad'), rows.map((r) => r.level).join(', '));

    // h) un craquement inséré dans la prise (trou de 3 ms au plus fort de la voix : un bloc perdu à l'enregistrement) :
    //    signalé avec son instant
    const click = await page.evaluate(() => {
        const t = window.__studiovoix.tracks[0], m = t.take.mono, sr = t.take.sampleRate;
        let n0 = 0; for (let i = sr; i < m.length - sr; ++i) if (Math.abs(m[i]) > Math.abs(m[n0])) n0 = i;
        const keep = m.slice(n0, n0 + Math.round(0.003 * sr));
        m.fill(0, n0, n0 + keep.length);
        window.__svTestKeep = { n0, keep };
        const sec = t.take.startSec + n0 / sr;
        return { sec, label: `${Math.floor(sec / 60)}:${String(Math.floor(sec % 60)).padStart(2, '0')}` };
    });
    rows = await inspect(); show(rows);
    const crRow = rows.find((r) => /La prise craque/.test(r.text));
    check('craquement inséré dans la prise : signalé avec son instant', !!crRow && (crRow.level === 'warn' || crRow.level === 'bad') && crRow.text.includes(` à ${click.label}`) && /1 craquement /.test(crRow.text) && /enregistrement/.test(crRow.text),
        crRow ? `inséré à ${click.sec.toFixed(2)} s (${click.label}) — ${crRow.text.slice(0, 150)}` : `inséré à ${click.label}, aucun constat`);
    await page.evaluate(() => { const t = window.__studiovoix.tracks[0], k = window.__svTestKeep; t.take.mono.set(k.keep, k.n0); });

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

    // f) (facultatif) une vraie voix : VOICE_WAV sans exigence ; REAL_VOICE = voix propre, contrôles de saturation
    const realVoice = process.env.REAL_VOICE || '';
    if (process.env.VOICE_WAV || realVoice) {
        await page.goto(url, { waitUntil: 'load' });
        await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });
        await page.click('details.more > summary'); await page.uncheck('#isolateVoice').catch(() => {});
        await page.selectOption('#addRole', 'lead'); await page.click('#addTrackBtn');
        await page.locator('input.voiceFile').last().setInputFiles(realVoice || process.env.VOICE_WAV);
        await page.waitForFunction(() => { const t = window.__studiovoix.tracks.at(-1); return t.take && t.processed && t.status === 'done'; }, null, { timeout: 300000 });
        await page.evaluate(() => document.querySelector(`#tracks .track[data-id="${window.__studiovoix.tracks.at(-1).id}"] .head`).click());
        const t1 = Date.now(); rows = await inspect(); console.log(stamp(), `vraie voix inspectée en ${((Date.now() - t1) / 1000).toFixed(1)} s`); show(rows);
        console.log(stamp(), (await page.textContent('#log')).split(/(?=\d+:\d+:\d+ [AP]M)/).filter((l) => /Inspection/.test(l)).map((l) => '   ' + l.slice(0, 260)).join('\n'));
        if (realVoice) {
            check('vraie voix, réglages par défaut : ni saturation ni craquement signalés', !rows.some((r) => /déforme|La prise craque/.test(r.text)), rows.filter((r) => r.level !== 'info').map((r) => `[${r.level}] ${r.text.slice(0, 120)}`).join(' | '));
            await page.evaluate(() => { const t = window.__studiovoix.tracks.at(-1); t.fx = { ...(t.fx || {}), sat: { on: true, mix: 1, driveDb: 24 } }; });
            rows = await inspect(); show(rows);
            const rr = rows.find((r) => /Saturation/.test(r.text) && /déforme/.test(r.text));
            check('vraie voix, saturation au maximum : signalée et nommée', !!rr && /Éteindre « Saturation/.test(rr.btn), rr ? `[${rr.level}] ${rr.text.slice(0, 150)}` : 'aucun constat sur la saturation');
        }
    }
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
