#!/usr/bin/env bash
# This is just an example how ueberzug can be used with fzf.
# Copyright (C) 2019  Nico Bäurer
# Copyright (C) 2022  Tomasz Kapias
#     - Updated:
#         - optional PATH as only option
#         - internal FDfind query for images
#         - display SVGs after caching a converted png
#         - Imagemagick's identify infos as header with margin

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
readonly BASH_BINARY="$(which bash)"
readonly REDRAW_COMMAND="toggle-preview+toggle-preview"
readonly REDRAW_KEY="µ"
declare -r -x DEFAULT_PREVIEW_POSITION="right"
declare -r -x UEBERZUG_FIFO="$(mktemp --dry-run --suffix "fzf-$$-ueberzug")"
declare -r -x PREVIEW_ID="preview"

export UEBERZUG_FIFO

function start_ueberzug {
    if [ ! -p "${UEBERZUG_FIFO}" ]; then
        if [ -f "${UEBERZUG_FIFO}" ]; then
            rm "${UEBERZUG_FIFO}"
        fi
        mkfifo "${UEBERZUG_FIFO}"
    fi
    <"${UEBERZUG_FIFO}" \
        ueberzug layer --parser bash --silent &
    # prevent EOF
    3>"${UEBERZUG_FIFO}" \
        exec
    ueberzug_pid=$!
}


function finalise {
    3>&- \
        exec
    &>/dev/null \
        rm "${UEBERZUG_FIFO}"
    &>/dev/null \
        kill $(jobs -p)
}


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

