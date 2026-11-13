// StudioVoix Web, essai de « Séparer la chanson » : faux morceau à parties connues.
//   node web/test/make_song.mjs <musique.f32> <voixA.f32> <voixB.f32> <voixC.f32> <dossier>
// Entrées : PCM float32 44,1 kHz (musique stéréo entrelacée, voix mono), par exemple décodées par ffmpeg.
// Morceau : musique réelle + voix principale (A puis B, en alternance) + backs (voix C, stéréo large, -9 dB) + réverb de
// la voix principale (-12 dB). Écrit song.wav (le morceau) et truth_instru.wav (la vraie musique), 16 bits stéréo.
import { readFileSync, writeFileSync } from 'node:fs';
const sr = 44100, N = 20 * sr;
const [fm, fa, fb, fc, out] = process.argv.slice(2);
if (!out) { console.error('usage : node web/test/make_song.mjs <musique.f32> <voixA.f32> <voixB.f32> <voixC.f32> <dossier>'); process.exit(2); }
const rd = (f) => { const b = readFileSync(f); return new Float32Array(b.buffer, b.byteOffset, b.length / 4); };
const mus = rd(fm), A = rd(fa), B = rd(fb), C = rd(fc);
const rms = (x) => { let s = 0, n = 0; for (const v of x) if (Math.abs(v) > 1e-4) { s += v * v; n++; } return Math.sqrt(s / Math.max(1, n)); };
const leadDry = new Float32Array(N), back = [new Float32Array(N), new Float32Array(N)], wet = new Float32Array(N);
const put = (dst, src, at, g) => { for (let i = 0; i < src.length && at + i < N; ++i) dst[at + i] += src[i] * g; };
put(leadDry, A.subarray(0, Math.min(A.length, 9.5 * sr)), 0.5 * sr, 0.25 / rms(A));
put(leadDry, B.subarray(0, Math.min(B.length, 8.5 * sr)), 11 * sr, 0.25 / rms(B));
// backs : voix C sur 3–8 s et 13–18 s, stéréo large (gauche / droite décalées de 12 ms), -9 dB sous la principale
const gC = 0.25 / rms(C) * Math.pow(10, -9 / 20), d = Math.round(0.012 * sr);
for (const [t0, t1] of [[3, 8], [13, 18]]) {
  const seg = C.subarray(Math.round((t0 - 3) * sr), Math.round((t1 - 3) * sr));
  put(back[0], seg, t0 * sr, gC); put(back[1], seg, t0 * sr + d, gC * 0.9);
}
// réverb : réponse impulsionnelle bruit × exp (RT60 1,2 s), niveau -12 dB
let seed = 7; const rnd = () => ((seed = (seed * 1103515245 + 12345) >>> 0) / 4294967296) * 2 - 1;
const L = Math.round(1.2 * sr), ir = new Float32Array(L);
for (let i = 0; i < L; ++i) ir[i] = rnd() * Math.exp(-6.9 * i / L);
let e = 0; for (const v of ir) e += v * v; const nrm = Math.pow(10, -12 / 20) / Math.sqrt(e);
const step = 16;   // convolution creuse (1 échantillon d'IR sur 16) : assez pour une queue diffuse, rapide
for (let k = 0; k < L; k += step) { const h = ir[k] * nrm * Math.sqrt(step); if (!h) continue; for (let i = 0; i + k < N; ++i) wet[i + k] += leadDry[i] * h; }
const musL = new Float32Array(N), musR = new Float32Array(N);
const gM = 0.25 / rms(mus) * Math.pow(10, -2 / 20);
for (let i = 0; i < N; ++i) { musL[i] = mus[2 * i] * gM; musR[i] = mus[2 * i + 1] * gM; }
const song = new Float32Array(2 * N);
for (let i = 0; i < N; ++i) {
  song[2 * i] = musL[i] + leadDry[i] + wet[i] + back[0][i];
  song[2 * i + 1] = musR[i] + leadDry[i] + wet[i] + back[1][i];
}
let pk = 0; for (const v of song) pk = Math.max(pk, Math.abs(v));
const g = pk > 0.98 ? 0.98 / pk : 1;
const scale = (x) => x.map((v) => v * g);
const st = (l, r) => { const o = new Float32Array(2 * N); for (let i = 0; i < N; ++i) { o[2 * i] = l[i]; o[2 * i + 1] = r[i]; } return o; };
const wav = (f, x) => {
  const n = x.length / 2, buf = Buffer.alloc(44 + n * 4);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 4, 4); buf.write('WAVEfmt ', 8); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(2, 22); buf.writeUInt32LE(sr, 24); buf.writeUInt32LE(sr * 4, 28); buf.writeUInt16LE(4, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < 2 * n; ++i) buf.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(x[i] * 32767))), 44 + 2 * i);
  writeFileSync(out + '/' + f, buf);
};
wav('song.wav', scale(song));
wav('truth_instru.wav', scale(st(musL, musR)));
console.log(`song.wav et truth_instru.wav écrits dans ${out} (20 s, gain ${g.toFixed(2)})`);
