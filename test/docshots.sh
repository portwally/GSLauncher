#!/bin/bash
# Takes the screenshots of the guide (docs/img/*.png) in MAME, with test/run.sh.
cd "$(dirname "$0")/.."
IMG=docs/img; mkdir -p $IMG
# run SLOTS SECONDS KEYS SHOTS: the shots copied to docs/img by their names
run() {
    SLOTS="$1" RUN_SECONDS="$2" KEYS="$3" SHOTS="$4" ./test/run.sh > /dev/null 2>&1
    for s in ${4//,/ }; do n="${s#*:}"; cp "build/test/screens/$n.png" "$IMG/$n.png" || echo "no $n"; done
}
run test/slots_web1.txt 42 "30:cmd-n" "28:main,38:addapp"
run test/slots_web.txt 44 "30:cmd-e,32:2,36:cmd-r" "28:pages,35:edit,40:rename"
run test/slots_web.txt 70 "30:mouse-66-5,31:mdown,32:mouse-90-44,36:mouse-320-150,38:mup,40:mouse-105-5,41:mdown,42:mouse-120-32,46:mouse-320-150,48:mup,50:mouse-152-5,51:mdown,52:mouse-165-32,56:mouse-320-150,58:mup,60:mouse-246-5,61:mdown,62:mouse-260-44" "35:menu-file,45:menu-page,55:menu-view,66:menu-help"
run test/slots_used.txt 54 "30:mouse-105-5,31:mdown,32:mouse-120-33,34:mup,39:esc,41:mouse-105-5,42:mdown,43:mouse-120-57,45:mup" "28:lastused,38:newpage,50:removepage"
run test/slots7.txt 42 "" "38:notfound"
run none 80 "32:return,64:esc" "30:find1,60:find2,70:empty"
run test/slots_web.txt 56 "30:mouse-66-5,31:mdown,32:mouse-90-143,34:mup,38:mouse-245-124,42:click" "36:confirm,50:shutdown"
run test/slots_web.txt 56 "30:mouse-16-5,31:mdown,32:mouse-30-20,34:mup,39:return,42:mouse-246-5,43:mdown,44:mouse-260-80,46:mup" "38:about,52:help"
ls $IMG
