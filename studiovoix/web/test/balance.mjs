// Essai de l'équilibre automatique (moteur WASM, dans la page) : plusieurs pistes « voix principale » enregistrées à des
// niveaux très différents doivent sortir au même niveau après mixage, qu'il y en ait 2 ou 40 ; les backs entre eux aussi ;
// une seule voix principale n'est pas touchée.
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
} catch (err) {
    console.log(stamp(), 'ÉCHEC :', err.message);
    failed = true;
} finally {
    await browser.close();
}
console.log(stamp(), failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
