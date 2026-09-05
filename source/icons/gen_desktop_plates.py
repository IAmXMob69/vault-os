#!/usr/bin/env python3
"""ICO-06 — desktop plates matching dock stamp. CANON tokens. Size-safe 16–48."""
from pathlib import Path
from PIL import Image, ImageDraw

PHOS = (0x1A, 0xFF, 0x6B, 255)
INSET = (0x12, 0x16, 0x12, 255)
BEVEL_HI = (0x2A, 0x33, 0x2A, 255)
BEVEL_LO = (0x05, 0x06, 0x05, 255)
PANEL = (0x0C, 0x0F, 0x0C, 255)
SIZES = (16, 24, 32, 48)


def plate(size, fill=INSET):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, size - 1, size - 1], fill=fill)
    d.line([(0, 0), (size - 1, 0)], fill=BEVEL_HI)
    d.line([(0, 0), (0, size - 1)], fill=BEVEL_HI)
    d.line([(0, size - 1), (size - 1, size - 1)], fill=BEVEL_LO)
    d.line([(size - 1, 0), (size - 1, size - 1)], fill=BEVEL_LO)
    return im, d


def led(d, size, color=PHOS):
    s = 2 if size >= 32 else 1
    x = size - 3 - s
    y = 2
    d.rectangle([x, y, x + s, y + s], fill=color)


def rect(d, box, fill):
    x0, y0, x1, y1 = box
    if x1 >= x0 and y1 >= y0:
        d.rectangle([x0, y0, x1, y1], fill=fill)


def home(size):
    im, d = plate(size)
    m = size // 2
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    # roof
    d.polygon([(m, p), (size - p, m), (p, m)], fill=PHOS)
    # walls
    rect(d, [p + 1, m, size - p - 2, size - p], PHOS)
    # door well
    dw = max(2, size // 7)
    rect(d, [m - dw // 2, size - p - dw - 1, m + dw // 2, size - p - 1], INSET)
    led(d, size)
    return im


def trash(size, full=False):
    im, d = plate(size)
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    # lid
    rect(d, [p + 1, p + 1, size - p - 2, p + 2], PHOS)
    rect(d, [p + 2, p, size - p - 3, p + 1], PHOS)
    top = p + 3
    # body outline as filled trapezoid
    d.polygon(
        [(p + 1, top), (size - p - 2, top), (size - p - 3, size - p), (p + 2, size - p)],
        fill=PHOS,
    )
    # well
    if size >= 24:
        d.polygon(
            [(p + 3, top + 2), (size - p - 4, top + 2), (size - p - 5, size - p - 2), (p + 4, size - p - 2)],
            fill=INSET,
        )
    if full and size >= 24:
        step = max(3, size // 10)
        for i in range(3):
            x = p + 5 + i * step
            rect(d, [x, top + 3, x + 1, size - p - 3], PHOS)
    led(d, size)
    return im


def desktop(size):
    im, d = plate(size)
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    w = 2 if size >= 32 else 1
    # monitor
    d.rectangle([p, p, size - 1 - p, size - p - 3], outline=PHOS, width=w)
    # screen well
    rect(d, [p + w + 1, p + w + 1, size - p - w - 2, size - p - 5], PANEL)
    # stand + base
    rect(d, [size // 2 - 1, size - p - 3, size // 2, size - p - 1], PHOS)
    rect(d, [p + 2, size - p, size - p - 3, size - p], PHOS)
    led(d, size)
    return im


def computer(size):
    im, d = plate(size)
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    w = 2 if size >= 32 else 1
    d.rectangle([p, p, size - 1 - p, size - p - 2], outline=PHOS, width=w)
    rect(d, [p + w + 1, p + w + 1, size - p - w - 2, size - p - 5], PANEL)
    rect(d, [p + 2, size - p - 3, p + 4, size - p - 2], PHOS)
    led(d, size)
    return im


def drive(size):
    im, d = plate(size)
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    w = 2 if size >= 32 else 1
    d.ellipse([p, p + 1, size - 1 - p, size - p - 1], outline=PHOS, width=w)
    m = size // 2
    r = max(1, size // 12)
    d.ellipse([m - r, m - r, m + r, m + r], fill=PHOS)
    led(d, size)
    return im


def removable(size):
    im, d = plate(size)
    p = 3 if size <= 16 else 4 if size <= 24 else 6
    mid = size // 2
    half = max(2, size // 10)
    rect(d, [p + 1, p + 3, size - p - 2, size - p], PHOS)
    rect(d, [p + 3, p + 5, size - p - 4, size - p - 2], INSET)
    rect(d, [mid - half, p, mid + half, p + 4], PHOS)
    led(d, size)
    return im


def save_all(theme: Path) -> int:
    mapping = {
        ("places", "user-home"): home,
        ("places", "folder-home"): home,
        ("places", "gtk-home"): home,
        ("places", "go-home"): home,
        ("places", "user-trash"): lambda s: trash(s, False),
        ("places", "user-trash-empty"): lambda s: trash(s, False),
        ("places", "trashcan_empty"): lambda s: trash(s, False),
        ("places", "user-trash-full"): lambda s: trash(s, True),
        ("places", "trashcan_full"): lambda s: trash(s, True),
        ("places", "user-desktop"): desktop,
        ("devices", "computer"): computer,
        ("devices", "video-display"): computer,
        ("devices", "drive-harddisk"): drive,
        ("devices", "drive-harddisk-system"): drive,
        ("devices", "gtk-harddisk"): drive,
        ("devices", "drive-removable-media"): removable,
        ("devices", "media-removable"): removable,
        ("devices", "media-flash"): removable,
        ("devices", "gnome-dev-removable"): removable,
    }
    n = 0
    for (ctx, name), fn in mapping.items():
        for size in SIZES:
            dest = theme / f"{size}x{size}" / ctx
            dest.mkdir(parents=True, exist_ok=True)
            fn(size).save(dest / f"{name}.png")
            n += 1
    return n


def main():
    src = Path.home() / "Vault.OS" / "source" / "icons"
    live = Path.home() / ".icons" / "Vault.OS"
    print("source", save_all(src))
    print("live", save_all(live))


if __name__ == "__main__":
    main()
