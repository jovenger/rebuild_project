# Inférence PyTorch (processeur) des candidats d'autres architectures sur les extraits du banc.
#   THREADS=3 python -I infer.py <candidat> <items_dir> <out_dir> [extrait …]
# Sorties : <out>/<extrait>.<candidat>.voc.f32 (voix du modèle), .inst.f32 (instru du modèle si elle existe), .json (temps, mémoire).
import sys, os, json, time, resource, logging, random
HERE = os.path.dirname(os.path.abspath(__file__))
B2 = os.path.dirname(HERE)
MSST = os.path.join(B2, 'src', 'msst')
sys.path[:0] = [MSST, os.path.join(HERE, 'stubs')]
import numpy as np, soundfile as sf, torch, yaml

THREADS = int(os.environ.get('THREADS', 3))
torch.set_num_threads(THREADS)
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] infer : %(message)s')
log = logging.getLogger('infer')
MODELS = os.path.join(B2, 'models')
CANDS = {
    'htdemucs': dict(kind='demucs', sig='955717e8'),
    'bsrof': dict(kind='msst', model_type='bs_roformer', cfg=os.path.join(MSST, 'configs/viperx/model_bs_roformer_ep_317_sdr_12.9755.yaml'), ckpt='model_bs_roformer_ep_317_sdr_12.9755.ckpt'),
    'mdx23c': dict(kind='msst', model_type='mdx23c', cfg=os.path.join(MODELS, 'model_2_stem_full_band_8k.yaml'), ckpt='MDX23C-8KFFT-InstVoc_HQ.ckpt'),
    'melinst': dict(kind='msst', model_type='mel_band_roformer', cfg=os.path.join(MODELS, 'config_melbandroformer_inst.yaml'), ckpt='melband_roformer_inst_v1.ckpt'),
    'scnet': dict(kind='msst', model_type='scnet', cfg=os.path.join(MSST, 'configs/config_musdb18_scnet.yaml'), ckpt='scnet_checkpoint_musdb18.ckpt'),
}


def rss_mb():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024


def load(cand):
    c = CANDS[cand]
    t0 = time.perf_counter()
    if c['kind'] == 'demucs':
        from pathlib import Path
        from demucs.pretrained import get_model
        import fractions, demucs.htdemucs
        # chargement « poids seuls » (fichier d'un miroir, non fiable) : seules ces classes sont autorisées au dépaquetage
        torch.serialization.add_safe_globals([demucs.htdemucs.HTDemucs, fractions.Fraction, (np._core.multiarray.scalar, 'numpy.core.multiarray.scalar'), np.dtype, type(np.dtype(np.float64)), type(np.dtype(np.int64)), type(np.dtype(np.float32))])
        model = get_model(c['sig'], repo=Path(MODELS))
        model.eval()
        info = dict(sources=list(model.sources), segment=float(model.segment), samplerate=model.samplerate)
        cfg = None
    else:
        from utils.settings import get_model_from_config
        model, cfg = get_model_from_config(c['model_type'], c['cfg'])
        sd = torch.load(os.path.join(MODELS, c['ckpt']), map_location='cpu', weights_only=True)
        for k in ('state', 'state_dict', 'model_state_dict'):
            if isinstance(sd, dict) and k in sd: sd = sd[k]
        missing = model.load_state_dict(sd, strict=True)
        model.eval()
        ov = os.environ.get('OVERLAP')
        if ov: cfg.inference.num_overlap = int(ov)
        cfg.inference.batch_size = 1
        info = dict(normalize=bool(cfg.inference.get('normalize', False)), instruments=list(cfg.training.instruments), target=cfg.training.get('target_instrument', None),
                    chunk_size=int(cfg.inference.get('chunk_size', cfg.audio.chunk_size)), num_overlap=int(cfg.inference.num_overlap))
    info['params_M'] = sum(p.numel() for p in model.parameters()) / 1e6
    info['load_s'] = time.perf_counter() - t0
    log.info(f'{cand} chargé : {info}')
    return model, cfg, info


