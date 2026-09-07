#!/usr/bin/env bash
# Tag the built image and push it to the local registry.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

host podman tag "${IMAGE_NAME}:${IMAGE_TAG}" "$HOST_IMAGE_REF"
host podman push --tls-verify=false "$HOST_IMAGE_REF" 2>&1 | tee "$LOG_DIR/push.log"
log "pushed ${HOST_IMAGE_REF}"
