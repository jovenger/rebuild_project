// StudioVoix Web : projet dans UN fichier (« .studiovoix »), pour le garder hors du navigateur ou le rouvrir sur un
// autre appareil. Le fichier contient exactement ce que la sauvegarde automatique garde : les métadonnées du projet
// (pistes, types, styles, réglages, prises, montage) et tous les sons (prises, instru), au bit près (float 32 bits).
// Format (tout en petit-boutiste) :
//   octets 0-7   : « SVPROJ1\n »
//   octets 8-11  : longueur L de l'en-tête (uint32)
//   octets 12…   : en-tête JSON (UTF-8), complété par des espaces pour que les sons commencent sur un multiple de 4
//                  { format, app, savedAt, meta, audio: [{ id, length (échantillons), offset (octets depuis le début
//                    des sons), crc (CRC-32 des octets du son) }], extra }
//   ensuite      : les sons bout à bout, float 32 bits.
// Un fichier vient de l'extérieur : tout est contrôlé à la lecture (signature, tailles, bornes, chevauchements, somme de
// contrôle de chaque son, valeurs non finies), et une erreur dit en clair ce qui ne va pas — jamais de lecture « au mieux ».
// Module ES pur (ni page ni IndexedDB) : utilisé par la page et par l'essai Node web/test/projectfile.mjs.

export const PROJECT_MAGIC = 'SVPROJ1\n';
export const PROJECT_EXT = '.studiovoix';
export const PROJECT_FORMAT = 1;
export const LIMITS = { headerBytes: 16 * 1024 * 1024, sounds: 4096, idChars: 200, tracks: 512, takesPerTrack: 256 };

const enc = new TextEncoder(), dec = new TextDecoder('utf-8', { fatal: true });
const fail = (msg) => { throw new Error(`fichier de projet : ${msg}`); };
const isInt = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;
const littleEndian = new Uint8Array(new Uint32Array([1]).buffer)[0] === 1;

// CRC-32 (polynôme 0xEDB88320, celui de zip / png), table calculée une fois.
let crcTable = null;
export function crc32(bytes, crc = 0) {
    if (!crcTable) {
        crcTable = new Uint32Array(256);
        for (let n = 0; n < 256; ++n) { let c = n; for (let k = 0; k < 8; ++k) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; crcTable[n] = c >>> 0; }
    }
    let c = ~crc >>> 0;
    for (let i = 0; i < bytes.length; ++i) c = crcTable[(c ^ bytes[i]) & 255] ^ (c >>> 8);
    return ~c >>> 0;
}

/**
 * Identifiants de sons dont les métadonnées ont besoin : instru gauche / droite (et la chanson d'avant la séparation,
 * si elle est gardée) ; pour chaque prise, son son — ou, si
 * la prise est montée (liste `clips`), les sons source de ses bouts (son rendu est recalculé à l'ouverture).
 */
export function audioRefs(meta) {
    const ids = new Set();
    if (meta?.instru?.audioId) { ids.add(`${meta.instru.audioId}L`); ids.add(`${meta.instru.audioId}R`); }
    const orig = meta?.instru?.original?.audioId;   // chanson d'avant la séparation (« Rétablir le morceau »)
    if (typeof orig === 'string' && orig) { ids.add(`${orig}L`); ids.add(`${orig}R`); }
    for (const t of meta?.tracks || [])
        for (const k of t?.takes || []) {
            if (Array.isArray(k?.clips)) { for (const c of k.clips) if (typeof c?.src === 'string' && c.src) ids.add(c.src); }
            else if (typeof k?.audioId === 'string') ids.add(k.audioId);
        }
    return [...ids];
}

/** Contrôle des métadonnées : ce dont la page se sert pour reconstruire le projet. Lève une erreur claire sinon. */
export function checkMeta(meta) {
    if (!meta || typeof meta !== 'object' || Array.isArray(meta)) fail('métadonnées absentes');
    if (meta.version !== 1) fail(`version de projet ${JSON.stringify(meta.version)} non prise en charge (attendu : 1)`);
    if (!Array.isArray(meta.tracks)) fail('liste des pistes absente');
    if (meta.tracks.length > LIMITS.tracks) fail(`trop de pistes (${meta.tracks.length}, au plus ${LIMITS.tracks})`);
    meta.tracks.forEach((t, i) => {
        if (!t || typeof t !== 'object') fail(`piste ${i + 1} illisible`);
        if (typeof t.name !== 'string' || typeof t.roleId !== 'string') fail(`piste ${i + 1} : nom ou type absent`);
        if (!Array.isArray(t.takes)) fail(`piste ${i + 1} (« ${t.name} ») : liste des prises absente`);
        if (t.takes.length > LIMITS.takesPerTrack) fail(`piste ${i + 1} : trop de prises (${t.takes.length})`);
        t.takes.forEach((k, j) => {
            if (!k || typeof k.audioId !== 'string' || !k.audioId) fail(`piste ${i + 1}, prise ${j + 1} : son non désigné`);
            if (!(k.sampleRate >= 8000 && k.sampleRate <= 192000)) fail(`piste ${i + 1}, prise ${j + 1} : fréquence ${k.sampleRate} Hz hors bornes`);
            if (!(Number.isFinite(k.startSec) && k.startSec >= 0)) fail(`piste ${i + 1}, prise ${j + 1} : place dans le morceau invalide`);
        });
    });
    if (meta.instru != null) {
        if (typeof meta.instru !== 'object' || typeof meta.instru.audioId !== 'string') fail('instru : son non désigné');
        if (!(meta.instru.sampleRate >= 8000 && meta.instru.sampleRate <= 192000)) fail(`instru : fréquence ${meta.instru.sampleRate} Hz hors bornes`);
    }
    return meta;
}

