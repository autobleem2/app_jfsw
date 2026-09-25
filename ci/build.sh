#!/usr/bin/env bash
# Builds JFSW (Shadow Warrior) in the autobleem-build image (ghcr.io/autobleem2/autobleem-build) and packages it as the
# AutoBleem App Apps/shadowwarrior/ with the shareware episode (sw.grp v1.2):
#
#   ci/build.sh native                    a host build (build_native/)
#   ci/build.sh psc|rpi|rpi64|pcusb|win   a target -> dist/shadowwarrior-<key>-<version>.zip
#   ci/build.sh all                       every one of them
#
# upstream/jfsw is a pinned submodule (with its own jfbuild, jfmact and jfaudiolib submodules), never edited: each
# build copies it and applies patches/jfsw/*.patch (CLAUDE.md). The classic software renderer only (USE_POLYMOST=0,
# the owner's choice - the console has no desktop OpenGL). SDL2 is the launcher's (the console, Windows) or the
# system's (the Pis, the PC stick); the audio library is told there is no pkg-config, so it takes SDL's audio
# and nothing else (no ALSA, Vorbis or FluidSynth to ship). The game data comes from our mirror, sha256-pinned.
#
# On the build server: docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src \
#                          ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

APP=shadowwarrior
VERSION="${AB_VERSION:-$(tr -d '\r' < VERSION)}"
JOBS="${JOBS:-$(nproc)}"
PSC=${AB_PSC_TOOLCHAIN:-/opt/psc}
MINGW_SDL2=${AB_MINGW_SDL2:-/opt/mingw-sdl2}
MIRROR="${AB_MIRROR_URL:-https://autobleem.retromenele.pl/mirror}"
UPSTREAM_VERSION=$(git -C upstream/jfsw describe --tags --always 2>/dev/null || echo 20260105)
DATA=sw-shareware-1.2.zip
DATA_SHA=326f6502b8dbf7fa72c438e1932e0edc5852fd33ab2649244011df1bc3c45f96

banner() { printf '\n==== %s ====\n' "$*"; }

fetch_data() {
    mkdir -p build_data
    local zip="build_data/$DATA"
    if ! { [ -f "$zip" ] && echo "$DATA_SHA  $zip" | sha256sum -c --quiet - 2>/dev/null; }; then
        banner "data: $DATA (our mirror)"
        curl -fsSL -o "$zip" "$MIRROR/jfsw/$DATA"
        echo "$DATA_SHA  $zip" | sha256sum -c -
    fi
}

# ---------------------------------------------------------------------------------------------------------
# One target. Each target_* sets CC, CXX, STRIP, PLATFORM_T, CFLAGS_T, SDL_CFLAGS, SDL_LIBS, EXTRA_LDFLAGS, EXE
# ---------------------------------------------------------------------------------------------------------
pc_sdl() { SDL_CFLAGS=$("$1" --cflags sdl2); SDL_LIBS=$("$1" --libs sdl2); }
target_native() {
    CC=gcc; CXX=g++; STRIP=strip; PLATFORM_T=LINUX; CFLAGS_T=""; EXTRA_LDFLAGS=""; EXE=sw
    pc_sdl pkg-config
}
target_psc() {
    CC="$PSC/bin/armv8-sony-linux-gnueabihf-gcc"; CXX="$PSC/bin/armv8-sony-linux-gnueabihf-g++"
    STRIP="$PSC/bin/armv8-sony-linux-gnueabihf-strip"; PLATFORM_T=LINUX; EXTRA_LDFLAGS=""; EXE=sw
    CFLAGS_T="-mfloat-abi=hard -march=armv8-a -mfpu=neon-vfpv4"
    SDL_CFLAGS=$(PKG_CONFIG_LIBDIR="$PSC/sdl2/lib/pkgconfig" pkg-config --cflags sdl2)
    SDL_LIBS=$(PKG_CONFIG_LIBDIR="$PSC/sdl2/lib/pkgconfig" pkg-config --libs sdl2)
}
target_rpi() {
    CC=arm-linux-gnueabihf-gcc; CXX=arm-linux-gnueabihf-g++; STRIP=arm-linux-gnueabihf-strip
    PLATFORM_T=LINUX; CFLAGS_T="-mfloat-abi=hard -mfpu=neon-vfpv4 -march=armv7-a"; EXTRA_LDFLAGS=""; EXE=sw
    pc_sdl arm-linux-gnueabihf-pkg-config
}
target_rpi64() {
    CC=aarch64-linux-gnu-gcc; CXX=aarch64-linux-gnu-g++; STRIP=aarch64-linux-gnu-strip
    PLATFORM_T=LINUX; CFLAGS_T="-march=armv8-a"; EXTRA_LDFLAGS=""; EXE=sw
    pc_sdl aarch64-linux-gnu-pkg-config
}
target_pcusb() {
    CC=i686-linux-gnu-gcc; CXX=i686-linux-gnu-g++; STRIP=i686-linux-gnu-strip
    PLATFORM_T=LINUX; CFLAGS_T="-march=i686 -mtune=generic -D_FILE_OFFSET_BITS=64"; EXTRA_LDFLAGS=""; EXE=sw
    pc_sdl i386-linux-gnu-pkg-config
}
target_win() {
    # upstream's own Windows build (RENDERTYPE=WIN): its Win32 layer draws, reads an XInput pad - shuffled into
    # SDL's button order, triggers on axes 4/5, so the layout patch fits it unchanged - and shows the setup
    # window that -nosetup skips (that window only builds with the Win32 layer, so SDL is not an option here).
    # No SDL at all; the audio is upstream's XAudio2 with its bundled static Vorbis. The C++ runtime and
    # winpthread go in statically - nothing else ships them.
    CC=x86_64-w64-mingw32-gcc; CXX=x86_64-w64-mingw32-g++; STRIP=x86_64-w64-mingw32-strip
    PLATFORM_T=WINDOWS; RENDER_T=WIN; CFLAGS_T=""; EXE=sw.exe
    SDL_CFLAGS=""; SDL_LIBS=""
    EXTRA_LDFLAGS="-static-libgcc -static-libstdc++ -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive,-Bdynamic"
}

