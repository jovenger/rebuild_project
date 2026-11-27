// Essai Node du rééchantillonnage (resample.js) : aller-retour 48 kHz → 44,1 kHz → 48 kHz sur des sons purs.
// Seuils : gain à ±0,05 dB et distorsion < -80 dB jusqu'à 16 kHz (le navigateur seul : -6,8 dB et -12 dB à 16 kHz).
//   node web/test/resample.mjs
import { resampleSinc } from '../resample.js';
let failed = false;
for (const [a, b] of [[48000, 44100], [44100, 48000]]) {
    for (const f of [100, 1000, 4000, 8000, 12000, 16000, 18000]) {
        const n = a * 2, x = new Float32Array(n);
        for (let i = 0; i < n; ++i) x[i] = 0.5 * Math.sin(2 * Math.PI * f * i / a);
        const t0 = performance.now();
        const y = resampleSinc(resampleSinc(x, a, b), b, a);
        const ms = performance.now() - t0;
        let xy = 0, xx = 0, yy = 0;
        for (let i = 4800; i < n - 4800; ++i) { xy += x[i] * y[i]; xx += x[i] * x[i]; yy += y[i] * y[i]; }
        const g = xy / xx, dist = 10 * Math.log10((yy - 2 * g * xy + g * g * xx) / xx + 1e-20), gdb = 20 * Math.log10(Math.abs(g));
        const ok = Math.abs(gdb) < 0.05 && dist < -80 && y.length === n;
        if (!ok) failed = true;
        console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${a} → ${b} → ${a}, ${f} Hz : gain ${gdb.toFixed(3)} dB, distorsion ${dist.toFixed(1)} dB (${ms.toFixed(0)} ms pour 2 s)`);
    }
}
console.log(failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