/** Un son prêt à écrire : sa ligne de table (place = `offset` octets depuis le début des sons) et ses octets (sans copie). */
export function describeSound(id, a, offset) {
    if (!littleEndian) fail('cet appareil range les nombres dans l\'autre sens (gros-boutiste) : enregistrement non pris en charge');
    if (typeof id !== 'string' || !id || id.length > LIMITS.idChars) fail(`identifiant de son invalide (${String(id).slice(0, 40)})`);
    if (!(a instanceof Float32Array)) fail(`le son « ${id} » n'est pas un son (Float32Array attendu)`);
    const bytes = new Uint8Array(a.buffer, a.byteOffset, a.byteLength);
    return { entry: { id, length: a.length, offset, crc: crc32(bytes) }, bytes };
}

/**
 * Début du fichier (signature + en-tête) pour des métadonnées et une table de sons (lignes de describeSound, dans
 * l'ordre d'écriture). Retourne { parts: [signature, en-tête], header }. Lève une erreur si un son dont les
 * métadonnées ont besoin n'est pas dans la table.
 */
export function packHeader(meta, table, extra = {}) {
    checkMeta(meta);
    if (table.length > LIMITS.sounds) fail(`trop de sons (${table.length}, au plus ${LIMITS.sounds})`);
    const have = new Set(table.map((s) => s.id));
    const missing = audioRefs(meta).filter((id) => !have.has(id));
    if (missing.length) fail(`son(s) du projet introuvable(s) : ${missing.slice(0, 5).join(', ')}${missing.length > 5 ? '…' : ''}`);
    const header = { format: PROJECT_FORMAT, app: 'studiovoix-web', savedAt: new Date().toISOString(), meta, audio: table, extra };
    let json = enc.encode(JSON.stringify(header));
    const pad = (4 - ((12 + json.length) % 4)) % 4;   // les sons commencent sur un multiple de 4 octets
    if (pad) { const p = new Uint8Array(json.length + pad); p.set(json); p.fill(32, json.length); json = p; }
    if (json.length > LIMITS.headerBytes) fail(`en-tête trop grand (${json.length} octets)`);
    const head = new Uint8Array(12);
    head.set(enc.encode(PROJECT_MAGIC));
    new DataView(head.buffer).setUint32(8, json.length, true);
    return { parts: [head, json], header };
}

/**
 * Prépare le fichier d'un projet. `audio` : Map (ou liste de couples) identifiant → Float32Array.
 * Retourne { parts, size, header } ; `new Blob(parts)` donne le fichier (les sons ne sont pas recopiés).
 * Lève une erreur si un son dont les métadonnées ont besoin manque, ou s'il n'est pas un Float32Array.
 * (La page écrit son par son avec describeSound + packHeader, pour ne pas garder tous les sons en mémoire.)
 */
export function packProject(meta, audio, extra = {}) {
    checkMeta(meta);
    const sounds = audio instanceof Map ? audio : new Map(audio);
    const missing = audioRefs(meta).filter((id) => !sounds.has(id));
    if (missing.length) fail(`son(s) du projet introuvable(s) : ${missing.slice(0, 5).join(', ')}${missing.length > 5 ? '…' : ''}`);
    if (sounds.size > LIMITS.sounds) fail(`trop de sons (${sounds.size}, au plus ${LIMITS.sounds})`);
    const table = [], data = [];
    let offset = 0;
    for (const [id, a] of sounds) {
        const d = describeSound(id, a, offset);
        table.push(d.entry);
        data.push(d.bytes);
        offset += d.bytes.length;
    }
    const h = packHeader(meta, table, extra);
    return { parts: [...h.parts, ...data], size: h.parts[0].length + h.parts[1].length + offset, header: h.header };
}

