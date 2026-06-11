#!/bin/bash

readonly TOOLNAME="ezchdiso"
readonly VERSION="0.97"
readonly MEMDIR="/dev/shm"

# --- Helper Functions ---
usage() {
    echo "$TOOLNAME: an utility to convert ISO files into CHD format"
    echo "Requires mame-tools package installed."
    echo "Usage: $0 [workdir] [destdir] [params]"
    echo "Params (comma-separated,no spaces in between): delete"
    exit 1
}

check_dependencies() {
    for cmd in chdman realpath; do
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
mapfile -t isofiles < <(find "$workdir" -maxdepth 1 -name "*.iso" | sort -f)
isofiles_total=${#isofiles[@]}
for ((i=0; i<isofiles_total; i++)); do
    isofile="${isofiles[$i]}"
    isoname=$(basename "$isofile")
    isoname=${isoname%.*}
    chdfile="$destdir/$isoname.chd"

    chdman createdvd --force -i "$isofile" -o "$chdfile"

    if grep -qiw "delete" <<< "$params" && [[ -e "$chdfile" ]]; then
        rm "$isofile"
    fi
done

echo "Processing complete."
