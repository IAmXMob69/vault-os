# xfwm resize/drag fix (v8)

## Cause
PipBoy-NV window borders were only **3×3 / 3×16 px**, so resize grips were almost impossible to hit and frame chrome felt broken.

## Fix
Regenerated theme with usable grips:
- sides **8 px**, bottom **8 px**, corners **16×16**
- title bar **30 px** tall (draggable)
- Pip-Boy CRT colors retained

## If still stuck
```bash
xfconf-query -c xfwm4 -p /general/theme -s Default
xfconf-query -c xfwm4 -p /general/theme -s PipBoy-NV
# or:
xfwm4 --replace &
```
Hold **Alt** and drag anywhere on a window to move (easy_click).
