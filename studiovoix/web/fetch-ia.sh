#!/usr/bin/env bash
# StudioVoix Web : récupère ce qu'il faut à l'isolation de la voix (IA), versions épinglées et sommes vérifiées.
#   web/vendor/ : ONNX Runtime Web 1.22.0 (MIT, npm onnxruntime-web) — moteur d'inférence WebGPU / WASM ;
#                 lamejs 1.2.1 (LGPL-3.0, npm lamejs) — encodeur MP3 de l'export
#   web/models/ : UVR-MDX-NET-Voc_FT.onnx (MIT, projet Ultimate Vocal Remover) — modèle « voix seule », 66,8 Mo ;
#                 UVR_MDXNET_KARA_2.onnx (UVR, 52,8 Mo), Reverb_HQ_By_FoxJoy.onnx (66,8 Mo, licence non indiquée),
#                 wespeaker_en_voxceleb_resnet34.onnx (WeSpeaker / sherpa-onnx, Apache-2.0, 26,5 Mo)
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

# Modèles de « Séparer la chanson » : karaoké (voix principale / backs), réverb (ambiance), empreinte de voix (chanteurs).
fetch_model() {   # fichier url sha256
  local f="$1" url="$2" sha="$3"
  if [ ! -f "$CACHE/$f" ] || [ "$(sha256sum "$CACHE/$f" | cut -d' ' -f1)" != "$sha" ]; then
    log "téléchargement du modèle $f"
    curl -fsSL --retry 4 --retry-delay 5 -o "$CACHE/$f.part" "$url"
    mv "$CACHE/$f.part" "$CACHE/$f"
  fi
  local got; got="$(sha256sum "$CACHE/$f" | cut -d' ' -f1)"
  if [ "$got" != "$sha" ]; then echo "fetch-ia : [error] SHA-256 de $f : $got au lieu de $sha" >&2; exit 1; fi
  cp "$CACHE/$f" "$WEB/models/$f"
  log "modèle $f vérifié"
}
UVR=https://github.com/TRvlvr/model_repo/releases/download/all_public_uvr_models
fetch_model UVR_MDXNET_KARA_2.onnx "$UVR/UVR_MDXNET_KARA_2.onnx" bf32e15105a09c0f7dddd2b67346146334d6f3ecb399ed7638eba2ab07cbf5f4
fetch_model Reverb_HQ_By_FoxJoy.onnx "$UVR/Reverb_HQ_By_FoxJoy.onnx" 233bb5c6aaa365e568659a0a81211746fa881f8f47f82d9e864fce1f7692db80
fetch_model wespeaker_en_voxceleb_resnet34.onnx \
  https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34.onnx \
  5ef208a9da1453335308a6b6f4e6dfbd7e183a38b604de0a57664f45d257fe94

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

# Encodeur MP3 pour l'export (lamejs, LGPL-3.0, portage JavaScript de LAME — lame.sourceforge.net) : fichier séparé,
# non modifié, version épinglée et somme vérifiée.
LAME_VERSION=1.2.1
LAME_SHA=15d285e2587b3bdbfd18a68de6ce07cc074f7480a82c3815da2dc1c348ec6df4
if [ ! -f "$CACHE/lamejs-$LAME_VERSION.tgz" ]; then
  log "téléchargement de lamejs@$LAME_VERSION (npm)"
  (cd "$CACHE" && npm pack --silent "lamejs@$LAME_VERSION" >/dev/null)
fi
rm -rf "$CACHE/lame" && mkdir -p "$CACHE/lame"
tar xzf "$CACHE/lamejs-$LAME_VERSION.tgz" -C "$CACHE/lame"
GOT="$(sha256sum "$CACHE/lame/package/lame.min.js" | cut -d' ' -f1)"
if [ "$GOT" != "$LAME_SHA" ]; then echo "fetch-ia : [error] lame.min.js : SHA-256 $GOT au lieu de $LAME_SHA" >&2; exit 1; fi
cp "$CACHE/lame/package/lame.min.js" "$WEB/vendor/lame.min.js"
cp "$CACHE/lame/package/LICENSE" "$WEB/vendor/LICENSE-lamejs.txt" 2>/dev/null || true
log "lamejs $LAME_VERSION copié dans web/vendor (SHA-256 vérifié)"
