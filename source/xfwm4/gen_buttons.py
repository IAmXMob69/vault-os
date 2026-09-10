#!/usr/bin/env python3
"""Stamp matching 22px xfwm4 latches: hide / maximize / close / menu / shade / stick.

22px sits in the 28px title fill so the phosphor rail under the title
still reads as one line. Square plates, 1px bevel, thin centered glyphs.
Close is rad on hover only — not a stop-sign at rest.
"""
from __future__ import annotations

from pathlib import Path

SIZE = 22

# Glyphs are 16x16, blit at (3, 3). '.' = skip.
HIDE = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....XXXXXXXX....",
    "....XXXXXXXX....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
MAXI = [
    "................",
    "................",
    "....XXXXXXXX....",
    "....X......X....",
    "....X......X....",
    "....X......X....",
    "....X......X....",
    "....X......X....",
    "....X......X....",
    "....X......X....",
    "....XXXXXXXX....",
    "................",
    "................",
    "................",
    "................",
    "................",
]
REST = [
    "................",
    "......XXXXXX....",
    "......X....X....",
    "......X....X....",
    "....XXXXXX.X....",
    "....X.X....X....",
    "....X.XXXXXX....",
    "....X....X......",
    "....X....X......",
    "....XXXXXX......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

MENU = [
    "................",
    "................",
    "....XXXXXXXX....",
    "....XXXXXXXX....",
    "................",
    "................",
    "....XXXXXXXX....",
    "....XXXXXXXX....",
    "................",
    "................",
    "....XXXXXXXX....",
    "....XXXXXXXX....",
    "................",
    "................",
    "................",
    "................",
]
SHADE = [
    "................",
    "................",
    ".......XX.......",
    "......XXXX......",
    ".....XXXXXX.....",
    "....XXXXXXXX....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
SHADE_DN = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....XXXXXXXX....",
    ".....XXXXXX.....",
    "......XXXX......",
    ".......XX.......",
    "................",
    "................",
    "................",
    "................",
]
STICK = [
    "................",
    "................",
    "......XXXX......",
    "......XXXX......",
    "......XXXX......",
    "......XXXX......",
    ".......XX.......",
    ".......XX.......",
    ".......XX.......",
    ".......XX.......",
    ".......XX.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]
STICK_ON = [
    "................",
    "................",
    ".....XXXXXX.....",
    ".....XXXXXX.....",
    ".....XXXXXX.....",
    ".....XXXXXX.....",
    ".....XXXXXX.....",
    ".......XX.......",
    ".......XX.......",
    ".......XX.......",
    ".......XX.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]

CLOSE = [
    "................",
    "...XX......XX...",
    "...XXX....XXX...",
    "....XXX..XXX....",
    ".....XXXXXX.....",
    "......XXXX......",
    ".......XX.......",
    ".......XX.......",
    "......XXXX......",
    ".....XXXXXX.....",
    "....XXX..XXX....",
    "...XXX....XXX...",
    "...XX......XX...",
    "................",
    "................",
    "................",
]

CANON = {
    "L": ("#050605", "active_shadow_1"),
    "H": ("#2A332A", "active_highlight_1"),
    "P": ("#121612", "active_color_2"),
    "G": ("#8A8F86", "active_mid_1"),
    "O": ("#1AFF6B", "active_text_color"),
    "N": ("#0E8A3A", "active_highlight_2"),
    "W": ("#D4EDDD", None),
    "R": ("#C41E3A", None),
    "T": ("None", None),
}
CANON_INACT = {
    **CANON,
    "L": ("#050605", "inactive_shadow_1"),
    "H": ("#2A332A", "inactive_highlight_1"),
    "P": ("#121612", "inactive_color_2"),
    "G": ("#8A8F86", "inactive_mid_1"),
    "O": ("#8A8F86", "inactive_mid_1"),
    "N": ("#06381A", "inactive_highlight_2"),
}
REDUCED = {
    "L": ("#050605", "active_shadow_1"),
    "H": ("#3A463A", "active_highlight_1"),
    "P": ("#121612", "active_color_2"),
    "G": ("#B7BEB4", "active_mid_1"),
    "O": ("#66FF9C", "active_text_color"),
    "N": ("#1AFF6B", "active_highlight_2"),
    "W": ("#F2F7F2", None),
    "R": ("#E94D5A", None),
    "T": ("None", None),
}
REDUCED_INACT = {
    **REDUCED,
    "L": ("#050605", "inactive_shadow_1"),
    "H": ("#3A463A", "inactive_highlight_1"),
    "P": ("#121612", "inactive_color_2"),
    "G": ("#B7BEB4", "inactive_mid_1"),
    "O": ("#B7BEB4", "inactive_mid_1"),
    "N": ("#0E8A3A", "inactive_highlight_2"),
}


def plate(fill: str = "P", pressed: bool = False) -> list[list[str]]:
    g = [["T"] * SIZE for _ in range(SIZE)]
    hi, lo = ("L", "H") if pressed else ("H", "L")
    for x in range(1, SIZE - 1):
        g[0][x] = hi
        g[SIZE - 1][x] = lo
    for y in range(1, SIZE - 1):
        g[y][0] = hi
        g[y][SIZE - 1] = lo
        for x in range(1, SIZE - 1):
            g[y][x] = fill
    return g


def blit(g: list[list[str]], stamp: list[str], color: str, ox: int = 3, oy: int = 3) -> None:
    for y, row in enumerate(stamp):
        for x, ch in enumerate(row):
            if ch == "X":
                g[oy + y][ox + x] = color


def used(g: list[list[str]]) -> set[str]:
    return {c for row in g for c in row}


def write_xpm(path: Path, name: str, grid: list[list[str]], pal: dict) -> None:
    chars = [c for c in ("T", "H", "L", "P", "G", "O", "N", "W", "R") if c in used(grid)]
    lines = [
        "/* XPM */",
        f"/* {name} */",
        f"static char * {name.replace('-', '_')}_xpm[] = {{",
        f'"{SIZE} {SIZE} {len(chars)} 1",',
    ]
    for c in chars:
        hexcol, sym = pal[c]
        if hexcol == "None":
            lines.append(f'"{c} c None",')
        elif sym:
            lines.append(f'"{c} c {hexcol} s {sym}",')
        else:
            lines.append(f'"{c} c {hexcol}",')
    for y, row in enumerate(grid):
        comma = "," if y < SIZE - 1 else ""
        lines.append(f'"{"".join(row)}"{comma}')
    lines.append("};")
    path.write_text("\n".join(lines) + "\n")


def make(kind: str, state: str, pal: dict) -> list[list[str]]:
    pressed = state == "pressed"
    prelight = state == "prelight"
    inactive = state == "inactive"
    fill = "R" if (kind == "close" and (prelight or pressed)) else "P"
    g = plate(fill=fill, pressed=pressed)

    if kind == "close":
        glyph = "W" if fill == "R" else ("R" if not inactive else "G")
        blit(g, CLOSE, glyph)
    elif kind == "hide":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, HIDE, glyph)
    elif kind == "maximize":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, MAXI, glyph)
    elif kind == "maximize-toggled":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, REST, glyph)
    elif kind == "menu":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, MENU, glyph)
    elif kind == "shade":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, SHADE, glyph)
    elif kind == "shade-toggled":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, SHADE_DN, glyph)
    elif kind == "stick":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, STICK, glyph)
    elif kind == "stick-toggled":
        glyph = "O" if (prelight or pressed) else "G"
        blit(g, STICK_ON, glyph)
    else:
        raise ValueError(kind)
    return g


