#!/bin/env bash


function calculate_position {
    # TODO costs: creating processes > reading files
    #      so.. maybe we should store the terminal size in a temporary file
    #      on receiving SIGWINCH
    #      (in this case we will also need to use perl or something else
    #      as bash won't execute traps if a command is running)
    < <(</dev/tty stty size) \
        read TERMINAL_LINES TERMINAL_COLUMNS

    case "${PREVIEW_POSITION:-${DEFAULT_PREVIEW_POSITION}}" in
        left|up|top)
            X=1
            Y=1
            ;;
        right)
            X=$((TERMINAL_COLUMNS - COLUMNS - 2))
            Y=1
            ;;
        down|bottom)
            X=1
            Y=$((TERMINAL_LINES - LINES - 1))
            ;;
    esac
}


function draw_preview {
    calculate_position

    >"${UEBERZUG_FIFO}" declare -A -p cmd=( \
        [action]=add [identifier]="${PREVIEW_ID}" \
        [x]="$(( ${X} - 2 ))" [y]="$(( ${Y} + 5 ))" \
        [width]="${COLUMNS}" [height]="$(( ${LINES} - 4 ))" \
        [scaler]=contain \
        [path]="${@}")
        # add [synchronously_draw]=True if you want to see each change
}

function svg_preview {
    CACHEDIR="$HOME/.cache/fzf-img"
    mkdir $CACHEDIR
    SVGCACHE="$CACHEDIR/thumbnail.$(stat --printf '%n\0%i\0%F\0%s\0%W\0%Y' -- "$(readlink -f "$1")" | \
        sha256sum | awk '{print $1}')"
    [ ! -f "$SVGCACHE" ] && convert -background none "${@}" "${SVGCACHE}.png"
    calculate_position

    >"${UEBERZUG_FIFO}" declare -A -p cmd=( \
        [action]=add [identifier]="${PREVIEW_ID}" \
        [x]="${X}" [y]="$(( ${Y} + 4 ))" \
        [width]="${COLUMNS}" [height]="$(( ${LINES} - 6 ))" \
        [scaler]=contain \
        [path]="${SVGCACHE}.png")
        # add [synchronously_draw]=True if you want to see each change
}

image="$1"
backend="$2"
colsmethod="$3"
wppv="$4"

echo "Using Backend: $backend    Cols Method: $colsmethod"
wal --backend $backend --cols16 $colsmethod -i "$image" $wppv -q
wal --preview | sed -n '3,$ p'
# awk '{print \$2,\$3,\$4,\$5,\$6,\$7}'
draw_preview "$image"
