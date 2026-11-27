# Coûts mesurés par candidat à partir de out/*.json (écrits par infer.py) : temps / durée, temps processeur / durée, mémoire max.
import json, glob, os, sys
OUT = sys.argv[1]; MODELS = sys.argv[2]
FILES = dict(htdemucs='955717e8-8726e21a.th', tim_htdemucs='955717e8-8726e21a.th', scnet='scnet_checkpoint_musdb18.ckpt', scnet_nonorm='scnet_checkpoint_musdb18.ckpt',
             bsrof_o1='model_bs_roformer_ep_317_sdr_12.9755.ckpt', bsrof_o2='model_bs_roformer_ep_317_sdr_12.9755.ckpt', mdx23c_o2='MDX23C-8KFFT-InstVoc_HQ.ckpt', melinst='melband_roformer_inst_v1.ckpt')
tags = sorted({os.path.basename(f).split('.')[1] for f in glob.glob(os.path.join(OUT, '*.json')) if len(os.path.basename(f).split('.')) == 3})
print('candidat\tn\tfils\ttemps/durée\tcpu/durée\tmém. max Mo\tcharge moy.\tparamètres M\tfichier Mo\trecouvrement\tmorceau s')
for t in tags:
    js = [json.load(open(f)) for f in sorted(glob.glob(os.path.join(OUT, f'*.{t}.json')))]
    js = [j for j in js if 'audio_seconds' in j]
    if not js: continue
    a = sum(j['audio_seconds'] for j in js); w = sum(j['seconds'] for j in js); c = sum(j['cpu_seconds'] for j in js)
    sz = os.path.getsize(os.path.join(MODELS, FILES[t])) / 1e6 if t in FILES and os.path.exists(os.path.join(MODELS, FILES[t])) else float('nan')
    ch = js[0].get('info_chunk_size'); seg = js[0].get('info_segment')
    print(f"{t}\t{len(js)}\t{js[0]['threads']}\t{w / a:.2f}\t{c / a:.2f}\t{max(j['peak_rss_mb'] for j in js):.0f}\t{sum(j['load'] for j in js) / len(js):.1f}\t{js[0]['info_params_M']:.1f}\t{sz:.0f}\t{js[0].get('info_num_overlap', 'demucs 0,25')}\t{(ch / 44100 if ch else seg):.2f}")
