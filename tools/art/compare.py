"""Puts the concept art next to our renders: compare.py RENDER_DIR OUT.png Animal..."""
import sys
from PIL import Image, ImageDraw, ImageFont

CELLS = {  # concept sheet cell boxes (docs/art/animals-concept.png, 1536x1024)
    "Chicken": (0, 0, 384, 338), "Duck": (384, 0, 768, 338), "Dog": (768, 0, 1152, 338), "Cat": (1152, 0, 1536, 338),
    "Cow": (0, 338, 384, 676), "Goat": (384, 338, 768, 676), "Sheep": (768, 338, 1152, 676), "Rabbit": (1152, 338, 1536, 676),
    "Horse": (0, 676, 384, 1024), "Bee": (384, 676, 768, 1024), "Beehive": (768, 676, 1152, 1024), "Fox": (1152, 676, 1536, 1024),
}
src, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
concept = Image.open("docs/art/animals-concept.png").convert("RGB")
H = 420
rows = []
for n in names:
    c = concept.crop(CELLS[n]).resize((int(384 * H / 338), H))
    a = Image.open(f"{src}/{n}_front.png").convert("RGB").resize((H, H))
    b = Image.open(f"{src}/{n}_side.png").convert("RGB").resize((H, H))
    row = Image.new("RGB", (c.width + 2 * H, H), (60, 60, 60))
    row.paste(c, (0, 0)); row.paste(a, (c.width, 0)); row.paste(b, (c.width + H, 0))
    rows.append(row)
sheet = Image.new("RGB", (rows[0].width, H * len(rows)))
for i, r in enumerate(rows):
    sheet.paste(r, (0, i * H))
d = ImageDraw.Draw(sheet)
try:
    f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except Exception:
    f = ImageFont.load_default()
for i, n in enumerate(names):
    d.text((rows[0].width - 2 * H + 10, i * H + 10), "ours", fill=(255, 255, 255), font=f)
sheet.save(out)
