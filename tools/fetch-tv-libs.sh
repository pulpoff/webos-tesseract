#!/bin/sh
# Copies the TV's shared libraries into build/tv-root for tools/check-symbols.py: those directly in
# /lib, /usr/lib and the folders /etc/ld.so.conf names (OpenSSL 1.1 lives in /usr/openssl-1.1/lib),
# plus ld.so.conf itself. usage: tools/fetch-tv-libs.sh root@<tv address>
set -e
cd "$(dirname "$0")/.."
[ -n "$1" ] || { echo "usage: $0 root@<tv address>" >&2; exit 1; }
rm -rf build/tv-root
mkdir -p build/tv-root
ssh "$1" 'cd / && { echo etc/ld.so.conf; for d in lib usr/lib $(grep "^/" etc/ld.so.conf | sed "s|^/||"); do
	[ -d "$d" ] && find "$d" -maxdepth 1 -name "*.so*"; done; } | sort -u | tar -cf - -T -' | tar -xf - -C build/tv-root
du -sh build/tv-root
