"""Generate web/PWA icons and AppBar mark from Dacha roof master."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
roof_path = root / 'assets' / 'brand' / 'dacha_roof.jpg'
if not roof_path.exists():
    raise SystemExit(f'missing roof master: {roof_path}')

roof = Image.open(roof_path).convert('RGBA')
# Crop to roof content if master is wide; keep square-ish subject centered.
bw, bh = roof.size
side = min(bw, bh)
left = (bw - side) // 2
top = max(0, (bh - side) // 2 - side // 10)
roof = roof.crop((left, top, left + side, top + side))

calendar_blue = (8, 105, 186, 255)  # #0869BA


def fit_square(
    img: Image.Image,
    size: int,
    bg: tuple[int, int, int, int] = (255, 255, 255, 255),
    pad_ratio: float = 0.04,
) -> Image.Image:
    canvas = Image.new('RGBA', (size, size), bg)
    max_side = int(size * (1 - 2 * pad_ratio))
    ratio = min(max_side / img.width, max_side / img.height)
    w = max(1, int(img.width * ratio))
    h = max(1, int(img.height * ratio))
    resized = img.resize((w, h), Image.Resampling.LANCZOS)
    canvas.paste(resized, ((size - w) // 2, (size - h) // 2), resized)
    return canvas


web = root / 'web'
icons = web / 'icons'
brand_assets = root / 'assets' / 'brand'
icons.mkdir(parents=True, exist_ok=True)
(web / 'brand').mkdir(parents=True, exist_ok=True)
brand_assets.mkdir(parents=True, exist_ok=True)

# AppBar / drawer / footer mark = same roof as tab icons.
fit_square(roof, 256, pad_ratio=0.04).save(brand_assets / 'logo_mark.png')

# Tab / PWA: roof on white, small pad → larger visual in tab bar.
fit_square(roof, 192, pad_ratio=0.04).save(icons / 'Icon-192.png')
fit_square(roof, 512, pad_ratio=0.04).save(icons / 'Icon-512.png')
fit_square(roof, 192, bg=calendar_blue, pad_ratio=0.12).save(
    icons / 'Icon-maskable-192.png'
)
fit_square(roof, 512, bg=calendar_blue, pad_ratio=0.12).save(
    icons / 'Icon-maskable-512.png'
)
fit_square(roof, 180, pad_ratio=0.05).save(icons / 'Icon-180.png')
fit_square(roof, 96, pad_ratio=0.02).save(web / 'favicon.png')

# Keep OG with roof mark on brand green for share cards.
og = Image.new('RGBA', (1200, 630), (54, 103, 77, 255))
mark = fit_square(roof, 360, pad_ratio=0.06)
og.paste(mark, ((1200 - 360) // 2, (630 - 360) // 2), mark)
og.convert('RGB').save(web / 'brand' / 'og-default.png')
print('icons + logo_mark generated from dacha_roof.jpg')
