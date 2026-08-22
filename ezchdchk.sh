#!/bin/bash

readonly TOOLNAME="ezchdchk"
readonly VERSION="0.98"
readonly LOGDIR=$(realpath "logs")
readonly SHMDIR="/dev/shm"
readonly COLUMNSS="%-120s\t%-5s\t%-7s\t%-11s\t%s"

# --- Helper Functions ---
usage() {
    echo "$TOOLNAME: an utility to validate CHD collections against redump.org DATs"
    echo "Requires mame-tools package installed."
    echo "Usage: $0 [datfile] [workdir] [params]"
    echo "Params (comma-separated,no spaces in between): rename,move,ignorefix,verbose"
    exit 1
}

check_dependencies() {
    for cmd in chdman sha1sum realpath column; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required dependency '$cmd' not found."
            exit 1
        fi
    done
}

# --- Initialization ---
[[ $# -lt 2 ]] && usage
check_dependencies

datfile=$(realpath "$1")
workdir=$(realpath "$2")
params="${3,,}"

echo "params: $params"

if [[ ! -f "$datfile" ]]; then
    echo "Error: redump datfile '$datfile' not found."
    exit 1
fi

if [[ ! -d "$workdir" ]]; then
    echo "Error: workdir '$workdir' not valid."
    exit 1
fi

if [[ ! -d "$LOGDIR" ]]; then
    mkdir "$LOGDIR"
fi

datname="$(basename "${datfile%.*}")"
logfile="$LOGDIR/$datname.log"
> "$logfile"

targetdir_base="$SHMDIR/$TOOLNAME/$datname"
mkdir -p "$targetdir_base"

# Collect files into an array for accurate counting
mapfile -t chdfiles < <(find "$workdir" -maxdepth 1 -name "*.chd" | sort -f)
chdfiles_total=${#chdfiles[@]}

for ((i=0; i<chdfiles_total; i++)); do
    chdfile="${chdfiles[$i]}"
    processing_index=$((i + 1))
    chdname=$(basename "$chdfile")
    chdname_noext=${chdname%.*}
    echo Processing CHD [$processing_index/$chdfiles_total]: "${chdfile}"

    chdstatus="[TBD]"
    tracklist=""
    tracksnumber=0
    tracksmatched=0
    trackinfo=""
    chdinfo=""

    gamename=""
    gamename_rename=""

    targetdir="$targetdir_base/$chdname_noext"
    if [[ -d "$targetdir" ]]; then
        rm -rf "$targetdir"
    fi
    mkdir "$targetdir"

    compression=$(chdman info -i "$chdfile" | grep -i "compression:")
    if grep -qi "cd.*" <<< "$compression"; then
# CD Logic
        echo "Media type: CD"
        cuefile="$targetdir/$chdname_noext.cue"
        chdman extractcd --force --splitbin -i "$chdfile" -o "$cuefile" &> /dev/null
        mapfile -t track1file < <(find "$targetdir" -maxdepth 1 -name "*(Track 1).bin" -o -name "*(Track 01).bin")
        track1file="${track1file[0]}"
        track1hash=$(sha1sum "$track1file" | awk '{print $1}')
        track1hash_matchlines=$(grep -i "sha1=\"${track1hash}\"" "$datfile")
        while IFS= read -r line; do
            romname=$(echo "$line" | grep -oP 'name="\K[^"]+')
            romname=$(echo "${romname}" | sed 's/&amp;/\&/g')
            romname_noext=${romname%.*}
            gamename="${romname_noext% (Track*}"
            gamename_escaped=$(echo "$gamename" | sed 's/&/\&amp;/g')
            tracklist=""
            tracksnumber=0
            tracksmatched=0
            trackinfo=""
            if [[ -n "$gamename" ]]; then
                echo ">" Found game: "$gamename"
                tracklist+=$(grep "<rom.*name=\"${gamename_escaped}\.bin" "$datfile")
                tracklist+=$(grep "<rom.*name=\"${gamename_escaped} (Track.*\.bin" "$datfile")
                tracksnumber=$(grep -c '.' <<< "$tracklist")
            fi
            mapfile -t trackfiles < <(find "$targetdir" -maxdepth 1 -name "*.bin" | sort -f)
            trackfiles_total=${#trackfiles[@]}
            for ((j=0; j<trackfiles_total; j++)); do
                trackfile="${trackfiles[$j]}"
                trackstatus="[TBD]";
                trackname=$(basename "$trackfile")
                trackhash=$(sha1sum "$trackfile" | awk '{print $1}')
                trackhash_matchline=$(grep -i "sha1=\"${trackhash}\"" <<< "$tracklist")
                romname=$(echo "$trackhash_matchline" | grep -oP 'name="\K[^"]+')
                romname_unescaped=$(echo "${romname}" | sed 's/&amp;/\&/g')
                if [[ -n "$trackhash_matchline" ]]; then
                    trackstatus="[MATCH]"
                    ((tracksmatched++))
                else
                    trackstatus="[MISS]"
                fi
                trackinfo+=$(printf "$COLUMNSS" "* $trackname" "[TRK]" "$trackhash" "$trackstatus" "$romname_unescaped")
                trackinfo+=$'\n'
            done
            if [[ $tracksnumber -gt 0 && $tracksmatched -eq $tracksnumber && "$gamename" == "$chdname_noext" ]]; then
                chdstatus="[MATCH]"
                if [[ "$trackfiles_total" -gt "$tracksnumber" ]]; then
                    chdstatus+="[+]"
                fi
            elif [[ $tracksnumber -gt 0 && $tracksmatched -eq $tracksnumber ]]; then
                gamename_rename="$gamename"
                chdstatus="[RENAME]"
                if [[ "$trackfiles_total" -gt "$tracksnumber" ]]; then
                    chdstatus+="[+]"
                fi
            elif [[ $tracksnumber -gt 0 && $tracksmatched -lt $tracksnumber ]]; then
                chdstatus="[FIXME]"
                if grep -qiw "ignorefix" <<< "$params"; then
                    continue
                fi
            else
                chdstatus="[MISS]"
            fi
            tracksratio=$(printf "[%02d/%02d]" "$tracksmatched" "$tracksnumber")
            chdinfo+=$(printf "$COLUMNSS" "$chdname" "[CD]" "$tracksratio" "$chdstatus" "$gamename")
            chdinfo+=$'\n'
            if grep -qiw "verbose" <<< "$params"; then
                chdinfo+="$trackinfo"
            fi
        done <<< "$track1hash_matchlines"
    else
# DVD Logic
        echo "Media type: DVD"
        isofile="$targetdir/$chdname_noext.iso"
        chdman extractdvd --force -i "$chdfile" -o "$isofile" &> /dev/null
        isoname=$(basename "$isofile")
        isohash=$(sha1sum "$isofile" | awk '{print $1}')
        matchline=$(grep -i "sha1=\"${isohash}\"" "$datfile")
        romname=$(echo "$matchline" | grep -oP 'name="\K[^"]+')
        romname=$(echo "${romname}" | sed 's/&amp;/\&/g')
        gamename=${romname%.*}
        if [[ -n "$gamename" ]]; then
            echo ">" Found game: "$gamename"
        fi
        if [[ "$gamename" == "$chdname_noext" ]]; then
            chdstatus="[MATCH]"
        elif [[ -n "$matchline" ]]; then
            gamename_rename="$gamename"
            chdstatus="[RENAME]"
        else
            chdstatus="[MISS]"
        fi
        trackinfo=$(printf "$COLUMNSS" "* $isoname" "[TRK]" "$isohash" "$chdstatus" "$romname")
        trackinfo+=$'\n'
        chdinfo+=$(printf "$COLUMNSS" "$chdname" "[DVD]" "[01/01]" "$chdstatus" "$gamename")
        chdinfo+=$'\n'
        if grep -qiw "verbose" <<< "$params"; then
            chdinfo+="$trackinfo"
        fi
    fi
# COMMON Logic
    if [[ -n "$gamename_rename" ]] && grep -qiw "rename" <<< "$params"; then
        echo "action: rename"
        echo "gamename_rename: $gamename_rename"
        chdfile_new="$workdir/$gamename_rename.chd"
        mv "$chdfile" "$chdfile_new"
        echo CHD file \""$chdfile"\" renamed to \""$chdfile_new"\"
    fi
    if [[ -z "$gamename" ]]; then
        echo ">" No game found.
        if grep -qiw "move" <<< "$params"; then
            echo "action: move"
            movedir="$workdir/$chdstatus/"
            if [[ ! -d "$movedir" ]]; then
                mkdir "$movedir"
            fi
            mv "$chdfile" "$movedir"
            echo CHD file \""$chdfile"\" moved to \""$movedir"\"
        fi
    fi
    column -t -s $'\t' <<< "$chdinfo" >> "$logfile"
    if [[ -d "$targetdir" ]]; then
        rm -rf "$targetdir"
    fi
done

echo "Processing complete. The log file has been written. [$logfile]"
echo "Files processed: $chdfiles_total"
