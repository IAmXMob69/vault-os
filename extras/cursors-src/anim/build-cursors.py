#!/usr/bin/env python3
"""Build PipBoy-NV animated watch / left_ptr_watch Xcursors from video frames."""
from __future__ import annotations

import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
FRAMES_DIR = ROOT / "video-frames"
OUT_PNG = ROOT / "watch-frames"
PTR_SRC = ROOT.parent / "left_ptr.png"
CURSOR_DIRS = [
    Path.home() / "Projects/vault-os/cursors/PipBoy-NV-Cursors/cursors",
    Path.home() / ".icons/PipBoy-NV-Cursors/cursors",
]
SIZES = (24, 32, 48)
N_FRAMES = 16
DELAY_MS = 50
XCURSOR_IMAGE = 0xFFFD0002


def key_black(im: Image.Image, t: int = 16) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            m = max(r, g, b)
            if m < t:
                px[x, y] = (0, 0, 0, 0)
            else:
                alpha = min(255, int((m - t) * 1.2) + 32)
                px[x, y] = (r, g, b, alpha)
    return im


def pick_frames() -> list[Path]:
    allf = sorted(FRAMES_DIR.glob("f*.png"))
    if len(allf) < N_FRAMES:
        raise SystemExit(f"need {N_FRAMES} frames, got {len(allf)}")
    # drop last if it is a near-duplicate of the first (loop closure)
    span = len(allf) - 1
    return [allf[round(i * span / N_FRAMES) % span] for i in range(N_FRAMES)]


def punch(im: Image.Image, gain: float) -> Image.Image:
    if gain <= 1.0:
        return im
    im = im.copy()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            px[x, y] = (
                min(255, int(r * gain * 0.55)),
                min(255, int(g * gain)),
                min(255, int(b * gain * 0.45)),
                a,
            )
    return im


def scale_keyed(im: Image.Image, size: int) -> Image.Image:
    out = im.resize((size, size), Image.Resampling.LANCZOS)
    if size <= 32:
        out = punch(out, 1.45 if size == 24 else 1.2)
    return out


def write_xcursor(path: Path, frames_by_size: dict[int, list[Image.Image]], hot: dict[int, tuple[int, int]]):
    """frames_by_size[size] = list of RGBA images, one per animation frame."""
    chunks = []
    ntoc = 0
    for size in SIZES:
        for im in frames_by_size[size]:
            ntoc += 1
            chunks.append((size, im, hot[size]))

    header_size = 16
    toc_size = ntoc * 12
    pos = header_size + toc_size
    toc = []
    body = bytearray()
    for size, im, (hx, hy) in chunks:
        w, h = im.size
        raw = im.tobytes("raw", "BGRA")
        chunk = struct.pack("<IIIIIIIII", 36, XCURSOR_IMAGE, size, 1, w, h, hx, hy, DELAY_MS)
        chunk += raw
        toc.append((XCURSOR_IMAGE, size, pos))
        body += chunk
        pos += len(chunk)

    out = bytearray()
    out += b"Xcur"
    out += struct.pack("<III", 16, 0x10000, ntoc)
    for typ, sub, p in toc:
        out += struct.pack("<III", typ, sub, p)
    out += body
    path.write_bytes(bytes(out))
    path.chmod(0o644)


def load_pointer(size: int) -> Image.Image:
    src = Image.open(PTR_SRC).convert("RGBA")
    # trim empty
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    # pointer should occupy ~60% of the cell, top-left
    target = max(8, int(size * 0.62))
    src = src.resize((target, int(target * src.height / src.width)), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(src, (1, 1), src)
    return canvas


def compose_ptr_watch(ptr: Image.Image, spin: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(ptr)
    badge = max(10, int(size * 0.48))
    small = spin.resize((badge, badge), Image.Resampling.LANCZOS)
    x = size - badge - 1
    y = size - badge - 1
    canvas.alpha_composite(small, (x, y))
    return canvas


def main():
    OUT_PNG.mkdir(parents=True, exist_ok=True)
    picks = pick_frames()
    keyed = []
    for i, p in enumerate(picks, 1):
        im = key_black(Image.open(p))
        im.save(OUT_PNG / f"watch-{i:02d}.png")
        keyed.append(im)

    watch = {s: [scale_keyed(im, s) for im in keyed] for s in SIZES}
    ptrs = {s: load_pointer(s) for s in SIZES}
    ptr_watch = {s: [compose_ptr_watch(ptrs[s], fr, s) for fr in watch[s]] for s in SIZES}

    watch_hot = {s: (s // 2, s // 2) for s in SIZES}
    ptr_hot = {24: (2, 2), 32: (2, 2), 48: (4, 4)}

    for dest in CURSOR_DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        write_xcursor(dest / "watch", watch, watch_hot)
        write_xcursor(dest / "left_ptr_watch", ptr_watch, ptr_hot)
        print("wrote", dest / "watch", (dest / "watch").stat().st_size)

    # preview sheet at 48px
    sheet = Image.new("RGBA", (48 * N_FRAMES, 48 * 2), (0, 0, 0, 0))
    bg = Image.new("RGB", sheet.size, (8, 12, 8))
    for i, im in enumerate(watch[48]):
        sheet.paste(im, (i * 48, 0), im)
    for i, im in enumerate(ptr_watch[48]):
        sheet.paste(im, (i * 48, 48), im)
    bg.paste(Image.new("RGB", sheet.size, (8, 12, 8)))
    vis = Image.alpha_composite(bg.convert("RGBA"), sheet)
    vis.save(ROOT / "upgrade-sheet.png")
    print("preview", ROOT / "upgrade-sheet.png")


if __name__ == "__main__":
    main()
