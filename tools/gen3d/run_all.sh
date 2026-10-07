#!/usr/bin/env bash
# Runs the whole pipeline on both RTX cards (inside Ubuntu/WSL2):
#
#   bash run_all.sh CONCEPTS_DIR WORK_DIR [extra generate.py options]
#
#   1. prepare.py   concept images -> clean RGBA inputs   (WORK_DIR/inputs)
#   2. generate.py  one worker per GPU                     (WORK_DIR/raw)
# Then pick the best seed of each model and clean it for Roblox with
# roblox_prep.py (Blender), see README.md.
#
# Sheets with several views in a row: set SPLIT_VIEW to the view to use,
# e.g. SPLIT_VIEW=1 for the side view (0 = first view).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONCEPTS="$1"
WORK="$2"
shift 2

set +u  # conda's scripts use unset variables
# shellcheck disable=SC1091
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate trellis2

mkdir -p "$WORK"
if [ -n "${SPLIT_VIEW:-}" ]; then
  python "$HERE/prepare.py" "$CONCEPTS" "$WORK/inputs" --split --view "$SPLIT_VIEW"
else
  python "$HERE/prepare.py" "$CONCEPTS" "$WORK/inputs"
fi

GPUS=$(nvidia-smi --query-gpu=index --format=csv,noheader | wc -l)
echo "== $GPUS GPU(s) =="
pids=()
for ((i = 0; i < GPUS; i++)); do
  CUDA_VISIBLE_DEVICES=$i python "$HERE/generate.py" "$WORK/inputs" "$WORK/raw" \
    --worker "$i" --workers "$GPUS" "$@" > "$WORK/gpu$i.log" 2>&1 &
  pids+=($!)
  echo "worker $i started (log: $WORK/gpu$i.log)"
done
for p in "${pids[@]}"; do wait "$p"; done
echo "== done: models in $WORK/raw =="
