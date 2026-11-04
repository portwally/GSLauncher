#!/bin/bash
# Copies the latest builds of your apps into the hard disk image you boot in
# Ample, each into its folder there, so GSLauncher (and the Finder) find them.
#
#   ./install.sh                    all of them
#   ./install.sh gscommander        just one (or several):
#                                   launcher, gscommander, megaconvert, conquer
#
#   DISK=...  the disk image (default: ~/Roms/apple2gs/My GS Apps.hdv)
#   FORCE=1   even while MAME is running (it may not see the change, and may
#             write over it: quit MAME first)
#
# Build each app first (its ./build.sh). On the disk, an app's old files are
# replaced, its other files (settings, saved games) are kept. A copy of the
# disk image as it was is kept next to it (.bak). Needs cadius.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
DOCS="$(dirname "$ROOT")"
DISK="${DISK:-$HOME/Roms/apple2gs/My GS Apps.hdv}"
GSC="${GSC:-$DOCS/GS Commander}"
MCGS="${MCGS:-$DOCS/MegaconvertGS}"
CONQ="${CONQ:-$DOCS/Conquer GS 2}"

[ -f "$DISK" ] || { echo "no disk image $DISK (set DISK=...)" >&2; exit 1; }
if [ -z "$FORCE" ] && { pgrep -qx mame64 || pgrep -qx mame; }; then
    echo "MAME is running: quit it first (it has the disk open), or FORCE=1" >&2; exit 1
fi
APPS=("$@"); [ ${#APPS[@]} -eq 0 ] && APPS=(launcher gscommander megaconvert conquer)

cp "$DISK" "$DISK.bak"
VOL="$(cadius CATALOG "$DISK" | awk '/^\//{print $1; exit}')"   # "/System/"
VOL="${VOL%/}"
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT

# cadius exits 0 even when it fails: look for its error lines
disk() { local out; out="$(cadius "$@" 2>&1)"; if grep -q "Error" <<< "$out"; then echo "$out" >&2; exit 1; fi; }
# folder FOLDER: made if it is not there
folder() { cadius CREATEFOLDER "$DISK" "$VOL/$1" > /dev/null 2>&1 || true; }
# put SRC FOLDER NAME#TTAAAA: the file into the folder, replacing the old one
put() {
    local src="$1" dir="$2" name="$3"
    [ -f "$src" ] || { echo "missing $src: build it first" >&2; exit 1; }
    cp "$src" "$STAGE/$name"
    cadius DELETEFILE "$DISK" "$VOL/$dir/${name%%#*}" > /dev/null 2>&1 || true
    disk ADDFILE "$DISK" "$VOL/$dir" "$STAGE/$name"
    rm -f "$STAGE/$name"
    echo "  $VOL/$dir/${name%%#*}"
}
text() { tr '\n' '\r' < "$1" > "$STAGE/text.tmp"; echo "$STAGE/text.tmp"; }

for app in "${APPS[@]}"; do
    case "$app" in
    launcher)
        echo "GSLauncher"
        folder GSLauncher; folder GSLauncher/Icons
        put "$ROOT/build/GSLauncher" GSLauncher "GSLauncher#B3DB03"
        put "$(text "$ROOT/README.txt")" GSLauncher "ReadMe#040000"
        put "$ROOT/build/GSL.Icons" GSLauncher/Icons "GSL.Icons#CA0000"
        # the slots: only the first time (after that, they are yours)
        if ! cadius CATALOG "$DISK" | grep -q "Launcher.Slots"; then
            put "$(text "$ROOT/slots.txt")" GSLauncher "Launcher.Slots#040000"
        fi ;;
    gscommander)
        echo "GS Commander"
        folder GSCommander; folder GSCommander/Icons
        put "$GSC/build/GSCmdr" GSCommander "GSCommander#B3DB03"
        put "$(text "$GSC/README.txt")" GSCommander "ReadMe#040000"
        put "$GSC/art/IBMKLONE.12" GSCommander "IBMKLONE.12#C80000"
        put "$GSC/build/GSC.Icons" GSCommander/Icons "GSC.Icons#CA0000" ;;
    megaconvert)
        echo "MegaconvertGS"
        folder MegaconvertGS; folder MegaconvertGS/Icons
        put "$MCGS/build/MegaconvertGS" MegaconvertGS "MegaconvertGS#B3DB03"
        put "$MCGS/build/MCGS.Help" MegaconvertGS "MCGS.Help#040000"
        put "$MCGS/build/MCGS.Title" MegaconvertGS "MCGS.Title#C10000"
        put "$MCGS/build/MegaconvertGS.Icons" MegaconvertGS/Icons "MCGS.Icons#CA0000" ;;
    conquer)
        echo "Conquer GS 2"
        folder ConquerGS2; folder ConquerGS2/ICONS
        for f in "$CONQ"/build/CONQUER.*#* "$CONQ"/build/EDITOR.*#* "$CONQ"/build/MAP.*#*; do
            n="$(basename "$f")"
            case "$n" in CONQUER.ICONS#*) continue;; esac
            put "$f" ConquerGS2 "$n"
        done
        put "$CONQ/build/CONQUER.ICONS#CA0000" ConquerGS2/ICONS "CONQUER.ICONS#CA0000" ;;
    *) echo "unknown app $app (launcher, gscommander, megaconvert, conquer)" >&2; exit 1 ;;
    esac
done
echo "done: $DISK (the old one: $DISK.bak)"
