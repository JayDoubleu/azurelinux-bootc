#!/usr/bin/env bash
# Build the bootc container image with podman. The result is IMAGE_NAME:build.
# 15-chunk-image.sh turns it into the final IMAGE_NAME:IMAGE_TAG.
# Usage: 10-build-image.sh [VERSION]
# VERSION is a build number. The image stores it in /usr/lib/azurelinux-bootc/version.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The image carries the public key from config/. Create the key pair on the first build.
if [ ! -f "$SIGN_KEY" ] || [ ! -f "$SIGN_PUBKEY" ]; then
  "$REPO_ROOT/scripts/22-keys.sh"
fi

version="${1:-1}"
log "building ${IMAGE_NAME}:${BUILD_TAG} with VERSION=${version}"
host podman build \
  --build-arg "VERSION=${version}" \
  -t "${IMAGE_NAME}:${BUILD_TAG}" \
  -f "$REPO_ROOT/Containerfile" \
  "$REPO_ROOT" 2>&1 | tee "$LOG_DIR/build-v${version}.log"
log "built ${IMAGE_NAME}:${BUILD_TAG} (VERSION=${version})"