def run(cand, model, cfg, song):
    """song (n, 2) float64 → dict nom → (n, 2) float32"""
    c = CANDS[cand]
    mix = torch.tensor(song.T, dtype=torch.float32)                      # (2, n)
    if c['kind'] == 'demucs':
        from demucs.apply import apply_model
        random.seed(0); torch.manual_seed(0)
        # procédure de demucs.separate : normalisation par la moyenne mono, shifts=1, overlap 0,25, découpage par segment
        ref = mix.mean(0); mean, std = ref.mean(), ref.std()
        x = (mix - mean) / std
        with torch.no_grad():
            out = apply_model(model, x[None], shifts=int(os.environ.get('SHIFTS', 1)), split=True, overlap=0.25, progress=False, num_workers=0, device='cpu')[0]
        out = out * std + mean
        return {name: out[i].numpy().T for i, name in enumerate(model.sources)}
    from utils.model_utils import demix
    # inference.py du dépôt : normalisation (moyenne / écart type du mono) si la configuration le demande (SCNet)
    norm = bool(cfg.inference.get('normalize', False)) and not os.environ.get('NO_NORMALIZE')
    if norm:
        mono = mix.mean(0); mean, std = mono.mean(), mono.std()
        mix = (mix - mean) / std
    res = demix(cfg, model, mix, torch.device('cpu'), c['model_type'], pbar=False)
    if norm: res = {k: np.asarray(v) * float(std) + float(mean) for k, v in res.items()}
    return {k: np.asarray(v).T for k, v in res.items()}


if __name__ == '__main__':
    cand, items_dir, out_dir = sys.argv[1:4]
    ids = sys.argv[4:] or sorted(d for d in os.listdir(items_dir) if os.path.isdir(os.path.join(items_dir, d)))
    os.makedirs(out_dir, exist_ok=True)
    tag = os.environ.get('TAG', cand)          # nom des sorties (ex. bsrof_o1 pour OVERLAP=1)
    model, cfg, info = load(cand)
    log.info(f'mémoire après chargement {rss_mb():.0f} Mo ; {THREADS} fils')
    for iid in ids:
        pj = os.path.join(out_dir, f'{iid}.{tag}.json')
        if os.path.exists(pj) and not os.environ.get('FORCE'): log.info(f'{iid} : déjà fait'); continue
        song, sr = sf.read(os.path.join(items_dir, iid, 'song.wav'), dtype='float64', always_2d=True)
        if sr != 44100 or song.shape[1] != 2: raise ValueError(f'{iid} : {sr} Hz, {song.shape[1]} canaux')
        t0 = time.perf_counter(); c0 = time.process_time()
        try:
            res = run(cand, model, cfg, song)
        except Exception as e:
            log.exception(f'{iid} : échec {type(e).__name__} : {e}'); sys.exit(1)
        dt = time.perf_counter() - t0; cpu = time.process_time() - c0
        names = {k.lower(): k for k in res}
        for k, v in res.items():
            if not np.isfinite(v).all(): raise ValueError(f'{iid} / {k} : sortie non finie')
        voc = res[names['vocals']] if 'vocals' in names else None
        inst = None
        for k in ('instrumental', 'other', 'instrument'):
            if k in names and len(res) <= 2: inst = res[names[k]]
        if inst is None and len(res) > 2: inst = sum(v for k, v in res.items() if k.lower() != 'vocals')   # somme des pistes non vocales
        if voc is not None: voc.astype(np.float32).tofile(os.path.join(out_dir, f'{iid}.{tag}.voc.f32'))
        if inst is not None: inst.astype(np.float32).tofile(os.path.join(out_dir, f'{iid}.{tag}.inst.f32'))
        dur = len(song) / sr
        meta = dict(item=iid, cand=cand, tag=tag, outputs=list(res), has_voc=voc is not None, has_inst=inst is not None, seconds=dt, cpu_seconds=cpu, audio_seconds=dur,
                    rtf=dt / dur, peak_rss_mb=rss_mb(), threads=THREADS, torch=torch.__version__, load=os.getloadavg()[0], **{f'info_{k}': v for k, v in info.items()})
        json.dump(meta, open(pj, 'w'))
        log.info(f'{iid} : {dt:.1f} s pour {dur:.1f} s de chanson (×{dt / dur:.2f}), cpu {cpu:.0f} s, mémoire max {rss_mb():.0f} Mo, sorties {list(res)}, charge {os.getloadavg()[0]:.1f}')
    log.info('fini')
