// Prototype « dans la chaîne du produit » des post-traitements de la famille A : même boucle par morceaux que
// separateVocals (copie figée de isolate.js : MdxStft, mdxGrid), avec en plus, par morceau, le calcul d'un ou plusieurs
// « signaux à soustraire » (spectre de la chanson S et sortie du modèle V sous la main) et UNE transformée retour de
// plus par signal. La voix rendue est inchangée (vérifié contre separateVocals par check_post.mjs).
//   instru = chanson − signal à soustraire   (ligne de base : signal à soustraire = compensate × voix)
import { MDX, MdxStft, mdxGrid } from '../frozen/isolate.js';

// Règles : (S, V, out, cfg) → out = spectre à soustraire de la chanson, au format [4, F, T] (G ré, G im, D ré, D im).
// V est déjà multiplié par « compensate ».
export const RULES = {
    // ligne de base refaite dans le domaine des transformées (contrôle : doit égaler compensate × voix)
    base(S, V, out) { out.set(V); },
    // borne : |instru| ≤ |chanson| à chaque point temps-fréquence et par canal (retire le bruit que le modèle ajoute
    // là où la chanson est vide) ; N = S − V ; g = min(1, |S| / |N|) ; à soustraire = S − g·N.
    borne(S, V, out, cfg) {
        const F = cfg.dimF, T = cfg.dimT, FT = F * T;
        for (let ch = 0; ch < 2; ++ch) {
            const re = 2 * ch * FT, im = re + FT;
            for (let f = 0; f < F; ++f) {
                const keep = f < 3;   // les 3 premières bandes sont à zéro à l'entrée du modèle : comme la ligne de base
                for (let t = 0, i = f * T; t < T; ++t, ++i) {
                    const sr = S[re + i], si = S[im + i], vr = V[re + i], vi = V[im + i];
                    if (keep) { out[re + i] = vr; out[im + i] = vi; continue; }
                    const nr = sr - vr, ni = si - vi, s2 = sr * sr + si * si, n2 = nr * nr + ni * ni;
                    const g = n2 > s2 ? Math.sqrt(s2 / n2) : 1;
                    out[re + i] = sr - g * nr; out[im + i] = si - g * ni;
                }
            }
        }
    },
};

// Seuil dans les aigus : au-dessus de f0, la voix estimée n'est soustraite que si elle pèse assez devant la chanson
// (rapport des modules lissés 3 × 3 en temps et en fréquence : 0 sous a, 1 au-dessus de b). Puis, si `borne`, la règle
// « borne ». Tampons gardés d'un morceau à l'autre.
let magS = null, magV = null;
function seuil(S, V, out, cfg, f0Hz, a, b, borne) {
    const F = cfg.dimF, T = cfg.dimT, FT = F * T, f0 = Math.max(3, Math.round(f0Hz * cfg.nFft / cfg.sampleRate));
    if (!magS || magS.length !== FT) { magS = new Float32Array(FT); magV = new Float32Array(FT); }
    for (let ch = 0; ch < 2; ++ch) {
        const re = 2 * ch * FT, im = re + FT;
        for (let i = (f0 - 1) * T; i < FT; ++i) { magS[i] = Math.hypot(S[re + i], S[im + i]); magV[i] = Math.hypot(V[re + i], V[im + i]); }
        for (let f = 0; f < F; ++f) {
            const fa = Math.max(f0 - 1, f - 1), fb = Math.min(F - 1, f + 1);
            for (let t = 0, i = f * T; t < T; ++t, ++i) {
                const sr = S[re + i], si = S[im + i];
                let vr = V[re + i], vi = V[im + i];
                if (f < 3) { out[re + i] = vr; out[im + i] = vi; continue; }
                if (f >= f0) {
                    const ta = Math.max(0, t - 1), tb = Math.min(T - 1, t + 1);
                    let ms = 0, mv = 0;
                    for (let ff = fa; ff <= fb; ++ff) for (let tt = ta; tt <= tb; ++tt) { ms += magS[ff * T + tt]; mv += magV[ff * T + tt]; }
                    const r = mv / (ms + 1e-12), g = r <= a ? 0 : r >= b ? 1 : (r - a) / (b - a);
                    vr *= g; vi *= g;
                }
                let nr = sr - vr, ni = si - vi;
                if (borne) { const s2 = sr * sr + si * si, n2 = nr * nr + ni * ni; if (n2 > s2) { const k = Math.sqrt(s2 / n2); nr *= k; ni *= k; } }
                out[re + i] = sr - nr; out[im + i] = si - ni;
            }
        }
    }
}
// Borne par bande : sur le morceau, la voix estimée ne peut pas avoir plus d'énergie que beta × la chanson dans une
// bande de fréquence (ligne entière du spectre, par canal) ; sinon la ligne est baissée. Un gain par ligne = un filtre
// fixe sur le morceau : pas de problème de cohérence, applicable à la sortie brute du modèle, sans transformée en plus.
// Vise le bruit que le modèle ajoute dans les bandes où la chanson est vide (source coupée à 16 kHz, par exemple).
function borneBande(S, V, out, cfg, beta) {
    const F = cfg.dimF, T = cfg.dimT, FT = F * T;
    for (let ch = 0; ch < 2; ++ch) {
        const re = 2 * ch * FT, im = re + FT;
        for (let f = 0; f < F; ++f) {
            let es = 0, ev = 0;
            for (let t = 0, i = f * T; t < T; ++t, ++i) { es += S[re + i] * S[re + i] + S[im + i] * S[im + i]; ev += V[re + i] * V[re + i] + V[im + i] * V[im + i]; }
            const g = f < 3 || ev <= beta * es ? 1 : Math.sqrt(beta * es / ev);
            for (let t = 0, i = f * T; t < T; ++t, ++i) { out[re + i] = g * V[re + i]; out[im + i] = g * V[im + i]; }
        }
    }
}
RULES.borne_bande = (S, V, out, cfg) => borneBande(S, V, out, cfg, 2);
RULES.borne_bande1 = (S, V, out, cfg) => borneBande(S, V, out, cfg, 1);
RULES.seuil6k = (S, V, out, cfg) => seuil(S, V, out, cfg, 6000, 0.2, 0.5, false);
RULES.seuil6k_borne = (S, V, out, cfg) => seuil(S, V, out, cfg, 6000, 0.2, 0.5, true);

