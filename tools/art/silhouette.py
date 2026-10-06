"""Splits a turnaround sheet (white background, views in a row) into view masks
and prints their sizes: silhouette.py IMAGE [OUT_PREFIX]"""
import sys
import numpy as np
from PIL import Image

def views(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(int)
    fg = im.min(axis=2) < 246  # not background white
    try:  # white animals on white: fill the inside of each outline
        from scipy.ndimage import binary_closing, binary_fill_holes
        fg = binary_fill_holes(binary_closing(fg, iterations=2))
    except ImportError:
        pass
    cols = fg.any(axis=0)
    out, start = [], None
    for x, c in enumerate(list(cols) + [False]):
        if c and start is None:
            start = x
        elif not c and start is not None:
            if x - start > 40:
                out.append((start, x))
            start = None
    res = []
    for a, b in out:
        sub = fg[:, a:b]
        rows = np.where(sub.any(axis=1))[0]
        res.append(dict(x0=a, x1=b, y0=int(rows[0]), y1=int(rows[-1]) + 1, mask=sub[rows[0]:rows[-1] + 1], rgb=im[rows[0]:rows[-1] + 1, a:b]))
    return res

if __name__ == "__main__":
    vs = views(sys.argv[1])
    for i, v in enumerate(vs):
        h, w = v["mask"].shape
        print(f"view {i}: x {v['x0']}-{v['x1']} y {v['y0']}-{v['y1']}  size {w}x{h}")
        if len(sys.argv) > 2:
            Image.fromarray((v["mask"] * 255).astype(np.uint8)).save(f"{sys.argv[2]}_{i}.png")
