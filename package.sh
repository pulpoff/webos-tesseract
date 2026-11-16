#!/bin/sh
# Packages the build (./build-deps.sh, ./build.sh) into output/<id>_<version>_all.ipk, in the layout
# ares-package produces. The app folder holds:
# - tesseract, the game (appinfo.json's main), with its rpath on lib/;
# - lib/: SDL 2.30.12 (webosbrew's), SDL2_image and SDL2_mixer;
# - config/ and media/: Tesseract's scripts, shaders, maps, textures, models and sounds, with the
#   opaque PNG images as JPEG (tools/slim-media.py);
# - home/: the settings and maps the game saves, writable by the game's user;
# - the licenses: Tesseract's, Sauerbraten's, ENet's, and MEDIA-CHANGES.txt on the media.
# It also writes output/<id>.manifest.json for the Homebrew Channel.
set -e
cd "$(dirname "$0")"
TOP=$PWD
T=${WEBOS_TOOLCHAIN:-$TOP/toolchain/arm-webos-linux-gnueabi_sdk-buildroot}
TC=$T/bin/arm-webos-linux-gnueabi
P=$TOP/prefix
SRC=tesseract-src
export TMPDIR=$TOP/build/tmp
mkdir -p "$TMPDIR"
ID=$(sed -n 's/.*"id": *"\([^"]*\)".*/\1/p' app/appinfo.json)
VER=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' app/appinfo.json)

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
D=$W/data/usr/palm/applications/$ID
mkdir -p "$D/lib" "$W/data/usr/palm/packages/$ID" "$W/control"
# the icons under names that change with the picture: a launcher that keeps icons loaded (Luma does,
# by their file) shows a new one
cp app/appinfo.json "$D/"
for f in icon largeIcon; do
	h=$(sha1sum "app/$f.png" | cut -c1-8)
	cp "app/$f.png" "$D/$f-$h.png"
	sed -i "s|\"$f.png\"|\"$f-$h.png\"|" "$D/appinfo.json"
done
cp build/tesseract "$D/tesseract"
for l in libSDL2-2.0.so.0 libSDL2_image-2.0.so.0 libSDL2_mixer-2.0.so.0; do cp -L "$P/lib/$l" "$D/lib/"; done
# the media with its opaque PNG images as JPEG, which the TV's app storage has room for
python3 tools/slim-media.py "$SRC" build/data
# the app's cube (app/logo.jpg) as the game's logo in the main menu and the map browser
python3 tools/menu-logo.py app/logo.jpg build/data
cp -r build/data/config build/data/media "$D/"
cp "$SRC/src/readme_tesseract.txt" "$D/LICENSE"
cp "$SRC/src/readme_sauerbraten.txt" "$D/LICENSE-sauerbraten"
cp "$SRC/src/enet/LICENSE" "$D/LICENSE-enet"
cat > "$D/MEDIA-CHANGES.txt" <<'TXT'
The media in this package are Tesseract's, each under the license in the info.txt, readme.txt or
license.txt file beside it, with these changes for LG webOS TVs:
- the opaque PNG images in media/texture, media/sky and media/model are converted to JPEG (quality
  90, and 95 without chroma subsampling for normal maps), and the .cfg files naming them changed to
  match, so that the media fit the TV's app storage;
- media/interface/logo.png, logo_1024.png and cube.png are replaced with this app's logo.
TXT
# The game runs as its own user, and the app folder is root's: home/ holds what the game saves.
mkdir -p "$D/home"
chmod 777 "$D/home"

find "$D" -type f \( -name '*.so*' -o -name tesseract \) | while read -r f; do
	"$TC-strip" --strip-unneeded "$f"
	chmod 755 "$f"
done

# every symbol the binaries use must be defined in lib/ or on the TV (tools/check-symbols.py), given
# a copy of the TV's libraries in TV_ROOT (tools/fetch-tv-libs.sh root@<tv>); skipped without one.
R=${TV_ROOT:-build/tv-root}
if [ -d "$R" ]; then
	python3 tools/check-symbols.py "$TC-readelf" "$D" "$R"
fi

printf '{\n  "id": "%s",\n  "version": "%s",\n  "app": "%s"\n}\n' "$ID" "$VER" "$ID" > "$W/data/usr/palm/packages/$ID/packageinfo.json"
SIZE=$(du -sb "$W/data" | cut -f1)
cat > "$W/control/control" <<CTL
Package: $ID
Version: $VER
Section: misc
Priority: optional
Architecture: all
Installed-Size: $SIZE
Maintainer: N/A <nobody@example.com>
Description: This is a webOS application.
webOS-Package-Format-Version: 2
webOS-Packager-Version: x.y.x
CTL
printf '2.0\n' > "$W/debian-binary"
(cd "$W/control" && tar --owner=0 --group=0 -czf ../control.tar.gz control)
# ustar: paths over 100 characters go into its prefix field, as webOS's installer reads (GNU tar's
# own long names make it fail with error -5)
(cd "$W/data" && tar --format=ustar --owner=0 --group=0 -czf ../data.tar.gz usr)
mkdir -p output
OUT=output/${ID}_${VER}_all.ipk
rm -f "$OUT"
# webOS rejects GNU ar output (error -5), so write the ar container as ares-package does.
python3 - "$OUT" "$W/debian-binary" "$W/control.tar.gz" "$W/data.tar.gz" <<'PY'
import os, sys, time
out = open(sys.argv[1], 'wb'); out.write(b'!<arch>\n')
for p in sys.argv[2:]:
    data = open(p, 'rb').read()
    hdr = '%-16s%-12d%-6d%-6d%-8s%-10d`\n' % (os.path.basename(p), int(time.time()), 0, 0, '100644', len(data))
    out.write(hdr.encode()); out.write(data)
    if len(data) % 2: out.write(b'\n')
out.close()
PY
# The Homebrew Channel manifest; the release publishes it next to the IPK.
python3 - "$OUT" app/appinfo.json "output/$ID.manifest.json" <<'PY'
import hashlib, json, os, sys
ipk, info, out = sys.argv[1:]
a = json.load(open(info))
m = {
    "id": a["id"], "version": a["version"], "type": a["type"], "title": a["title"],
    "appDescription": "Tesseract, the first-person shooter with real-time global illumination, with the remote and game controllers",
    "iconUri": "https://raw.githubusercontent.com/pulpoff/webos-tesseract/main/app/largeIcon.png",
    "sourceUrl": "https://github.com/pulpoff/webos-tesseract",
    "rootRequired": False,
    "ipkUrl": os.path.basename(ipk),
    "ipkHash": {"sha256": hashlib.sha256(open(ipk, "rb").read()).hexdigest()},
}
json.dump(m, open(out, "w"), indent=2); open(out, "a").write("\n")
PY
echo "installed size: $((SIZE / 1048576)) MB"
ls -la "$OUT" "output/$ID.manifest.json"
