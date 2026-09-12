#!/usr/bin/env python3
"""Status and action plates for busy, presence, and common GTK gaps.

Phosphor busy glyph is a segmented ring that reads without animation.
Colors follow CANON (#1AFF6B on inset). Shape carries rad/amber meaning.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

PHOS = (0x1A, 0xFF, 0x6B, 255)
INSET = (0x12, 0x16, 0x12, 255)
BEVEL_HI = (0x2A, 0x33, 0x2A, 255)
BEVEL_LO = (0x05, 0x06, 0x05, 255)
STEEL = (0x8A, 0x8F, 0x86, 255)
RAD = (0xC4, 0x1E, 0x3A, 255)
AMBER = (0xFF, 0xB0, 0x00, 255)
PHOS_DIM = (0x0E, 0x8A, 0x3A, 255)
SIZES = (16, 24, 32, 48)
ROOT = Path(__file__).resolve().parent


def plate(size: int):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, size - 1, size - 1], fill=INSET)
    d.line([(0, 0), (size - 1, 0)], fill=BEVEL_HI)
    d.line([(0, 0), (0, size - 1)], fill=BEVEL_HI)
    d.line([(0, size - 1), (size - 1, size - 1)], fill=BEVEL_LO)
    d.line([(size - 1, 0), (size - 1, size - 1)], fill=BEVEL_LO)
    return im, d


def led(d, size: int, color=PHOS):
    s = 2 if size >= 32 else 1
    d.rectangle([size - 3 - s, 2, size - 3, 2 + s], fill=color)


def sw(size: int) -> int:
    return 2 if size >= 32 else 1


def process_working(size: int):
    im, d = plate(size)
    cx = cy = size / 2
    r = size * 0.32
    segs = 8
    thick = max(2, size // 10)
    for i in range(segs):
        a0 = math.radians(i * (360 / segs) - 90)
        a1 = math.radians((i + 0.65) * (360 / segs) - 90)
        pts = []
        for s in range(5):
            t = a0 + (a1 - a0) * (s / 4)
            pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
        if i < segs // 3:
            color = STEEL
        elif i < 2 * segs // 3:
            color = PHOS_DIM
        else:
            color = PHOS
        d.line(pts, fill=color, width=thick)
    hr = max(1, size // 16)
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=PHOS)
    led(d, size)
    return im


def gtk_execute(size: int):
    im, d = plate(size)
    p = max(4, size // 6)
    d.polygon([(p, p), (size - p, size // 2), (p, size - p)], fill=PHOS)
    led(d, size)
    return im


def dialog_password(size: int):
    im, d = plate(size)
    p = max(4, size // 7)
    d.rectangle([p + 1, size // 2 - 1, size - p - 2, size - p], fill=PHOS)
    d.rectangle([p + 3, size // 2 + 1, size - p - 4, size - p - 2], fill=INSET)
    d.arc([p + 3, p, size - p - 4, size // 2 + 2], 0, 180, fill=PHOS, width=sw(size))
    led(d, size)
    return im


def user_dot(size: int, fill):
    im, d = plate(size)
    mid = size // 2
    r = max(3, size // 6)
    d.ellipse([mid - r, max(3, size // 6) - 1, mid + r, max(3, size // 6) - 1 + 2 * r], fill=STEEL)
    d.ellipse([mid - r - 2, mid + r - 1, mid + r + 2, size - max(3, size // 8)], fill=STEEL)
    led(d, size, fill)
    return im


def emblem_sync(size: int):
    im, d = plate(size)
    w = sw(size)
    p = max(4, size // 6)
    d.arc([p, p, size - p, size - p], 40, 200, fill=PHOS, width=w)
    d.arc([p, p, size - p, size - p], 220, 20, fill=PHOS, width=w)
    led(d, size)
    return im


def playlist_repeat(size: int):
    im, d = plate(size)
    w = sw(size)
    p = max(4, size // 6)
    d.arc([p, p + 2, size - p, size - p], 20, 340, fill=PHOS, width=w)
    d.polygon([(size - p - 1, p + 2), (size - p + 3, p + 6), (size - p - 5, p + 6)], fill=PHOS)
    led(d, size)
    return im


def playlist_shuffle(size: int):
    im, d = plate(size)
    w = sw(size)
    p = max(4, size // 6)
    d.line([(p, size // 3), (size - p, 2 * size // 3)], fill=PHOS, width=w)
    d.line([(p, 2 * size // 3), (size - p, size // 3)], fill=PHOS, width=w)
    led(d, size)
    return im


ITEMS = [
    ("status", "process-working", process_working),
    ("status", "process-working-symbolic", process_working),
    ("status", "image-loading", process_working),
    ("status", "content-loading", process_working),
    ("actions", "gtk-execute", gtk_execute),
    ("actions", "system-run", gtk_execute),
    ("status", "dialog-password", dialog_password),
    ("status", "user-available", lambda s: user_dot(s, PHOS)),
    ("status", "user-away", lambda s: user_dot(s, AMBER)),
    ("status", "user-busy", lambda s: user_dot(s, RAD)),
    ("status", "user-offline", lambda s: user_dot(s, STEEL)),
    ("emblems", "emblem-synchronizing", emblem_sync),
    ("actions", "media-playlist-repeat", playlist_repeat),
    ("actions", "media-playlist-shuffle", playlist_shuffle),
]


def write_tree(root: Path) -> int:
    n = 0
    for ctx, name, fn in ITEMS:
        for size in SIZES:
            dest = root / f"{size}x{size}" / ctx
            dest.mkdir(parents=True, exist_ok=True)
            fn(size).save(dest / f"{name}.png")
            n += 1
    return n


def main() -> None:
    n = write_tree(ROOT)
    packaged = ROOT.parents[1] / "icons" / "Vault.OS"
    if packaged.is_dir():
        n += write_tree(packaged)
    print(f"wrote {n} plates under {ROOT}")


if __name__ == "__main__":
    main()
