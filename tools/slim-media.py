#!/usr/bin/env python3
"""slim-media.py <tesseract-src> <out>: copies Tesseract's media/ into <out>/media, with the opaque
PNG images of its textures, skies and models as JPEG, and the configs that name them updated.

The TV's app storage can't hold Tesseract's 250 MB of PNG textures: as JPEG (quality 90, and 95
without chroma subsampling for normal maps) they take a fraction of that. Images with transparency
stay PNG, as do the water caustics and media/texture/game/ (notexture.png), which the engine
loads by their PNG names.
"""
import os
import re
import shutil
import sys

from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
CONVERT = ('media/texture/', 'media/sky/', 'media/model/')
KEEP = ('media/texture/mat_water/caustic/', 'media/texture/game/')
NORMAL = re.compile(r'_(normal|nm|norm|n|bump|local)\.png$', re.I)

renamed = set()
before = after = 0
for root, _, files in os.walk(os.path.join(SRC, 'media')):
    for f in sorted(files):
        path = os.path.join(root, f)
        rel = os.path.relpath(path, SRC).replace(os.sep, '/')
        dst = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        size = os.path.getsize(path)
        before += size
        if f.lower().endswith('.png') and rel.startswith(CONVERT) and not rel.startswith(KEEP):
            jpg = dst[:-4] + '.jpg'
            # converted on an earlier run
            if os.path.exists(jpg) and os.path.getmtime(jpg) >= os.path.getmtime(path):
                renamed.add(rel)
                after += os.path.getsize(jpg)
                continue
            if os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(path):
                after += size
                continue
            im = Image.open(path)
            im.load()
            if 'A' in im.getbands() or 'transparency' in im.info:
                alpha = im.convert('RGBA').getchannel('A')
                if alpha.getextrema()[0] < 255:
                    shutil.copy2(path, dst)
                    after += size
                    continue
            im = im.convert('L' if im.mode in ('L', 'LA', 'I;16', 'I') else 'RGB')
            if NORMAL.search(f):
                im.save(jpg, quality=95, subsampling=0, optimize=True)
            else:
                im.save(jpg, quality=90, optimize=True)
            renamed.add(rel)
            after += os.path.getsize(jpg)
        else:
            if not (os.path.exists(dst) and os.path.getmtime(dst) >= os.path.getmtime(path)):
                shutil.copy2(path, dst)
            after += size

# config/ as it is, then the scripts naming the converted images fixed
shutil.copytree(os.path.join(SRC, 'config'), os.path.join(OUT, 'config'), dirs_exist_ok=True)

# the scripts naming the converted images: names are relative to the script's folder (models), to
# media/texture/ (textures) or to the data folder
TOKEN = re.compile(r'[\w./\-]+\.png', re.I)
unresolved = set()


def fix(text, base):
    def sub(m):
        tok = m.group(0)
        for c in (os.path.join(base, tok), os.path.join('media/texture', tok), os.path.join('media', tok), tok):
            c = os.path.normpath(c).replace(os.sep, '/')
            if c in renamed:
                return tok[:-4] + '.jpg'
            if os.path.exists(os.path.join(SRC, c)):
                return tok
        unresolved.add(tok)
        return tok
    return TOKEN.sub(sub, text)


for top in ('media', 'config'):
    for root, _, files in os.walk(os.path.join(OUT if top == 'media' else SRC, top)):
        for f in files:
            if not f.endswith(('.cfg', '.tex')):
                continue
            path = os.path.join(root, f)
            rel_dir = os.path.relpath(root, OUT if top == 'media' else SRC).replace(os.sep, '/')
            text = open(path, encoding='latin-1').read()
            new = fix(text, rel_dir)
            if new != text:
                dst = os.path.join(OUT, os.path.relpath(path, OUT if top == 'media' else SRC))
                open(dst, 'w', encoding='latin-1').write(new)

print(f'media: {before / 1e6:.0f} MB -> {after / 1e6:.0f} MB, {len(renamed)} images as JPEG')
if unresolved:
    print('names not found:', ' '.join(sorted(unresolved)[:40]))
