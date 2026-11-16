// Liste des calculs lourds (modèle), par ordre de priorité. node mkjobs.mjs > jobs.json
import { readdirSync, statSync } from 'node:fs';
const B = new URL('..', import.meta.url).pathname;
const items = readdirSync(B + 'items').filter((d) => statSync(B + 'items/' + d).isDirectory()).sort();
const cfgs = [
    ['voc', { model: 'voc' }], ['vocn', { model: 'voc', neg: true }], ['inst', { model: 'insthq3' }],
    ['vocs', { model: 'voc', shift: 98432 }], ['voco', { model: 'voc', overlap: 0.5 }], ['instn', { model: 'insthq3', neg: true }],
    ['vocsn', { model: 'voc', shift: 98432, neg: true }],
];
const jobs = [];
for (const [tag, c] of cfgs) for (const it of items) jobs.push({ in: `${B}items/${it}/song.wav`, out: `${B}out/${it}.${tag}.f32`, ...c });
console.log(JSON.stringify(jobs, null, 1));