is_img_extension() {
    grep -iE '\.(jpe?g|png|jxl|webp)$'
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


function print_on_winch {
    # print "$@" to stdin on receiving SIGWINCH
    # use exec as we will only kill direct childs on exiting,
    # also the additional bash process isn't needed
    </dev/tty \
        exec perl -e '
            require "sys/ioctl.ph";
            while (1) {
                local $SIG{WINCH} = sub {
                    ioctl(STDIN, &TIOCSTI, $_) for split "", join " ", @ARGV;
                };
                sleep;
            }' \
            "${@}" &
}

#  default: wal -i
wal_img_cmd='wal -i'
#  default: wal --theme
wal_thm_cmd='wal --theme'
#  default: darken
colsmethod=darken
# should the program set the wallpaper as a preview
#  default: no
prevwpp="no"
lastusedthemefile="${XDG_CACHE_HOME:-$HOME/.cache}/wal/last_used_theme"
lastthemestr=$(cat "$lastusedthemefile")
lasttheme="${XDG_CACHE_HOME:-$HOME/.cache}/wal/schemes/${lastthemestr}"
config_dir="${XDG_CONFIG_HOME:-~/.config}/wal-choose"
config_file="${config_dir}/configrc"

if [ -f "$config_file" ]; then
    . "$config_file"
else
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
    cat <<___CONFIG > "$config_file"
# default config
# wal-choose allows to change the commands used for building and applying
# themes, this is so to allow custom wrappers for pywal like the one i use.

# wal -i command
wal_img_cmd='wal -i'
# wal --theme command
wal_thm_cmd='wal --theme'
# wal --cols16 method
# available: darken, lighten
colsmethod=darken
# preview wallpaper
# valid value:
# case insensitive
# no, n, 0, false, EMPTY
# yes, y, 1, true
# anything else will be interpreted as false
prevwpp="no"
___CONFIG
fi

# echo "$lastthemestr"
# cat "$lasttheme"
# echo
# selection=$(find "$1" | fzf)

if [ -z "$WAL_CHOOSE_COLORS" ]; then
    WAL_CHOOSE_COLORS="--color=fg:15,bg:0,hl:10,fg+:15,bg+:8,hl+:12 \
    --color=info:10,prompt:13,pointer:12,marker:12,spinner:14,header:4 \
    --color=scrollbar:12"
fi

if [ -z "$WAL_CHOOSE_OPTS" ]; then
    WAL_CHOOSE_OPTS="--layout=reverse --height 100% --no-multi \
     --cycle --border sharp \
     --preview-window sharp \
     --prompt='filter: ' \
     --bind ctrl-g:last \
     --bind alt-g:first \
     --bind alt-k:preview-up \
     --bind alt-j:preview-down"
fi

# usage: 
# wiht one arg:
#     import_test "library"
#     will run as: import library
# wiht two arg:
#     import_test "library" "module"
#     will run as: from library import module
import_test() {
if [ -n "$2" ]; then
    library="$1"
    module="$2"
    python3 - <<___HEREDOC
import sys
try:
    from $library import $module
except ImportError:
    sys.exit(1)
___HEREDOC
else
    library="$1"
    python3 - <<___HEREDOC
import sys
try:
    import $library
except ImportError:
    sys.exit(1)
___HEREDOC
fi
}

# usage: prettyp "$1" "$2" "$3"
# result: [1] 2: 3
prettyp() {
    if [ -n "$3" ]; then
        printf '[\033[1;32m%s\033[0m] \033[1;31m%s\033[0m: %s\n' "$1" "$2" "$3"
    else
        printf '[\033[1;32m%s\033[0m] %s\n' "$1" "$2"
    fi
}

myname="${0##*/}"

backend_schemer=""
backend_colorthief=""
backend_colorz=""
backend_fast_colorthief=""
backend_modern_colorthief=""
backend_okthief=""
backend_haishoku=""
backend_list='wal'


which schemer2 >/dev/null
backend_schemer=$?
[ "$backend_schemer" = 0 ] && backend_list="${backend_list}"' schemer2'

import_test "colorthief" "ColorThief"
backend_colorthief=$?
[ "$backend_colorthief" = 0 ] && backend_list="${backend_list}"' colorthief'

import_test "colorz"
backend_colorz=$?
[ "$backend_colorz" = 0 ] && backend_list="${backend_list}"' colorz'

import_test "fast_colorthief"
backend_fast_colorthief=$?
[ "$backend_fast_colorthief" = 0 ] && backend_list="${backend_list}"' fast_colorthief'

import_test "modern_colorthief"
backend_modern_colorthief=$?
[ "$backend_modern_colorthief" = 0 ] && backend_list="${backend_list}"' modern_colorthief'

which okthief >/dev/null
backend_okthief=$?
[ "$backend_okthief" = 0 ] && backend_list="${backend_list}"' okthief'

import_test "haishoku.haishoku" "Haishoku"
backend_haishoku=$?
[ "$backend_haishoku" = 0 ] && backend_list="${backend_list}"' haishoku'

choos_backend() {
    backend_sel=""
    backend_sel=$(printf '%s\n' ${backend_list} | fzf)
    if [ -z "$backend_sel" ]; then
        backend_sel="wal"
    fi
}


export FZF_DEFAULT_OPTS="${WAL_CHOOSE_OPTS} ${WAL_CHOOSE_COLORS}"

dir=""
if [ -z "$1" ]; then
    dir="$PWD"
else
    if [ -d "$1" ]; then
        dir="$1"
    else
        prettyp "$myname" "no valid directory provided"
        prettyp "$myname" "using" "$PWD"
        dir="$PWD"
    fi
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap finalise EXIT
    # print the redraw key twice as there's a run condition we can't circumvent
    # (we can't know the time fzf finished redrawing it's layout)
    print_on_winch "${REDRAW_KEY}${REDRAW_KEY}"

    # original header definition
    # fzf --ansi --keep-right --header "jpg/jpeg/png/webp files in $([[ -z $1 ]] && echo $PWD || realpath $1)" 
    export -f draw_preview svg_preview calculate_position
fi

# wallpaper preview arg
# will be either "-n" or empty
wppv_arg=""

case $prevwpp in
    [Yy][Ee][Ss]|[Yy]|1|[Tt][Rr][Uu][Ee])
        # we do nothing here cuz the default is empty!!!
        ;;
    [Nn][Oo]|[Nn]|0|[Ff][Aa][Ll][Ss][Ee]|*)
        wppv_arg="-n"
        ;;
esac

choose_wal() {
    start_ueberzug
    SHELL="${BASH_BINARY}" \
    selection=$(find -L "$dir" -maxdepth 1 -type f -print | is_img_extension | sort -V | \
    fzf --ansi --keep-right --header "wal-choose: choose wallpaper from files in $dir" \
    --preview "@lib@/wal-preview {1} $backend_sel $colsmethod $wppv_arg" \
    --preview-window "${DEFAULT_PREVIEW_POSITION}" \
    --bind "${REDRAW_KEY}:${REDRAW_COMMAND}")
    kill "$ueberzug_pid"
}

Ystr='Yes'
Nstr='No'
EXstr='exit?'
prompt_exit() {
    if [ "$(printf '%s\n%s\n' $Ystr $Nstr | fzf --disabled --prompt "$EXstr" +m)" = "$Ystr" ]; then
        printf '0\n'
    else
        printf '1\n'
    fi
}

NO_CONTINUE=1
while [ "$NO_CONTINUE" -ne 0 ]; do
    choos_backend
    choose_wal "$@"
    NO_CONTINUE=$(prompt_exit)
done

if [ -z "$selection" ]; then
    prettyp "$myname" "selection empty"
    prettyp "$myname" "last theme will be used"
    $wal_thm_cmd "${lasttheme}"
else
    prettyp "$myname" "selected image" "${selection}"
    $wal_img_cmd "${selection}" --backend "$backend_sel"
fi
