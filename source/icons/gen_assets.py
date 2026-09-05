#!/usr/bin/env python3
"""Vault.OS icon / cursor / wallpaper generator.
Phosphor on inset plates, bevel stamp, cursor without amber chrome.
"""
from __future__ import annotations

import os
import struct
from pathlib import Path

from PIL import Image, ImageDraw

# --- CANON tokens (do not invent) ---
PHOS = (0x1A, 0xFF, 0x6B, 255)          # phosphor-primary
PHOS_DIM = (0x0E, 0x8A, 0x3A, 255)
PHOS_HOT = (0x66, 0xFF, 0x9C, 255)
VAULT_BLACK = (0x07, 0x08, 0x07, 255)
PANEL_BLACK = (0x0C, 0x0F, 0x0C, 255)
INSET = (0x12, 0x16, 0x12, 255)
BEVEL_HI = (0x2A, 0x33, 0x2A, 255)
BEVEL_LO = (0x05, 0x06, 0x05, 255)
STEEL = (0x8A, 0x8F, 0x86, 255)
STEEL_950 = VAULT_BLACK
STEEL_900 = PANEL_BLACK
STEEL_800 = INSET
STEEL_700 = BEVEL_HI
STEEL_600 = BEVEL_HI
STEEL_500 = (0x60, 0x66, 0x5C, 255)
STEEL_400 = STEEL
GOLD_DIM = STEEL                        # 111 mark: steel, amber is WARN only
GOLD = (0xFF, 0xB0, 0x00, 255)          # amber-warn
BLOOD = (0xC4, 0x1E, 0x3A, 255)
RAD = BLOOD
INFO = STEEL
TRANSPARENT = (0, 0, 0, 0)

SIZES = (16, 24, 32, 48)
CURSOR_SIZE = 24

SRC = Path.home() / "Vault.OS" / "source"
ICON_SRC = SRC / "icons"
WALL_SRC = SRC / "wallpapers"
LIVE_ICONS = Path.home() / ".icons" / "Vault.OS"
LIVE_WALL = Path.home() / ".local" / "share" / "backgrounds" / "Vault.OS"


def u(v: float, size: int) -> int:
    return int(round(v * size / 16.0))


def plate(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (size, size), TRANSPARENT)
    d = ImageDraw.Draw(im)
    # stamped plate: inset fill, 1px bevel-hi (top/left), 1px bevel-lo (bottom/right)
    d.rectangle([0, 0, size - 1, size - 1], fill=INSET)
    d.line([(0, 0), (size - 1, 0)], fill=BEVEL_HI)
    d.line([(0, 0), (0, size - 1)], fill=BEVEL_HI)
    d.line([(0, size - 1), (size - 1, size - 1)], fill=BEVEL_LO)
    d.line([(size - 1, 0), (size - 1, size - 1)], fill=BEVEL_LO)
    return im, d


def stroke(size: int) -> int:
    return 1 if size <= 24 else 2


def R(d, size, x, y, w, h, fill=PHOS):
    d.rectangle([u(x, size), u(y, size), u(x + w, size) - 1, u(y + h, size) - 1], fill=fill)


def L(d, size, x1, y1, x2, y2, fill=PHOS):
    w = stroke(size)
    d.line([(u(x1, size), u(y1, size)), (u(x2, size), u(y2, size))], fill=fill, width=w)


def P(d, size, pts, fill=PHOS):
    d.polygon([(u(x, size), u(y, size)) for x, y in pts], fill=fill)


def E(d, size, x, y, w, h, fill=None, outline=PHOS):
    box = [u(x, size), u(y, size), u(x + w, size) - 1, u(y + h, size) - 1]
    d.ellipse(box, fill=fill, outline=outline, width=stroke(size))


# --- glyphs (16-unit design space, 1px plate already applied by coords 2-13) ---
def g_folder(d, s):
    R(d, s, 2, 4, 5, 2)
    R(d, s, 2, 5, 12, 9)


def g_folder_open(d, s):
    R(d, s, 2, 4, 5, 2)
    R(d, s, 2, 6, 12, 8)
    P(d, s, [(2, 8), (14, 8), (12, 14), (3, 14)])


def g_home(d, s):
    P(d, s, [(8, 2), (14, 8), (12, 8), (12, 14), (4, 14), (4, 8), (2, 8)])
    R(d, s, 7, 10, 2, 4, STEEL_800)


