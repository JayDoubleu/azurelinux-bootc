#!/usr/bin/env bash
# Convert out/disk.raw to a fixed-size VHD. Azure takes fixed VHDs whose size is a whole number
# of MiB; DISK_SIZE is 20G, which fits. The output is sparse on disk. Not tested on Azure.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -f "$DISK_IMAGE" ] || die "no disk image at $DISK_IMAGE; run: make disk"
if [ -f "$QEMU_PIDFILE" ] && host kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
  die "the VM holds a write lock on $DISK_IMAGE; run: make stop"
fi
host qemu-img convert -f raw -O vpc -o subformat=fixed,force_size "$DISK_IMAGE" "$VHD_IMAGE"
host qemu-img info "$VHD_IMAGE" | head -n 5
log "VHD ready: $VHD_IMAGE"
