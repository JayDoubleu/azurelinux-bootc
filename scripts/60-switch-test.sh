#!/usr/bin/env bash
# Move the running VM to the signed image on ghcr.io and verify the boot.
# Usage: 60-switch-test.sh [IMAGE]    default: GHCR_IMAGE_REF from lib.sh
# If the package is private, the VM needs a token with the read:packages scope. The script
# takes it from `gh auth token` and writes /etc/ostree/auth.json in the VM. The token stays
# out of the image and out of the logs.
# Precondition: the VM runs in the background.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

image="${1:-$GHCR_IMAGE_REF}"
registry="${image%%/*}"

log "waiting for the VM on port $SSH_PORT"
wait_for_ssh "$SSH_WAIT" || die "the VM is not reachable; run: make run-bg"

if command -v gh >/dev/null 2>&1 && token="$(gh auth token 2>/dev/null)" && [ -n "$token" ]; then
  user="$(gh api user --jq .login)"
  printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$registry" "$(printf '%s:%s' "$user" "$token" | base64 -w0)" \
    | ssh_vm 'mkdir -p /etc/ostree && install -m 600 /dev/stdin /etc/ostree/auth.json'
  log "wrote /etc/ostree/auth.json in the VM for ${registry} as ${user}"
else
  log "no gh token; the pull works only if the package is public"
fi

before="$(ssh_vm cat "$VERSION_FILE")"
log "booted version ${before}; switching to ${image}"
ssh_vm bootc switch --enforce-container-sigpolicy "$image" 2>&1 \
  | grep -vE '^\[|Fetching ostree chunk' | tee "$LOG_DIR/switch.log"

log "rebooting the VM"
ssh_vm systemctl reboot >/dev/null 2>&1 || true
sleep 15
wait_for_ssh "$SSH_WAIT" || die "the VM did not come back after reboot; see $SERIAL_LOG"

booted="$(ssh_vm bootc status --format=json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"]["booted"]["image"]["image"]["image"])')"
after="$(ssh_vm cat "$VERSION_FILE")"
mode="$(ssh_vm getenforce)"
ssh_vm bootc status > "$LOG_DIR/status-switch.txt"
if [ "$booted" != "$image" ]; then
  die "FAIL: booted image is ${booted}, expected ${image}"
fi
log "booted ${booted}, version ${after}, SELinux ${mode}"
ssh_vm bootc upgrade --check 2>&1 | tail -n 1
log "PASS: switch to ${image}"
