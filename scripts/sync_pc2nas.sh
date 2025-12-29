#!/usr/bin/env bash
# ==============================================================================
# One-way sync PC → NAS using rsync.
# Public Domain; 2025 Philipp Elhaus
# ==============================================================================
# Tracks completed items via ./rsync_done/<name>.done.
# Usage:
#   ./sync_pc2nas.sh [DEST_USER] [DEST_HOST] [SRC_PATH] [DEST_PATH]
# Defaults:
#   DEST_USER=Administrator
#   DEST_HOST=10.0.0.20
#   SRC_PATH=/mnt/c/tmp
#   DEST_PATH=/share/CACHEDEV2_DATA/Public

dest_user="${1:-Administrator}"
dest_host="${2:-10.0.0.20}"
src="${3:-/mnt/c/tmp}"
dest_path="${4:-/share/CACHEDEV2_DATA/Public}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
done_dir="$script_dir/rsync_done"
mkdir -p "$done_dir"

# Adjust SSH options/key as needed
rsync_rsh="ssh -i ~/.ssh/nas_key"

echo "Source: $src"
echo "Dest  : $dest_user@$dest_host:$dest_path"
echo

mapfile -t folders < <(cd "$src" 2>/dev/null && ls -A) || {
    echo "Source path error"
    exit 1
}

total=${#folders[@]}

is_done() {
    [[ -f "$done_dir/$1.done" ]]
}

process_item() {
    local name="$1" idx="$2"
    if is_done "$name"; then
        echo "[$idx/$total] SKIP $name"
        return
    fi

    echo "[$idx/$total] START $name"
    if rsync -e "$rsync_rsh" -a --ignore-existing --info=progress2 \
        "$src/$name" "$dest_user@$dest_host:$dest_path/"; then
        touch "$done_dir/$name.done"
        echo "[$idx/$total] DONE $name"
    else
        echo "[$idx/$total] FAIL $name"
    fi
}

i=0
for name in "${folders[@]}"; do
    ((i++))
    process_item "$name" "$i"
done

echo "Completed $(ls "$done_dir"/*.done 2>/dev/null | wc -l*_
