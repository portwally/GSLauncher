#!/bin/bash
# Makes build/GSLauncher.po: an 800K ProDOS disk with GSLauncher (an S16
# application), its read-me and its Finder icon. Run
# ./build.sh first. Needs cadius.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
B="$ROOT/build"
DISK="$B/GSLauncher.po"
STAGE="$B/disk"
[ -f "$B/GSLauncher" ] || { echo "build/GSLauncher is missing: run ./build.sh first" >&2; exit 1; }
rm -rf "$STAGE" "$DISK"; mkdir -p "$STAGE/Icons"
cp "$B/GSLauncher" "$STAGE/GSLauncher#B3DB03"                      # S16
tr '\n' '\r' < "$ROOT/README.txt" > "$STAGE/ReadMe#040000"          # TXT
# (no Launcher.Slots: without it the first start offers Find Apps)
cp "$B/GSL.Icons" "$STAGE/Icons/GSL.Icons#CA0000"                   # ICN
disk() { local out; out="$(cadius "$@" 2>&1)"; if grep -q "Error" <<< "$out"; then echo "$out" >&2; exit 1; fi; }
disk CREATEVOLUME "$DISK" GSLauncher 800KB
for f in "$STAGE"/*#*; do disk ADDFILE "$DISK" /GSLauncher "$f"; done
disk CREATEFOLDER "$DISK" /GSLauncher/Icons
disk ADDFILE "$DISK" /GSLauncher/Icons "$STAGE/Icons/GSL.Icons#CA0000"
rm -rf "$STAGE"
cadius CATALOG "$DISK" | grep -E "GSLauncher|ReadMe|Icons"