SPECS = [
    ("hide-active", "hide", "active"),
    ("hide-inactive", "hide", "inactive"),
    ("hide-prelight", "hide", "prelight"),
    ("hide-pressed", "hide", "pressed"),
    ("maximize-active", "maximize", "active"),
    ("maximize-inactive", "maximize", "inactive"),
    ("maximize-prelight", "maximize", "prelight"),
    ("maximize-pressed", "maximize", "pressed"),
    ("maximize-toggled-active", "maximize-toggled", "active"),
    ("maximize-toggled-inactive", "maximize-toggled", "inactive"),
    ("maximize-toggled-prelight", "maximize-toggled", "prelight"),
    ("maximize-toggled-pressed", "maximize-toggled", "pressed"),
    ("close-active", "close", "active"),
    ("close-inactive", "close", "inactive"),
    ("close-prelight", "close", "prelight"),
    ("close-pressed", "close", "pressed"),
    ("menu-active", "menu", "active"),
    ("menu-inactive", "menu", "inactive"),
    ("menu-prelight", "menu", "prelight"),
    ("menu-pressed", "menu", "pressed"),
    ("shade-active", "shade", "active"),
    ("shade-inactive", "shade", "inactive"),
    ("shade-prelight", "shade", "prelight"),
    ("shade-pressed", "shade", "pressed"),
    ("shade-toggled-active", "shade-toggled", "active"),
    ("shade-toggled-inactive", "shade-toggled", "inactive"),
    ("shade-toggled-prelight", "shade-toggled", "prelight"),
    ("shade-toggled-pressed", "shade-toggled", "pressed"),
    ("stick-active", "stick", "active"),
    ("stick-inactive", "stick", "inactive"),
    ("stick-prelight", "stick", "prelight"),
    ("stick-pressed", "stick", "pressed"),
    ("stick-toggled-active", "stick-toggled", "active"),
    ("stick-toggled-inactive", "stick-toggled", "inactive"),
    ("stick-toggled-prelight", "stick-toggled", "prelight"),
    ("stick-toggled-pressed", "stick-toggled", "pressed"),
]



def generate(out: Path, reduced: bool = False) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for fname, kind, state in SPECS:
        pal = (REDUCED_INACT if reduced else CANON_INACT) if state == "inactive" else (
            REDUCED if reduced else CANON
        )
        write_xpm(out / f"{fname}.xpm", fname, make(kind, state, pal), pal)


if __name__ == "__main__":
    root = Path(__file__).resolve().parent
    generate(root, reduced=False)
    generate(root.parent / "xfwm4-reduced", reduced=True)
    print("wrote", len(SPECS), "buttons × 2 palettes")
