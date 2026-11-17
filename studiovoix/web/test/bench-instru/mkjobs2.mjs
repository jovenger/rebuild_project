// Calculs supplémentaires : deux autres modèles publics de la même famille (évaluation seulement).
import { readdirSync, statSync } from 'node:fs';
const B = new URL('..', import.meta.url).pathname;
const items = readdirSync(B + 'items').filter((d) => statSync(B + 'items/' + d).isDirectory()).sort();
const cfgs = [['kim', { model: 'kim2' }], ['inst4', { model: 'insthq4' }]];
const jobs = [];
for (const [tag, c] of cfgs) for (const it of items) jobs.push({ in: `${B}items/${it}/song.wav`, out: `${B}out/${it}.${tag}.f32`, ...c });
console.log(JSON.stringify(jobs, null, 1));
