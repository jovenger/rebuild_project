#!/usr/bin/env bash
# Rejoue tout le banc (dossier de travail B). Les étapes déjà faites sont sautées (sorties gardées dans out/ et results/).
# Prérequis déjà en place : bench/node_modules (onnxruntime-node 1.22.0, installé avec --ignore-scripts), venv/ (numpy
# 2.2.6, scipy 1.15.3, soundfile 0.13.1), frozen/ (copies de isolate.js et resample.js), models/ (3 modèles d'évaluation),
# dl/musdb7/MUSDB18-7-STEMS.zip. Limite : 3 fils (THREADS pour le modèle ; Python en 1 fil).
set -euo pipefail
B="$(cd "$(dirname "$0")/.." && pwd)"; S="$(dirname "$B")"; PY="$B/venv/bin/python -I"; cd "$B/bench"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
# 1) fidélité : doit rendre 16,25 / 6,28 dB (48 kHz) — référence du produit 16,3 / 6,3
node fidelity.mjs "$S/fix/sep/48/song.wav" "$S/fix/sep/48/truth_instru.wav" fid48
# 2) extraits à vérité connue (MUSDB18-7 décompressé dans dl/musdb7/x) + chanson d'essai du produit dans items/p_parle
[ -d "$B/dl/musdb7/x" ] || unzip -q -o "$B/dl/musdb7/MUSDB18-7-STEMS.zip" -d "$B/dl/musdb7/x"
[ -f "$B/items/items.json" ] || $PY make_items.py "$B/dl/musdb7/x" "$B/items"
# 3) calculs du modèle (lourd) : ligne de base, signe inversé, décalage, recouvrement, Inst HQ 3, puis Kim Vocal 2 et Inst HQ 4
node mkjobs.mjs > jobs.json && THREADS=${THREADS:-3} node sep.mjs jobs.json
node mkjobs2.mjs > jobs2.json && THREADS=${THREADS:-3} node sep.mjs jobs2.json
# 4) prototypes JavaScript dans la boucle par morceaux (règles sur la sortie brute, puis sur le spectre cohérent)
ITEMS=$(ls -d "$B"/items/*/ | xargs -n1 basename | tr '\n' ' ')
THREADS=${THREADS:-3} node run_post.mjs borne,seuil6k,seuil6k_borne,borne_bande,borne_bande1 $ITEMS
CONSISTENT=1 THREADS=${THREADS:-3} node run_post.mjs borne,seuil6k_borne,borne_bande,borne_bande1 $ITEMS
CONSISTENT=1 THREADS=${THREADS:-3} TAG=fid48 node run_post.mjs borne,borne_bande "$S/fix/sep/48/song.wav"
# 5) contrôle des mesures sur cas fabriqués, plancher de la mesure « restes de voix », mesures, tableaux
$PY selftest.py "$B/items" t_fem1
$PY run_bench.py "$B/items" "$B/out" "$B/results"
$PY floor.py "$B/items" "$B/out" "$B/results"
$PY report.py "$B/results" > "$B/logs/report_final.txt"
$PY diag_bands.py "$B/items" "$B/out" p_parle t_fem1 m_fem1
$PY diag_compo.py "$B/items" "$B/out"
echo "tableaux : $B/logs/report_final.txt"
