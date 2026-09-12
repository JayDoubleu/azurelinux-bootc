#!/usr/bin/env bash
# Sign the built image and push it to the local registry.
# skopeo copies the image from the rootless image store, signs it with the sigstore private
# key from 22-keys.sh, and stores the signature next to the image in the registry. The
# registries.d directory from config/ tells skopeo that this registry takes such attachments.
# The signature names the image as HOST_IMAGE_REF. The policy in the image maps the VM's name
# for the registry back to it.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -f "$SIGN_KEY" ] || die "no signing key at $SIGN_KEY; run: make keys"

host skopeo --registries.d "$REGISTRIES_D" copy \
  --dest-tls-verify="$PUSH_TLS_VERIFY" \
  --sign-by-sigstore-private-key "$SIGN_KEY" \
  --sign-passphrase-file "$SIGN_PASSPHRASE" \
  "containers-storage:localhost/${IMAGE_NAME}:${IMAGE_TAG}" \
  "docker://${HOST_IMAGE_REF}" 2>&1 | tee "$LOG_DIR/push.log"
log "pushed and signed ${HOST_IMAGE_REF}"

# EXTRA_TAGS holds more tags for the same image, for example "v5 20260912". CI sets it.
for tag in ${EXTRA_TAGS:-}; do
  host skopeo --registries.d "$REGISTRIES_D" copy \
    --dest-tls-verify="$PUSH_TLS_VERIFY" \
    --sign-by-sigstore-private-key "$SIGN_KEY" \
    --sign-passphrase-file "$SIGN_PASSPHRASE" \
    "containers-storage:localhost/${IMAGE_NAME}:${IMAGE_TAG}" \
    "docker://${REGISTRY_FROM_HOST}/${IMAGE_NAME}:${tag}" >/dev/null
  log "pushed and signed ${REGISTRY_FROM_HOST}/${IMAGE_NAME}:${tag}"
done
