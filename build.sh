#!/bin/sh
# Builds Tesseract's client for webOS into build/tesseract, against prefix/ (./build-deps.sh first).
# On the first run it fetches Tesseract into tesseract-src/ at the pinned commit (the GitHub mirror
# of its SVN) and applies patches/tesseract-webos.patch: the renderer on OpenGL ES 3.2, the remote
# and the TV. Run ./package.sh afterwards.
set -e
cd "$(dirname "$0")"
TOP=$PWD
T=${WEBOS_TOOLCHAIN:-$TOP/toolchain/arm-webos-linux-gnueabi_sdk-buildroot}
TC=$T/bin/arm-webos-linux-gnueabi

TESSERACT_COMMIT=db03fcbf57daf806ebcc4dfae1781b5ad3c61a63
if [ ! -d tesseract-src/.git ]; then
	git init -q tesseract-src
	git -C tesseract-src fetch -q --depth 1 https://github.com/redeclipse/tesseract.git "$TESSERACT_COMMIT"
	git -C tesseract-src checkout -q FETCH_HEAD
	git -C tesseract-src apply ../patches/tesseract-webos.patch
fi

mkdir -p build
make -s -f webos/tesseract.mk -j"$(nproc)" TESSERACT="$TOP/tesseract-src" PREFIX="$TOP/prefix" \
	OBJ="$TOP/build/obj" OUT="$TOP/build/tesseract" CXX="$TC-g++" CC="$TC-gcc" \
	ARCH="-mcpu=cortex-a55 -mfpu=neon-fp-armv8 -mfloat-abi=softfp" "$@"
echo "built build/tesseract"
