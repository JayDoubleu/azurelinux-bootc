#!/usr/bin/env bash
# Write the image to a raw disk file with `bootc install to-disk`.
# This step needs root on the host: it uses loop devices and mounts.
# It re-runs itself on the host with sudo when started from the toolbox or as a user.
# It pulls the image from the local registry, because root podman has its own image store.
# --enforce-container-sigpolicy records the target image as signature-verified, so bootc
# upgrade refuses a policy that accepts unsigned images.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Re-run on the host as root when needed. Loop devices and mounts need root. sudo resets the
# environment, so the settings that select the image and the registry go through explicitly.
sudo_env=(
  "ARCH=$ARCH" "IMAGE_NAME=$IMAGE_NAME" "IMAGE_TAG=$IMAGE_TAG" "OUT_DIR=$OUT_DIR"
  "REGISTRY_PORT=$REGISTRY_PORT" "REGISTRY_FROM_HOST=$REGISTRY_FROM_HOST" "DISK_SIZE=$DISK_SIZE"
)
if [ -f /run/.toolboxenv ]; then
  log "re-running on the host with sudo"
  exec flatpak-spawn --host sudo env "${sudo_env[@]}" "$REPO_ROOT/scripts/30-install-disk.sh"
fi
if [ "$(id -u)" -ne 0 ]; then
  log "re-running with sudo"
  exec sudo env "${sudo_env[@]}" "$REPO_ROOT/scripts/30-install-disk.sh"
fi

mkdir -p "$OUT_DIR/ssh"
if [ ! -f "$SSH_KEY" ]; then
  ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C azurelinux-bootc-test >/dev/null
  log "created ssh key $SSH_KEY"
fi

log "pulling ${HOST_IMAGE_REF} into the root image store"
podman pull --platform "$PODMAN_PLATFORM" --tls-verify=false "$HOST_IMAGE_REF" >/dev/null

rm -f "$DISK_IMAGE"
truncate -s "$DISK_SIZE" "$DISK_IMAGE"
log "installing to $DISK_IMAGE (${DISK_SIZE}); the VM will pull updates from ${VM_IMAGE_REF}"

podman run --rm --privileged --pid=host --platform "$PODMAN_PLATFORM" \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  -v "$OUT_DIR:/output" \
  "$HOST_IMAGE_REF" \
  bootc install to-disk \
    --via-loopback \
    --generic-image \
    --wipe \
    --filesystem xfs \
    --target-imgref "$VM_IMAGE_REF" \
    --enforce-container-sigpolicy \
    --root-ssh-authorized-keys /output/ssh/id_ed25519.pub \
    "/output/$(basename "$DISK_IMAGE")" 2>&1 | tee "$LOG_DIR/install.log"

# The root image store only serves this install. Drop the image again so the store does not
# grow by one image per install.
podman rmi -f "$HOST_IMAGE_REF" >/dev/null
podman image prune -f >/dev/null

# Hand the output back to the user who ran sudo, so QEMU can run without root.
if [ -n "${SUDO_UID:-}" ]; then
  chown -R "${SUDO_UID}:${SUDO_GID:-$SUDO_UID}" "$OUT_DIR"
fi
log "disk image ready: $DISK_IMAGE"
