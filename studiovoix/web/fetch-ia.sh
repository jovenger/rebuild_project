#!/usr/bin/env bash
# StudioVoix Web : récupère ce qu'il faut à l'isolation de la voix (IA), versions épinglées et sommes vérifiées.
#   web/vendor/ : ONNX Runtime Web 1.22.0 (MIT, npm onnxruntime-web) — moteur d'inférence WebGPU / WASM
#   web/models/ : UVR-MDX-NET-Voc_FT.onnx (MIT, projet Ultimate Vocal Remover) — modèle « voix seule », 66,8 Mo
# Usage : web/fetch-ia.sh [dossier_cache]   (le cache évite de retélécharger le modèle)
set -euo pipefail
WEB="$(cd "$(dirname "$0")" && pwd)"
CACHE="${1:-${SV_IA_CACHE:-$WEB/build/ia-cache}}"
ORT_VERSION=1.22.0
MODEL=UVR-MDX-NET-Voc_FT.onnx
MODEL_URL="https://github.com/TRvlvr/model_repo/releases/download/all_public_uvr_models/$MODEL"
MODEL_SHA=534b2070fcc7df514b13ef660dc8cbb328679c2374d04354a5c42bb14ecce111
log() { echo "$(date -u +%H:%M:%S) [info] fetch-ia : $*"; }
mkdir -p "$CACHE" "$WEB/vendor" "$WEB/models"

if [ ! -f "$CACHE/$MODEL" ] || [ "$(sha256sum "$CACHE/$MODEL" | cut -d' ' -f1)" != "$MODEL_SHA" ]; then
  log "téléchargement du modèle $MODEL"
  curl -fsSL --retry 4 --retry-delay 5 -o "$CACHE/$MODEL.part" "$MODEL_URL"
  mv "$CACHE/$MODEL.part" "$CACHE/$MODEL"
fi
SUM="$(sha256sum "$CACHE/$MODEL" | cut -d' ' -f1)"
if [ "$SUM" != "$MODEL_SHA" ]; then echo "fetch-ia : [error] SHA-256 du modèle $SUM au lieu de $MODEL_SHA" >&2; exit 1; fi
cp "$CACHE/$MODEL" "$WEB/models/$MODEL"
log "modèle vérifié (SHA-256 $MODEL_SHA)"

if [ ! -f "$CACHE/onnxruntime-web-$ORT_VERSION.tgz" ]; then
  log "téléchargement d'onnxruntime-web@$ORT_VERSION (npm)"
  (cd "$CACHE" && npm pack --silent "onnxruntime-web@$ORT_VERSION" >/dev/null)
fi
rm -rf "$CACHE/ort" && mkdir -p "$CACHE/ort"
tar xzf "$CACHE/onnxruntime-web-$ORT_VERSION.tgz" -C "$CACHE/ort"
V="$(node -p "require('$CACHE/ort/package/package.json').version")"
if [ "$V" != "$ORT_VERSION" ]; then echo "fetch-ia : [error] onnxruntime-web $V au lieu de $ORT_VERSION" >&2; exit 1; fi
for f in ort.webgpu.min.mjs ort-wasm-simd-threaded.jsep.mjs ort-wasm-simd-threaded.jsep.wasm; do
  cp "$CACHE/ort/package/dist/$f" "$WEB/vendor/$f"
done
cp "$CACHE/ort/package/LICENSE" "$WEB/vendor/LICENSE-onnxruntime-web.txt" 2>/dev/null || true
log "onnxruntime-web $V copié dans web/vendor ($(du -sh "$WEB/vendor" | cut -f1))"
