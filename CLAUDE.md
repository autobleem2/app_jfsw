# app_jfsw - developer context

**JFSW** (Jonathon Fowler's port of Shadow Warrior) packaged as an AutoBleem App: `Apps/shadowwarrior/`, Store id
`app/shadowwarrior` (the RetroBoot App's folder and id, so the Store updates it in place on psc), one zip per
platform (`dist/shadowwarrior-<key>-<version>.zip`), with the v1.2 shareware episode. Started 2026-09-25, the
fifth third-party App port (autobleem-main `docs/decisions.md`, "Third-party App ports" - the rules;
`app_opentyrian`'s CLAUDE.md is the template).

## The owner's decisions for this port (2026-09-25)

- **Upstream**: `jonof/jfsw` pinned at tag `20260105`, with its own submodules (jfbuild, jfmact, jfaudiolib -
  relative URLs, `../<name>.git` on github.com/jonof). The package version is `20260105-1` (`VERSION`).
- **The 2020 layout** (`patches/jfsw/0001-psc-pad-layout.patch`, JFSW's "classic" default tables in
  `_functio.h`): Square fire, Cross crouch (double press: AutoRun), Circle open, Triangle jump, Select use item,
  Start menu (double press: map), L1 next item, R1 next weapon, L2/R2 strafe (the digital axes 4 and 5,
  positive), the D-pad move/turn, left stick turn/move, right stick strafe/look. Upstream's classic set put the
  D-pad on aiming and looking - the console's own pad could not move.
- **The software renderer everywhere** (`USE_POLYMOST=0 USE_OPENGL=0`): the console has no desktop GL, and one
  code path is less to go wrong.

## Layout

| path | what |
|---|---|
| `upstream/jfsw` | the pinned upstream source (submodule, with nested submodules) |
| `patches/jfsw/0001-psc-pad-layout.patch` | the default pad tables (above). The button order is SDL's GameController order, which the Win32 layer also uses for XInput (`winlayer.c` shuffles XInput into it, triggers on axes 4/5) - one table for every platform. |
| `patches/jfsw/0002-nosetup-on-the-first-start.patch` | `-nosetup` wins even when there is no config yet (upstream shows the setup window then regardless) - a pad-driven launcher cannot click through it |
| `patches/jfsw/0003-no-start-window-with-nosetup.patch` | with `-nosetup` on the command line the start window (a start-up log that flashed on screen - the owner saw it) is not created at all; the rest of `startwin_game.c` copes with no window |
| `resources/` | `app.ini` (`Exec=bin/{key}/sw`, `Args=-nosetup`, no `Lib`, `VirtualPad=true`), `readme.txt`, `icon.png` |
| `ci/build.sh` | `native|psc|rpi|rpi64|pcusb|win|all`: the data from our mirror, then upstream's Makefile with everything on its command line - `PLATFORM`, `RENDERTYPE` (SDL on Linux, **WIN on Windows**), CPU flags on `CC`/`CXX` (not `CFLAGS`: `bin2c` is built with `HOSTCXX=g++` and run during the build), a generated `sdl2-config` for the target, `PKGCONFIG=false` (so jfaudiolib takes SDL audio only - no ALSA, Vorbis or FluidSynth to ship; GTK off too), a `git` on `PATH` that answers `describe` with the upstream tag (the version stamps; `version.c` still says "(not set)" - that is upstream's fallback file, harmless) |
| `tools/make_icon.py` | draws the icon from the game's own title screen (TITLE_PIC, tile 2324, out of sw.grp's TILESnnn.ART in PALETTE.DAT's colours), fitted to the width - the words run to its edges |
| `tools/store_item.py`, `tools/check_psc_binary.sh`, `tools/check_needed.sh` | as in the other ports |

## Things to know

- **Windows is upstream's native build** (`RENDERTYPE=WIN`: Win32 video, XInput pads, XAudio2 sound with its
  bundled static Vorbis) - no SDL at all, so none of the launcher's DLLs is needed. `RENDERTYPE=SDL` does not
  link on Windows: `startwin_game.c` is Win32-only. The C++ runtime and winpthread are linked statically.
  Run on the dev PC on 2026-09-25: full screen, 4:3, correct (the owner watched), no setup window after the
  two patches.
- **Portable mode**: an empty `user_profiles_disabled` in the App folder makes JFSW keep `sw.cfg`, the saves,
  `grpfiles.cache` and `sw.log` there (upstream's own switch).
- **The data**: `mirror/jfsw/sw-shareware-1.2.zip` (sw.grp + sw.rts, the files of the 2020 package; sw.grp's
  CRC32 0x08A7FA1F is JFSW's "Shareware Version" in `grpscan.c`).
- **The picture**: 640x480, 8-bit, full screen - the engine scales its frame to the display's height at the
  frame's aspect, so no arguments are needed (checked before copying anything from 2020 - see Wolf4SDL).
- **Build on the server**: sync with MSYS2's rsync (excluding `/build_*`, `/dist`), then
  `docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all`.
- **Not yet run**: on a console, a Pi or the PC stick (the tester checklist).
