#!/usr/bin/env bash
# Lance une commande et la tue si sa mémoire résidente dépasse LIMIT_MB (défaut 8000) : protège la machine partagée.
LIMIT_MB=${LIMIT_MB:-8000}
"$@" & pid=$!
peak=0
while kill -0 $pid 2>/dev/null; do
  rss=$(awk '/VmRSS/{print int($2/1024)}' /proc/$pid/status 2>/dev/null || echo 0)
  [ "${rss:-0}" -gt "$peak" ] && peak=$rss
  if [ "${rss:-0}" -gt "$LIMIT_MB" ]; then echo "$(date -u +%FT%TZ) [error] guard : mémoire $rss Mo > $LIMIT_MB Mo, arrêt de $pid" >&2; kill -9 $pid; wait $pid 2>/dev/null; echo "guard : mémoire max vue $peak Mo" >&2; exit 137; fi
  sleep 1
done
wait $pid; rc=$?
echo "guard : mémoire max vue $peak Mo, code $rc" >&2
exit $rc
