// Essai Node de la porte dans le temps de l'instru séparée (instru.js) : instru = chanson − g × voix estimée.
// Contrôlé : original exact là où la voix estimée est nulle ou 40 dB sous la chanson, chanson − voix exacte là où elle
// est au niveau de la chanson, pas de saut du gain, tenue de ± 100 ms, sons vides / courts / de longueurs différentes,
// et accord avec la règle de référence réécrite ici sans astuce (run_bench.py, tgate(-30)).
//   node web/test/gate.mjs
import { instruGate, gatedInstru, GATE_DEFAULTS } from '../instru.js';

let failed = false;
const check = (ok, text) => { if (!ok) failed = true; console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${text}`); };
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const noise = (n, amp, rand) => { const x = new Float32Array(n); for (let i = 0; i < n; ++i) x[i] = amp * (2 * rand() - 1); return x; };
const maxDiff = (a, b, from = 0, to = a.length) => { let m = 0; for (let i = from; i < to; ++i) m = Math.max(m, Math.abs(a[i] - b[i])); return m; };
const minus = (s, v) => s.map((x, i) => x - (i < v.length ? v[i] : 0));   // chanson − voix, comme la page avant la porte

// Règle de référence, écrite simplement (traduction de tgate(-30) de run_bench.py) : gain par échantillon et instru.
function reference(sL, sR, vL, vR, sr, thr = -30) {
    const n = sL.length, FR = Math.floor(0.05 * sr), k = Math.floor(n / FR);
    const g = [];
    for (let j = 0; j < k; ++j) {
        let ev = 0, es = 0;
        for (let i = j * FR; i < (j + 1) * FR; ++i) { ev += vL[i] ** 2 + vR[i] ** 2; es += sL[i] ** 2 + sR[i] ** 2; }
        const r = 10 * Math.log10(Math.max(ev / Math.max(es, 1e-12), 1e-30));
        g.push(Math.min(1, Math.max(0, (r - thr) / 6)));
    }
    const held = g.map((_, j) => { let s = 0; for (let d = -2; d <= 2; ++d) s += g[j + d] ?? 0; return Math.min(1, s); });
    const gain = new Float64Array(n), left = new Float64Array(n), right = new Float64Array(n);
    for (let i = 0; i < n; ++i) {
        const p = i / FR - 0.5;                       // position en trames, par rapport au centre de la trame 0
        if (p <= 0) gain[i] = held[0];
        else if (p >= k - 1) gain[i] = held[k - 1];
        else { const j = Math.floor(p); gain[i] = held[j] + (held[j + 1] - held[j]) * (p - j); }
        left[i] = sL[i] - gain[i] * vL[i]; right[i] = sR[i] - gain[i] * vR[i];
    }
    return { gain, left, right };
}

for (const sr of [44100, 48000]) {
    const fr = Math.floor(0.05 * sr), rand = rng(sr);
    const head = `${sr} Hz :`;

    // 1) Voix estimée nulle, puis 40 dB sous la chanson, pendant 0,5 s entre deux passages chantés (zones non alignées
    //    sur les trames) : l'instru est la chanson, écart exactement 0, à 175 ms des bords (tenue + trame + demi-trame).
    {
        const n = Math.round(3.3 * sr), sL = noise(n, 0.3, rand), sR = noise(n, 0.3, rand), vL = noise(n, 0.3, rand), vR = noise(n, 0.3, rand);
        const zones = [[Math.round(0.613 * sr), 0, 'nulle'], [Math.round(1.777 * sr), 0.01, '40 dB sous la chanson']];
        for (const [a, k] of zones) for (let i = a; i < a + Math.round(0.5 * sr); ++i) { vL[i] *= k; vR[i] *= k; }
        const out = gatedInstru(sL, sR, vL, vR, sr), margin = Math.ceil(3.5 * fr);
        for (const [a, , name] of zones) {
            const from = a + margin, to = a + Math.round(0.5 * sr) - margin;
            const d = Math.max(maxDiff(out.left, sL, from, to), maxDiff(out.right, sR, from, to));
            check(d === 0 && to - from >= 0.14 * sr, `${head} voix estimée ${name} pendant 0,5 s → instru = chanson sur ${((to - from) / sr * 1000).toFixed(0)} ms au cœur du passage (écart ${d})`);
        }
        // Chanson entière sans voix (40 dB dessous partout, puis voix nulle) : la chanson ressort telle quelle, en entier.
        const quiet = gatedInstru(sL, sR, sL.map((x) => 0.01 * x), sR.map((x) => -0.01 * x), sr);
        const zero = gatedInstru(sL, sR, new Float32Array(n), new Float32Array(n), sr);
        const dq = Math.max(maxDiff(quiet.left, sL), maxDiff(quiet.right, sR)), dz = Math.max(maxDiff(zero.left, sL), maxDiff(zero.right, sR));
        check(dq === 0 && quiet.closed === 1 && quiet.open === 0, `${head} voix estimée 40 dB sous la chanson partout → instru = chanson partout (écart ${dq}, porte fermée ${(100 * quiet.closed).toFixed(0)} %)`);
        check(dz === 0 && zero.closed === 1, `${head} voix estimée nulle partout → instru = chanson partout (écart ${dz})`);
    }

    // 2) Voix estimée au niveau de la chanson : instru = chanson − voix, exactement (le calcul d'avant la porte).
    {
        const n = Math.round(2.03 * sr), sL = noise(n, 0.3, rand), sR = noise(n, 0.3, rand), vL = noise(n, 0.3, rand), vR = noise(n, 0.3, rand);
        const out = gatedInstru(sL, sR, vL, vR, sr), d = Math.max(maxDiff(out.left, minus(sL, vL)), maxDiff(out.right, minus(sR, vR)));
        check(d === 0 && out.open === 1 && out.closed === 0, `${head} voix estimée au niveau de la chanson → instru = chanson − voix exactement (écart ${d}, porte ouverte ${(100 * out.open).toFixed(0)} %)`);
        // Juste au-dessus de la pente (−23 dB) : encore chanson − voix ; juste sous le seuil (−31 dB) : chanson.
        const at = (db, opts) => { const k = 10 ** (db / 20); return instruGate(sL, sR, sL.map((x) => k * x), sR.map((x) => k * x), sr, opts); };
        const hi = at(-23), lo = at(-31), mid = at(-27), mid1 = at(-27, { holdFrames: 1 });
        check(hi.open === 1 && lo.closed === 1, `${head} voix à −23 dB (au-dessus de la pente) : ouverte ${(100 * hi.open).toFixed(0)} % ; à −31 dB (sous le seuil) : fermée ${(100 * lo.closed).toFixed(0)} %`);
        check(mid1.between === 1 && mid1.gain.every((x) => Math.abs(x - 0.5) < 1e-4) && mid.open === 1,
            `${head} voix à −27 dB (milieu de la pente) : gain ${mid1.gain[fr * 20].toFixed(3)} sans tenue, ${mid.gain[fr * 20].toFixed(3)} avec la tenue de 5 trames`);
    }

    // 3) Transition : pas de saut. Le gain bouge d'au plus 1/trame par échantillon (à l'arrondi 32 bits près).
    // 4) Tenue : une trame active isolée garde ouvertes ses voisines à ± 100 ms.
    {
        const frames = 40, j0 = 17, n = frames * fr + 311, sL = noise(n, 0.3, rand), sR = noise(n, 0.3, rand), vL = new Float32Array(n), vR = new Float32Array(n);
        for (let i = j0 * fr; i < (j0 + 1) * fr; ++i) { vL[i] = 0.3 * (2 * rand() - 1); vR[i] = 0.3 * (2 * rand() - 1); }
        const { gain, closed, open, between } = instruGate(sL, sR, vL, vR, sr), out = gatedInstru(sL, sR, vL, vR, sr);
        let step = 0; for (let i = 1; i < n; ++i) step = Math.max(step, Math.abs(gain[i] - gain[i - 1]));
        check(step <= 1 / fr + 2e-7 && step > 0.9 / fr, `${head} transition sans saut : pas le plus grand ${step.toExponential(3)} par échantillon (limite 1/${fr} = ${(1 / fr).toExponential(3)})`);
        const c = (j) => (j + 0.5) * fr;              // centre de la trame j
        let allOpen = true, allClosed = true, ramps = true;
        for (let i = Math.ceil(c(j0 - 2)); i <= Math.floor(c(j0 + 2)); ++i) if (gain[i] !== 1) allOpen = false;
        for (let i = 0; i < n; ++i) if ((i <= c(j0 - 3) || i >= c(j0 + 3)) && gain[i] !== 0) allClosed = false;
        for (let i = Math.floor(c(j0 - 3)) + 1; i < Math.ceil(c(j0 - 2)); ++i) if (!(gain[i] > 0 && gain[i] < 1 && gain[i] > gain[i - 1])) ramps = false;
        for (let i = Math.floor(c(j0 + 2)) + 1; i < Math.ceil(c(j0 + 3)); ++i) if (!(gain[i] > 0 && gain[i] < 1 && gain[i] < gain[i - 1])) ramps = false;
        const openMs = (Math.floor(c(j0 + 2)) - Math.ceil(c(j0 - 2)) + 1) / sr * 1000;
        check(allOpen && allClosed && ramps, `${head} tenue : une trame active isolée ouvre la porte ${openMs.toFixed(0)} ms (± 100 ms autour de son centre), fondus de 50 ms, fermée ailleurs`);
        const dIn = Math.max(maxDiff(out.left, minus(sL, vL), j0 * fr, (j0 + 1) * fr), maxDiff(out.right, minus(sR, vR), j0 * fr, (j0 + 1) * fr));
        const dAll = Math.max(maxDiff(out.left, sL.map((x, i) => x - gain[i] * vL[i])), maxDiff(out.right, sR.map((x, i) => x - gain[i] * vR[i])));
        check(dIn === 0 && dAll === 0 && out.closed === closed && out.open === open && Math.abs(closed + open + between - 1) < 1e-12,
            `${head} dans la trame active l'instru est chanson − voix exactement ; gatedInstru = chanson − gain × voix (écart ${dAll}) ; bilan fermée ${(100 * closed).toFixed(1)} % / ouverte ${(100 * open).toFixed(1)} % / entre les deux ${(100 * between).toFixed(1)} %`);
    }

    // 5) Cas limites : pas d'erreur, sortie à la longueur de la chanson.
    {
        const cases = [];
        const run = (name, sL, sR, vL, vR, want) => {
            try {
                const g = instruGate(sL, sR, vL, vR, sr), o = gatedInstru(sL, sR, vL, vR, sr);
                const okLen = g.gain.length === sL.length && o.left.length === sL.length && o.right.length === sL.length;
                const finite = o.left.every(Number.isFinite) && o.right.every(Number.isFinite) && g.gain.every((x) => x >= 0 && x <= 1);
                cases.push(`${name} ${okLen && finite && want(o, g) ? 'oui' : 'NON'}`);
                return okLen && finite && want(o, g);
            } catch (err) { cases.push(`${name} ERREUR ${err.message}`); return false; }
        };
        const e = new Float32Array(0), short = Math.floor(fr / 3), n = 7 * fr + 5;
        const sL = noise(n, 0.3, rand), sR = noise(n, 0.3, rand), vL = noise(n + 999, 0.3, rand), vR = noise(n + 999, 0.3, rand);
        let ok = run('vide', e, e, e, e, (o, g) => o.closed === 0 && o.open === 0 && g.frames === 0);
        ok = run('chanson vide, voix non vide', e, e, vL, vR, () => true) && ok;
        ok = run('plus court qu\'une trame, voix au niveau', sL.subarray(0, short), sR.subarray(0, short), vL.subarray(0, short), vR.subarray(0, short),
            (o) => o.open === 1 && maxDiff(o.left, minus(sL.subarray(0, short), vL)) === 0) && ok;
        ok = run('plus court qu\'une trame, voix nulle', sL.subarray(0, short), sR.subarray(0, short), new Float32Array(short), new Float32Array(short),
            (o) => o.closed === 1 && maxDiff(o.left, sL) === 0) && ok;
        ok = run('un seul échantillon', sL.subarray(0, 1), sR.subarray(0, 1), vL.subarray(0, 1), vR.subarray(0, 1), () => true) && ok;
        ok = run('voix plus longue', sL, sR, vL, vR, (o) => o.open === 1 && maxDiff(o.left, minus(sL, vL)) === 0 && maxDiff(o.right, minus(sR, vR)) === 0) && ok;
        // voix plus courte : la suite compte pour du silence → porte fermée à la fin, chanson intacte
        const cut = 3 * fr;
        ok = run('voix plus courte', sL, sR, vL.subarray(0, cut), vR.subarray(0, cut),
            (o) => maxDiff(o.left, minus(sL, vL), 0, cut) === 0 && maxDiff(o.left, sL, Math.ceil(6.5 * fr), n) === 0 && maxDiff(o.right, sR, Math.ceil(6.5 * fr), n) === 0) && ok;
        ok = run('voix vide', sL, sR, e, e, (o) => o.closed === 1 && maxDiff(o.left, sL) === 0) && ok;
        ok = run('chanson muette, voix muette', new Float32Array(n), new Float32Array(n), new Float32Array(n), new Float32Array(n), (o) => o.closed === 1) && ok;
        check(ok, `${head} cas limites sans erreur, sortie à la longueur de la chanson : ${cases.join(' ; ')}`);
        // NaN dans la voix estimée (panne du modèle) : la porte reste ouverte autour, la panne n'est pas masquée.
        const vn = new Float32Array(n); vn[3 * fr + 7] = NaN;
        const gn = instruGate(sL, sR, vn, new Float32Array(n), sr), on = gatedInstru(sL, sR, vn, new Float32Array(n), sr);
        check(gn.gain[3 * fr + 7] === 1 && gn.gain[0] === 0 && Number.isNaN(on.left[3 * fr + 7]) && on.left[0] === sL[0] && on.right[3 * fr + 7] === sR[3 * fr + 7],
            `${head} NaN dans la voix estimée : porte ouverte à cet endroit (gain ${gn.gain[3 * fr + 7]}), le NaN reste visible dans l'instru, le reste est intact`);
        let threw = 0;
        for (const bad of [() => instruGate(sL, sR, vL, vR, 0), () => instruGate(sL, sR, vL, vR, NaN), () => gatedInstru(sL, sR.subarray(1), vL, vR, sr), () => gatedInstru(sL, sR, vL, vR, sr, { frameSec: 0 })])
            try { bad(); } catch { ++threw; }
        check(threw === 4, `${head} entrées invalides (fréquence nulle ou NaN, canaux de longueurs différentes, trame nulle) : ${threw}/4 refusées avec un message`);
    }

    // 6) Accord avec la règle de référence sur un son aléatoire : niveaux de voix de « rien » à « au niveau », par
    //    passages de longueurs quelconques, canaux différents, longueur non multiple de la trame.
    {
        const n = Math.round(12.345 * sr), sL = noise(n, 0.4, rand), sR = noise(n, 0.25, rand), vL = noise(n, 0.4, rand), vR = noise(n, 0.25, rand);
        for (let a = 0; a < n;) {
            const len = Math.round((0.02 + 0.6 * rand()) * sr), u = rand();
            const k = u < 0.2 ? 0 : 10 ** ((-50 + 55 * rand()) / 20);       // 1 passage sur 5 sans voix, sinon −50 à +5 dB
            const ks = rand() < 0.1 ? 0 : 1;                                 // parfois la chanson elle-même est muette
            for (let i = a; i < Math.min(n, a + len); ++i) { vL[i] *= k; vR[i] *= k; sL[i] *= ks; sR[i] *= ks; }
            a += len;
        }
        const ref = reference(sL, sR, vL, vR, sr), g = instruGate(sL, sR, vL, vR, sr), out = gatedInstru(sL, sR, vL, vR, sr);
        const dg = maxDiff(g.gain, ref.gain), di = Math.max(maxDiff(out.left, ref.left), maxDiff(out.right, ref.right));
        let step = 0; for (let i = 1; i < n; ++i) step = Math.max(step, Math.abs(g.gain[i] - g.gain[i - 1]));
        check(step <= 1 / fr + 2e-7, `${head} son aléatoire, transitions sans saut : pas le plus grand ${step.toExponential(3)} par échantillon (limite ${(1 / fr).toExponential(3)})`);
        check(dg < 1e-6 && di < 1e-6 && g.closed > 0.05 && g.open > 0.05 && g.between > 0.05 && g.frame === fr,
            `${head} même résultat que la règle de référence sur ${(n / sr).toFixed(1)} s de son aléatoire : écart du gain ${dg.toExponential(1)}, de l'instru ${di.toExponential(1)} (limite 1e-6) ; fermée ${(100 * g.closed).toFixed(0)} % / ouverte ${(100 * g.open).toFixed(0)} % / entre les deux ${(100 * g.between).toFixed(0)} %`);
    }
}

