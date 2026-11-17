#!/usr/bin/env bash
# File d'attente : exécute une à une les lignes de queue.txt (un seul calcul lourd à la fois). Ligne « STOP » = fin.
B2="$(cd "$(dirname "$0")/.." && pwd)"; cd "$B2"; Q="$B2/queue.txt"; touch "$Q"; n=0
while true; do
  total=$(wc -l < "$Q")
  if [ "$n" -lt "$total" ]; then
    n=$((n+1)); cmd=$(sed -n "${n}p" "$Q")
    [ "$cmd" = "STOP" ] && { echo "$(date -u +%FT%TZ) [info] queue : STOP" >> logs/queue.log; exit 0; }
    echo "$(date -u +%FT%TZ) [info] queue : début #$n : $cmd" >> logs/queue.log
    bash -c "$cmd"; rc=$?
    echo "$(date -u +%FT%TZ) [info] queue : fin #$n (code $rc)" >> logs/queue.log
  else sleep 2; fi
done
