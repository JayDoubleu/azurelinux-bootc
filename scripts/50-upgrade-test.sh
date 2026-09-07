#!/usr/bin/env bash
# End-to-end update test against a running VM.
# Steps: read the booted version N, build and push version N+1, run `bootc upgrade`,
# reboot, verify N+1, run `bootc rollback`, reboot, verify N.
# Precondition: the VM runs in the background and the registry is up.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

get_version() { ssh_vm cat "$VERSION_FILE"; }

reboot_and_wait() {
  log "rebooting the VM"
  ssh_vm systemctl reboot >/dev/null 2>&1 || true
  sleep 15
  wait_for_ssh 300 || die "the VM did not come back after reboot; see $SERIAL_LOG"
}

log "waiting for the VM on port $SSH_PORT"
wait_for_ssh 300 || die "the VM is not reachable; run: make run-bg"

before="$(get_version)"
next=$(( before + 1 ))
log "booted version: $before; building version $next"
ssh_vm bootc status > "$LOG_DIR/status-before.txt"

"$REPO_ROOT/scripts/10-build-image.sh" "$next" >/dev/null
"$REPO_ROOT/scripts/25-push.sh" >/dev/null

log "running bootc upgrade in the VM"
ssh_vm bootc upgrade 2>&1 | tee "$LOG_DIR/upgrade.log"
reboot_and_wait

after="$(get_version)"
ssh_vm bootc status > "$LOG_DIR/status-after.txt"
if [ "$after" != "$next" ]; then
  die "FAIL: expected version $next after upgrade, got $after"
fi
log "upgrade ok: version $after"

log "running bootc rollback in the VM"
ssh_vm bootc rollback 2>&1 | tee "$LOG_DIR/rollback.log"
reboot_and_wait

rolled="$(get_version)"
ssh_vm bootc status > "$LOG_DIR/status-rollback.txt"
if [ "$rolled" != "$before" ]; then
  die "FAIL: expected version $before after rollback, got $rolled"
fi
log "rollback ok: version $rolled"
log "PASS: upgrade $before -> $next and rollback -> $before"
