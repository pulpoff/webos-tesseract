#!/usr/bin/env python3
"""menu-logo.py <logo> <out>: the app's cube (app/logo.jpg, on black) as Tesseract's own logos, in
<out>/media/interface/:
- logo_1024.png and logo.png, the main menu's logo (drawn in a 2:1 box over the top half of the
  screen), with the cube alone, centred, clear of the menu below it;
- cube.png, which the map browser shows for maps without a picture.
The cube is the image as it is, its black background made transparent: solid inside the cube's
outline, and its glow outside it kept as light."""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

LOGO, OUT = sys.argv[1:3]
img = Image.open(LOGO).convert('RGB')
w, h = img.size

# solid inside the outline: each row filled between its outermost bright pixels (the outline is
# convex and bright)
lum = img.convert('L').load()
solid = Image.new('L', img.size, 0)
sd = ImageDraw.Draw(solid)
for y in range(h):
    xs = [x for x in range(w) if lum[x, y] > 90]
    if xs:
        sd.line((xs[0] + 2, y, xs[-1] - 2, y), fill=255)
solid = solid.filter(ImageFilter.GaussianBlur(1.5))

# outside it the glow, as light over black: as opaque as it is bright, its colour unpremultiplied
r, g, b = img.split()
glow = ImageChops.lighter(ImageChops.lighter(r, g), b).point(lambda v: min(255, int(v*1.3)))
alpha = ImageChops.lighter(solid, glow)
cube = img.convert('RGBA')
cube.putalpha(alpha)
px, ap, sp = cube.load(), alpha.load(), solid.load()
for y in range(h):
    for x in range(w):
        a = ap[x, y]
        if 0 < a < 255 and sp[x, y] < 250:
            cr, cg, cb, _ = px[x, y]
            k = 255.0/a
            px[x, y] = (min(255, int(cr*k)), min(255, int(cg*k)), min(255, int(cb*k)), a)
cube = cube.crop(alpha.point(lambda v: 255 if v > 8 else 0).getbbox())


def fitted(height):
    k = height/cube.height
    return cube.resize((round(cube.width*k), height), Image.LANCZOS)


os.makedirs(f'{OUT}/media/interface', exist_ok=True)

# the menu: rows 30-310 of 512, centred
logo = Image.new('RGBA', (1024, 512), (0, 0, 0, 0))
c = fitted(280)
logo.alpha_composite(c, ((1024 - c.width)//2, 30))
logo.save(f'{OUT}/media/interface/logo_1024.png')
logo.resize((512, 256), Image.LANCZOS).save(f'{OUT}/media/interface/logo.png')

# the map browser's stand-in picture
square = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
c = fitted(round(240*cube.height/max(cube.size)))
square.alpha_composite(c, ((256 - c.width)//2, (256 - c.height)//2))
square.save(f'{OUT}/media/interface/cube.png')
