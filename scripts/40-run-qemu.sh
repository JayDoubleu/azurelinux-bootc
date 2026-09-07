#!/usr/bin/env bash
# Boot the disk image in QEMU with UEFI firmware.
# Usage: 40-run-qemu.sh              # foreground, serial console on this terminal
#        40-run-qemu.sh --background # detached, serial log in out/serial.log, console on out/serial.sock
# ssh reaches the VM at localhost:2222 as root with out/ssh/id_ed25519.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mode="${1:-foreground}"
[ -f "$DISK_IMAGE" ] || die "no disk image at $DISK_IMAGE; run on the host: sudo make disk"

if [ ! -f "$OVMF_VARS" ]; then
  host cp "$OVMF_VARS_SRC" "$OVMF_VARS"
fi

# shellcheck disable=SC2054  # QEMU option values contain commas by design
args=(
  -machine q35,accel=kvm
  -cpu host
  -m "$VM_MEMORY"
  -smp "$VM_CPUS"
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
  -drive "if=pflash,format=raw,file=$OVMF_VARS"
  -drive "file=$DISK_IMAGE,format=raw,if=virtio,cache=writeback"
  -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22"
  -device virtio-rng-pci
)

case "$mode" in
  --background|-b)
    if [ -f "$QEMU_PIDFILE" ] && host kill -0 "$(cat "$QEMU_PIDFILE")" 2>/dev/null; then
      die "QEMU already runs with pid $(cat "$QEMU_PIDFILE"); run: make stop"
    fi
    rm -f "$QEMU_PIDFILE" "$QEMU_MONITOR" "$SERIAL_SOCK"
    : > "$SERIAL_LOG"
    # The serial console is a unix socket with a log file, so scripts can both read
    # the boot log and type into the console. See 43-serial.sh.
    args+=(
      -display none
      -chardev "socket,id=serial0,path=$SERIAL_SOCK,server=on,wait=off,logfile=$SERIAL_LOG"
      -serial chardev:serial0
      -monitor "unix:$QEMU_MONITOR,server,nowait"
      -pidfile "$QEMU_PIDFILE"
      -daemonize
    )
    host qemu-system-x86_64 "${args[@]}"
    log "QEMU started in the background; serial log: $SERIAL_LOG; ssh: make ssh"
    ;;
  foreground)
    args+=( -nographic )
    log "starting QEMU in the foreground; exit with Ctrl-a x"
    host qemu-system-x86_64 "${args[@]}"
    ;;
  *)
    die "usage: $0 [--background]"
    ;;
esac
