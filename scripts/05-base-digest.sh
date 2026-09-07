#!/usr/bin/env bash
# Compare the base image digest pinned in the Containerfile with the registry tag.
# Usage: 05-base-digest.sh           # report; exit 1 when the tag points at a newer digest
#        05-base-digest.sh --update  # rewrite the pin and its comment in the Containerfile
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

containerfile="$REPO_ROOT/Containerfile"
pinned="$(sed -n 's/^ARG BASE_IMAGE=.*@\(sha256:[0-9a-f]\{64\}\)$/\1/p' "$containerfile")"
[ -n "$pinned" ] || die "no digest pin found in $containerfile"

log "pinned:  $pinned"
current="$(host skopeo inspect --format '{{.Digest}}' "docker://${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}")"
log "tag ${BASE_IMAGE_TAG}: $current"

# Find the dated tag that carries the same digest, for the comment in the Containerfile.
dated=""
while read -r tag; do
  d="$(host skopeo inspect --format '{{.Digest}}' "docker://${BASE_IMAGE_REPO}:${tag}" 2>/dev/null || true)"
  if [ "$d" = "$current" ]; then dated="$tag"; break; fi
done < <(host skopeo list-tags "docker://${BASE_IMAGE_REPO}" | sed -n 's/^ *"\([0-9.]*\)",\{0,1\}$/\1/p' | sort -r)
log "dated tag for the current digest: ${dated:-unknown}"

if [ "$pinned" = "$current" ]; then
  log "the pin is current"
  exit 0
fi

if [ "${1:-}" != "--update" ]; then
  log "the tag moved; run: $0 --update"
  exit 1
fi

today="$(date +%F)"
sed -i \
  -e "s|@sha256:[0-9a-f]\{64\}$|@${current}|" \
  -e "s|^# Pinned from tag .*$|# Pinned from tag ${dated:-unknown} (tag ${BASE_IMAGE_TAG} on ${today}). Check with: make base-digest|" \
  "$containerfile"
log "updated $containerfile to $current"