/** Comme separateVocals (un seul appel, sans tranches), plus les signaux à soustraire demandés.
 *  Rend { left, right (voix, avant compensate), subs: { nom: { left, right } }, profile }. */
export async function separateWithSubs(left, right, runModel, cfg = MDX, opts = {}, rules = ['borne']) {
    const stft = new MdxStft(cfg), n = left.length, comp = opts.compensate ?? cfg.compensate;
    const { trim, chunk, len, step, total } = mdxGrid(n, cfg, opts.overlap);
    const prof = { chunks: 0, skipped: 0, stftMs: 0, modelMs: 0, istftMs: 0, postMs: 0, incNum: [0, 0, 0], incDen: [0, 0, 0] };
    let peak = 0;
    for (let i = 0; i < n; ++i) peak = Math.max(peak, Math.abs(left[i]), Math.abs(right[i]));
    if (peak < 1e-6) throw new Error('signal muet');
    const ml = new Float32Array(len), mr = new Float32Array(len);
    for (let i = 0; i < n; ++i) { ml[trim + i] = left[i] / peak; mr[trim + i] = right[i] / peak; }
    const skipRms = Number.isFinite(opts.skipBelowDb) ? Math.pow(10, opts.skipBelowDb / 20) : -1;
    const acc = () => ({ l: new Float64Array(len), r: new Float64Array(len) });
    const res = acc(), subs = Object.fromEntries(rules.map((k) => [k, acc()])), div = new Float64Array(len);
    const spec = new Float32Array(4 * cfg.dimF * cfg.dimT), vc = new Float32Array(spec.length), sub = new Float32Array(spec.length), vcons = new Float32Array(spec.length);
    const cl = new Float32Array(chunk), cr = new Float32Array(chunk), ol = new Float32Array(chunk), or = new Float32Array(chunk);
    for (let k = 0; k < total; ++k) {
        const start = k * step, end = Math.min(start + chunk, len), actual = end - start;
        cl.fill(0); cr.fill(0); cl.set(ml.subarray(start, end)); cr.set(mr.subarray(start, end));
        let e = 0;
        if (skipRms > 0) { for (let i = 0; i < actual; ++i) e += cl[i] * cl[i] + cr[i] * cr[i]; e = Math.sqrt(e / Math.max(1, 2 * actual)); }
        const skipped = skipRms > 0 && e < skipRms;
        const w = new Float64Array(actual);
        for (let i = 0; i < actual; ++i) { w[i] = actual > 1 ? 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (actual - 1)) : 1; div[start + i] += w[i]; }
        if (skipped) { ++prof.skipped; continue; }
        const t0 = performance.now();
        stft.forward(cl, cr, spec);
        const t1 = performance.now();
        const voc = await runModel(spec);
        const t2 = performance.now();
        stft.inverse(voc, ol, or);
        const t3 = performance.now();
        for (let i = 0; i < actual; ++i) { res.l[start + i] += ol[i] * w[i]; res.r[start + i] += or[i] * w[i]; }
        prof.stftMs += t1 - t0; prof.modelMs += t2 - t1; prof.istftMs += t3 - t2; ++prof.chunks;
        const t4 = performance.now();
        if (opts.consistent) {
            // Spectre « cohérent » de la voix : transformée aller de la voix revenue dans le temps (la sortie brute du
            // modèle n'est pas la transformée d'un signal : la transformée retour en jette une partie). Coût : + 1 aller.
            stft.forward(ol, or, vcons);
            const F = cfg.dimF, T = cfg.dimT, FT = F * T, edges = [0, Math.round(6000 * cfg.nFft / cfg.sampleRate), Math.round(12000 * cfg.nFft / cfg.sampleRate), F];
            for (let b = 0; b < 3; ++b) for (let c4 = 0; c4 < 4; ++c4) for (let i = c4 * FT + Math.max(3, edges[b]) * T, e2 = c4 * FT + edges[b + 1] * T; i < e2; ++i) {
                const d = voc[i] - vcons[i]; prof.incNum[b] += d * d; prof.incDen[b] += voc[i] * voc[i];
            }
            for (let i = 0; i < vc.length; ++i) vc[i] = vcons[i] * comp;
        } else for (let i = 0; i < vc.length; ++i) vc[i] = voc[i] * comp;
        for (const name of rules) {
            RULES[name](spec, vc, sub, cfg);
            stft.inverse(sub, ol, or);
            const a = subs[name];
            for (let i = 0; i < actual; ++i) { a.l[start + i] += ol[i] * w[i]; a.r[start + i] += or[i] * w[i]; }
        }
        prof.postMs += performance.now() - t4;
    }
    const fin = (a) => {
        const L = new Float32Array(n), R = new Float32Array(n);
        for (let i = 0; i < n; ++i) { const d = div[trim + i], g = d > 1e-9 ? peak / d : 0; L[i] = a.l[trim + i] * g; R[i] = a.r[trim + i] * g; }
        return { left: L, right: R };
    };
    const v = fin(res);
    return { left: v.left, right: v.right, subs: Object.fromEntries(rules.map((k) => [k, fin(subs[k])])), profile: prof };
}
