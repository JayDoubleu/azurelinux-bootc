#!/usr/bin/env bash
# Send commands to the background QEMU monitor.
# Usage: 42-qemu-monitor.sh [--delay SECONDS] COMMAND...
# Example: 42-qemu-monitor.sh --delay 2 'sendkey ret' 'sendkey ret'
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

delay=0.5
if [ "${1:-}" = "--delay" ]; then
  delay="$2"
  shift 2
fi
[ "$#" -ge 1 ] || die "usage: $0 [--delay SECONDS] COMMAND..."
[ -S "$QEMU_MONITOR" ] || die "no monitor socket at $QEMU_MONITOR; is the VM running in the background?"

# python3 runs on the host so it can open the socket that the host QEMU created.
host python3 - "$QEMU_MONITOR" "$delay" "$@" <<'PY'
import socket, sys, time
path, delay, cmds = sys.argv[1], float(sys.argv[2]), sys.argv[3:]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(path)
s.settimeout(1.0)
def drain():
    out = b""
    try:
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            out += chunk
    except socket.timeout:
        pass
    return out.decode(errors="replace")
drain()
for c in cmds:
    s.sendall((c + "\n").encode())
    time.sleep(delay)
    reply = drain().replace("\r", "")
    print(f"> {c}\n{reply.strip()}")
PY
