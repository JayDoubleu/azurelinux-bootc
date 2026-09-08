#!/usr/bin/env bash
# Create the sigstore key pair that signs the image.
# Private key and passphrase: out/keys/. They stay out of git.
# Public key: config/etc/pki/containers/azurelinux-bootc.pub. It is also out of git. The build
# copies it into the image, and config/etc/containers/policy.json requires a signature from it.
# 10-build-image.sh runs this script when the private key is missing.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [ -f "$SIGN_KEY" ] && [ -f "$SIGN_PUBKEY" ]; then
  log "signing key exists: $SIGN_KEY"
  exit 0
fi

mkdir -p "$KEY_DIR" "$(dirname "$SIGN_PUBKEY")"
umask 077
if [ ! -f "$SIGN_PASSPHRASE" ]; then
  head -c 32 /dev/urandom | base64 | tr -d '\n' > "$SIGN_PASSPHRASE"
fi
rm -f "$SIGN_KEY" "${SIGN_KEY%.private}.pub"
host skopeo generate-sigstore-key --output-prefix "${SIGN_KEY%.private}" --passphrase-file "$SIGN_PASSPHRASE" >/dev/null
install -m 0644 "${SIGN_KEY%.private}.pub" "$SIGN_PUBKEY"
log "created $SIGN_KEY and $SIGN_PUBKEY"
