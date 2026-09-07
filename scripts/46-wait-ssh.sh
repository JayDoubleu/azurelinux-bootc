#!/usr/bin/env bash
# Wait until the VM answers over ssh. Usage: 46-wait-ssh.sh [SECONDS]
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

limit="${1:-300}"
log "waiting up to ${limit}s for ssh on port ${SSH_PORT}"
if wait_for_ssh "$limit"; then
  log "ssh is up"
else
  die "ssh did not answer within ${limit}s; read $SERIAL_LOG"
fi
