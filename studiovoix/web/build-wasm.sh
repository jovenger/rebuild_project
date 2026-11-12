#!/usr/bin/env bash
# StudioVoix Web : compile le moteur C++ (JUCE + cœur DSP) en WebAssembly avec Emscripten.
#
#   web/build-wasm.sh [dossier JUCE] [dossier de sortie]
#
# - dossier JUCE : racine du dépôt JUCE 9.0.4 (défaut : ../juce ou $JUCE_DIR) ;
# - sortie : web/dist (studiovoix.js + studiovoix.wasm), à servir avec index.html et app.js.
# Prérequis : emcc (Emscripten 3.1+). Aucun thread, aucun fichier : tout passe par la mémoire.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
JUCE="${1:-${JUCE_DIR:-$ROOT/../juce}}"
OUT="${2:-$HERE/dist}"
BUILD="${SV_WASM_BUILD_DIR:-$HERE/build}"
BUILD_NUMBER="${SV_BUILD_NUMBER:-0}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

if [ ! -f "$JUCE/modules/juce_core/juce_core.cpp" ]; then
    echo "JUCE introuvable : $JUCE (passer le dossier en premier argument ou JUCE_DIR)" >&2
    exit 1
fi
command -v em++ >/dev/null || { echo "em++ introuvable : installer Emscripten" >&2; exit 1; }

mkdir -p "$BUILD/obj" "$OUT"
echo "[wasm] JUCE : $JUCE"
echo "[wasm] sortie : $OUT (build $BUILD_NUMBER, $(em++ --version | head -1))"

# --- juce_core : JUCE 9.0.4 n'a pas d'entrée WASM dans sa table de priorités de threads (compile ailleurs). Copie
#     patchée du module : les priorités valent 0 comme sous Linux (pas de threads dans la version web de toute façon).
PATCHED="$BUILD/juce_core_wasm"
if [ ! -f "$PATCHED/.patched" ]; then
    rm -rf "$PATCHED"
    cp -r "$JUCE/modules/juce_core" "$PATCHED"
    python3 - "$PATCHED/native/juce_ThreadPriorities_native.h" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "       #if JUCE_LINUX || JUCE_BSD\n        { Thread::Priority::highest,    0 },"
assert s.count(old) == 1, "motif JUCE_LINUX introuvable dans juce_ThreadPriorities_native.h"
s = s.replace(old, "       #if JUCE_LINUX || JUCE_BSD || JUCE_WASM\n        { Thread::Priority::highest,    0 },")
open(p, "w", encoding="utf-8").write(s)
print("[wasm] juce_core : table des priorités étendue à WASM")
PYEOF
    touch "$PATCHED/.patched"
fi

DEFS=(
    -DJUCE_GLOBAL_MODULE_SETTINGS_INCLUDED=1
    -DJUCE_STANDALONE_APPLICATION=1
    -DJUCE_USE_CURL=0 -DJUCE_WEB_BROWSER=0
    -DJUCE_USE_MP3AUDIOFORMAT=0 -DJUCE_USE_LAME_AUDIO_FORMAT=0 -DJUCE_USE_FLAC=1 -DJUCE_USE_OGGVORBIS=0
    -DJUCE_STRICT_REFCOUNTEDPOINTER=1 -DJUCE_DISPLAY_SPLASH_SCREEN=0
    -DJUCE_MODULE_AVAILABLE_juce_core=1 -DJUCE_MODULE_AVAILABLE_juce_events=1
    -DJUCE_MODULE_AVAILABLE_juce_audio_basics=1 -DJUCE_MODULE_AVAILABLE_juce_audio_formats=1
    -DJUCE_MODULE_AVAILABLE_juce_dsp=1
    -DNDEBUG=1
    -DSV_EDITION_IA=0 -DSV_BUILD_NUMBER="$BUILD_NUMBER" "-DSV_BUILD_NUMBER_STR=\"$BUILD_NUMBER\"" '-DSV_DISPLAY_NAME="StudioVoix Web"'
)
CXXFLAGS=(-std=c++20 -O2 -include emscripten/emscripten.h -I"$JUCE/modules" -I"$ROOT/src" "${DEFS[@]}")

