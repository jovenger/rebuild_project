# Poids stockés en demi-précision : chaque gros poids float32 devient float16 + un nœud Cast(→ float32) ; le calcul reste en
# float32 (seule la taille du fichier baisse).   python -I fp16_weights.py <entrée.onnx> <sortie.onnx>
import sys, os, logging
import numpy as np, onnx
from onnx import helper, numpy_helper, TensorProto
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] fp16 : %(message)s')
log = logging.getLogger('fp16')
src, dst = sys.argv[1:3]
m = onnx.load(src)
casts, n, worst = [], 0, 0.0
for init in m.graph.initializer:
    if init.data_type != TensorProto.FLOAT: continue
    a = numpy_helper.to_array(init)
    if a.size < 1024: continue
    h = a.astype(np.float16)
    if not np.isfinite(h).all(): log.warning(f'{init.name} : dépassement en float16, laissé en float32'); continue
    worst = max(worst, float(np.abs(h.astype(np.float32) - a).max()))
    name = init.name
    init.CopyFrom(numpy_helper.from_array(h, name + '_fp16'))
    casts.append(helper.make_node('Cast', [name + '_fp16'], [name], to=TensorProto.FLOAT, name='cast_' + name))
    n += 1
nodes = list(m.graph.node)
del m.graph.node[:]
m.graph.node.extend(casts + nodes)
onnx.save(m, dst)
log.info(f'{n} poids convertis ; écart absolu maximal sur un poids {worst:.2e} ; {os.path.getsize(src) / 1e6:.0f} Mo → {os.path.getsize(dst) / 1e6:.0f} Mo')
