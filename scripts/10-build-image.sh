#!/usr/bin/env bash
# Build the bootc container image.
# Usage: 10-build-image.sh [VERSION]
# VERSION is a build number. The image stores it in /usr/lib/azurelinux-bootc/version.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

version="${1:-1}"
log "building ${IMAGE_NAME}:${IMAGE_TAG} with VERSION=${version}"
host podman build \
  --build-arg "VERSION=${version}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  -f "$REPO_ROOT/Containerfile" \
  "$REPO_ROOT" 2>&1 | tee "$LOG_DIR/build-v${version}.log"
log "built ${IMAGE_NAME}:${IMAGE_TAG} (VERSION=${version})"
