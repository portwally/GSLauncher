# Fails on a global label defined twice, or a local (:label) defined twice
# under the same global label: Merlin 32 silently takes the first.
import os, re, sys
src = sys.argv[1]
bad = 0
seen = {}
for name in sorted(os.listdir(src)):
    if not name.endswith(".s") or name == "link.s":
        continue
    glob = None
    local = set()
    for n, line in enumerate(open(os.path.join(src, name), encoding="latin-1"), 1):
        m = re.match(r"([:\]]?[A-Za-z_][\w.]*)\s", line + " ")
        if not m or line[0] in "* ;":
            continue
        lab = m.group(1)
        if lab.startswith("]"):
            continue
        if lab.startswith(":"):
            if lab in local:
                print(f"{name}:{n}: local {lab} twice under {glob}"); bad = 1
            local.add(lab)
        else:
            parts = line.split()
            if len(parts) > 1 and parts[1].upper() in ("MAC",):
                continue
            if lab in seen:
                print(f"{name}:{n}: {lab} also at {seen[lab]}"); bad = 1
            seen[lab] = f"{name}:{n}"
            glob, local = lab, set()
sys.exit(bad)
