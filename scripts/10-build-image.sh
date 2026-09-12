#!/usr/bin/env bash
# Build the bootc container image with podman. The result is IMAGE_NAME:build.
# 15-chunk-image.sh turns it into the final IMAGE_NAME:IMAGE_TAG.
# Usage: 10-build-image.sh [VERSION]
# VERSION is a build number. The image stores it in /usr/lib/azurelinux-bootc/version.
# EXTRA_PACKAGES, if set, adds packages to the build. The upgrade test uses it to measure a package change.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The image carries the public key from config/. Create the key pair on the first build.
if [ ! -f "$SIGN_KEY" ] || [ ! -f "$SIGN_PUBKEY" ]; then
  "$REPO_ROOT/scripts/22-keys.sh"
fi

version="${1:-1}"
old_id="$(host podman image inspect --format '{{.Id}}' "${IMAGE_NAME}:${BUILD_TAG}" 2>/dev/null || true)"
log "building ${IMAGE_NAME}:${BUILD_TAG} for ${ARCH} with VERSION=${version}"
host podman build \
  --platform "$PODMAN_PLATFORM" \
  --build-arg "TARGETARCH=${TARGETARCH}" \
  --build-arg "VERSION=${version}" \
  --build-arg "EXTRA_PACKAGES=${EXTRA_PACKAGES:-}" \
  -t "${IMAGE_NAME}:${BUILD_TAG}" \
  -f "$REPO_ROOT/Containerfile" \
  "$REPO_ROOT" 2>&1 | tee "$LOG_DIR/build-v${version}.log"
# Remove the image the tag pointed at before, unless it still has a tag. Keeps the store bounded.
new_id="$(host podman image inspect --format '{{.Id}}' "${IMAGE_NAME}:${BUILD_TAG}")"
if [ -n "$old_id" ] && [ "$old_id" != "$new_id" ]; then
  host podman rmi "$old_id" >/dev/null 2>&1 || true
fi
log "built ${IMAGE_NAME}:${BUILD_TAG} (VERSION=${version})"