def g_desktop(d, s):
    d.rectangle([u(3, s), u(3, s), u(13, s) - 1, u(10, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 4, 4, 8, 5, STEEL_800)
    R(d, s, 7, 10, 2, 2)
    R(d, s, 5, 12, 6, 2)


def g_trash(d, s):
    R(d, s, 5, 3, 6, 1)
    R(d, s, 4, 4, 8, 1)
    P(d, s, [(5, 5), (11, 5), (10, 13), (6, 13)])


def g_trash_full(d, s):
    g_trash(d, s)
    R(d, s, 7, 6, 2, 5, STEEL_800)


def g_computer(d, s):
    R(d, s, 4, 2, 8, 10)
    R(d, s, 5, 3, 6, 6, STEEL_800)
    R(d, s, 6, 10, 2, 1)
    R(d, s, 5, 13, 6, 1)


def g_drive(d, s):
    E(d, s, 3, 5, 10, 6, fill=None, outline=PHOS)
    E(d, s, 6, 7, 4, 2, fill=PHOS, outline=PHOS)
    R(d, s, 3, 8, 10, 3)


def g_network(d, s):
    E(d, s, 6, 2, 4, 4, fill=PHOS, outline=PHOS)
    E(d, s, 2, 10, 4, 4, fill=PHOS, outline=PHOS)
    E(d, s, 10, 10, 4, 4, fill=PHOS, outline=PHOS)
    L(d, s, 8, 6, 4, 10)
    L(d, s, 8, 6, 12, 10)


def g_optical(d, s):
    E(d, s, 2, 2, 12, 12, fill=None, outline=PHOS)
    E(d, s, 6, 6, 4, 4, fill=PHOS, outline=PHOS)


def g_text(d, s):
    R(d, s, 4, 2, 8, 12)
    R(d, s, 5, 4, 6, 1, STEEL_800)
    R(d, s, 5, 7, 6, 1, STEEL_800)
    R(d, s, 5, 10, 4, 1, STEEL_800)


def g_image(d, s):
    d.rectangle([u(3, s), u(3, s), u(13, s) - 1, u(13, s) - 1], outline=PHOS, width=stroke(s))
    P(d, s, [(3, 13), (7, 7), (10, 11), (12, 9), (13, 13)])
    E(d, s, 5, 4, 3, 3, fill=PHOS, outline=PHOS)


def g_audio(d, s):
    P(d, s, [(3, 6), (6, 6), (10, 3), (10, 13), (6, 10), (3, 10)])
    E(d, s, 11, 6, 3, 4, fill=None, outline=PHOS)


def g_video(d, s):
    d.rectangle([u(3, s), u(4, s), u(10, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))
    P(d, s, [(10, 6), (14, 4), (14, 12), (10, 10)])


def g_exec(d, s):
    g_gear(d, s)


def g_package(d, s):
    P(d, s, [(8, 2), (14, 5), (14, 11), (8, 14), (2, 11), (2, 5)])
    L(d, s, 8, 2, 8, 14)
    L(d, s, 2, 5, 14, 5)


def g_html(d, s):
    g_text(d, s)
    P(d, s, [(5, 8), (7, 6), (7, 7), (6, 8), (7, 9), (7, 10)])
    P(d, s, [(11, 8), (9, 6), (9, 7), (10, 8), (9, 9), (9, 10)])


def g_pdf(d, s):
    g_text(d, s)
    R(d, s, 8, 10, 4, 3)


def g_font(d, s):
    P(d, s, [(4, 13), (6, 3), (8, 3), (10, 13), (8, 13), (8, 11), (6, 11), (6, 13)])
    R(d, s, 6, 8, 2, 1)


def g_unknown(d, s):
    d.rectangle([u(4, s), u(2, s), u(12, s) - 1, u(14, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 7, 5, 2, 4)
    R(d, s, 7, 11, 2, 2)


def g_terminal(d, s):
    d.rectangle([u(2, s), u(3, s), u(14, s) - 1, u(13, s) - 1], outline=PHOS, width=stroke(s))
    P(d, s, [(4, 6), (7, 8), (4, 10)])
    R(d, s, 8, 10, 4, 1)


def g_thunar(d, s):
    g_folder(d, s)
    R(d, s, 8, 8, 4, 4, STEEL_800)
    d.rectangle([u(8, s), u(8, s), u(12, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))


def g_gear(d, s):
    E(d, s, 5, 5, 6, 6, fill=None, outline=PHOS)
    E(d, s, 7, 7, 2, 2, fill=PHOS, outline=PHOS)
    R(d, s, 7, 2, 2, 3)
    R(d, s, 7, 11, 2, 3)
    R(d, s, 2, 7, 3, 2)
    R(d, s, 11, 7, 3, 2)


def g_sliders(d, s):
    R(d, s, 3, 3, 2, 10)
    R(d, s, 7, 3, 2, 10)
    R(d, s, 11, 3, 2, 10)
    R(d, s, 2, 5, 4, 2)
    R(d, s, 6, 9, 4, 2)
    R(d, s, 10, 6, 4, 2)


def g_globe(d, s):
    E(d, s, 2, 2, 12, 12, fill=None, outline=PHOS)
    E(d, s, 5, 2, 6, 12, fill=None, outline=PHOS)
    L(d, s, 2, 8, 14, 8)
    L(d, s, 3, 5, 13, 5)
    L(d, s, 3, 11, 13, 11)


def g_note(d, s):
    R(d, s, 10, 3, 2, 8)
    R(d, s, 6, 3, 6, 2)
    E(d, s, 7, 10, 4, 3, fill=PHOS, outline=PHOS)
    E(d, s, 3, 11, 4, 3, fill=PHOS, outline=PHOS)
    R(d, s, 6, 6, 2, 6)


def g_office(d, s):
    g_text(d, s)
    R(d, s, 10, 2, 3, 3)


def g_games(d, s):
    P(d, s, [(8, 2), (14, 8), (8, 14), (2, 8)])
    E(d, s, 7, 7, 2, 2, fill=STEEL_800, outline=STEEL_800)


def g_other(d, s):
    R(d, s, 3, 3, 4, 4)
    R(d, s, 9, 3, 4, 4)
    R(d, s, 3, 9, 4, 4)
    R(d, s, 9, 9, 4, 4)


def g_start(d, s):
    # Vault 111 — three stamped 1s (flag + stem + base, not III)
    def one(x):
        R(d, s, x, 4, 1, 1)
        R(d, s, x + 1, 3, 2, 9)
        R(d, s, x, 12, 3, 1)
    one(2)
    one(6)
    one(10)


def g_editor(d, s):
    g_text(d, s)
    P(d, s, [(10, 10), (14, 6), (14, 8), (12, 12)])


def g_search(d, s):
    E(d, s, 3, 3, 8, 8, fill=None, outline=PHOS)
    L(d, s, 10, 10, 13, 13)


def g_help(d, s):
    E(d, s, 4, 2, 8, 8, fill=None, outline=PHOS)
    R(d, s, 7, 11, 2, 3)


def g_monitor(d, s):
    d.rectangle([u(2, s), u(3, s), u(14, s) - 1, u(11, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 4, 5, 8, 4, STEEL_800)
    R(d, s, 7, 11, 2, 2)
    R(d, s, 5, 13, 6, 1)


def g_info(d, s):
    E(d, s, 3, 2, 10, 12, fill=None, outline=PHOS)
    R(d, s, 7, 4, 2, 2)
    R(d, s, 7, 7, 2, 5)


def g_warning(d, s):
    P(d, s, [(8, 2), (14, 14), (2, 14)])
    R(d, s, 7, 6, 2, 4, STEEL_800)
    R(d, s, 7, 11, 2, 2, STEEL_800)


def g_error(d, s):
    d.rectangle([u(3, s), u(3, s), u(13, s) - 1, u(13, s) - 1], outline=PHOS, width=stroke(s))
    L(d, s, 5, 5, 11, 11)
    L(d, s, 11, 5, 5, 11)


def g_question(d, s):
    E(d, s, 4, 2, 8, 8, fill=None, outline=PHOS)
    R(d, s, 7, 8, 2, 2)
    R(d, s, 7, 12, 2, 2)


def g_vol_high(d, s):
    P(d, s, [(2, 6), (5, 6), (8, 3), (8, 13), (5, 10), (2, 10)])
    E(d, s, 9, 5, 3, 6, fill=None, outline=PHOS)
    E(d, s, 11, 3, 4, 10, fill=None, outline=PHOS)


def g_vol_med(d, s):
    P(d, s, [(2, 6), (5, 6), (8, 3), (8, 13), (5, 10), (2, 10)])
    E(d, s, 9, 5, 3, 6, fill=None, outline=PHOS)


def g_vol_low(d, s):
    P(d, s, [(3, 6), (6, 6), (9, 3), (9, 13), (6, 10), (3, 10)])


def g_vol_mute(d, s):
    g_vol_low(d, s)
    L(d, s, 3, 3, 13, 13)


def g_net_idle(d, s):
    L(d, s, 8, 13, 8, 8)
    P(d, s, [(8, 3), (13, 8), (11, 8), (11, 13), (5, 13), (5, 8), (3, 8)])


def g_net_off(d, s):
    g_net_idle(d, s)
    L(d, s, 3, 3, 13, 13)


def g_battery(d, s, fill_h=6):
    R(d, s, 4, 4, 9, 8)
    R(d, s, 13, 6, 1, 4)
    if fill_h:
        R(d, s, 5, 5, 7, fill_h, PHOS)


def g_bat_full(d, s):
    g_battery(d, s, 6)


def g_bat_good(d, s):
    g_battery(d, s, 4)


def g_bat_low(d, s):
    g_battery(d, s, 2)


def g_bat_empty(d, s):
    g_battery(d, s, 0)
    d.rectangle([u(4, s), u(4, s), u(13, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 13, 6, 1, 4)


def g_bat_caution(d, s):
    g_battery(d, s, 2)
    R(d, s, 7, 6, 2, 2, STEEL_800)


def g_printer(d, s):
    R(d, s, 5, 2, 6, 4)
    R(d, s, 3, 6, 10, 5)
    R(d, s, 5, 10, 6, 4)
    R(d, s, 6, 7, 2, 1, STEEL_800)


def g_lock(d, s):
    E(d, s, 5, 3, 6, 5, fill=None, outline=PHOS)
    R(d, s, 4, 7, 8, 7)
    R(d, s, 7, 10, 2, 2, STEEL_800)


def g_unlock(d, s):
    E(d, s, 5, 2, 6, 5, fill=None, outline=PHOS)
    R(d, s, 5, 2, 2, 4, STEEL_800)
    R(d, s, 4, 7, 8, 7)


def g_mail(d, s):
    d.rectangle([u(2, s), u(4, s), u(14, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))
    L(d, s, 2, 4, 8, 9)
    L(d, s, 14, 4, 8, 9)


def g_update(d, s):
    E(d, s, 3, 3, 10, 10, fill=None, outline=PHOS)
    P(d, s, [(8, 2), (11, 6), (9, 6), (9, 10), (7, 10), (7, 6), (5, 6)])


def g_doc_new(d, s):
    g_text(d, s)
    R(d, s, 10, 10, 4, 1)
    R(d, s, 11, 9, 1, 4)


def g_doc_save(d, s):
    P(d, s, [(3, 3), (13, 3), (13, 13), (3, 13)])
    R(d, s, 5, 3, 6, 4, STEEL_800)
    R(d, s, 5, 9, 6, 3, STEEL_800)


def g_copy(d, s):
    d.rectangle([u(4, s), u(4, s), u(12, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))
    d.rectangle([u(6, s), u(2, s), u(14, s) - 1, u(10, s) - 1], outline=PHOS, width=stroke(s))


def g_cut(d, s):
    E(d, s, 2, 8, 5, 5, fill=None, outline=PHOS)
    E(d, s, 9, 8, 5, 5, fill=None, outline=PHOS)
    L(d, s, 6, 9, 10, 3)
    L(d, s, 10, 9, 6, 3)


def g_paste(d, s):
    R(d, s, 5, 2, 6, 3)
    d.rectangle([u(4, s), u(4, s), u(12, s) - 1, u(14, s) - 1], outline=PHOS, width=stroke(s))


def g_delete(d, s):
    g_trash(d, s)


def g_undo(d, s):
    E(d, s, 3, 4, 10, 8, fill=None, outline=PHOS)
    P(d, s, [(3, 4), (3, 8), (7, 8)])
    R(d, s, 11, 8, 2, 4, STEEL_800)


def g_find(d, s):
    g_search(d, s)


def g_go_up(d, s):
    P(d, s, [(8, 3), (13, 9), (10, 9), (10, 13), (6, 13), (6, 9), (3, 9)])


def g_go_down(d, s):
    P(d, s, [(8, 13), (13, 7), (10, 7), (10, 3), (6, 3), (6, 7), (3, 7)])


def g_go_prev(d, s):
    P(d, s, [(3, 8), (9, 3), (9, 6), (13, 6), (13, 10), (9, 10), (9, 13)])


def g_go_next(d, s):
    P(d, s, [(13, 8), (7, 3), (7, 6), (3, 6), (3, 10), (7, 10), (7, 13)])


def g_add(d, s):
    R(d, s, 7, 3, 2, 10)
    R(d, s, 3, 7, 10, 2)


def g_remove(d, s):
    R(d, s, 3, 7, 10, 2)


def g_close(d, s):
    L(d, s, 4, 4, 12, 12)
    L(d, s, 12, 4, 4, 12)


def g_max(d, s):
    d.rectangle([u(4, s), u(4, s), u(12, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))


def g_min(d, s):
    R(d, s, 4, 11, 8, 2)


def g_refresh(d, s):
    E(d, s, 3, 3, 10, 10, fill=None, outline=PHOS)
    P(d, s, [(12, 2), (14, 6), (10, 6)])


def g_stop(d, s):
    P(d, s, [(8, 2), (14, 8), (8, 14), (2, 8)])
    R(d, s, 6, 6, 4, 4, STEEL_800)


def g_shutdown(d, s):
    E(d, s, 3, 3, 10, 10, fill=None, outline=PHOS)
    R(d, s, 7, 2, 2, 6)


def g_reboot(d, s):
    g_refresh(d, s)


def g_logout(d, s):
    d.rectangle([u(3, s), u(3, s), u(10, s) - 1, u(13, s) - 1], outline=PHOS, width=stroke(s))
    P(d, s, [(8, 8), (13, 8), (11, 5), (14, 8), (11, 11), (13, 8)])


def g_run(d, s):
    P(d, s, [(4, 3), (13, 8), (4, 13)])


def g_zoom_in(d, s):
    g_search(d, s)
    R(d, s, 6, 6, 3, 1)
    R(d, s, 7, 5, 1, 3)


def g_zoom_out(d, s):
    g_search(d, s)
    R(d, s, 6, 6, 3, 1)


def g_play(d, s):
    P(d, s, [(4, 3), (13, 8), (4, 13)])


def g_pause(d, s):
    R(d, s, 4, 3, 3, 10)
    R(d, s, 9, 3, 3, 10)


def g_media_stop(d, s):
    R(d, s, 4, 4, 8, 8)


def g_keyboard(d, s):
    d.rectangle([u(2, s), u(5, s), u(14, s) - 1, u(12, s) - 1], outline=PHOS, width=stroke(s))
    for x in (4, 6, 8, 10, 12):
        R(d, s, x, 7, 1, 1)


def g_mouse(d, s):
    E(d, s, 5, 2, 6, 12, fill=None, outline=PHOS)
    L(d, s, 8, 2, 8, 7)
    L(d, s, 5, 7, 11, 7)


def g_camera(d, s):
    R(d, s, 3, 5, 10, 7)
    R(d, s, 6, 3, 4, 2)
    E(d, s, 6, 6, 4, 4, fill=None, outline=PHOS)


def g_display(d, s):
    g_desktop(d, s)


def g_wired(d, s):
    R(d, s, 6, 2, 4, 5)
    R(d, s, 7, 7, 2, 3)
    R(d, s, 4, 10, 8, 4)


def g_wireless(d, s):
    E(d, s, 3, 5, 10, 10, fill=None, outline=PHOS)
    E(d, s, 5, 7, 6, 6, fill=None, outline=PHOS)
    E(d, s, 7, 10, 2, 2, fill=PHOS, outline=PHOS)


def g_phone(d, s):
    d.rectangle([u(5, s), u(2, s), u(11, s) - 1, u(14, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 7, 12, 2, 1)


def g_flash(d, s):
    R(d, s, 5, 3, 6, 10)
    R(d, s, 6, 2, 4, 1)
    R(d, s, 7, 13, 2, 1)


def g_missing(d, s):
    d.rectangle([u(3, s), u(3, s), u(13, s) - 1, u(13, s) - 1], outline=PHOS, width=stroke(s))
    R(d, s, 4, 4, 2, 2)
    R(d, s, 10, 4, 2, 2)
    R(d, s, 4, 10, 8, 2)


def g_bold(d, s):
    R(d, s, 4, 3, 2, 10)
    R(d, s, 4, 3, 6, 2)
    R(d, s, 4, 7, 6, 2)
    R(d, s, 4, 11, 6, 2)
    R(d, s, 9, 4, 2, 3)
    R(d, s, 9, 8, 2, 3)


def g_fullscreen(d, s):
    P(d, s, [(3, 3), (7, 3), (3, 7)])
    P(d, s, [(13, 3), (13, 7), (9, 3)])
    P(d, s, [(3, 13), (7, 13), (3, 9)])
    P(d, s, [(13, 13), (13, 9), (9, 13)])


# Map: (context, name, glyph)
ICONS: list[tuple[str, str, object]] = []


def add(ctx, name, glyph):
    ICONS.append((ctx, name, glyph))


def add_many(ctx, names, glyph):
    for n in names:
        add(ctx, n, glyph)


add_many("places", ["folder", "inode-directory", "gtk-directory"], g_folder)
add("places", "folder-open", g_folder_open)
add("places", "folder-documents", g_folder)
add("places", "folder-download", g_folder)
add("places", "folder-pictures", g_image)
add("places", "folder-music", g_note)
add("places", "folder-videos", g_video)
add("places", "folder-publicshare", g_folder)
add_many("places", ["user-home", "folder-home", "gtk-home", "go-home"], g_home)
add("places", "user-desktop", g_desktop)
add_many("places", ["user-trash", "user-trash-empty", "trashcan_empty"], g_trash)
add_many("places", ["user-trash-full", "trashcan_full"], g_trash_full)
add("places", "user-bookmarks", g_text)
add("places", "network-workgroup", g_network)
add("places", "network-server", g_computer)

add_many("devices", ["computer", "video-display"], g_computer)
add_many("devices", ["drive-harddisk", "drive-harddisk-system", "gtk-harddisk"], g_drive)
add_many("devices", ["drive-optical", "media-optical"], g_optical)
add("devices", "drive-removable-media", g_flash)
add("devices", "media-flash", g_flash)
add("devices", "audio-card", g_audio)
add("devices", "camera-photo", g_camera)
add("devices", "input-keyboard", g_keyboard)
add("devices", "input-mouse", g_mouse)
add("devices", "network-wired", g_wired)
add("devices", "network-wireless", g_wireless)
add("devices", "phone", g_phone)
add_many("devices", ["printer", "printer-printing"], g_printer)

add_many("mimes", ["text-x-generic", "text-plain", "gtk-file"], g_text)
add("mimes", "text-html", g_html)
add("mimes", "text-x-script", g_exec)
add_many("mimes", ["image-x-generic", "image-jpeg", "image-png"], g_image)
add("mimes", "audio-x-generic", g_audio)
add("mimes", "video-x-generic", g_video)
add_many("mimes", ["application-x-executable", "application-x-addon"], g_exec)
add_many("mimes", ["package-x-generic", "application-x-archive", "application-gzip"], g_package)
add_many("mimes", ["application-octet-stream", "unknown"], g_unknown)
add("mimes", "font-x-generic", g_font)
add("mimes", "application-pdf", g_pdf)

add_many("apps", ["xfce4-terminal", "org.xfce.terminal", "utilities-terminal", "org.xfce.terminalemulator"], g_terminal)
add_many("apps", ["Thunar", "thunar", "org.xfce.thunar", "system-file-manager", "xfce-filemanager"], g_thunar)
add_many("apps", ["xfce4-settings", "org.xfce.settings.manager", "preferences-system", "preferences-desktop", "gtk-preferences"], g_gear)
add_many("apps", ["xfce4-appfinder", "org.xfce.appfinder"], g_search)
add("apps", "applications-system", g_gear)
add("apps", "applications-accessories", g_sliders)
add("apps", "applications-development", g_exec)
add("apps", "applications-games", g_games)
add("apps", "applications-graphics", g_image)
add("apps", "applications-internet", g_globe)
add("apps", "applications-multimedia", g_note)
add("apps", "applications-office", g_office)
add("apps", "applications-other", g_other)
add("apps", "applications-utilities", g_sliders)
add_many("apps", ["start-here", "xfce4-panel-menu", "xfce4-panel", "distributor-logo", "xfce4-whiskermenu"], g_start)
add_many("apps", ["web-browser", "firefox", "firefox-esr"], g_globe)
add_many("apps", ["accessories-text-editor", "mousepad", "org.xfce.mousepad", "text-editor"], g_editor)
add("apps", "help-browser", g_help)
add("apps", "utilities-system-monitor", g_monitor)
add("apps", "xfce4-session", g_logout)

add("status", "dialog-information", g_info)
add("status", "dialog-warning", g_warning)
add("status", "dialog-error", g_error)
add("status", "dialog-question", g_question)
add("status", "audio-volume-high", g_vol_high)
add("status", "audio-volume-medium", g_vol_med)
add("status", "audio-volume-low", g_vol_low)
add("status", "audio-volume-muted", g_vol_mute)
add_many("status", ["network-idle", "network-transmit", "network-receive", "network-transmit-receive"], g_net_idle)
add_many("status", ["network-offline", "network-error"], g_net_off)
add("status", "battery", g_bat_good)
add("status", "battery-full", g_bat_full)
add("status", "battery-good", g_bat_good)
add("status", "battery-low", g_bat_low)
add("status", "battery-caution", g_bat_caution)
add("status", "battery-empty", g_bat_empty)
add("status", "battery-missing", g_bat_empty)
add("status", "printer-error", g_printer)
add("status", "security-high", g_lock)
add("status", "security-medium", g_lock)
add("status", "security-low", g_unlock)
add("status", "image-missing", g_missing)
add("status", "software-update-available", g_update)
add("status", "software-update-urgent", g_update)
add("status", "mail-unread", g_mail)
add("status", "changes-prevent", g_lock)
add("status", "changes-allow", g_unlock)
add("status", "appointment-soon", g_info)

add("actions", "document-new", g_doc_new)
add("actions", "document-open", g_folder_open)
add("actions", "document-save", g_doc_save)
add("actions", "document-save-as", g_doc_save)
add("actions", "document-print", g_printer)
add("actions", "document-properties", g_sliders)
add("actions", "document-revert", g_undo)
add_many("actions", ["edit-copy", "gtk-copy"], g_copy)
add("actions", "edit-cut", g_cut)
add("actions", "edit-paste", g_paste)
add_many("actions", ["edit-delete", "gtk-delete"], g_delete)
add("actions", "edit-find", g_find)
add("actions", "edit-undo", g_undo)
add("actions", "edit-redo", g_refresh)
add("actions", "edit-select-all", g_max)
add("actions", "go-up", g_go_up)
add("actions", "go-down", g_go_down)
add("actions", "go-previous", g_go_prev)
add("actions", "go-next", g_go_next)
add("actions", "go-jump", g_go_next)
add("actions", "list-add", g_add)
add("actions", "list-remove", g_remove)
add_many("actions", ["window-close", "gtk-close"], g_close)
add("actions", "window-maximize", g_max)
add("actions", "window-minimize", g_min)
add("actions", "window-restore", g_max)
add_many("actions", ["view-refresh", "gtk-refresh"], g_refresh)
add("actions", "view-fullscreen", g_fullscreen)
add("actions", "view-restore", g_max)
add("actions", "process-stop", g_stop)
add_many("actions", ["system-search", "gtk-find"], g_search)
add("actions", "system-log-out", g_logout)
add("actions", "system-shutdown", g_shutdown)
add("actions", "system-reboot", g_reboot)
add("actions", "system-lock-screen", g_lock)
add("actions", "system-run", g_run)
add("actions", "application-exit", g_logout)
add("actions", "help-about", g_info)
add("actions", "help-contents", g_help)
add("actions", "zoom-in", g_zoom_in)
add("actions", "zoom-out", g_zoom_out)
add("actions", "zoom-original", g_search)
add("actions", "format-text-bold", g_bold)
add("actions", "media-playback-start", g_play)
add("actions", "media-playback-pause", g_pause)
add("actions", "media-playback-stop", g_media_stop)


def render_icon(glyph, size: int) -> Image.Image:
    im, d = plate(size)
    glyph(d, size)
    return im


def write_index(root: Path, dirs: list[str]) -> None:
    lines = [
        "[Icon Theme]",
        "Name=Vault.OS",
        "Comment=Vault.OS stamped plates",
        "Inherits=hicolor",
        "Example=folder",
        "DisplayDepth=32",
        f"Directories={','.join(dirs)}",
        "",
    ]
    for d in dirs:
        size_s, ctx = d.split("/", 1)
        size = int(size_s.split("x")[0])
        ctx_name = {"apps": "Applications", "mimes": "MimeTypes"}.get(ctx, ctx.capitalize())
        lines += [
            f"[{d}]",
            f"Size={size}",
            f"Context={ctx_name}",
            "Type=Fixed",
            "",
        ]
    (root / "index.theme").write_text("\n".join(lines), encoding="utf-8")


# --- cursors ---
def pack_xcursor(images: list[tuple[Image.Image, int, int, int]]) -> bytes:
    """images: (PIL RGBA, nominal_size, xhot, yhot)"""
    n = len(images)
    header_size = 16
    toc_off = header_size
    toc_size = n * 12
    img_off = toc_off + toc_size
    chunks = []
    toc = []
    pos = img_off
    for im, nominal, xhot, yhot in images:
        w, h = im.size
        pixels = im.convert("RGBA").tobytes("raw", "BGRA")
        chunk = struct.pack("<IIIIIIII", 36, 0xFFFD0002, nominal, 1, w, h, xhot, yhot)
        chunk += struct.pack("<I", 0)  # delay
        chunk += pixels
        toc.append((0xFFFD0002, nominal, pos))
        chunks.append(chunk)
        pos += len(chunk)
    buf = bytearray()
    buf += b"Xcur"
    buf += struct.pack("<III", header_size, 0x00010000, n)
    for typ, subtype, p in toc:
        buf += struct.pack("<III", typ, subtype, p)
    for c in chunks:
        buf += c
    return bytes(buf)


def cursor_base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (CURSOR_SIZE, CURSOR_SIZE), TRANSPARENT)
    return im, ImageDraw.Draw(im)


def outline_poly(d, pts, fill, outline, width=1):
    d.polygon(pts, fill=fill)
    # redraw outline as closed line
    d.line(pts + [pts[0]], fill=outline, width=width)


def make_cursors(out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    cs = CURSOR_SIZE
    fill, ol = VAULT_BLACK, PHOS

    def save(name, im, xhot, yhot):
        data = pack_xcursor([(im, cs, xhot, yhot)])
        (out / name).write_bytes(data)

    def link(src, *names):
        for n in names:
            dest = out / n
            if dest.exists() or dest.is_symlink():
                dest.unlink()
            os.symlink(src, dest)

    # left_ptr
    im, d = cursor_base()
    pts = [(1, 1), (1, 18), (6, 14), (10, 22), (13, 21), (8, 13), (15, 13)]
    outline_poly(d, pts, fill, ol)
    save("left_ptr", im, 1, 1)
    link("left_ptr", "default", "arrow", "top_left_arrow", "left_arrow")

    # hand2
    im, d = cursor_base()
    # palm
    d.polygon([(8, 10), (7, 22), (16, 22), (17, 12), (15, 10)], fill=fill, outline=ol)
    # fingers
    for x in (8, 11, 14):
        d.rectangle([x, 4, x + 2, 12], fill=fill, outline=ol)
    d.rectangle([6, 8, 8, 14], fill=fill, outline=ol)  # thumb
    save("hand2", im, 10, 4)
    link("hand2", "pointer", "pointing_hand", "hand1")

    # xterm
    im, d = cursor_base()
    d.rectangle([10, 3, 12, 20], fill=fill, outline=ol)
    d.rectangle([7, 3, 15, 5], fill=fill, outline=ol)
    d.rectangle([7, 18, 15, 20], fill=fill, outline=ol)
    save("xterm", im, 11, 12)
    link("xterm", "ibeam", "text", "vertical-text")

    # watch / wait
    im, d = cursor_base()
    d.ellipse([3, 3, 20, 20], fill=fill, outline=ol)
    d.line([(12, 12), (12, 7)], fill=ol, width=1)
    d.line([(12, 12), (16, 12)], fill=ol, width=1)
    save("watch", im, 12, 12)
    link("watch", "wait")

    # left_ptr_watch / progress
    im, d = cursor_base()
    pts = [(1, 1), (1, 16), (5, 13), (8, 20), (11, 19), (7, 12), (13, 12)]
    outline_poly(d, pts, fill, ol)
    d.ellipse([13, 13, 23, 23], fill=fill, outline=ol)
    save("left_ptr_watch", im, 1, 1)
    link("left_ptr_watch", "progress")

    # fleur / move
    im, d = cursor_base()
    d.polygon([(12, 1), (16, 6), (13, 6), (13, 10), (17, 10), (17, 7), (22, 12),
               (17, 17), (17, 14), (13, 14), (13, 18), (16, 18), (12, 23),
               (8, 18), (11, 18), (11, 14), (7, 14), (7, 17), (2, 12),
               (7, 7), (7, 10), (11, 10), (11, 6), (8, 6)], fill=fill, outline=ol)
    save("fleur", im, 12, 12)
    link("fleur", "move", "grabbing", "all-scroll", "size_all", "grab")

    # sb_h_double_arrow
    im, d = cursor_base()
    d.polygon([(1, 12), (8, 6), (8, 10), (16, 10), (16, 6), (23, 12),
               (16, 18), (16, 14), (8, 14), (8, 18)], fill=fill, outline=ol)
    save("sb_h_double_arrow", im, 12, 12)
    link("sb_h_double_arrow", "size_hor", "h_double_arrow", "ew-resize",
         "col-resize", "split_h", "e-resize", "w-resize", "left_side", "right_side",
         "02800600000000000600000000000000")

    # sb_v_double_arrow
    im, d = cursor_base()
    d.polygon([(12, 1), (18, 8), (14, 8), (14, 16), (18, 16), (12, 23),
               (6, 16), (10, 16), (10, 8), (6, 8)], fill=fill, outline=ol)
    save("sb_v_double_arrow", im, 12, 12)
    link("sb_v_double_arrow", "size_ver", "v_double_arrow", "ns-resize",
         "row-resize", "split_v", "n-resize", "s-resize", "top_side", "bottom_side",
         "00008100000000007700000000000000")

    # corners
    im, d = cursor_base()
    d.polygon([(4, 4), (18, 4), (18, 8), (8, 8), (8, 18), (4, 18)], fill=fill, outline=ol)
    save("top_left_corner", im, 5, 5)
    link("top_left_corner", "nw-resize", "ul_angle")

    im, d = cursor_base()
    d.polygon([(20, 4), (6, 4), (6, 8), (16, 8), (16, 18), (20, 18)], fill=fill, outline=ol)
    save("top_right_corner", im, 18, 5)
    link("top_right_corner", "ne-resize", "ur_angle", "nesw-resize", "fd_double_arrow")

    im, d = cursor_base()
    d.polygon([(4, 20), (4, 6), (8, 6), (8, 16), (18, 16), (18, 20)], fill=fill, outline=ol)
    save("bottom_left_corner", im, 5, 18)
    link("bottom_left_corner", "sw-resize", "ll_angle")

    im, d = cursor_base()
    d.polygon([(20, 20), (20, 6), (16, 6), (16, 16), (6, 16), (6, 20)], fill=fill, outline=ol)
    save("bottom_right_corner", im, 18, 18)
    link("bottom_right_corner", "se-resize", "lr_angle", "nwse-resize", "bd_double_arrow")

    # crossed_circle
    im, d = cursor_base()
    d.ellipse([2, 2, 21, 21], fill=fill, outline=ol)
    d.line([(6, 6), (17, 17)], fill=ol, width=2)
    save("crossed_circle", im, 12, 12)
    link("crossed_circle", "not-allowed", "dnd-no-drop", "no-drop", "circle", "forbidden")

    # pencil
    im, d = cursor_base()
    d.polygon([(4, 20), (6, 22), (20, 8), (18, 6)], fill=fill, outline=ol)
    d.polygon([(18, 6), (20, 8), (22, 4)], fill=fill, outline=ol)
    save("pencil", im, 4, 20)
    link("pencil", "draft")

    # crosshair
    im, d = cursor_base()
    d.rectangle([11, 2, 12, 22], fill=fill, outline=ol)
    d.rectangle([2, 11, 22, 12], fill=fill, outline=ol)
    save("crosshair", im, 12, 12)
    link("crosshair", "tcross", "cross")

    # plus / cell
    im, d = cursor_base()
    d.rectangle([11, 4, 13, 20], fill=fill, outline=ol)
    d.rectangle([4, 11, 20, 13], fill=fill, outline=ol)
    save("plus", im, 12, 12)
    link("plus", "cell", "cross_reverse")

    # question_arrow
    im, d = cursor_base()
    pts = [(1, 1), (1, 14), (5, 11), (8, 18), (11, 17), (7, 10), (13, 10)]
    outline_poly(d, pts, fill, ol)
    d.ellipse([14, 2, 23, 11], fill=fill, outline=ol)
    d.point((18, 13), fill=ol)
    save("question_arrow", im, 1, 1)
    link("question_arrow", "help", "whats_this", "draped_box")

    # copy
    im, d = cursor_base()
    pts = [(1, 1), (1, 14), (5, 11), (8, 18), (11, 17), (7, 10), (13, 10)]
    outline_poly(d, pts, fill, ol)
    d.rectangle([14, 14, 22, 22], fill=fill, outline=ol)
    d.line([(18, 16), (18, 20)], fill=ol, width=1)
    d.line([(16, 18), (20, 18)], fill=ol, width=1)
    save("copy", im, 1, 1)
    link("copy", "dnd-copy", "alias")

    (out.parent / "cursor.theme").write_text("[Icon Theme]\nName=Vault.OS\nInherits=core\n", encoding="utf-8")


def make_wallpaper(path: Path) -> None:
    import math
    w, h = 1920, 1080
    im = Image.new("RGB", (w, h), STEEL_950[:3])
    d = ImageDraw.Draw(im)
    # 8% phos over steel-950 (RGB blend — PIL RGB draw ignores alpha)
    grid = (
        int(STEEL_950[0] * 0.92 + PHOS[0] * 0.08),
        int(STEEL_950[1] * 0.92 + PHOS[1] * 0.08),
        int(STEEL_950[2] * 0.92 + PHOS[2] * 0.08),
    )
    for x in range(0, w, 8):
        d.line([(x, 0), (x, h - 1)], fill=grid)
    for y in range(0, h, 8):
        d.line([(0, y), (w - 1, y)], fill=grid)

    cx, cy = w // 2, h // 2
    d.ellipse([cx - 220, cy - 220, cx + 220, cy + 220], outline=GOLD_DIM[:3], width=4)
    d.ellipse([cx - 176, cy - 176, cx + 176, cy + 176], outline=GOLD_DIM[:3], width=2)
    for i in range(12):
        a = i * math.pi / 6
        x1 = cx + int(204 * math.cos(a))
        y1 = cy + int(204 * math.sin(a))
        x2 = cx + int(232 * math.cos(a))
        y2 = cy + int(232 * math.sin(a))
        d.line([(x1, y1), (x2, y2)], fill=GOLD_DIM[:3], width=10)

    def one(x, y, tw, th, stem, flag, base):
        # flag (top-left), stem, small base — reads as 1 not I
        d.rectangle([x, y + flag, x + flag, y + flag * 2], fill=GOLD_DIM[:3])
        d.rectangle([x + (tw - stem) // 2, y, x + (tw + stem) // 2, y + th], fill=GOLD_DIM[:3])
        d.rectangle([x, y + th - base, x + tw, y + th], fill=GOLD_DIM[:3])

    tw, th, gap = 72, 240, 48
    total = 3 * tw + 2 * gap
    x0 = cx - total // 2
    y0 = cy - th // 2
    for i in range(3):
        one(x0 + i * (tw + gap), y0, tw, th, 22, 22, 16)

    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")


def main() -> None:
    dirs_set = set()
    written = 0
    for ctx, name, glyph in ICONS:
        for size in SIZES:
            rel = f"{size}x{size}/{ctx}"
            dirs_set.add(rel)
            dest = ICON_SRC / rel
            dest.mkdir(parents=True, exist_ok=True)
            im = render_icon(glyph, size)
            im.save(dest / f"{name}.png", "PNG")
            written += 1

    dirs = sorted(dirs_set, key=lambda d: (int(d.split("x")[0]), d))
    write_index(ICON_SRC, dirs)
    make_cursors(ICON_SRC / "cursors")
    wall = WALL_SRC / "vault-111.png"
    make_wallpaper(wall)

    # live copies
    import shutil

    if LIVE_ICONS.exists():
        shutil.rmtree(LIVE_ICONS)
    shutil.copytree(ICON_SRC, LIVE_ICONS, ignore=shutil.ignore_patterns("gen_assets.py", "README.md"))
    LIVE_WALL.mkdir(parents=True, exist_ok=True)
    shutil.copy2(wall, LIVE_WALL / "vault-111.png")

    print(f"icons_png={written}")
    print(f"unique_names={len({n for _, n, _ in ICONS})}")
    print(f"source={ICON_SRC}")
    print(f"live_icons={LIVE_ICONS}")
    print(f"wallpaper={wall}")
    print(f"live_wall={LIVE_WALL / 'vault-111.png'}")
    print(f"cursors={(ICON_SRC / 'cursors')}")


if __name__ == "__main__":
    main()