/** Longueur de l'en-tête, lue dans les 12 premiers octets (signature contrôlée). */
export function headerLength(first12) {
    if (!(first12 instanceof Uint8Array) || first12.length < 12) fail('trop court pour être un projet StudioVoix (moins de 12 octets)');
    for (let i = 0; i < 8; ++i) if (first12[i] !== PROJECT_MAGIC.charCodeAt(i)) fail('ce n\'est pas un projet StudioVoix (signature absente)');
    const n = new DataView(first12.buffer, first12.byteOffset, 12).getUint32(8, true);
    if (!isInt(n, 2, LIMITS.headerBytes)) fail(`en-tête de taille invalide (${n} octets)`);
    return n;
}

/**
 * Lit et contrôle l'en-tête. `prefix` : les 12 + L premiers octets du fichier ; `fileSize` : taille du fichier entier.
 * Retourne { header, dataStart } ; chaque son se lit ensuite dans [dataStart + offset, dataStart + offset + 4 × length[.
 */
export function parseHeader(prefix, fileSize) {
    const n = headerLength(prefix);
    if (prefix.length < 12 + n) fail(`fichier tronqué : en-tête de ${n} octets annoncé, ${Math.max(0, prefix.length - 12)} présents`);
    let header;
    try { header = JSON.parse(dec.decode(prefix.subarray(12, 12 + n))); }
    catch (e) { fail(`en-tête illisible (${e.message})`); }
    if (!header || typeof header !== 'object') fail('en-tête illisible');
    if (header.format !== PROJECT_FORMAT) fail(`format ${JSON.stringify(header.format)} non pris en charge (attendu : ${PROJECT_FORMAT}) — fichier fait par une version plus récente ?`);
    checkMeta(header.meta);
    if (!Array.isArray(header.audio)) fail('table des sons absente');
    if (header.audio.length > LIMITS.sounds) fail(`trop de sons (${header.audio.length}, au plus ${LIMITS.sounds})`);
    const dataStart = 12 + n, dataBytes = fileSize - dataStart;
    if (!isInt(fileSize, dataStart, Number.MAX_SAFE_INTEGER)) fail('taille de fichier invalide');
    const seen = new Set();
    let expect = 0;
    for (const [i, s] of header.audio.entries()) {
        if (!s || typeof s.id !== 'string' || !s.id || s.id.length > LIMITS.idChars) fail(`son ${i + 1} : identifiant invalide`);
        if (seen.has(s.id)) fail(`son « ${s.id} » présent deux fois`);
        seen.add(s.id);
        if (!isInt(s.length, 0, 0x7FFFFFFF) || !isInt(s.offset, 0, Number.MAX_SAFE_INTEGER) || !isInt(s.crc, 0, 0xFFFFFFFF)) fail(`son « ${s.id} » : taille, place ou somme de contrôle invalide`);
        if (s.offset !== expect) fail(`son « ${s.id} » : place inattendue (octet ${s.offset} au lieu de ${expect}) — sons qui se chevauchent ou trou`);
        expect += 4 * s.length;
    }
    if (expect > dataBytes) fail(`fichier tronqué : ${expect} octets de son annoncés, ${dataBytes} présents`);
    if (expect < dataBytes) fail(`fichier plus long que prévu (${dataBytes - expect} octets en trop après les sons)`);
    const missing = audioRefs(header.meta).filter((id) => !seen.has(id));
    if (missing.length) fail(`son(s) du projet absent(s) du fichier : ${missing.slice(0, 5).join(', ')}${missing.length > 5 ? '…' : ''}`);
    return { header, dataStart };
}

/** Un son du fichier : `bytes` = ses octets exacts. Contrôle la taille, la somme de contrôle et les valeurs. */
export function unpackAudio(bytes, entry) {
    if (!littleEndian) fail('cet appareil range les nombres dans l\'autre sens (gros-boutiste) : lecture non prise en charge');
    if (!(bytes instanceof Uint8Array) || bytes.length !== 4 * entry.length) fail(`son « ${entry.id} » : ${bytes?.length ?? 0} octets lus au lieu de ${4 * entry.length}`);
    const crc = crc32(bytes);
    if (crc !== entry.crc) fail(`son « ${entry.id} » abîmé (somme de contrôle ${crc.toString(16)} au lieu de ${entry.crc.toString(16)})`);
    const out = new Float32Array(entry.length);
    new Uint8Array(out.buffer).set(bytes);
    for (let i = 0; i < out.length; ++i) if (!Number.isFinite(out[i])) fail(`son « ${entry.id} » : valeur non finie à l'échantillon ${i}`);
    return out;
}
