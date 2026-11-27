// Essai de l'équilibre automatique (moteur WASM, dans la page) : plusieurs pistes « voix principale » enregistrées à des
// niveaux très différents doivent sortir au même niveau après mixage, qu'il y en ait 2 ou 40 ; les backs entre eux aussi ;
// une seule voix principale n'est pas touchée ; l'écart de volume d'un type (backs…) se règle et revient à l'origine ;
// l'écart voix principale / instru se règle aussi (équilibre et mixage final, borné), sans réglage c'est celui du style.
//   node web/test/balance.mjs <url>
import { createRequire } from 'node:module';
const require = createRequire(process.env.PLAYWRIGHT_DIR ? process.env.PLAYWRIGHT_DIR.replace(/\/?$/, '/') : import.meta.url);
const { chromium } = require('playwright');

const [url] = process.argv.slice(2);
if (!url) { console.error('usage : node web/test/balance.mjs <url>'); process.exit(2); }
const t0 = Date.now(), stamp = () => `[${((Date.now() - t0) / 1000).toFixed(1)} s]`;

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
let failed = false;
try {
    const page = await browser.newPage();
    page.on('pageerror', (e) => console.log(stamp(), 'PAGEERROR', e.message));
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForFunction(() => window.__studiovoix?.ready, null, { timeout: 120000 });

    // Dans la page : pistes de synthèse (voix = ton modulé à 4 Hz, 3 s chacune), niveaux connus, appel direct du moteur.
    const run = (cfg) => page.evaluate(async (cfg) => {
        const sr = 44100, st = window.__studiovoix;
        const voice = (sec, gainDb, f) => {
            const n = Math.round(sec * sr), x = new Float32Array(n), g = 0.2 * Math.pow(10, gainDb / 20);
            for (let i = 0; i < n; ++i) x[i] = g * Math.sin(2 * Math.PI * f * i / sr) * (0.55 + 0.45 * Math.sin(2 * Math.PI * 4 * i / sr));
            return x;
        };
        const total = cfg.seconds;
        const instru = new Float32Array(Math.round(total * sr));
        for (let i = 0; i < instru.length; ++i) instru[i] = 0.12 * Math.sin(2 * Math.PI * 110 * i / sr) + 0.05 * Math.sin(2 * Math.PI * 1760 * i / sr);
        const tracks = cfg.tracks.map((t, k) => { const x = voice(t.sec, t.gainDb, t.f); return { key: k + 1, left: x, right: x.slice(), startSec: t.startSec, roleId: t.roleId, volumeDb: 0 }; });
        const call = (cmd, payload) => new Promise((resolve, reject) => {
            const id = 9000000 + Math.floor(Math.random() * 1e6);
            const on = (e) => { if (e.data?.id !== id) return; st.worker.removeEventListener('message', on); e.data.ok ? resolve(e.data) : reject(new Error(e.data.error)); };
            st.worker.addEventListener('message', on);
            st.worker.postMessage({ id, cmd, ...payload });
        });
        const r = await call('balance', { instruL: instru, instruR: instru.slice(), sampleRate: sr, styleId: 'rap_conscient', tracks });
        return { report: r.report.report, items: r.report.tracks.map((it) => ({ key: it.key, role: it.role, lufs: it.lufs, gainDb: it.gainDb, autoGainDb: it.autoGainDb })) };
    }, cfg);

    // Niveau final d'une piste = niveau d'entrée connu (gainDb de synthèse) + gain rendu par le moteur.
    const spread = (xs) => Math.max(...xs) - Math.min(...xs);
    const check = (name, cond, detail) => { console.log(stamp(), cond ? 'OK   ' : 'ÉCHEC', name, '—', detail); if (!cond) failed = true; };

    // 1) 40 voix principales l'une après l'autre, de -15 à +5 dB, + 2 backs à -12 et +3 dB.
    {
        const N = 40, tracks = [];
        for (let i = 0; i < N; ++i) tracks.push({ sec: 3, startSec: 3 * i, gainDb: -15 + 20 * ((i * 7) % N) / (N - 1), f: 180 + 5 * i, roleId: 'lead' });
        tracks.push({ sec: 6, startSec: 10, gainDb: -12, f: 330, roleId: 'manual_back' }, { sec: 6, startSec: 40, gainDb: 3, f: 350, roleId: 'manual_back' });
        const r = await run({ seconds: 3 * N, tracks });
        const fin = r.items.map((it, k) => tracks[k].gainDb + it.gainDb);
        const lead = fin.slice(0, N), backs = fin.slice(N);
        const inSpread = spread(tracks.slice(0, N).map((t) => t.gainDb));
        console.log(stamp(), 'rapport :', (r.report || '').split('\n')[0]);
        check('40 voix principales au même niveau', spread(lead) < 0.5, `écart avant ${inSpread.toFixed(1)} dB → après ${spread(lead).toFixed(2)} dB`);
        check('2 backs au même niveau entre eux', spread(backs) < 0.5, `écart avant 15.0 dB → après ${spread(backs).toFixed(2)} dB`);
        const under = lead.reduce((a, b) => a + b, 0) / N - backs.reduce((a, b) => a + b, 0) / backs.length;
        check('backs sous la voix principale', under > 5 && under < 9, `${under.toFixed(1)} dB sous la voix principale (visé 7)`);
    }
    // 2) 2 voix principales en même temps (doublage) à -8 et +2 dB.
    {
        const tracks = [{ sec: 8, startSec: 0, gainDb: -8, f: 200, roleId: 'lead' }, { sec: 8, startSec: 0, gainDb: 2, f: 260, roleId: 'lead' }];
        const r = await run({ seconds: 10, tracks });
        const fin = r.items.map((it, k) => tracks[k].gainDb + it.gainDb);
        check('2 voix principales simultanées au même niveau', spread(fin) < 0.5, `écart avant 10.0 dB → après ${spread(fin).toFixed(2)} dB`);
    }
    // 3) Une seule voix principale : aucun gain de mise à niveau.
    {
        const tracks = [{ sec: 8, startSec: 0, gainDb: -6, f: 220, roleId: 'lead' }];
        const r = await run({ seconds: 10, tracks });
        check('1 seule voix principale : pas touchée', Math.abs(r.items[0].autoGainDb) < 1e-6, `gain de mise à niveau ${r.items[0].autoGainDb.toFixed(2)} dB`);
    }
    // 4) Une piste beaucoup trop faible (-30 dB) : correction limitée à +12 dB et signalée.
    {
        const tracks = [{ sec: 6, startSec: 0, gainDb: 0, f: 200, roleId: 'lead' }, { sec: 6, startSec: 6, gainDb: 0, f: 220, roleId: 'lead' }, { sec: 6, startSec: 12, gainDb: -30, f: 240, roleId: 'lead' }];
        const r = await run({ seconds: 18, tracks });
        check('piste trop loin : limitée à +12 dB et signalée', Math.abs(r.items[2].autoGainDb - 12) < 0.01 && /limitée/.test(r.report || ''), `gain ${r.items[2].autoGainDb.toFixed(1)} dB ; rapport : ${(r.report || '').split('\n')[0]}`);
    }
    // 5) Écarts de volume par type réglables depuis la page (commande setRoleOffset du moteur) : changer l'écart des
    //    backs déplace leur niveau d'autant ; le retour aux valeurs d'origine redonne l'ancien résultat.
    {
        const engine = (cmd, payload) => page.evaluate(({ cmd, payload }) => new Promise((resolve) => {
            const st = window.__studiovoix, id = 9500000 + Math.floor(Math.random() * 1e6);
            const on = (e) => { if (e.data?.id !== id) return; st.worker.removeEventListener('message', on); resolve(e.data.ok ? { ok: true, roles: e.data.roles } : { ok: false, error: e.data.error }); };
            st.worker.addEventListener('message', on);
            st.worker.postMessage({ id, cmd, ...payload });
        }), { cmd, payload });
        const place = (r, id) => r.roles.find((x) => x.id === id);
        const tracks = [{ sec: 8, startSec: 0, gainDb: 0, f: 200, roleId: 'lead' }, { sec: 8, startSec: 0, gainDb: -5, f: 330, roleId: 'manual_back' }];
        const under = async () => { const r = await run({ seconds: 10, tracks }); const fin = r.items.map((it, k) => tracks[k].gainDb + it.gainDb); return { back: fin[1] - fin[0], gains: r.items.map((it) => it.gainDb) }; };
        const origin = await engine('setRoleOffset', { reset: true });
        const ORIGIN = { double: -9, manual_back: -7, harmony: -9, adlib: -9, ambiance: -14, instrument: -4 };
        const known = origin.roles.filter((x) => x.id in ORIGIN);
        check('écarts d\'origine inchangés', origin.ok && known.length >= 4 && known.every((x) => x.placeLu === ORIGIN[x.id] && x.defaultPlaceLu === ORIGIN[x.id]),
            known.map((x) => `${x.id} ${x.placeLu}`).join(', ') + ' LU');
        const a = await under();
        const set = await engine('setRoleOffset', { roleId: 'manual_back', lu: -12 });
        check('écart des backs réglé à -12 LU', set.ok && place(set, 'manual_back').placeLu === -12 && place(set, 'manual_back').defaultPlaceLu === -7, `rendu : ${place(set, 'manual_back')?.placeLu} LU (origine ${place(set, 'manual_back')?.defaultPlaceLu})`);
        const b = await under();
        check('les backs descendent d\'autant', Math.abs((b.back - a.back) - (-5)) < 0.1, `backs / voix principale : ${a.back.toFixed(2)} dB → ${b.back.toFixed(2)} dB (déplacement ${(b.back - a.back).toFixed(2)} dB, attendu -5)`);
        const lo = await engine('setRoleOffset', { roleId: 'manual_back', lu: -40 }), hi = await engine('setRoleOffset', { roleId: 'manual_back', lu: 6 });
        check('écart borné à [-24, 0] LU', place(lo, 'manual_back').placeLu === -24 && place(hi, 'manual_back').placeLu === 0, `-40 → ${place(lo, 'manual_back').placeLu} ; +6 → ${place(hi, 'manual_back').placeLu}`);
        const lead = await engine('setRoleOffset', { roleId: 'lead', lu: -3 }), unknown = await engine('setRoleOffset', { roleId: 'nimporte', lu: -3 });
        check('voix principale et type inconnu refusés', !lead.ok && !unknown.ok, `${lead.error || 'accepté'} | ${unknown.error || 'accepté'}`);
        const back = await engine('setRoleOffset', { roleId: 'manual_back', reset: true });
        const c = await under();
        check('retour à la valeur d\'origine : ancien résultat', place(back, 'manual_back').placeLu === -7 && c.gains.every((g, k) => Math.abs(g - a.gains[k]) < 1e-4),
            `backs / voix principale ${c.back.toFixed(2)} dB (avant réglage ${a.back.toFixed(2)}) ; gains ${c.gains.map((g) => g.toFixed(3)).join(' / ')} contre ${a.gains.map((g) => g.toFixed(3)).join(' / ')}`);
        await engine('setRoleOffset', { roleId: 'ambiance', lu: -20 });
        await engine('setRoleOffset', { roleId: 'double', lu: -3 });
        const all = await engine('setRoleOffset', { reset: true });
        check('retour aux valeurs d\'origine pour tous les types', all.ok && all.roles.every((x) => x.placeLu === x.defaultPlaceLu), all.roles.map((x) => `${x.id} ${x.placeLu}`).join(', '));
    }
    // 6) Écart voix principale / instru réglé depuis la page (champ vocalOverInstruLu des commandes balance et finalMix) :
    //    absent = valeur du style ; réglé = l'écart mesuré vaut la valeur ; hors bornes = ramené à [-4, +8] LU.
    {
        const mix = (cmd, extra) => page.evaluate(async ({ cmd, extra }) => {
            const sr = 44100, st = window.__studiovoix, n = 10 * sr;
            const instru = new Float32Array(n), voice = new Float32Array(8 * sr);
            for (let i = 0; i < n; ++i) instru[i] = 0.12 * Math.sin(2 * Math.PI * 110 * i / sr) + 0.05 * Math.sin(2 * Math.PI * 1760 * i / sr);
            for (let i = 0; i < voice.length; ++i) voice[i] = 0.2 * Math.sin(2 * Math.PI * 220 * i / sr) * (0.55 + 0.45 * Math.sin(2 * Math.PI * 4 * i / sr));
            const id = 9700000 + Math.floor(Math.random() * 1e6);
            const r = await new Promise((resolve, reject) => {
                const on = (e) => { if (e.data?.id !== id) return; st.worker.removeEventListener('message', on); e.data.ok ? resolve(e.data) : reject(new Error(e.data.error)); };
                st.worker.addEventListener('message', on);
                st.worker.postMessage({ id, cmd, instruL: instru, instruR: instru.slice(), sampleRate: sr, styleId: 'rap_conscient', targetId: 'spotify', duckingDb: 0,
                    tracks: [{ key: 1, left: voice, right: voice.slice(), startSec: 0, roleId: 'lead', volumeDb: 0 }], ...extra });
            });
            const rep = r.report;
            return { gain: rep.vocalGainDb, gap: rep.leadLufs + rep.vocalGainDb - rep.instruLufs, over: rep.vocalOverInstruLu, style: rep.styleVocalOverInstruLu, set: rep.vocalOverInstruSet };
        }, { cmd, extra });
        const styleLu = await page.evaluate(() => window.__studiovoix.styles.flatMap((g) => g.styles).find((s) => s.id === 'rap_conscient').vocalOverInstruLu);
        const a = await mix('balance', {});
        check('voix / instru sans réglage : valeur du style', !a.set && a.over === styleLu && a.style === styleLu && Math.abs(a.gap - styleLu) < 0.1, `visé ${a.over} LU (style ${styleLu}), écart mesuré ${a.gap.toFixed(2)} LU`);
        const b = await mix('balance', { vocalOverInstruLu: 5 });
        check('voix / instru réglé à +5 LU : l\'écart mesuré vaut +5 LU', b.set && b.over === 5 && Math.abs(b.gap - 5) < 0.1 && Math.abs((b.gain - a.gain) - (5 - styleLu)) < 0.1, `écart mesuré ${a.gap.toFixed(2)} → ${b.gap.toFixed(2)} LU, gain voix ${a.gain.toFixed(2)} → ${b.gain.toFixed(2)} dB`);
        const hi = await mix('balance', { vocalOverInstruLu: 20 }), lo = await mix('balance', { vocalOverInstruLu: -30 }), none = await mix('balance', { vocalOverInstruLu: -99 });
        check('voix / instru borné à [-4, +8] LU ; -99 = valeur du style', hi.over === 8 && lo.over === -4 && !none.set && none.over === styleLu && Math.abs(none.gain - a.gain) < 1e-6, `+20 → ${hi.over} ; -30 → ${lo.over} ; -99 → ${none.over} (style)`);
        const f0 = await mix('finalMix', {}), f5 = await mix('finalMix', { vocalOverInstruLu: 5 });
        check('« Mixer la chanson » : même réglage (sans = style, +5 LU = +5 LU)', !f0.set && f0.over === styleLu && f5.set && f5.over === 5 && Math.abs(f5.gap - 5) < 0.1 && Math.abs((f5.gain - f0.gain) - (5 - styleLu)) < 0.1,
            `sans réglage : écart ${f0.gap.toFixed(2)} LU ; réglé : ${f5.gap.toFixed(2)} LU (gain voix ${f0.gain.toFixed(2)} → ${f5.gain.toFixed(2)} dB)`);
    }
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
