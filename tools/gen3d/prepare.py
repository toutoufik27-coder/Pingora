"""Turns concept images into clean inputs for TRELLIS.2.

    python prepare.py IN_DIR OUT_DIR [--split] [--view N] [--size 1024]

For every image in IN_DIR it removes the plain light background (flood fill
from the borders, so white parts inside the object are kept), crops to the
object, pads it to a square and saves an RGBA PNG. Because the PNG already has
transparency, TRELLIS.2 skips its own background-removal model.

--split   the image is a sheet with several views in a row (like our
          turnaround sheets): each view is saved as NAME_v0.png, NAME_v1.png...
--view N  with --split, keep only view N (0 = first). For TRELLIS.2 a
          three-quarter view works best; a front view is the next best.

Only needs Pillow, numpy and scipy.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

EXTS = {".png", ".jpg", ".jpeg", ".webp"}


def object_mask(rgb: np.ndarray, tol: int) -> np.ndarray:
    """True on the object: everything not connected to the border through
    near-background pixels."""
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(border, axis=0)
    near_bg = np.abs(rgb.astype(int) - bg).max(axis=2) <= tol
    labels, _ = ndimage.label(near_bg)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, edge_labels[edge_labels > 0])
    mask = ~background
    mask = ndimage.binary_opening(mask, iterations=1)
    mask = ndimage.binary_fill_holes(mask)
    # drop specks: keep components bigger than 0.2% of the largest
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.where(sizes >= sizes.max() * 0.002)[0])
        mask = keep
    return mask


def soft_alpha(mask: np.ndarray) -> np.ndarray:
    """Slightly feathered edge so the outline is not jagged."""
    a = ndimage.gaussian_filter(mask.astype(np.float32), 0.8)
    return (np.clip(a * 1.2, 0, 1) * 255).astype(np.uint8)


def to_square(rgba: Image.Image, size: int, margin: float = 0.06) -> Image.Image:
    bbox = rgba.getbbox()
    rgba = rgba.crop(bbox)
    side = int(max(rgba.size) * (1 + 2 * margin))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def split_views(mask: np.ndarray, min_gap: int = 8, min_width: int = 40):
    """Column ranges of separate objects laid out left to right."""
    cols = mask.any(axis=0)
    ranges, start, gap = [], None, 0
    for x, c in enumerate(list(cols) + [False] * (min_gap + 1)):
        if c:
            if start is None:
                start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap > min_gap:
                end = x - gap + 1
                if end - start >= min_width:
                    ranges.append((start, end))
                start, gap = None, 0
    return ranges


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--split", action="store_true")
    ap.add_argument("--view", type=int, default=None)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--tol", type=int, default=12, help="how close to the background colour counts as background")
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in Path(a.inp).iterdir() if p.suffix.lower() in EXTS)
    if not files:
        raise SystemExit(f"no images in {a.inp}")
    for path in files:
        im = Image.open(path).convert("RGB")
        rgb = np.asarray(im)
        mask = object_mask(rgb, a.tol)
        alpha = soft_alpha(mask)
        rgba = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
        if a.split:
            views = split_views(mask)
            picks = [a.view] if a.view is not None else range(len(views))
            for i in picks:
                if i >= len(views):
                    print(f"  {path.name}: only {len(views)} views, no view {i}")
                    continue
                x0, x1 = views[i]
                part = rgba.crop((x0, 0, x1, rgba.height))
                name = f"{path.stem}_v{i}.png" if a.view is None else f"{path.stem}.png"
                to_square(part, a.size).save(out / name)
                print(f"  {path.name} view {i} -> {name}")
        else:
            to_square(rgba, a.size).save(out / f"{path.stem}.png")
            print(f"  {path.name} -> {path.stem}.png")


if __name__ == "__main__":
    main()
