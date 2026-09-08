#!/usr/bin/env bash
# Run shellcheck from a container when the host does not have it installed.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

files=()
for f in "$REPO_ROOT"/scripts/*.sh; do
  files+=("/mnt/$(basename "$f")")
done

host podman run --rm -v "$REPO_ROOT/scripts:/mnt:ro,Z" \
  docker.io/koalaman/shellcheck:stable -x -P SCRIPTDIR "${files[@]}"
