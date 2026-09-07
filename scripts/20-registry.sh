#!/usr/bin/env bash
# Manage the local OCI registry that the VM pulls from.
# Usage: 20-registry.sh [up|down|status]
# The registry listens on 127.0.0.1:5000 on the host. The VM reaches it at 10.0.2.2:5000.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-up}" in
  up)
    if host podman container exists "$REGISTRY_NAME"; then
      host podman start "$REGISTRY_NAME" >/dev/null
    else
      host podman run -d --name "$REGISTRY_NAME" \
        -p "127.0.0.1:${REGISTRY_PORT}:5000" \
        docker.io/library/registry:2 >/dev/null
    fi
    log "registry up at ${REGISTRY_FROM_HOST} (VM sees ${REGISTRY_FROM_VM})"
    ;;
  down)
    host podman rm -f "$REGISTRY_NAME" >/dev/null 2>&1 || true
    log "registry removed"
    ;;
  status)
    host podman ps -a --filter "name=${REGISTRY_NAME}" --format '{{.Names}} {{.Status}}'
    ;;
  *)
    die "usage: $0 [up|down|status]"
    ;;
esac
