import sys
from PIL import Image, ImageDraw, ImageFont
d, out = sys.argv[1], sys.argv[2]
names = ["Chicken","Duck","Dog","Cat","Cow","Goat","Sheep","Rabbit","Horse","Bee","Fox"]
W = 480; sheet = Image.new("RGB", (W*4, W*3), (80, 82, 86))
try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
except Exception: font = ImageFont.load_default()
for i, n in enumerate(names):
    im = Image.open(f"{d}/{n}.png").convert("RGB")
    x, y = (i % 4) * W, (i // 4) * W
    sheet.paste(im, (x, y))
    ImageDraw.Draw(sheet).text((x + 16, y + 12), n, fill=(255, 255, 255), font=font)
sheet.save(out)
