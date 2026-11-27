#!/usr/bin/env bash
# StudioVoix Web : remet en place l'environnement local de build et d'essai (conteneur recyclé).
#
#   bash studiovoix/web/test/dev-setup.sh            (dossier de travail par défaut : /tmp/studiovoix-dev)
#   SV_SCRATCH=/un/dossier bash studiovoix/web/test/dev-setup.sh
#
# Mesuré le 16/11/2026 : 65 s à froid (JUCE 5 s, build 32 s, IA 12 s, sons 14 s) + ~30 s d'installation apt d'Emscripten ;
# 5 s quand tout est déjà là.
#
# Rejouable : rien n'est retéléchargé ni réinstallé si c'est déjà là (sommes SHA-256 vérifiées à chaque passage).
# Suit le job « Web (WebAssembly, GitHub Pages) » de .github/workflows/studiovoix.yml (mêmes URL, versions, sommes).
# N'écrit que dans le dossier de travail ($S, hors dépôt) et dans les sorties ignorées par git : web/dist, web/models, web/vendor.
#
# Variables (facultatives) :
#   SV_REPO        racine du dépôt (défaut : celle qui contient ce script)
#   SV_SCRATCH     dossier de travail hors dépôt : JUCE, build, cache IA, sons d'essai, journaux (défaut /tmp/studiovoix-dev)
#   SV_BUILD_NUMBER numéro de build passé au moteur (défaut 0)
#   SKIP_VOICES=1  ne pas récupérer les voix chantées facultatives (fix/voices)
set -euo pipefail

S="${SV_SCRATCH:-/tmp/studiovoix-dev}"
REPO="${SV_REPO:-$(cd "$(dirname "$0")/../../.." && pwd)}"
SV="$REPO/studiovoix"
JUCE_TAG=9.0.4
JUCE="$S/juce"
FIX="$S/fix"
SEP="$FIX/sep"
LOGS="$S/logs"
mkdir -p "$LOGS" "$FIX"
exec > >(tee -a "$LOGS/bootstrap.log") 2>&1

