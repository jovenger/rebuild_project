// Essai Node du projet en fichier (projectfile.js) : aller-retour au bit près, et refus clair de tout fichier abîmé
// (un fichier vient de l'extérieur : signature, tailles, bornes, chevauchements, somme de contrôle, valeurs non finies).
//   node web/test/projectfile.mjs
import { packProject, parseHeader, headerLength, unpackAudio, audioRefs, checkMeta, crc32, PROJECT_MAGIC } from '../projectfile.js';
let failed = false;
const check = (name, ok, detail) => { console.log(`${ok ? 'OK   ' : 'ÉCHEC'} ${name} — ${detail}`); if (!ok) failed = true; };
const refuses = (name, fn, want) => {
    let msg = null;
    try { fn(); } catch (e) { msg = e.message; }
    check(`refus : ${name}`, msg !== null && want.test(msg), msg === null ? 'ACCEPTÉ à tort' : msg);
};

// ---------------------------------------------------------------- un projet de synthèse (tirage fixe)
let seed = 4242;
const rnd = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed / 4294967296; };
const sound = (n) => Float32Array.from({ length: n }, () => 2 * rnd() - 1);
const meta = {
    version: 1, savedAt: 1, nextTrackId: 3, armedId: 1, rawLevelOn: false,
    instru: { audioId: 'i1', sampleRate: 48000, name: 'instru « été ».wav' },
    tracks: [
        { id: 1, name: 'Voix principale', roleId: 'lead', styleId: 'rap_conscient', volumeDb: 0, mute: false, solo: false, noFx: false, smooth: true, locked: true, fx: { comp: { ratio: 3 } }, active: 1,
          takes: [{ audioId: 'a1', sampleRate: 48000, startSec: 0, note: 'micro', label: 'Prise 1' }, { audioId: 'a2', sampleRate: 48000, startSec: 1.25, note: 'micro', label: 'Prise 2' }] },
        { id: 2, name: 'Back', roleId: 'manual_back', styleId: 'rap_conscient', volumeDb: -2, mute: true, solo: false, noFx: true, smooth: false, locked: false, fx: {}, active: 0,
          takes: [{ audioId: 'a3', sampleRate: 44100, startSec: 0.5, note: '', label: 'Prise 1', sources: ['s1'] }] },
    ],
};
const audio = new Map([['i1L', sound(4801)], ['i1R', sound(4801)], ['a1', sound(1000)], ['a2', sound(1)], ['a3', sound(777)], ['s1', sound(333)], ['vide', new Float32Array(0)]]);
const fileOf = (p) => { const out = new Uint8Array(p.size); let o = 0; for (const part of p.parts) { out.set(part, o); o += part.length; } return out; };

// ---------------------------------------------------------------- aller-retour
const packed = packProject(meta, audio, { roleOffsets: { manual_back: -5 } });
const file = fileOf(packed);
check('taille annoncée = taille du fichier', file.length === packed.size, `${packed.size} octets, ${audio.size} sons`);
check('signature en tête', new TextDecoder().decode(file.subarray(0, 8)) === PROJECT_MAGIC, JSON.stringify(PROJECT_MAGIC));
const n = headerLength(file.subarray(0, 12));
const { header, dataStart } = parseHeader(file.subarray(0, 12 + n), file.length);
check('les sons commencent sur un multiple de 4 octets', dataStart % 4 === 0, `octet ${dataStart}`);
check('métadonnées retrouvées à l\'identique', JSON.stringify(header.meta) === JSON.stringify(meta), `${header.meta.tracks.length} pistes, instru « ${header.meta.instru.name} »`);
check('réglages annexes retrouvés', header.extra?.roleOffsets?.manual_back === -5, JSON.stringify(header.extra));
let exact = true, total = 0;
for (const s of header.audio) {
    const a = unpackAudio(file.subarray(dataStart + s.offset, dataStart + s.offset + 4 * s.length), s), ref = audio.get(s.id);
    total += a.length;
    if (!ref || a.length !== ref.length) { exact = false; continue; }
    for (let i = 0; i < a.length; ++i) if (a[i] !== ref[i]) { exact = false; break; }
}
check('tous les sons au bit près', exact && header.audio.length === audio.size, `${header.audio.length} sons, ${total} échantillons`);
check('sons nécessaires listés', audioRefs(meta).sort().join() === ['a1', 'a2', 'a3', 'i1L', 'i1R', 's1'].sort().join(), audioRefs(meta).join(', '));
check('CRC-32 conforme (« 123456789 » → cbf43926)', crc32(new TextEncoder().encode('123456789')) === 0xCBF43926, crc32(new TextEncoder().encode('123456789')).toString(16));
// Un son vu à travers une fenêtre (sous-tableau) est enregistré tel quel, sans ses voisins.
const big = sound(100), view = big.subarray(10, 60);
const p2 = packProject({ version: 1, tracks: [{ name: 'v', roleId: 'lead', takes: [{ audioId: 'w', sampleRate: 48000, startSec: 0 }] }] }, [['w', view]]);
const f2 = fileOf(p2), h2 = parseHeader(f2.subarray(0, 12 + headerLength(f2.subarray(0, 12))), f2.length);
const w = unpackAudio(f2.subarray(h2.dataStart, h2.dataStart + 200), h2.header.audio[0]);
check('sous-tableau enregistré tel quel', w.length === 50 && w.every((v, i) => v === view[i]), `${w.length} échantillons`);
// Projet sans instru ni piste : accepté.
const p3 = packProject({ version: 1, tracks: [] }, new Map());
const f3 = fileOf(p3);
check('projet vide accepté', parseHeader(f3.subarray(0, 12 + headerLength(f3.subarray(0, 12))), f3.length).header.audio.length === 0, `${f3.length} octets`);

