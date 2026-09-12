#!/usr/bin/env bash
# Check that the VM rejects an unsigned image and accepts the signed one.
# Steps: push an unsigned variant of the current image under the same tag, expect
# `bootc upgrade --check` to fail; push the signed image again, expect it to pass.
# Precondition: the VM runs in the background and the registry is up.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log "waiting for the VM on port $SSH_PORT"
wait_for_ssh "$SSH_WAIT" || die "the VM is not reachable; run: make run-bg"

# A new label gives the image a new manifest digest, so no stored signature matches it.
unsigned_ref="localhost/${IMAGE_NAME}:unsigned"
log "building an unsigned variant ${unsigned_ref}"
printf 'FROM localhost/%s:%s\nLABEL org.azurelinux-bootc.test=unsigned\n' "$IMAGE_NAME" "$IMAGE_TAG" \
  > "$OUT_DIR/unsigned.Containerfile"
host podman build -q -t "$unsigned_ref" -f "$OUT_DIR/unsigned.Containerfile" "$OUT_DIR" >/dev/null

log "pushing the unsigned variant to ${HOST_IMAGE_REF}"
host skopeo copy -q --dest-tls-verify=false --remove-signatures \
  "containers-storage:${unsigned_ref}" "docker://${HOST_IMAGE_REF}"

log "expecting bootc upgrade --check to fail in the VM"
if ssh_vm bootc upgrade --check > "$LOG_DIR/signature-unsigned.log" 2>&1; then
  cat "$LOG_DIR/signature-unsigned.log"
  die "FAIL: the VM accepted an unsigned image"
fi
if ! grep -qiE "signature|rejected" "$LOG_DIR/signature-unsigned.log"; then
  cat "$LOG_DIR/signature-unsigned.log"
  die "FAIL: bootc upgrade --check failed for another reason"
fi
log "unsigned image rejected: $(tail -n 1 "$LOG_DIR/signature-unsigned.log")"

log "pushing the signed image again"
"$REPO_ROOT/scripts/25-push.sh" >/dev/null
ssh_vm bootc upgrade --check > "$LOG_DIR/signature-signed.log" 2>&1 \
  || { cat "$LOG_DIR/signature-signed.log"; die "FAIL: the VM rejected the signed image"; }
log "signed image accepted: $(head -n 1 "$LOG_DIR/signature-signed.log")"
host podman rmi "$unsigned_ref" >/dev/null 2>&1 || true
log "PASS: signature verification"
