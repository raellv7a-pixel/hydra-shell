#!/usr/bin/env bash
# color-picker.sh <output-png>
# Picks a color from screen, outputs "R G B" to stdout.
# Uses the generic Wayland point selector and screen capture tools.
FILE="$1"
[ -z "$FILE" ] && exit 1
for dep in slurp grim magick; do
    command -v "$dep" >/dev/null 2>&1 || exit 1
done
COORDS=$(slurp -p 2>/dev/null) || exit 1
X=${COORDS%%,*}; REST=${COORDS#*,}; Y=${REST%% *}
GX=$((X - 10)); GY=$((Y - 10))
grim -g "${GX},${GY} 21x21" "$FILE" 2>/dev/null || exit 1
magick "$FILE" -alpha off \
    -format '%[fx:int(255*u.p{10,10}.r)] %[fx:int(255*u.p{10,10}.g)] %[fx:int(255*u.p{10,10}.b)]' \
    info:- 2>/dev/null
