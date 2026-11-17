#!/usr/bin/env bash
# Mesures (1 fil) + tableau.  measure.sh <cand1,cand2,…>
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
cd /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B2
CANDS="$1" /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/venv/bin/python -I scripts/measure.py /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/items /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/out /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B2/out /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B2/results >> logs/measure.log 2>&1
/tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/venv/bin/python -I scripts/report.py results /tmp/claude-0/-home-user-rebuild-project/954cdb61-bb44-5f2f-8fc3-d4876ade99a0/scratchpad/B/results > logs/report_B2.txt 2>&1
