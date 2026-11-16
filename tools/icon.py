#!/usr/bin/env python3
"""icon.py <logo> <app-dir>: the app's icons (icon.png 80 px, largeIcon.png 130 px) from the logo
(app/logo.jpg, the cube on black): the cube centred on a black rounded tile, as the Quake III
port's icons are."""
import sys

from PIL import Image, ImageDraw

LOGO, APP = sys.argv[1], sys.argv[2]
logo = Image.open(LOGO).convert('RGB')
# the cube and its glow, found by brightness, in a black square around it
x0, y0, x1, y1 = logo.convert('L').point(lambda v: 255 if v > 30 else 0).getbbox()
side = int(max(x1 - x0, y1 - y0)/0.88)
square = Image.new('RGB', (side, side), (0, 0, 0))
square.paste(logo, (side//2 - (x0 + x1)//2, side//2 - (y0 + y1)//2))

for name, size in (('icon.png', 80), ('largeIcon.png', 130)):
    big = size*4
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big*0.175), fill=255)
    tile = square.resize((big, big), Image.LANCZOS).convert('RGBA')
    tile.putalpha(mask)
    tile.resize((size, size), Image.LANCZOS).save(f'{APP}/{name}')
