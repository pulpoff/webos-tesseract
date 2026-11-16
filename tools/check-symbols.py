#!/usr/bin/env python3
"""Checks that every symbol the packaged game needs is defined by a library it will find on the TV.

usage: check-symbols.py <readelf> <app dir> <tv root>

<app dir> is the unpacked app folder (lib/ beside the game); <tv root> holds copies of the TV's
libraries and its /etc/ld.so.conf (tools/fetch-tv-libs.sh). A library of the same name on the TV
may be older and lack a symbol, which only fails when the code runs. A symbol counts as found when
any library of the whole program (the game, lib/ and their system libraries) defines it.
"""
import os, re, subprocess, sys

readelf, app, tv = sys.argv[1:4]
SYS = ['/lib', '/usr/lib']
try:
    SYS += [l.strip() for l in open(os.path.join(tv, 'etc/ld.so.conf')) if l.strip().startswith('/')]
except OSError:
    pass

# symbols known to be missing and never called (none so far)
UNUSED = set()

def tvpath(path):
    """resolves a path on the TV, symlinks included, to its copy under <tv root>"""
    parts, seen = path.strip('/').split('/'), 0
    cur = ''
    while parts:
        cur = cur + '/' + parts.pop(0)
        local = tv + cur
        if os.path.islink(local):
            seen += 1
            if seen > 40:
                return None
            target = os.readlink(local)
            base = target if target.startswith('/') else os.path.dirname(cur) + '/' + target
            parts = os.path.normpath(base).strip('/').split('/') + parts
            cur = ''
    return tv + cur if os.path.exists(tv + cur) else None

def elf(path):
    with open(path, 'rb') as f:
        return f.read(4) == b'\x7fELF'

def dynamic(path):
    out = subprocess.run([readelf, '-d', '-W', path], capture_output=True, text=True).stdout
    return re.findall(r'\(NEEDED\).*\[(.*)\]', out)

def symbols(path):
    """(defined, undefined): defined as {name: set(versions)}, undefined as [(name, version)]"""
    out = subprocess.run([readelf, '--dyn-syms', '-W', path], capture_output=True, text=True).stdout
    defined, undefined = {}, []
    for line in out.splitlines():
        f = line.split()
        if len(f) < 8 or not f[0].endswith(':'):
            continue
        bind, ndx, name = f[4], f[6], f[7]
        if bind == 'LOCAL' or not name:
            continue
        base, _, ver = name.partition('@')
        ver = ver.lstrip('@')
        if ndx == 'UND':
            if bind != 'WEAK':
                undefined.append((base, ver))
        else:
            defined.setdefault(base, set()).add(ver)
    return defined, undefined

def find(lib):
    p = os.path.join(app, 'lib', lib)
    if os.path.exists(p):
        return os.path.realpath(p)
    for d in SYS:
        p = tvpath(d + '/' + lib)
        if p:
            return p
    return None

ours = []
for root, _, files in os.walk(app):
    for n in files:
        p = os.path.join(root, n)
        if not os.path.islink(p) and os.path.isfile(p) and elf(p):
            ours.append(p)

# the whole program's libraries, transitively
libs, todo, missing = {}, [], set()
for p in ours:
    todo += dynamic(p)
while todo:
    l = todo.pop()
    if l in libs or l in missing:
        continue
    p = find(l)
    if not p:
        missing.add(l)
        continue
    libs[l] = p
    todo += dynamic(p)

defined = {}
for p in ours + list(libs.values()):
    for name, vers in symbols(p)[0].items():
        defined.setdefault(name, set()).update(vers)

bad = 0
for l in sorted(missing):
    print('library not found: %s' % l); bad += 1
for p in sorted(ours):
    for name, ver in symbols(p)[1]:
        if name in UNUSED:
            continue
        if name not in defined:
            print('%s: %s%s undefined' % (os.path.relpath(p, app), name, '@' + ver if ver else '')); bad += 1
        elif ver and ver not in defined[name] and '' not in defined[name]:
            print('%s: %s@%s not on the TV (has %s)' % (os.path.relpath(p, app), name, ver,
                  ', '.join(sorted(defined[name])))); bad += 1
print('%d ELF files, %d libraries, %d problems' % (len(ours), len(libs), bad))
sys.exit(1 if bad else 0)
