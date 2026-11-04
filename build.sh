#!/bin/bash
# Assembles GSLauncher (build/GSLauncher, a GS/OS S16 application) with Merlin 32.
#   MERLIN32   path to the Merlin32 binary (default: the copy in ~/Downloads)
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
MERLIN32="${MERLIN32:-$HOME/Downloads/Merlin32_v1.2_b2/MacOs/Merlin32}"
mkdir -p "$ROOT/build"
python3 -I "$ROOT/test/labels.py" "$ROOT/src" || exit 1   # (Merlin silently takes the first of two)
# the generic icon (src/genicon.s) and the Finder icon, from art/make_icon.py
python3 -I "$ROOT/art/make_icon.py" "$ROOT/build/GSL.Icons" "$ROOT/build/icon-preview.png" "$ROOT/src/genicon.s"
A="$ROOT/build/asm"
rm -rf "$A"; mkdir -p "$A"
cp "$ROOT"/src/*.s "$A/"
cd "$A"
"$MERLIN32" -V "$A" link.s > "$ROOT/build/merlin.log" 2>&1 || { tail -30 "$ROOT/build/merlin.log"; exit 1; }
# Merlin 32 doesn't always fail with an exit code: look for its error lines
if grep -qi "error" "$ROOT/build/merlin.log"; then grep -i -B2 -A2 error "$ROOT/build/merlin.log"; exit 1; fi
mv -f GSLauncher "$ROOT/build/GSLauncher"
mv -f GSLauncher_*_Output.txt GSLauncher_Symbols.txt "$ROOT/build/" 2>/dev/null || true
rm -f _FileInformation.txt error_output.txt
echo "built build/GSLauncher ($(wc -c < "$ROOT/build/GSLauncher") bytes)"
