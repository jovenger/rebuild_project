// Essai de la « correction seule » (moteur WASM, dans la page) : une voix traitée avec l'identifiant de style
// « correction » ressort corrigée (volumes égalisés, compression à la mesure de la prise, justesse) et sans aucune
// couleur de style : ni réverb, ni écho, ni saturation, ni recalage rythmique, donc aucune traîne après la prise.
//   node web/test/correction.mjs <url> [voix.wav]
// Sans fichier : la voix de démonstration du moteur (synthèse, légèrement fausse). Avec un fichier (une vraie voix,
// par exemple jfk.wav du CI) : il est décodé par la page à 44,1 kHz, comme un fichier glissé dans le studio.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium } = require('playwright');

const [url, voiceFile = process.env.VOICE_FILE || ''] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/correction.mjs <url> [voix.wav]'); process.exit(2); }
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
let failed = false;
try {
    const page = await browser.newPage();
    page.on('pageerror', (e) => console.log(stamp(), 'PAGEERROR', e.message));
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });
    const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };

    // Dans la page : la voix (fichier décodé ou démo du moteur), et un appel direct du moteur par le worker de la page.
    const voiceB64 = voiceFile ? readFileSync(voiceFile).toString('base64') : '';
    const info = await page.evaluate(async (voiceB64) => {
        const st = window.__studiovoix, sr = 44100;
        const call = (cmd, payload) => new Promise((resolve, reject) => {
            const id = 7000000 + Math.floor(Math.random() * 1e6);
            const on = (e) => { if (e.data?.id !== id) return; st.worker.removeEventListener('message', on); e.data.ok ? resolve(e.data) : reject(new Error(e.data.error)); };
            st.worker.addEventListener('message', on);
            st.worker.postMessage({ id, cmd, ...payload });
        });
        // Voix de démonstration du moteur : chantée (synthèse) dans la gamme du morceau, légèrement fausse.
        const demo = (await call('demoVoice', { sampleRate: sr, bars: 8 })).left.slice(0, 20 * sr);
        let voice = demo;
        if (voiceB64) {
            const bin = atob(voiceB64), bytes = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; ++i) bytes[i] = bin.charCodeAt(i);
            const buf = await new OfflineAudioContext(1, 1, sr).decodeAudioData(bytes.buffer);   // rééchantillonné à 44,1 kHz
            voice = new Float32Array(buf.length);
            for (let c = 0; c < buf.numberOfChannels; ++c) { const d = buf.getChannelData(c); for (let i = 0; i < d.length; ++i) voice[i] += d[i] / buf.numberOfChannels; }
            voice = voice.slice(0, Math.min(voice.length, 20 * sr));
        }
        await call('setContext', { root: 9, minor: true, bpm: 100, firstBeatSec: 0, useScale: true });
        // Prise irrégulière faite exprès : un passage de 2,5 s sur deux est 10 dB plus bas (fondus de 30 ms).
        const uneven = voice.slice(), blk = Math.round(2.5 * sr), fade = Math.round(0.03 * sr), low = Math.pow(10, -10 / 20);
        for (let i = 0; i < uneven.length; ++i) {
            const k = Math.floor(i / blk), pos = i - k * blk, g = (odd) => (odd ? low : 1);
            const cur = g(k % 2 === 1), prev = g((k - 1) % 2 === 1 && k > 0);
            uneven[i] *= pos < fade ? prev + (cur - prev) * pos / fade : cur;
        }
        const peakDb = (x, a, b) => { let m = 0; for (let i = Math.max(0, a); i < Math.min(x.length, b); ++i) m = Math.max(m, Math.abs(x[i])); return 20 * Math.log10(m + 1e-12); };
        const levels = (x) => { const n = Math.round(0.4 * sr), hop = Math.round(0.1 * sr), v = []; for (let s = 0; s + n <= x.length; s += hop) { let e = 0; for (let i = 0; i < n; ++i) e += x[s + i] * x[s + i]; v.push(10 * Math.log10(e / n + 1e-20)); } return v; };
        const range = (lv, mask) => { const v = lv.filter((_, i) => mask[i]).sort((a, b) => a - b); return v.length < 5 ? NaN : v[Math.floor(0.9 * (v.length - 1))] - v[Math.floor(0.1 * (v.length - 1))]; };
        // Traite une prise ; rend le rapport, la sortie mono ramenée à la longueur de la prise, et la crête de la traîne
        // (de 0,25 s après la fin de la prise jusqu'au bout de la sortie, 3 s plus loin).
        window.__corr = async (which, cfg = {}) => {
            const x = which === 'uneven' ? uneven : which === 'voice' ? voice : which === 'demo' ? demo : window.__corrOut[which];
            const r = await call('processVoice', { mono: x.slice(), sampleRate: sr, styleId: cfg.style || 'correction', roleId: cfg.roleId || 'lead', cleaning: true, useScale: true, startSec: 0, fx: cfg.fx || null, gentle: !!cfg.gentle });
            const y = new Float32Array(x.length);
            for (let i = 0; i < x.length; ++i) y[i] = 0.5 * (r.left[i] + r.right[i]);
            if (cfg.keep) (window.__corrOut = window.__corrOut || {})[cfg.keep] = y;
            const from = x.length + Math.round(0.25 * sr);
            // Étendue de niveau (P90 - P10 du niveau sur 400 ms) avant et après, sur les MÊMES fenêtres : celles où la
            // prise d'origine est active (seuil d'activité du moteur, d'après ses mesures de la prise).
            const m = r.report.measure || {}, gate = Math.max(-60, Math.min(m.noiseFloorDb + 12, m.activeLevelDb - 20));
            const lx = levels(x), ly = levels(y), mask = lx.map((v) => v > gate);
            return { report: r.report, frames: r.left.length, takeFrames: x.length, tailDb: Math.max(peakDb(r.left, from, r.left.length), peakDb(r.right, from, r.right.length)), outPeakDb: peakDb(y, 0, y.length),
                rangeIn: range(lx, mask), rangeOut: range(ly, mask) };
        };
        return { seconds: voice.length / sr, listed: st.styles.flatMap((g) => g.styles.map((s) => s.id)) };
    }, voiceB64);
    const run = (which, cfg) => page.evaluate(({ which, cfg }) => window.__corr(which, cfg), { which, cfg });
    console.log(stamp(), 'voix :', voiceFile || 'démo du moteur (synthèse)', `— ${info.seconds.toFixed(1)} s`);
    check('« correction » hors de la liste des styles de la page', !info.listed.includes('correction'), `${info.listed.length} styles dans la liste`);

    // 1) La voix telle quelle : réglages rendus sans aucune couleur, rapport complet.
    const a = await run('voice', { keep: 'a' });
    const fx = a.report.fx, m = a.report.measure || {};
    console.log(stamp(), 'décisions :', a.report.fitNotes);
    console.log(stamp(), 'constats  :', a.report.found || 'aucun');
    check('mode correction rendu', a.report.ok && a.report.mode === 'correction' && a.report.styleId === 'correction', `mode « ${a.report.mode} », style « ${a.report.style} »`);
    check('ni réverb, ni écho, ni saturation, ni recalage dans les réglages rendus', [fx, a.report.preset].every((f) => f && !f.reverb.on && !f.delay.on && !f.sat.on && !f.timing.on),
        `réverb ${fx.reverb.on ? 'oui' : 'non'}, écho ${fx.delay.on ? 'oui' : 'non'}, saturation ${fx.sat.on ? 'oui' : 'non'}, recalage ${fx.timing.on ? 'oui' : 'non'}`);
    check('chaîne décrite sans couleur', /Réverb : aucune/.test(a.report.chain) && /Délai : aucun/.test(a.report.chain) && /Saturation : aucune/.test(a.report.chain) && !/Recalage/.test(a.report.chain),
        a.report.chain.split('\n').filter((l) => /Réverb|Délai|Saturation/.test(l)).join(' | '));
    check('mesures de la prise rendues', ['levelRangeDb', 'noiseFloorDb', 'bodyBalanceDb', 'presenceBalanceDb', 'pitchDeviationCents', 'activeLevelDb'].every((k) => Number.isFinite(m[k])),
        `dynamique ${m.levelRangeDb?.toFixed(1)} dB, bruit ${m.noiseFloorDb?.toFixed(0)} dBFS, corps ${m.bodyBalanceDb?.toFixed(1)} dB, présence ${m.presenceBalanceDb?.toFixed(1)} dB, justesse ${m.pitchDeviationCents?.toFixed(0)} cents`);
    check('compresseur décidé sur la dynamique mesurée', fx.comp.on && fx.comp.ratio >= 1.29 && fx.comp.ratio <= 3.01 && /compresseur .*dynamique mesurée/.test(a.report.fitNotes),
        `${fx.comp.ratio.toFixed(2)}:1, seuil ${fx.comp.thresholdDb.toFixed(1)} dB pour ${m.levelRangeDb?.toFixed(1)} dB de dynamique ; réduction moyenne ${a.report.compGrDb.toFixed(1)} dB`);

    // 2) Pas de traîne : après la fin de la prise, silence numérique (un style avec réverb en laisse une : l'essai la voit).
    const pop = await run('voice', { style: 'pop' });
    check('pas de traîne après la prise', a.tailDb < -100, `crête après la fin : ${a.tailDb.toFixed(0)} dBFS (sortie ${a.outPeakDb.toFixed(1)} dBFS ; ${((a.frames - a.takeFrames) / 44100).toFixed(1)} s après la prise)`);
    check('l\'essai voit une traîne quand il y en a une (style pop)', pop.tailDb > -70 && pop.report.mode === 'style', `crête après la fin : ${pop.tailDb.toFixed(0)} dBFS`);

    // 3) Étendue de niveau réduite (mêmes fenêtres avant et après : celles où la prise d'origine est active).
    const u = await run('uneven');
    check('prise irrégulière : étendue de niveau réduite', u.rangeOut < u.rangeIn - 2, `${u.rangeIn.toFixed(1)} dB avant → ${u.rangeOut.toFixed(1)} dB après (compresseur ${u.report.fx.comp.ratio.toFixed(2)}:1, réduction moyenne ${u.report.compGrDb.toFixed(1)} dB)`);
    check('prise telle quelle : étendue de niveau pas agrandie', a.rangeOut <= a.rangeIn + 0.5, `${a.rangeIn.toFixed(1)} dB avant → ${a.rangeOut.toFixed(1)} dB après`);
    check('compression à la bonne valeur : plus ferme sur la prise irrégulière', u.report.measure.levelRangeDb > m.levelRangeDb && u.report.fx.comp.ratio >= fx.comp.ratio && u.report.fx.comp.thresholdDb < fx.comp.thresholdDb
        && (u.report.fx.comp.ratio > fx.comp.ratio + 0.1 || fx.comp.ratio > 2.99),
        `${fx.comp.ratio.toFixed(2)}:1 à ${fx.comp.thresholdDb.toFixed(1)} dB (dynamique ${m.levelRangeDb.toFixed(1)} dB) contre ${u.report.fx.comp.ratio.toFixed(2)}:1 à ${u.report.fx.comp.thresholdDb.toFixed(1)} dB (${u.report.measure.levelRangeDb.toFixed(1)} dB)`);

    // 4) Justesse : seulement sur une voix chantée (des notes tenues : measure.heldNoteFraction >= 0,45). Une voix parlée
    //    ou rappée ne reçoit aucune justesse (correction moyenne nulle), et c'est dit dans les décisions.
    //    Sur une voix chantée : justesse non dégradée — écart moyen à la gamme mesuré par le moteur avant (prise) et
    //    après (sortie repassée par la même mesure) ; référence : la même correction sans la justesse (le nettoyage
    //    seul déplace la mesure de quelques cents). L'écart se mesure par rapport à la gamme du morceau : il n'a de
    //    sens que si la justesse a visé cette gamme. Si le moteur a visé la gamme propre à la voix (ou la note la plus
    //    proche), la comparaison est affichée mais marquée NON VÉRIFIÉ, et la voix de démonstration (chantée dans la
    //    gamme du morceau) est vérifiée à sa place.
    const SUNG = 0.45, held = m.heldNoteFraction, heldPct = (v) => `${Math.round(v * 100)} %`;
    check('part de notes tenues rendue', Number.isFinite(held) && held >= 0 && held <= 1, `notes tenues ${Number.isFinite(held) ? heldPct(held) : '?'} des trames voisées (voix chantée à partir de ${heldPct(SUNG)})`);
    const pitchCheck = async (which, first, label, mustApply) => {
        const r = first || await run(which, { keep: 'p' });
        if (mustApply) check(`voix chantée : justesse appliquée (${label})`, r.report.measure.heldNoteFraction >= SUNG && r.report.fx.pitch.on && r.report.meanCorrectionCents > 1 && /justesse ramenée/.test(r.report.fitNotes),
            `notes tenues ${heldPct(r.report.measure.heldNoteFraction)}, autotune ${r.report.fx.pitch.on ? Math.round(r.report.fx.pitch.amount * 100) + ' %' : 'éteint'}, correction moyenne ${r.report.meanCorrectionCents.toFixed(1)} cents`);
        const out = await run(first ? 'a' : 'p');
        await run(which, { fx: { pitch: { on: false } }, keep: 'n' });
        const ref = await run('n');
        const c = [r.report.measure.pitchDeviationCents, out.report.measure.pitchDeviationCents, ref.report.measure.pitchDeviationCents];
        const tune = r.report.fx.pitch.on ? Math.round(r.report.fx.pitch.amount * 100) + ' %' : 'éteint';
        const detail = `écart moyen à la gamme ${c[0].toFixed(1)} cents avant → ${c[1].toFixed(1)} cents après (même correction sans la justesse : ${c[2].toFixed(1)} cents ; autotune ${tune}, correction moyenne ${r.report.meanCorrectionCents.toFixed(1)} cents)`;
        const offScale = r.report.fx.pitch.on && (r.report.chromatic || !!r.report.adaptedKey);
        if (offScale) { console.log(stamp(), 'NON VÉRIFIÉ', `justesse non dégradée (${label})`, '—', detail, `; la justesse a visé ${r.report.chromatic ? 'la note la plus proche, sans gamme' : 'la gamme de la voix (' + r.report.adaptedKey + ')'} : l'écart à la gamme du morceau ne la juge pas`); return false; }
        check(`justesse non dégradée (${label})`, c[1] <= Math.max(c[0], c[2]) + 2, detail);
        return true;
    };
    let judged = false;
    if (fx.pitch.on) judged = await pitchCheck('voice', a, voiceFile ? 'voix fournie' : 'voix de démonstration', !voiceFile);
    else if (m.pitchDeviationCents >= 12 && m.voicedFraction > 0.2 && !m.polyphonic)
        check('voix parlée ou rappée : justesse non appliquée', held < SUNG && a.report.meanCorrectionCents === 0 && /voix parlée ou rappée : justesse non appliquée/.test(a.report.fitNotes),
            `notes tenues ${heldPct(held)} des trames voisées (il en faut ${heldPct(SUNG)}), écart à la gamme ${m.pitchDeviationCents.toFixed(1)} cents, autotune éteint, correction moyenne ${a.report.meanCorrectionCents.toFixed(1)} cents`);
    else console.log(stamp(), 'justesse :', `rien à corriger sur cette voix (écart à la gamme ${m.pitchDeviationCents.toFixed(1)} cents, voisé ${heldPct(m.voicedFraction)})`);
    if (!voiceFile && !fx.pitch.on) check('voix chantée de démonstration : justesse appliquée', false, `autotune éteint (notes tenues ${heldPct(held)})`);
    if (voiceFile && !judged) judged = await pitchCheck('demo', null, 'voix de démonstration, chantée dans la gamme', true);
    if (!judged) check('justesse vérifiée sur au moins une voix', false, 'aucune voix où la justesse a visé la gamme du morceau');

    // 5) Le type de piste ne change pas la correction ; « Voix lissée » ne durcit rien ; les réglages à la main s'appliquent après.
    const back = await run('voice', { roleId: 'manual_back' });
    check('même correction pour un back que pour la voix principale', JSON.stringify(back.report.fx) === JSON.stringify(fx), `type rendu : ${back.report.role}`);
    const g = await run('voice', { gentle: true }), gf = g.report.fx;
    check('« Voix lissée » ne durcit rien et n\'ajoute aucune couleur', gf.comp.ratio <= fx.comp.ratio + 1e-6 && gf.leveler.maxBoostDb <= fx.leveler.maxBoostDb + 1e-6 && gf.leveler.maxCutDb <= fx.leveler.maxCutDb + 1e-6
        && gf.clean.denoiseDb <= fx.clean.denoiseDb + 1e-6 && gf.deEss.amount <= fx.deEss.amount + 1e-6 && !gf.reverb.on && !gf.delay.on && !gf.sat.on && !gf.timing.on && g.tailDb < -100,
        `compresseur ${gf.comp.ratio.toFixed(2)}:1 (sans lissage ${fx.comp.ratio.toFixed(2)}:1), niveleur +${gf.leveler.maxBoostDb} / -${gf.leveler.maxCutDb} dB, traîne ${g.tailDb.toFixed(0)} dBFS`);
    const hand = await run('voice', { fx: { reverb: { on: true, send: 0.2 }, comp: { ratio: 4 } } });
    check('réglages à la main appliqués par-dessus la correction', hand.report.fx.reverb.on && Math.abs(hand.report.fx.comp.ratio - 4) < 1e-6 && !hand.report.preset.reverb.on && hand.tailDb > -70,
        `réverb à la main : ${hand.report.fx.reverb.on ? 'oui' : 'non'} (pré-réglage : ${hand.report.preset.reverb.on ? 'oui' : 'non'}), compresseur ${hand.report.fx.comp.ratio}:1, traîne ${hand.tailDb.toFixed(0)} dBFS`);
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
