#!/usr/bin/env bash
# ==============================================================================
# One-way sync NAS → PC using rsync.
# Public Domain; 2025 Philipp Elhaus
# ==============================================================================
# Tracks completed items via ./rsync_done/<name>.done.
# Usage:
#   ./sync_nas2pc.sh [SRC_USER] [SRC_HOST] [SRC_PATH] [DEST_PATH]
# Defaults:
#   SRC_USER=Administrator
#   SRC_HOST=10.0.0.20
#   SRC_PATH=/share/Public
#   DEST_PATH=/mnt/c/tmp

src_user="${1:-Administrator}"
src_host="${2:-10.0.0.20}"
src_path="${3:-/share/Public}"
dest="${4:-/mnt/c/tmp}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
done_dir="$script_dir/rsync_done"
mkdir -p "$done_dir"

echo "Source: $src_user@$src_host:$src_path"
echo "Dest  : $dest"
echo

mapfile -t folders < <(ssh "$src_user@$src_host" "cd '$src_path' 2>/dev/null && ls -A") || {
	echo "SSH error"
	exit 1
}

folders=("${folders[@]/@Recycle}")
total=${#folders[@]}

is_done() { [[ -f "$done_dir/$1.done" ]]; }

process_folder() {
	local name="$1" idx="$2"
	if is_done "$name"; then
		echo "[$idx/$total] SKIP $name"
		return
	fi

	echo "[$idx/$total] START $name"
	if rsync -e ssh -a --ignore-existing --info=progress2 \
		"$src_user@$src_host:$src_path/$name" "$dest/"; then
		touch "$done_dir/$name.done"
		echo "[$idx/$total] DONE $name"
	else
		echo "[$idx/$total] FAIL $name"
	fi
}

i=0
for name in "${folders[@]}"; do
	((i++))
	process_folder "$name" "$i"
done

echo "Completed $(ls "$done_dir"/*.done 2>/dev/null | wc -l) / $total"