build_target() { # build_target <key>
    local key="$1" dir="build_$1"
    banner "$key ($dir)"
    RENDER_T=SDL
    "target_$key"
    rm -rf "$dir"
    mkdir -p "$dir"
    cp -r upstream/jfsw "$dir/src"
    find "$dir/src" -name .git -prune -exec rm -rf {} +
    for p in patches/jfsw/*.patch; do
        [ -f "$p" ] || continue
        echo "patch: $p"
        patch -d "$dir/src" -p1 --no-backup-if-mismatch < "$p"
    done
    # an sdl2-config that answers for this target: the engine and the audio library both ask one
    cat > "$dir/sdl2-config" <<EOF
#!/bin/sh
case "\$1" in
    --cflags) echo "$SDL_CFLAGS" ;;
    --libs) echo "$SDL_LIBS" ;;
    --version) echo 2.0.14 ;;
esac
EOF
    chmod +x "$dir/sdl2-config"
    # the version stamps (version-auto.c, remade on every build) come from `git describe`, which has no
    # repository in this copy: a git that answers with the pinned upstream tag
    mkdir -p "$dir/bin"
    printf '#!/bin/sh\necho %s\n' "$UPSTREAM_VERSION" > "$dir/bin/git"
    chmod +x "$dir/bin/git"
    # the CPU flags ride on CC/CXX rather than CFLAGS: bin2c is built with HOSTCXX (the image's own g++) and
    # run during the build, and must not get the target's flags
    PATH="$ROOT/$dir/bin:$PATH" make -C "$dir/src" -j "$JOBS" "$EXE" \
        PLATFORM="$PLATFORM_T" RENDERTYPE="${RENDER_T:-SDL}" CC="$CC $CFLAGS_T" CXX="$CXX $CFLAGS_T" HOSTCC=gcc HOSTCXX=g++ \
        RC=x86_64-w64-mingw32-windres \
        SDL2CONFIG="$ROOT/$dir/sdl2-config" PKGCONFIG=false \
        USE_POLYMOST=0 USE_OPENGL=0 USE_ASM=0 RELEASE=1 \
        LDFLAGS="$EXTRA_LDFLAGS" >/dev/null

    local stage="$dir/Apps/$APP"
    mkdir -p "$stage/bin/$key"
    cp "$dir/src/$EXE" "$stage/bin/$key/"
    "$STRIP" "$stage/bin/$key/$EXE"
    cp resources/app.ini resources/readme.txt resources/icon.png "$stage/"
    # upstream's portable mode: settings and saves in the folder the game is started in (the App's)
    touch "$stage/user_profiles_disabled"
    cp "$dir/src/GPL.TXT" "$stage/COPYING-jfsw.txt"
    cp "$dir/src/jfbuild/buildlic.txt" "$stage/LICENSE-build-engine.txt" 2>/dev/null || true
    python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "build_data/$DATA" "$stage"
    sed -i "s/^Version=.*/Version=$VERSION/" "$stage/app.ini"
}

package() { # package <key>
    local key="$1" dir="build_$1"
    mkdir -p dist
    local zip="dist/$APP-$key-$VERSION.zip"
    rm -f "$zip"
    (cd "$dir" && python3 - "$ROOT/$zip" "$APP" <<'EOF'
import os, sys, zipfile
# every file under Apps/<app>, with its mode (the program stays executable where the filesystem keeps it)
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(os.path.join("Apps", sys.argv[2])):
        dirs.sort()
        for name in sorted(files):
            z.write(os.path.join(root, name))
EOF
    )
    ls -l "$zip"
}

check() { # check <key>: the program is the platform's and needs nothing we do not ship
    local key="$1" stage="build_$1/Apps/$APP"
    case "$key" in
        psc)
            file "$stage/bin/psc/sw" | grep -q 'ELF 32-bit LSB.*ARM'
            bash tools/check_psc_binary.sh "$stage/bin/psc/sw" "$PSC" ;;
        rpi) file "$stage/bin/rpi/sw" | grep -q 'ELF 32-bit LSB.*ARM' ;;
        rpi64) file "$stage/bin/rpi64/sw" | grep -q 'ELF 64-bit LSB.*aarch64' ;;
        pcusb) file "$stage/bin/pcusb/sw" | grep -q 'ELF 32-bit LSB.*Intel 80386' ;;
        win) file "$stage/bin/win/sw.exe" | grep -q 'PE32+ executable.*x86-64' ;;
    esac
    bash tools/check_needed.sh "$key" "$stage"
}

build_native() {
    fetch_data
    build_target native
    ls -l "build_native/Apps/$APP/bin/native/"
}

build_one() { # build_one <key>
    fetch_data
    build_target "$1"
    check "$1"
    package "$1"
}

[ $# -gt 0 ] || { echo "usage: $0 native|psc|rpi|rpi64|pcusb|win|all" >&2; exit 2; }
for target in "$@"; do
    case "$target" in
        native) build_native ;;
        psc | rpi | rpi64 | pcusb | win) build_one "$target" ;;
        all) build_native; for k in psc rpi rpi64 pcusb win; do build_one "$k"; done ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
    esac
done
