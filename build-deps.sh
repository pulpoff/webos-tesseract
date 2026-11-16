#!/bin/sh
# Cross-compiles what Tesseract needs that webOS doesn't have into prefix/, for 32-bit ARM
# (Cortex-A55, softfp, like webOS's userland):
# - SDL 2.30.12 for webOS (webosbrew's build, the one RetroArch and ioquake3 ship), unpacked as is;
# - SDL2_image with its own PNG and JPEG decoders (stb_image);
# - SDL2_mixer with WAV and Ogg Vorbis (stb_vorbis).
# zlib and OpenGL ES 3.2 come from the toolchain's sysroot, as the TV has them.
# On the first run it downloads the openlgtv webOS toolchain into toolchain/.
set -e
cd "$(dirname "$0")"
TOP=$PWD
T=${WEBOS_TOOLCHAIN:-$TOP/toolchain/arm-webos-linux-gnueabi_sdk-buildroot}
TC_URL=https://github.com/openlgtv/buildroot-nc4/releases/download/2026.08-webos/arm-webos-linux-gnueabi_sdk-buildroot-x86_64.tar.gz
if [ ! -x "$T/bin/cmake" ]; then
	mkdir -p toolchain
	curl -fL "$TC_URL" | tar -xz -C toolchain
	"$T/relocate-sdk.sh"
fi
SYSROOT=$T/arm-webos-linux-gnueabi/sysroot
P=$TOP/prefix
B=$TOP/build/deps
D=$TOP/downloads
export TMPDIR=$TOP/build/tmp
mkdir -p "$P/lib" "$P/include" "$B" "$D" "$TMPDIR"
ARCH="-mcpu=cortex-a55 -mfpu=neon-fp-armv8 -mfloat-abi=softfp"
CF="$ARCH -O2 -fPIC"
J=$(nproc)

fetch() { # url sha256 [name]
	f=$D/${3:-$(basename "$1")}
	[ -f "$f" ] || curl -fL -o "$f" "$1"
	echo "$2  $f" | sha256sum -c - >/dev/null || { echo "checksum mismatch: $f" >&2; exit 1; }
	echo "$f"
}
unpack() { # tarball dir
	rm -rf "$B/$2"; mkdir -p "$B/$2"; tar -xzf "$1" -C "$B/$2" --strip-components=1
}
cm() { # srcdir builddir [cmake args...]
	s=$1 b=$2; shift 2
	"$T/bin/cmake" -S "$s" -B "$b" -DCMAKE_TOOLCHAIN_FILE="$T/share/buildroot/toolchainfile.cmake" \
		-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$P" \
		-DCMAKE_FIND_ROOT_PATH="$P;$SYSROOT" -DCMAKE_PREFIX_PATH="$P" \
		-DCMAKE_C_FLAGS="$CF" -DCMAKE_CXX_FLAGS="$CF" -DCMAKE_POSITION_INDEPENDENT_CODE=ON "$@" >"$b.log" 2>&1 ||
		{ tail -30 "$b.log"; exit 1; }
	"$T/bin/cmake" --build "$b" -j"$J" >>"$b.log" 2>&1 || { tail -30 "$b.log"; exit 1; }
	"$T/bin/cmake" --install "$b" >>"$b.log" 2>&1
}
step() { [ -f "$B/.done-$1" ] && { echo "= $1 (done)"; return 1; }; echo "= $1"; }
done_() { touch "$B/.done-$1"; }

if step sdl2; then
	f=$(fetch https://github.com/webosbrew/SDL-webOS/releases/download/release-2.30.12-webos.1/SDL2-2.30.12-webos-abi.tar.gz \
		b43c05b26c0a0431a2b26a9b7036a24d8a34989441aeb87dd2825c1b50cbe83b)
	tar -xzf "$f" -C "$P"
	sed -i "s|^prefix=.*|prefix=$P|" "$P/lib/pkgconfig/sdl2.pc"
	done_ sdl2
fi

if step sdl2_image; then
	f=$(fetch https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.2/SDL2_image-2.8.2.tar.gz \
		8f486bbfbcf8464dd58c9e5d93394ab0255ce68b51c5a966a918244820a76ddc)
	unpack "$f" sdl2_image
	cm "$B/sdl2_image" "$B/sdl2_image-build" -DBUILD_SHARED_LIBS=ON -DSDL2IMAGE_VENDORED=OFF -DSDL2IMAGE_SAMPLES=OFF \
		-DSDL2IMAGE_BACKEND_STB=ON -DSDL2IMAGE_PNG=ON -DSDL2IMAGE_JPG=ON -DSDL2IMAGE_TGA=ON -DSDL2IMAGE_BMP=ON \
		-DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_JXL=OFF -DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_WEBP=OFF -DSDL2IMAGE_GIF=OFF \
		-DSDL2IMAGE_LBM=OFF -DSDL2IMAGE_PCX=OFF -DSDL2IMAGE_PNM=OFF -DSDL2IMAGE_QOI=OFF -DSDL2IMAGE_SVG=OFF \
		-DSDL2IMAGE_XCF=OFF -DSDL2IMAGE_XPM=OFF -DSDL2IMAGE_XV=OFF
	done_ sdl2_image
fi

if step sdl2_mixer; then
	f=$(fetch https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.0/SDL2_mixer-2.8.0.tar.gz \
		1cfb34c87b26dbdbc7afd68c4f545c0116ab5f90bbfecc5aebe2a9cb4bb31549)
	unpack "$f" sdl2_mixer
	cm "$B/sdl2_mixer" "$B/sdl2_mixer-build" -DBUILD_SHARED_LIBS=ON -DSDL2MIXER_VENDORED=OFF -DSDL2MIXER_SAMPLES=OFF \
		-DSDL2MIXER_VORBIS=STB -DSDL2MIXER_OPUS=OFF -DSDL2MIXER_FLAC=OFF -DSDL2MIXER_MOD=OFF -DSDL2MIXER_MIDI=OFF \
		-DSDL2MIXER_MP3=OFF -DSDL2MIXER_WAVPACK=OFF -DSDL2MIXER_GME=OFF -DSDL2MIXER_CMD=OFF -DSDL2MIXER_WAVE=ON
	done_ sdl2_mixer
fi
echo "dependencies in $P"
