#!/bin/bash
# Builds, and rewrites each branch Merlin finds too long (test/fixbranch.py)
# until the build is clean.
cd "$(dirname "$0")/.."
for i in $(seq 1 60); do
  out=$(./build.sh 2>&1)
  e=$(echo "$out" | grep "Bad Jump" | head -1)
  [ -z "$e" ] && break
  f=$(echo "$e" | sed -E "s/.*file '([^']+)'.*/\1/"); l=$(echo "$e" | sed -E "s/.*\(line ([0-9]+),.*/\1/")
  [ -f "src/$f" ] || { echo "too long in $f (not ours)"; break; }
  python3 test/fixbranch.py "src/$f" "$l"
done
echo "$out" | grep -E "Error|built"
