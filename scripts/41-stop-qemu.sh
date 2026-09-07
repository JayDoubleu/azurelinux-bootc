#!/usr/bin/env bash
# Stop the background QEMU VM.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ ! -f "$QEMU_PIDFILE" ]; then
  log "no pidfile; nothing to stop"
  exit 0
fi
pid="$(cat "$QEMU_PIDFILE")"
if host kill -0 "$pid" 2>/dev/null; then
  host kill "$pid"
  log "sent SIGTERM to QEMU pid $pid"
else
  log "QEMU pid $pid is not running"
fi
rm -f "$QEMU_PIDFILE" "$QEMU_MONITOR" "$SERIAL_SOCK"
