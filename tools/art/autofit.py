"""Tunes a model's proportions to match its reference silhouettes.

    python -I tools/art/autofit.py Chicken docs/art/ref/chicken-turnaround.png OUT.json

Coordinate search over the model's parameter dict (models.<NAME> in upper
case): each parameter is nudged up and down, kept if the mean overlap of the
front, side and top views improves, and the steps shrink until nothing helps.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import models  # noqa: E402
from fit import compare, load_refs  # noqa: E402

name, ref, out = sys.argv[1], sys.argv[2], sys.argv[3]
defaults = getattr(models, name.upper())
build = models.MODELS[name]
refs, pps = load_refs(ref)
WEIGHTS = {"front": 1.0, "side": 1.5, "top": 0.7}


def score(p):
    res = compare(build(p), refs, pps, voxel=0.025, which=tuple(WEIGHTS))
    return sum(WEIGHTS[v] * res[v][0] for v in WEIGHTS) / sum(WEIGHTS.values())


params = dict(defaults)
# parameters set by hand that the search must not touch (comma separated)
FROZEN = set(filter(None, os.environ.get("FREEZE", "").split(",")))
best = score(params)
print(f"start {best:.4f}")
steps = {k: (0.06 if abs(v) < 5 else 6.0) for k, v in params.items()}
for rnd in range(6):
    improved = False
    for k in params:
        if k in FROZEN:
            continue
        for sign in (1, -1):
            trial = dict(params)
            trial[k] = params[k] + sign * steps[k]
            if k.endswith(("_r", "_s")) or k in ("comb",):
                trial[k] = max(0.5, min(1.6, trial[k]))
            s = score(trial)
            if s > best + 1e-4:
                params, best, improved = trial, s, True
                print(f"  round {rnd} {k} -> {params[k]:.3f}  score {best:.4f}", flush=True)
                break
    if not improved:
        steps = {k: v / 2 for k, v in steps.items()}
print(f"final {best:.4f}")
json.dump({k: round(v, 4) for k, v in params.items()}, open(out, "w"), indent=1)
