#!/usr/bin/env bash
# Verify that the host has the tools the other scripts need.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

status=0
for tool in podman qemu-system-x86_64 qemu-img ssh-keygen; do
  if host_has "$tool"; then
    log "ok       $tool"
  else
    log "MISSING  $tool"
    status=1
  fi
done

for path in "$OVMF_CODE" "$OVMF_VARS_SRC" /dev/kvm; do
  if host_exists "$path"; then
    log "ok       $path"
  else
    log "MISSING  $path"
    status=1
  fi
done

if [ -f /run/.toolboxenv ]; then
  log "note     running in a toolbox; host commands go through flatpak-spawn"
fi

exit "$status"
