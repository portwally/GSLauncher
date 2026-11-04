#!/bin/bash
# Boots GSLauncher in MAME (from Ample): a copy of your System 6 disk with
# the apps installed by install.sh, and GSLauncher in the Finder's place, so
# GS/OS starts it as soon as it has booted (its slots file beside it).
#   BOOT_DISK    System 6 hard disk image (copied, never changed)
#   RUN_SECONDS  emulated seconds to run (default 60)
#   KEYS, SHOTS  see test/dump.lua
#   SLOTS        a slots file to use (default: slots.txt); SLOTS=none: none
# Pictures of the screen: build/test/screens/*.png. The disk as the
# program left it: build/test/after.po.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT_DISK="${BOOT_DISK:-$HOME/Roms/apple2gs/My GS Apps.hdv}"
RUN_SECONDS="${RUN_SECONDS:-60}"
MAME="${MAME:-/Applications/Emulatoren/Ample.app/Contents/MacOS/mame64}"
ROMS="${ROMS:-$HOME/Library/Application Support/Ample/roms}"
OUT="$ROOT/build/test"

rm -rf "$OUT"; mkdir -p "$OUT/stage" "$OUT/screens" "$OUT/mame"
DISK="$OUT/boot.po"
cp "$BOOT_DISK" "$DISK"
DISK="$DISK" FORCE=1 "$ROOT/install.sh" > "$OUT/install.log"
VOLUME="$(cadius CATALOG "$DISK" | awk '/^\//{print $1; exit}')"
disk() { local out; out="$(cadius "$@" 2>&1)"; if grep -q "Error" <<< "$out"; then echo "$out" >&2; exit 1; fi; }
cp "$ROOT/build/GSLauncher" "$OUT/stage/Finder#B3DB03"
disk DELETEFILE "$DISK" "${VOLUME}System/Finder"
cadius DELETEFILE "$DISK" "${VOLUME}System/SetStart.data" > /dev/null 2>&1 || true
disk ADDFILE "$DISK" "${VOLUME}System" "$OUT/stage/Finder#B3DB03"
if [ "$SLOTS" != "none" ]; then
    tr '\n' '\r' < "${SLOTS:-$ROOT/slots.txt}" > "$OUT/stage/Launcher.Slots#040000"
    disk ADDFILE "$DISK" "${VOLUME}System" "$OUT/stage/Launcher.Slots#040000"
fi
[ -n "$EXTRA" ] && eval "$EXTRA"
# the battery RAM (control panel settings) of Ample's IIgs
AMPLE_RTC="$HOME/Library/Application Support/Ample/nvram/apple2gs/rtc"
[ -f "$AMPLE_RTC" ] && mkdir -p "$OUT/mame/apple2gs" && cp "$AMPLE_RTC" "$OUT/mame/apple2gs/rtc"

KEYS="$KEYS" SHOTS="$SHOTS" DUMP_DIR="$OUT/screens" "$MAME" apple2gs -ramsize 4M -rompath "$ROMS" \
    -sl7 cffa2 -hard1 "$DISK" -window -nomaximize -sound none -cfg_directory "$OUT/mame" \
    -nvram_directory "$OUT/mame" -snapshot_directory "$OUT/mame" -nothrottle -skip_gameinfo \
    -seconds_to_run "$RUN_SECONDS" -autoboot_script "$ROOT/test/dump.lua" > "$OUT/mame.log" 2>&1 || true
cp "$DISK" "$OUT/after.po"
for f in "$OUT"/screens/*.shr; do [ -f "$f" ] && python3 -I "$ROOT/test/shr2png.py" "$f"; done
ls "$OUT/screens"
