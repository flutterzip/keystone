"""Draws Keystone's app icon and logo from code.

The mark is an arch of cut stones over a doorway, locked by a brass
keystone. `KeystoneMark` in lib/widgets/keystone_mark.dart paints the same
geometry; keep the two in step.

    python3 tool/make_mark.py && python3 tool/make_icons.py

The colours are read from Palette.light in lib/config/palette.dart, so the
icon follows the app's palette. Requires Pillow.
"""
import math
import re

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def palette(mode="light"):
    src = open("lib/config/palette.dart").read()
    block = src[src.index(f"static const {mode} = Palette("):]
    block = block[: block.index(");\n")]
    out = {}
    for name, hexa in re.findall(r"(\w+): Color\(0x([0-9A-Fa-f]{8})\)", block):
        out[name] = tuple(int(hexa[i:i + 2], 16) for i in (2, 4, 6))
    return out


P = palette()
GROUND, GROUND_DEEP = P["primary"], P["keyCard"]
STONE, KEY = P["paper"], P["accent"]
SS = 4

# The mark on a unit square. Shared with MarkGeometry.
CX, CY = 0.5, 0.535
OUTER, INNER = 0.40, 0.215
FOOT, GAP = 0.93, 0.024
KEY_RISE, KEY_HANG = 0.055, 0.028
PIER_MID = (CY + FOOT) / 2


def polar(r, deg):
    return (CX + r * math.cos(math.radians(deg)), CY - r * math.sin(math.radians(deg)))


def wedge(a, b, r0, r1):
    trim = math.degrees(GAP / 2 / ((r0 + r1) / 2))
    a, b = a - trim, b + trim
    n = 40
    return [polar(r1, a + (b - a) * i / n) for i in range(n + 1)] + [polar(r0, a + (b - a) * i / n) for i in range(n, -1, -1)]


def block(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def stones():
    out = []
    for left in (True, False):
        x0, x1 = (CX - OUTER, CX - INNER) if left else (CX + INNER, CX + OUTER)
        out.append((block(x0, PIER_MID + GAP / 2, x1, FOOT), False))
        out.append((block(x0, CY + GAP / 2, x1, PIER_MID - GAP / 2), False))
        out.append((wedge(180, 144, INNER, OUTER) if left else wedge(36, 0, INNER, OUTER), False))
        out.append((wedge(144, 108, INNER, OUTER) if left else wedge(72, 36, INNER, OUTER), False))
    out.append((wedge(108, 72, INNER - KEY_HANG, OUTER + KEY_RISE), True))
    return out


def ground(size):
    """Evergreen, lit from the upper left, falling to a deep corner."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            lit = max(0.0, 1 - math.hypot(x / size - 0.26, y / size - 0.2) / 0.9)
            px[x, y] = tuple(
                int(min(255, GROUND[i] + (GROUND_DEEP[i] - GROUND[i]) * t ** 1.2 + 26 * lit ** 2)) for i in range(3))
    return img


def compose(size, with_ground=True, stone=STONE, key=KEY, scale=0.74):
    big = size * SS
    img = ground(size).resize((big, big), Image.BICUBIC).convert("RGBA") if with_ground else Image.new("RGBA", (big, big), (0, 0, 0, 0))

    def place(p):  # the mark sits inside the icon with room round it
        k = scale if with_ground else 1.0
        return ((p[0] - 0.5) * k + 0.5) * big, ((p[1] - 0.5) * k + 0.5 + (0.0 if not with_ground else 0.005)) * big

    stone_mask = Image.new("L", (big, big), 0)
    key_mask = Image.new("L", (big, big), 0)
    for poly, is_key in stones():
        ImageDraw.Draw(key_mask if is_key else stone_mask).polygon([place(p) for p in poly], fill=255)
    if with_ground:
        shadow = ImageChops.lighter(stone_mask, key_mask).filter(ImageFilter.GaussianBlur(big * 0.02))
        shadow = ImageChops.offset(shadow, 0, int(big * 0.014)).point(lambda v: int(v * 0.55))
        img = Image.alpha_composite(img, Image.merge("RGBA", [Image.new("L", (big, big), 4)] * 3 + [shadow]))
    for mask, colour in ((stone_mask, stone), (key_mask, key)):
        layer = Image.new("RGBA", (big, big), colour + (0,))
        layer.putalpha(mask)
        img = Image.alpha_composite(img, layer)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    compose(1024).convert("RGB").save("assets/brand/icon_1024.png")
    compose(1024, with_ground=False, stone=P["ink"]).save("assets/brand/mark.png")
    print("assets/brand/icon_1024.png, assets/brand/mark.png")