// ---------------------------------------------------------------- refus à l'écriture
refuses('son nécessaire manquant à l\'écriture', () => packProject(meta, new Map([...audio].filter(([k]) => k !== 'a2'))), /introuvable.*a2/);
refuses('son qui n\'est pas un Float32Array', () => packProject(meta, new Map([...audio, ['x', new Int16Array(4)]])), /Float32Array/);
refuses('version de projet inconnue', () => packProject({ ...meta, version: 2 }, audio), /version/);
refuses('prise sans fréquence valide', () => checkMeta({ version: 1, tracks: [{ name: 'v', roleId: 'lead', takes: [{ audioId: 'a', sampleRate: 12, startSec: 0 }] }] }), /fréquence/);
refuses('prise à une place négative', () => checkMeta({ version: 1, tracks: [{ name: 'v', roleId: 'lead', takes: [{ audioId: 'a', sampleRate: 48000, startSec: -1 }] }] }), /place/);

// ---------------------------------------------------------------- refus à la lecture (fichiers abîmés)
const read = (bytes) => { const k = headerLength(bytes.subarray(0, 12)); const r = parseHeader(bytes.subarray(0, Math.min(bytes.length, 12 + k)), bytes.length); for (const s of r.header.audio) unpackAudio(bytes.subarray(r.dataStart + s.offset, r.dataStart + s.offset + 4 * s.length), s); return r; };
const withHeader = (edit) => {   // même fichier, en-tête réécrit
    const h = JSON.parse(JSON.stringify(header));
    edit(h);
    const json = new TextEncoder().encode(JSON.stringify(h)), head = new Uint8Array(12);
    head.set(new TextEncoder().encode(PROJECT_MAGIC));
    new DataView(head.buffer).setUint32(8, json.length, true);
    const out = new Uint8Array(12 + json.length + (file.length - dataStart));
    out.set(head); out.set(json, 12); out.set(file.subarray(dataStart), 12 + json.length);
    return out;
};
check('contrôle : le fichier intact se relit', (() => { try { read(file); return true; } catch { return false; } })(), 'aucune erreur');
check('contrôle : en-tête réécrit sans changement se relit', (() => { try { read(withHeader(() => {})); return true; } catch { return false; } })(), 'aucune erreur');
refuses('fichier de moins de 12 octets', () => read(file.subarray(0, 5)), /trop court/);
refuses('autre type de fichier (signature)', () => read(Uint8Array.from(file, (v, i) => (i === 0 ? 82 : v))), /signature/);
refuses('longueur d\'en-tête absurde', () => { const f = file.slice(); new DataView(f.buffer).setUint32(8, 0xFFFFFFF0, true); read(f); }, /taille invalide/);
refuses('fichier coupé dans l\'en-tête', () => read(file.subarray(0, 40)), /tronqué/);
refuses('fichier coupé dans les sons', () => read(file.subarray(0, file.length - 8)), /tronqué/);
refuses('octets en trop à la fin', () => { const f = new Uint8Array(file.length + 4); f.set(file); read(f); }, /trop/);
refuses('en-tête qui n\'est pas du JSON', () => { const f = file.slice(); f[12] = 33; read(f); }, /illisible/);
refuses('un son abîmé (un bit changé)', () => { const f = file.slice(); f[dataStart + 17] ^= 1; read(f); }, /abîmé/);
refuses('format plus récent', () => read(withHeader((h) => { h.format = 2; })), /format/);
refuses('sons qui se chevauchent', () => read(withHeader((h) => { h.audio[1].offset = 0; })), /chevauchent|place/);
refuses('longueur de son négative', () => read(withHeader((h) => { h.audio[0].length = -4; })), /invalide/);
refuses('son annoncé plus long que le fichier', () => read(withHeader((h) => { h.audio[h.audio.length - 1].length = 1e9; })), /tronqué/);
refuses('même identifiant deux fois', () => read(withHeader((h) => { h.audio[1].id = h.audio[0].id; })), /deux fois/);
refuses('son du projet absent du fichier', () => read(withHeader((h) => { h.audio.find((s) => s.id === 'a2').id = 'autre'; })), /absent/);
refuses('table des sons absente', () => read(withHeader((h) => { delete h.audio; })), /table/);
refuses('pistes absentes', () => read(withHeader((h) => { delete h.meta.tracks; })), /pistes/);
refuses('trop de sons annoncés', () => read(withHeader((h) => { h.audio = Array.from({ length: 5000 }, (_, i) => ({ id: `z${i}`, length: 0, offset: 0, crc: 0 })); })), /trop de sons/);
// Valeur non finie avec une somme de contrôle « juste » (fichier fabriqué exprès).
refuses('valeur non finie dans un son', () => {
    const bad = new Float32Array([0.1, NaN, 0.2]), b = new Uint8Array(bad.buffer);
    unpackAudio(b, { id: 'nan', length: 3, crc: crc32(b) });
}, /non finie/);

console.log(failed ? 'ÉCHEC' : 'Projet en fichier OK');
process.exit(failed ? 1 : 0);