# Modules JUCE (un .cpp amalgamé par module) et sources du cœur sans interface, sans plugins VST3, sans outils IA
# externes (processus), sans mise à jour (pas d'installateur dans le navigateur).
UNITS=(
    "$PATCHED/juce_core.cpp"
    "$JUCE/modules/juce_events/juce_events.cpp"
    "$JUCE/modules/juce_audio_basics/juce_audio_basics.cpp"
    "$JUCE/modules/juce_audio_formats/juce_audio_formats.cpp"
    "$JUCE/modules/juce_dsp/juce_dsp.cpp"
    "$ROOT/src/core/Log.cpp"
    "$ROOT/src/core/AudioIO.cpp"
    "$ROOT/src/core/Loudness.cpp"
    "$ROOT/src/core/analysis/PitchDetector.cpp"
    "$ROOT/src/core/analysis/KeyDetector.cpp"
    "$ROOT/src/core/analysis/TempoDetector.cpp"
    "$ROOT/src/core/analysis/StructureDetector.cpp"
    "$ROOT/src/core/analysis/VoiceActivity.cpp"
    "$ROOT/src/core/analysis/SpectrumAnalyzer.cpp"
    "$ROOT/src/core/analysis/ContentClassifier.cpp"
    "$ROOT/src/core/dsp/PitchShifter.cpp"
    "$ROOT/src/core/dsp/PitchCorrector.cpp"
    "$ROOT/src/core/dsp/Processors.cpp"
    "$ROOT/src/core/dsp/TimingCorrector.cpp"
    "$ROOT/src/core/dsp/VocalChain.cpp"
    "$ROOT/src/core/dsp/ProblemAnalyzer.cpp"
    "$ROOT/src/core/dsp/Denoiser.cpp"
    "$ROOT/src/core/dsp/Leveler.cpp"
    "$ROOT/src/core/dsp/TrackRepair.cpp"
    "$ROOT/src/core/dsp/BleedRemover.cpp"
    "$ROOT/src/core/dsp/MasterChain.cpp"
    "$ROOT/src/core/style/StyleProfiles.cpp"
    "$ROOT/src/core/mix/AutoMixer.cpp"
    "$ROOT/src/tests/TestSignals.cpp"
    "$ROOT/web/api.cpp"
)

# Compilation en parallèle, objets mis en cache par date. Un en-tête du projet plus récent qu'un objet force sa
# recompilation (sinon des objets compilés avec deux versions d'une même structure de réglages se mélangent : valeurs
# fausses, constaté au build 89 en local).
NEWEST_HEADER="$(find "$ROOT/src" "$ROOT/web" -name '*.h' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
OBJS=()
PIDS=()
for u in "${UNITS[@]}"; do
    o="$BUILD/obj/$(echo "$u" | sed 's#[/ ]#_#g').o"
    OBJS+=("$o")
    if [ ! -f "$o" ] || [ "$u" -nt "$o" ] || [ "$HERE/build-wasm.sh" -nt "$o" ] || { [ -n "$NEWEST_HEADER" ] && [ "$NEWEST_HEADER" -nt "$o" ]; }; then
        echo "[wasm] compile $(basename "$u")"
        em++ "${CXXFLAGS[@]}" -c "$u" -o "$o" &
        PIDS+=($!)
        if [ "${#PIDS[@]}" -ge "$JOBS" ]; then
            wait "${PIDS[0]}"; PIDS=("${PIDS[@]:1}")
        fi
    fi
done
for p in "${PIDS[@]:-}"; do [ -n "$p" ] && wait "$p"; done

echo "[wasm] édition de liens"
em++ -O2 "${OBJS[@]}" -o "$OUT/studiovoix.js" \
    -s WASM=1 -s MODULARIZE=1 -s EXPORT_ES6=1 -s EXPORT_NAME=createStudioVoix \
    -s ENVIRONMENT=web,worker -s ALLOW_MEMORY_GROWTH=1 -s INITIAL_MEMORY=134217728 -s MAXIMUM_MEMORY=2147483648 \
    -s TOTAL_STACK=4194304 -s FILESYSTEM=0 \
    -s EXPORTED_FUNCTIONS='["_sv_version","_sv_styles","_sv_analyze_instru","_sv_set_context","_sv_process_voice","_sv_mix","_sv_clean_take","_sv_demo_instru","_sv_demo_voice","_sv_balance_begin","_sv_balance_add","_sv_balance_end","_sv_limit","_sv_roles","_sv_out_left","_sv_out_right","_sv_out_frames","_sv_out_release","_sv_alloc","_sv_free","_malloc","_free"]' \
    -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","UTF8ToString","HEAPF32"]'
ls -l "$OUT/studiovoix.js" "$OUT/studiovoix.wasm"
echo "[wasm] OK"