// Réglages par défaut = règle décidée ; coût mesuré sur 4 min de stéréo à 48 kHz.
check(GATE_DEFAULTS.thresholdDb === -30 && GATE_DEFAULTS.slopeDb === 6 && GATE_DEFAULTS.frameSec === 0.05 && GATE_DEFAULTS.holdFrames === 5,
    `réglages par défaut : seuil ${GATE_DEFAULTS.thresholdDb} dB, pente ${GATE_DEFAULTS.slopeDb} dB, trames de ${GATE_DEFAULTS.frameSec * 1000} ms, tenue de ${GATE_DEFAULTS.holdFrames} trames`);
{
    const sr = 48000, n = 240 * sr, rand = rng(7), sL = noise(n, 0.3, rand), sR = noise(n, 0.3, rand), vL = sL.map((x, i) => (Math.floor(i / sr) % 3 ? 0.5 : 0.001) * x), vR = vL.slice();
    const t0 = performance.now(), out = gatedInstru(sL, sR, vL, vR, sr), ms = performance.now() - t0;
    check(out.left.length === n && ms < 5000, `4 min de stéréo à 48 kHz : porte calculée et appliquée en ${ms.toFixed(0)} ms (fermée ${(100 * out.closed).toFixed(0)} %)`);
}
console.log(failed ? 'ÉCHEC' : 'OK');
process.exit(failed ? 1 : 0);
