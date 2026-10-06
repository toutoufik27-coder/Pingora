"""Reference turnaround (front, side) next to our orthographic renders:
compare_ref.py RENDER_DIR Animal REF_TURNAROUND OUT.png"""
import sys
from PIL import Image
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from silhouette import views

src, name, ref, out = sys.argv[1:5]
vs = views(ref)
full = Image.open(ref).convert("RGB")
H = 520
tiles = []
for i, view in ((0, "front"), (1, "side")):
    v = vs[i]
    pad = 20
    crop = full.crop((v["x0"] - pad, max(0, v["y0"] - pad), v["x1"] + pad, v["y1"] + pad))
    tiles.append(crop.resize((int(crop.width * H / crop.height), H)))
    ours = Image.open(f"{src}/{name}_ortho_{view}.png").convert("RGB")
    # trim to the same framing: the render is centred with 15% margin
    tiles.append(ours.resize((H, H)))
W = sum(t.width for t in tiles)
sheet = Image.new("RGB", (W, H), (255, 255, 255))
x = 0
for t in tiles:
    sheet.paste(t, (x, 0))
    x += t.width
sheet.save(out)
