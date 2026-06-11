#!/bin/bash

readonly TOOLNAME="ezchdzip"
readonly VERSION="0.97"
readonly MEMDIR="/dev/shm"

# --- Helper Functions ---
usage() {
    echo "$TOOLNAME: an utility to convert zipped ISO or CUE/BIN files into CHD format"
    echo "Requires mame-tools package installed."
    echo "Usage: $0 [workdir] [destdir] [params]"
    echo "Params (comma-separated,no spaces in between): delete"
    exit 1
}

check_dependencies() {
    for cmd in chdman realpath unzip 7z; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required dependency '$cmd' not found."
            exit 1
        fi
    done
}

# --- Initialization ---
[[ $# -lt 1 ]] && usage
check_dependencies

workdir=$(realpath "$1")
destdir=$(realpath "$2")
params="$3"

if [[ ! -d "$workdir" ]]; then
    echo "Error: workdir '$workdir' not valid."
    exit 1
fi

if [[ ! -d "$destdir" ]]; then
    echo "Error: destdir '$destdir' not valid."
    exit 1
fi

# Collect files into an array for accurate counting
mapfile -t zipfiles < <(find "$workdir" -maxdepth 1 \( -name "*.zip" -o -name "*.7z" \) | sort -f)
zipfiles_total=${#zipfiles[@]}
for ((i=0; i<zipfiles_total; i++)); do
    zipfile="${zipfiles[$i]}"
    zipname=$(basename "$zipfile")
    zipname=${zipname%.*}

    targetdir="$MEMDIR/$zipname"
    if [[ -d "$targetdir" ]]; then
        rm -rf "$targetdir"
    fi
    mkdir "$targetdir"

    if [[ "$zipfile" == *.7z ]]; then
        7z x "$zipfile" -o"$targetdir"
    else
        unzip "$zipfile" -d "$targetdir"
    fi

    mapfile -t discfile < <(find "$targetdir" -maxdepth 1 -name "*.cue" -o -name "*.iso")
    discfile="${discfile[0]}"
    discname=$(basename "$discfile")
    discname=${discname%.*}
    chdfile="$destdir/$discname.chd"

    if grep -qi ".iso" <<< "$discfile"; then
        chdman createdvd --force -i "$discfile" -o "$chdfile"
    else
        chdman createcd --force -i "$discfile" -o "$chdfile"
    fi
    if [[ -d "$targetdir" ]]; then
        rm -rf "$targetdir"
    fi
    if grep -qiw "delete" <<< "$params" && [[ -e "$chdfile" ]]; then
        rm "$zipfile"
    fi
done

echo "Processing complete."
