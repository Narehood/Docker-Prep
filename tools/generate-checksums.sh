#!/usr/bin/env bash
set -euo pipefail

# Regenerates Scripts/.checksums.sha256 using GNU two-space sha256sum format.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scripts_dir="$repo_root/Scripts"
manifest="$scripts_dir/.checksums.sha256"
temporary=$(mktemp "$scripts_dir/.checksums.sha256.XXXXXXXX")

cleanup() {
    rm -f -- "$temporary"
}
trap cleanup EXIT

shopt -s nullglob
scripts=("$scripts_dir"/*.sh)
if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "No Scripts/*.sh files found; manifest was not changed." >&2
    exit 1
fi

(
    cd "$scripts_dir" || exit 1
    sha256sum "${scripts[@]##*/}" | sort -k2
) > "$temporary"

if [[ ! -s "$temporary" ]]; then
    echo "Checksum generation produced an empty manifest." >&2
    exit 1
fi

mv -- "$temporary" "$manifest"
trap - EXIT
echo "Updated $manifest"