STEP=init
log()  { printf '%s [info]  bootstrap/%s : %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STEP" "$*"; }
warn() { printf '%s [warn]  bootstrap/%s : %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STEP" "$*"; }
err()  { printf '%s [error] bootstrap/%s : %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STEP" "$*" >&2; }
trap 'err "échec ligne $LINENO (code $?) : $BASH_COMMAND"' ERR
step() { STEP="$1"; T0=$SECONDS; log "début"; }
done_step() { log "fin (${1:-fait}, $((SECONDS - T0)) s)"; }

SUDO=""
if [ "$(id -u)" != 0 ]; then SUDO="sudo"; fi

sha_ok() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$2" ]; }
# fetch <url> <fichier> <sha256> : télécharge seulement si absent ou somme différente ; somme toujours vérifiée.
fetch() {
    local url="$1" dest="$2" sha="$3"
    if sha_ok "$dest" "$sha"; then log "déjà là, somme vérifiée : $(basename "$dest")"; return 0; fi
    log "téléchargement : $url"
    curl -fsSL --retry 4 --retry-delay 5 -o "$dest.part" "$url"
    if ! sha_ok "$dest.part" "$sha"; then
        err "SHA-256 de $(basename "$dest") : $(sha256sum "$dest.part" | cut -d' ' -f1) au lieu de $sha"
        rm -f "$dest.part"; return 1
    fi
    mv "$dest.part" "$dest"
    log "téléchargé, somme vérifiée : $(basename "$dest")"
}
# stale <sortie> <entrée>... : vrai si la sortie manque ou si une entrée est plus récente.
stale() {
    local out="$1"; shift
    [ -f "$out" ] || return 0
    local i; for i in "$@"; do [ "$i" -nt "$out" ] && return 0; done
    return 1
}

[ -f "$SV/web/build-wasm.sh" ] || { err "dépôt introuvable : $SV (passer SV_REPO)"; exit 1; }
log "dépôt $REPO (branche $(git -C "$REPO" branch --show-current)), dossier de travail $S"

# --- 1. Emscripten (paquet Ubuntu, comme le job CI) -------------------------------------------------------------
step emscripten
if command -v emcc >/dev/null && command -v em++ >/dev/null; then
    done_step "déjà installé"
else
    $SUDO apt-get update -q > "$LOGS/apt-update.log" 2>&1
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -q emscripten > "$LOGS/apt-install.log" 2>&1
    done_step "installé par apt"
fi
log "$(emcc --version | head -1)"
for t in node python3 ffmpeg curl git; do command -v "$t" >/dev/null || { err "outil manquant : $t"; exit 1; }; done

# --- 2. JUCE -----------------------------------------------------------------------------------------------------
step juce
if [ -f "$JUCE/modules/juce_core/juce_core.cpp" ]; then
    done_step "déjà cloné"
else
    rm -rf "$JUCE.part"
    git clone --quiet --depth 1 --branch "$JUCE_TAG" https://github.com/juce-framework/JUCE.git "$JUCE.part"
    mv "$JUCE.part" "$JUCE"
    done_step "cloné"
fi
log "JUCE $(git -C "$JUCE" describe --tags 2>/dev/null || echo '?') ($(git -C "$JUCE" rev-parse --short HEAD))"

# --- 3. Moteur WebAssembly (objets en cache dans $S/wasm-build : seul ce qui a changé est recompilé) ---------
step wasm
(cd "$SV" && SV_WASM_BUILD_DIR="$S/wasm-build" SV_BUILD_NUMBER="${SV_BUILD_NUMBER:-0}" \
    bash web/build-wasm.sh "$JUCE" web/dist) > "$LOGS/build-wasm.log" 2>&1 \
    || { err "build-wasm.sh a échoué, voir $LOGS/build-wasm.log"; tail -n 20 "$LOGS/build-wasm.log" >&2; exit 1; }
log "$(ls -l "$SV/web/dist/studiovoix.js" "$SV/web/dist/studiovoix.wasm" | awk '{print $9" ("$5" octets)"}' | paste -sd' ')"
done_step "compilé"

# --- 4. IA : ONNX Runtime Web + modèles + lamejs (cache dans $S/ia-cache, sommes vérifiées par fetch-ia.sh) ---
step ia
bash "$SV/web/fetch-ia.sh" "$S/ia-cache" > "$LOGS/fetch-ia.log" 2>&1 \
    || { err "fetch-ia.sh a échoué, voir $LOGS/fetch-ia.log"; tail -n 20 "$LOGS/fetch-ia.log" >&2; exit 1; }
log "web/models : $(ls "$SV/web/models" | paste -sd' ')"
log "web/vendor : $(ls "$SV/web/vendor" | paste -sd' ')"
done_step "en place"

# --- 5. Sons d'essai (mêmes commandes et sommes que le job CI) -------------------------------------------------
step sons
RAW_LIBROSA=https://raw.githubusercontent.com/librosa/data/main/audio
fetch https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/samples/jfk.wav "$FIX/jfk.wav" \
    59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e
cd "$SV"
if stale "$FIX/fakemic/mic.wav" "$FIX/jfk.wav" web/test/make_fake_mic.py; then
    python3 web/test/make_fake_mic.py "$FIX/fakemic" --voice "$FIX/jfk.wav"
else log "déjà là : fakemic"; fi
if stale "$FIX/fakemic-clean/mic.wav" "$FIX/jfk.wav" web/test/make_fake_mic.py; then
    python3 web/test/make_fake_mic.py "$FIX/fakemic-clean" --voice "$FIX/jfk.wav" --no-radio
else log "déjà là : fakemic-clean"; fi

mkdir -p "$SEP/48"
fetch "$RAW_LIBROSA/Kevin_MacLeod_-_Vibe_Ace.ogg" "$SEP/music.ogg" 6c23aed3dd5aa57f2b1652ecab68d15d9b82ad257f54e639eb2880ca09bc118a
fetch "$RAW_LIBROSA/198-209-0000.hq.ogg"          "$SEP/b.ogg"     6a8d2c16e56dcb27b7f5fe5aa99bfd26b4722a6dabca1968eff951b456936514
fetch "$RAW_LIBROSA/3436-172162-0000.ogg"         "$SEP/c.ogg"     780e482b52f2c8a500356babf60178ce005449cc171a8537eb3ef2961eb3e855
if stale "$SEP/song.wav" "$SEP/music.ogg" "$SEP/b.ogg" "$SEP/c.ogg" "$FIX/jfk.wav" web/test/make_song.mjs \
   || stale "$SEP/truth_instru.wav" "$SEP/music.ogg"; then
    ffmpeg -hide_banner -loglevel error -y -ss 30 -t 20 -i "$SEP/music.ogg" -ar 44100 -ac 2 -f f32le "$SEP/music.f32"
    ffmpeg -hide_banner -loglevel error -y -i "$FIX/jfk.wav" -ar 44100 -ac 1 -f f32le "$SEP/a.f32"
    ffmpeg -hide_banner -loglevel error -y -i "$SEP/b.ogg" -ar 44100 -ac 1 -f f32le "$SEP/b.f32"
    ffmpeg -hide_banner -loglevel error -y -i "$SEP/c.ogg" -ar 44100 -ac 1 -f f32le "$SEP/c.f32"
    node web/test/make_song.mjs "$SEP/music.f32" "$SEP/a.f32" "$SEP/b.f32" "$SEP/c.f32" "$SEP"
else log "déjà là : sep/song.wav, sep/truth_instru.wav"; fi
for f in song truth_instru; do
    if stale "$SEP/48/$f.wav" "$SEP/$f.wav"; then
        ffmpeg -hide_banner -loglevel error -y -i "$SEP/$f.wav" -ar 48000 -c:a pcm_s16le "$SEP/48/$f.wav"
        log "écrit : sep/48/$f.wav"
    else log "déjà là : sep/48/$f.wav"; fi
done
done_step "en place"

# --- 6. Voix chantées libres (facultatif, hors CI ; un échec ici n'arrête pas le script) ------------------------
step voix
if [ "${SKIP_VOICES:-0}" = 1 ]; then
    done_step "sauté (SKIP_VOICES=1)"
else
    mkdir -p "$FIX/voices/src"
    # Karissa Hobbs — Let's Go Fishin' (chanson pop / folk avec voix ET accompagnement), dépôt librosa/data, révision
    # épinglée. Licence : voir ENV.md (CC BY 3.0 d'après le .txt du dépôt, CC BY-NC-SA 4.0 d'après son .toml).
    VOICE_REV=5285c94e33c74bbe97501f5c9fa95e5e2ce55d48
    VOICE_SHA=85901bde0bc5f2cad28acb83487ccf99bd6908d7359f1a449fd799d8bebb3319
    if fetch "https://raw.githubusercontent.com/librosa/data/$VOICE_REV/audio/Karissa_Hobbs_-_Lets_Go_Fishin.hq.ogg" \
             "$FIX/voices/src/Karissa_Hobbs_-_Lets_Go_Fishin.hq.ogg" "$VOICE_SHA"; then
        if stale "$FIX/voices/karissa_hobbs_lets_go_fishin.wav" "$FIX/voices/src/Karissa_Hobbs_-_Lets_Go_Fishin.hq.ogg"; then
            ffmpeg -hide_banner -loglevel error -y -i "$FIX/voices/src/Karissa_Hobbs_-_Lets_Go_Fishin.hq.ogg" \
                -ar 44100 -ac 1 -c:a pcm_s16le "$FIX/voices/karissa_hobbs_lets_go_fishin.wav"
            log "écrit : voices/karissa_hobbs_lets_go_fishin.wav (mono 44,1 kHz)"
        else log "déjà là : voices/karissa_hobbs_lets_go_fishin.wav"; fi
        done_step "en place"
    else
        warn "voix chantée non récupérée (facultatif) : on continue"
        done_step "incomplet"
    fi
fi

STEP=bilan
log "emcc : $(emcc --version | head -1)"
log "JUCE : $JUCE_TAG ($(git -C "$JUCE" rev-parse --short HEAD))"
log "node $(node --version), $(python3 --version), $(ffmpeg -version | head -1 | cut -d' ' -f1-3)"
log "git status --short : $(git -C "$REPO" status --short | paste -sd';' || true)"
log "terminé en $SECONDS s"
