"""Compares a model's silhouettes with a reference turnaround sheet.

    python -I tools/art/fit.py Chicken docs/art/ref/chicken-turnaround.png OUT.png

Prints the overlap (IoU) per view and writes an overlay: reference only in
red, model only in blue, both in grey. The reference is taken to be
REF_HEIGHT studs tall (default 2.4).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from silhouette import views  # noqa: E402

VIEWS = ("front", "side", "back", "top")


def load_refs(path):
    refs = views(path)
    px_per_stud = refs[0]["mask"].shape[0] / float(os.environ.get("REF_HEIGHT", "2.4"))
    return refs, px_per_stud


def compare(model, refs, px_per_stud, voxel=0.015, which=VIEWS):
    """Returns {view: (iou, overlay image)}."""
    out = {}
    for view in which:
        r = refs[VIEWS.index(view)]["mask"]
        ours = model.silhouette(view, voxel)
        scale = px_per_stud * voxel
        h, w = max(1, int(round(ours.shape[0] * scale))), max(1, int(round(ours.shape[1] * scale)))
        ours = np.asarray(Image.fromarray(ours.astype(np.uint8) * 255).resize((w, h))) > 127
        H, W = max(h, r.shape[0]) + 20, max(w, r.shape[1]) + 20
        a = np.zeros((H, W), bool)
        b = np.zeros((H, W), bool)
        if view == "top":  # centre both ways
            a[(H - r.shape[0]) // 2:(H - r.shape[0]) // 2 + r.shape[0], (W - r.shape[1]) // 2:(W - r.shape[1]) // 2 + r.shape[1]] = r
            b[(H - h) // 2:(H - h) // 2 + h, (W - w) // 2:(W - w) // 2 + w] = ours
        else:  # feet on the same line, centred across
            a[H - 10 - r.shape[0]:H - 10, (W - r.shape[1]) // 2:(W - r.shape[1]) // 2 + r.shape[1]] = r
            b[H - 10 - h:H - 10, (W - w) // 2:(W - w) // 2 + w] = ours
        iou = (a & b).sum() / max(1, (a | b).sum())
        img = np.full((H, W, 3), 255, np.uint8)
        img[a & ~b] = (230, 60, 60)
        img[b & ~a] = (60, 90, 230)
        img[a & b] = (170, 170, 170)
        out[view] = (iou, img)
    return out


def save_overlay(results, path):
    tiles = [img for _, img in results.values()]
    Ht = max(t.shape[0] for t in tiles)
    sheet = np.full((Ht, sum(t.shape[1] for t in tiles), 3), 255, np.uint8)
    x = 0
    for t in tiles:
        sheet[Ht - t.shape[0]:, x:x + t.shape[1]] = t
        x += t.shape[1]
    Image.fromarray(sheet).save(path)


if __name__ == "__main__":
    from models import MODELS

    name, ref, out = sys.argv[1], sys.argv[2], sys.argv[3]
    refs, pps = load_refs(ref)
    res = compare(MODELS[name](), refs, pps)
    for v, (iou, _) in res.items():
        print(f"{v:5s} IoU {iou:.3f}")
    save_overlay(res, out)
