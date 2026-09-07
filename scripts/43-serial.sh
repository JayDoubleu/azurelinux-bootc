#!/usr/bin/env bash
# Type into the serial console of the background VM and show what it prints.
# Usage: 43-serial.sh [--wait SECONDS] TEXT...
# Each TEXT argument is sent followed by Enter. The script then prints the console
# output that arrives within the wait time (default 3 seconds).
# Example: 43-serial.sh --wait 5 '' 'root' 'cat /etc/os-release'
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

wait_seconds=3
if [ "${1:-}" = "--wait" ]; then
  wait_seconds="$2"
  shift 2
fi
[ -S "$SERIAL_SOCK" ] || die "no serial socket at $SERIAL_SOCK; is the VM running in the background?"

# python3 runs on the host so it can open the socket that the host QEMU created.
host python3 - "$SERIAL_SOCK" "$wait_seconds" "$@" <<'PY'
import socket, sys, time, re
path, wait_seconds, lines = sys.argv[1], float(sys.argv[2]), sys.argv[3:]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(path)
s.settimeout(0.5)
def drain(seconds):
    out = b""
    end = time.time() + seconds
    while time.time() < end:
        try:
            chunk = s.recv(4096)
            if not chunk:
                break
            out += chunk
        except socket.timeout:
            pass
    text = out.decode(errors="replace").replace("\r", "")
    return re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", text)
drain(0.5)
for line in lines:
    s.sendall((line + "\n").encode())
    time.sleep(0.3)
print(drain(wait_seconds), end="")
PY
