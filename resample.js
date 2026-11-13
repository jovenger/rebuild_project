// StudioVoix Web : rééchantillonnage de qualité (sinc fenêtré, polyphase).
// Pourquoi : le navigateur (OfflineAudioContext + AudioBufferSourceNode) interpole linéairement quand la fréquence du
// son n'est pas celle du contexte. Mesuré sur 48 kHz → 44,1 kHz → 48 kHz : -1,7 dB et 8 % de distorsion à 8 kHz,
// -6,8 dB et 24 % à 16 kHz — des aigus étouffés qui « crépitent ». Or les modèles de séparation travaillent à 44,1 kHz
// et la plupart des téléphones et des PC sont à 48 kHz : tout « Séparer » et toute isolation de prise y passaient.
// Ici : filtre sinc à fenêtre de Kaiser (≈ -90 dB), 32 passages par zéro de chaque côté, une table par phase.
// Module ES pur : utilisé par la page et par les essais Node.

const gcd = (a, b) => { while (b) { [a, b] = [b, a % b]; } return a; };
function bessel0(x) { let s = 1, t = 1; for (let k = 1; k < 40; ++k) { t *= (x / (2 * k)) * (x / (2 * k)); s += t; if (t < 1e-12 * s) break; } return s; }

const plans = new Map();
/** Plan de conversion fromSr → toSr (table des filtres par phase), gardé d'un appel à l'autre. */
export function resamplePlan(fromSr, toSr, half = 32) {
    const key = `${fromSr}>${toSr}>${half}`;
    if (plans.has(key)) return plans.get(key);
    if (!(fromSr > 0 && toSr > 0)) throw new Error(`fréquences invalides : ${fromSr} → ${toSr}`);
    const g = gcd(Math.round(fromSr), Math.round(toSr)), L = Math.round(toSr) / g, M = Math.round(fromSr) / g;
    const scale = Math.min(1, toSr / fromSr);            // en descente, le filtre coupe plus bas et s'allonge
    const fc = 0.5 * scale * 0.94;                        // coupure (cycles par échantillon d'entrée) : ~20,7 kHz pour 44,1 ↔ 48
    const H = Math.ceil(half / scale);                    // demi-longueur en échantillons d'entrée
    const taps = 2 * H, beta = 8.6, i0b = bessel0(beta);
    if (L > 4096) throw new Error(`rapport de fréquences trop irrégulier (${fromSr} → ${toSr})`);
    const table = new Float32Array(L * taps);
    for (let p = 0; p < L; ++p) {
        const frac = p / L;                               // position entre deux échantillons d'entrée
        let sum = 0;
        for (let j = 0; j < taps; ++j) {
            const d = frac - (j - H + 1);                 // distance (en échantillons d'entrée) à l'échantillon j
            const u = d / H;
            const w = Math.abs(u) < 1 ? bessel0(beta * Math.sqrt(1 - u * u)) / i0b : 0;
            const a = 2 * Math.PI * fc * d;
            const h = (Math.abs(a) < 1e-9 ? 1 : Math.sin(a) / a) * 2 * fc * w;
            table[p * taps + j] = h; sum += h;
        }
        for (let j = 0; j < taps; ++j) table[p * taps + j] /= sum;   // gain exact en continu, phase par phase
    }
    const plan = { fromSr, toSr, L, M, H, taps, table };
    plans.set(key, plan);
    return plan;
}

/** Longueur de sortie pour n échantillons d'entrée. */
export const resampledLength = (n, fromSr, toSr) => Math.max(1, Math.round(n * toSr / fromSr));

/** Calcule out[n0..n1) (indices de sortie) à partir de x, avec le plan donné. */
export function resampleRange(plan, x, out, n0, n1) {
    const { L, M, H, taps, table } = plan, N = x.length;
    for (let n = n0; n < n1; ++n) {
        const pos = n * M, c = Math.floor(pos / L), p = pos - c * L, base = p * taps, first = c - H + 1;
        let acc = 0;
        const j0 = first < 0 ? -first : 0, j1 = first + taps > N ? N - first : taps;
        for (let j = j0; j < j1; ++j) acc += x[first + j] * table[base + j];
        out[n] = acc;
    }
}

/** Rééchantillonne d'un coup (Float32Array → Float32Array). */
export function resampleSinc(x, fromSr, toSr) {
    if (fromSr === toSr) return x.slice();
    const plan = resamplePlan(fromSr, toSr), out = new Float32Array(resampledLength(x.length, fromSr, toSr));
    resampleRange(plan, x, out, 0, out.length);
    return out;
}

/** Comme resampleSinc, par blocs, en rendant la main entre deux blocs (la page reste vivante sur un long morceau). */
export async function resampleSincAsync(x, fromSr, toSr, block = 1 << 17) {
    if (fromSr === toSr) return x.slice();
    const plan = resamplePlan(fromSr, toSr), out = new Float32Array(resampledLength(x.length, fromSr, toSr));
    for (let n = 0; n < out.length; n += block) {
        resampleRange(plan, x, out, n, Math.min(out.length, n + block));
        await new Promise((r) => setTimeout(r, 0));
    }
    return out;
}
