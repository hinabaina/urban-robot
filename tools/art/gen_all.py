"""Пересобрать все спрайты: python3 tools/art/gen_all.py (нужен Pillow)."""
import tiles, sprites, machines, props, ui

for mod in (sprites, machines, props, tiles, ui):
    mod.build()
print("ok: assets/sprites")
