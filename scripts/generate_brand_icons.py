"""Generate web/PWA icons from Dacha brand masters."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
src = root / 'docs' / 'mi-mockups' / '_open-latest'
kvadrat = Image.open(src / 'Dacha_internet_kvadrat.png').convert('RGBA')
kolo = Image.open(src / 'Dacha_internet_kolo.png').convert('RGBA')
znak = Image.open(src / 'DACHA_znak_baza.png').convert('RGBA')


def fit_square(
    img: Image.Image,
    size: int,
    bg: tuple[int, int, int, int] = (255, 255, 255, 0),
    pad_ratio: float = 0.08,
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
icons.mkdir(parents=True, exist_ok=True)
(web / 'brand').mkdir(parents=True, exist_ok=True)
(root / 'assets' / 'brand').mkdir(parents=True, exist_ok=True)

fit_square(kvadrat, 192, bg=(255, 255, 255, 255)).save(icons / 'Icon-192.png')
fit_square(kvadrat, 512, bg=(255, 255, 255, 255)).save(icons / 'Icon-512.png')
fit_square(kolo, 192, bg=(54, 103, 77, 255), pad_ratio=0.12).save(
    icons / 'Icon-maskable-192.png'
)
fit_square(kolo, 512, bg=(54, 103, 77, 255), pad_ratio=0.12).save(
    icons / 'Icon-maskable-512.png'
)
fit_square(kolo, 180, bg=(255, 255, 255, 255), pad_ratio=0.1).save(
    icons / 'Icon-180.png'
)
fit_square(kvadrat, 32, bg=(255, 255, 255, 255)).save(web / 'favicon.png')
fit_square(kvadrat, 256, bg=(0, 0, 0, 0), pad_ratio=0.02).save(
    root / 'assets' / 'brand' / 'logo_mark.png'
)

zw, zh = 640, 160
header = Image.new('RGBA', (zw, zh), (0, 0, 0, 0))
ratio = min((zw * 0.95) / znak.width, (zh * 0.9) / znak.height)
nw, nh = int(znak.width * ratio), int(znak.height * ratio)
rz = znak.resize((nw, nh), Image.Resampling.LANCZOS)
header.paste(rz, ((zw - nw) // 2, (zh - nh) // 2), rz)
header.save(root / 'assets' / 'brand' / 'logo_header.png')

og = Image.new('RGBA', (1200, 630), (54, 103, 77, 255))
mark = fit_square(kvadrat, 360, bg=(255, 255, 255, 255), pad_ratio=0.1)
og.paste(mark, ((1200 - 360) // 2, (630 - 360) // 2), mark)
og.convert('RGB').save(web / 'brand' / 'og-default.png')
print('icons generated')
