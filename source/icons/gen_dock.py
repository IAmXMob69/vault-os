#!/usr/bin/env python3
"""ICO-06 — five matching dock plates. CANON tokens only."""
from pathlib import Path
from PIL import Image, ImageDraw

PHOS = (0x1A, 0xFF, 0x6B, 255)
INSET = (0x12, 0x16, 0x12, 255)
BEVEL_HI = (0x2A, 0x33, 0x2A, 255)
BEVEL_LO = (0x05, 0x06, 0x05, 255)
RAD = (0xC4, 0x1E, 0x3A, 255)
BOLT = (0xD4, 0xED, 0xDD, 255)
PANEL = (0x0C, 0x0F, 0x0C, 255)


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
    x = size - 6
    d.rectangle([x, 3, x + 2, 5], fill=color)


def sw(size):
    return 2 if size >= 32 else 1


def terminal(size):
    im, d = plate(size)
    m = max(4, size // 8)
    d.rectangle([m, m + 1, size - 1 - m, size - 2 - m], outline=PHOS, width=sw(size))
    cx, cy = m + 3, size // 2
    d.polygon([(cx, cy - 5), (cx + 7, cy), (cx, cy + 5)], fill=PHOS)
    d.rectangle([cx + 9, cy + 3, size - m - 4, cy + 5], fill=PHOS)
    led(d, size)
    return im


def files(size):
    im, d = plate(size)
    m = max(4, size // 8)
    tab_w = size // 3
    d.rectangle([m, m + 2, m + tab_w, m + 6], fill=PHOS)
    d.rectangle([m, m + 6, size - 1 - m, size - 2 - m], fill=PHOS)
    d.rectangle([m + 2, m + 8, size - 3 - m, size - 4 - m], fill=INSET)
    led(d, size)
    return im


def browser(size):
    im, d = plate(size)
    w = sw(size)
    pad = max(4, size // 8)
    d.ellipse([pad, pad, size - 1 - pad, size - 1 - pad], outline=PHOS, width=w)
    d.ellipse([pad + 5, pad, size - 6 - pad, size - 1 - pad], outline=PHOS, width=1)
    mid = size // 2
    d.line([(pad, mid), (size - 1 - pad, mid)], fill=PHOS, width=w)
    d.line([(mid, pad), (mid, size - 1 - pad)], fill=PHOS, width=1)
    led(d, size)
    return im


def apps(size):
    im, d = plate(size)
    pad = max(5, size // 7)
    gap = 2
    inner = size - 2 * pad
    cell = (inner - gap) // 2
    for i in range(2):
        for j in range(2):
            x = pad + i * (cell + gap)
            y = pad + j * (cell + gap)
            d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=PHOS)
            d.rectangle([x + 2, y + 2, x + cell - 3, y + cell - 3], fill=INSET)
    led(d, size)
    return im


def close_all(size):
    im, d = plate(size, fill=RAD)
    led(d, size, RAD)
    w = 3 if size >= 32 else 2
    p = max(7, size // 5)
    d.line([(p, p), (size - 1 - p, size - 1 - p)], fill=BOLT, width=w)
    d.line([(size - 1 - p, p), (p, size - 1 - p)], fill=BOLT, width=w)
    return im


def show_desktop(size):
    im, d = plate(size)
    p = max(5, size // 7)
    d.rectangle([p, p, size - 1 - p, size - 8], outline=PHOS, width=sw(size))
    d.rectangle([p + 2, p + 2, size - 3 - p, size - 10], fill=PANEL)
    d.rectangle([size // 2 - 2, size - 8, size // 2 + 1, size - 6], fill=PHOS)
    d.rectangle([p + 4, size - 5, size - 5 - p, size - 3], fill=PHOS)
    led(d, size)
    return im


def save(im, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")


def main():
    src = Path.home() / "Vault.OS" / "source" / "icons" / "dock"
    src.mkdir(parents=True, exist_ok=True)
    makers = {
        "dock-terminal": terminal,
        "dock-files": files,
        "dock-browser": browser,
        "dock-apps": apps,
        "dock-close": close_all,
        "dock-desktop": show_desktop,
    }
    for name, fn in makers.items():
        save(fn(32), src / (name + ".png"))
        save(fn(48), src / (name + "@48.png"))
    hicolor = src / "hicolor"
    for sz in (16, 22, 24, 32, 48, 64, 96, 128, 256):
        save(close_all(sz), hicolor / (str(sz) + "x" + str(sz)) / "apps" / "vault-os-close-all.png")
        save(show_desktop(sz), hicolor / (str(sz) + "x" + str(sz)) / "apps" / "org.xfce.panel.showdesktop.png")
    print("wrote", src)


if __name__ == "__main__":
    main()
