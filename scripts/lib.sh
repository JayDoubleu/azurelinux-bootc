#!/usr/bin/env bash
# Shared settings and helpers. Source this file from the other scripts. Do not run it.
# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are used by the scripts that source this file

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
LOG_DIR="$OUT_DIR/logs"

# The Containerfile pins this image by digest. 05-base-digest.sh compares the pin with the tag.
BASE_IMAGE_REPO="mcr.microsoft.com/azurelinux-beta/base/core"
BASE_IMAGE_TAG="4.0"

IMAGE_NAME="${IMAGE_NAME:-azurelinux-bootc}"
IMAGE_TAG="${IMAGE_TAG:-dev}"

# QEMU user networking maps the host to 10.0.2.2 inside the VM.
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY_NAME="azl-registry"
REGISTRY_FROM_HOST="localhost:${REGISTRY_PORT}"
REGISTRY_FROM_VM="10.0.2.2:${REGISTRY_PORT}"
HOST_IMAGE_REF="${REGISTRY_FROM_HOST}/${IMAGE_NAME}:${IMAGE_TAG}"
VM_IMAGE_REF="${REGISTRY_FROM_VM}/${IMAGE_NAME}:${IMAGE_TAG}"

DISK_IMAGE="$OUT_DIR/disk.raw"
DISK_SIZE="${DISK_SIZE:-20G}"
VM_MEMORY="${VM_MEMORY:-2048}"
VM_CPUS="${VM_CPUS:-2}"
SSH_PORT="${SSH_PORT:-2222}"
SSH_KEY="$OUT_DIR/ssh/id_ed25519"

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/ovmf/OVMF_CODE.fd}"
OVMF_VARS_SRC="${OVMF_VARS_SRC:-/usr/share/edk2/ovmf/OVMF_VARS.fd}"
OVMF_VARS="$OUT_DIR/OVMF_VARS.fd"
QEMU_PIDFILE="$OUT_DIR/qemu.pid"
QEMU_MONITOR="$OUT_DIR/qemu-monitor.sock"
SERIAL_LOG="$OUT_DIR/serial.log"
SERIAL_SOCK="$OUT_DIR/serial.sock"

# The image writes its build number here. The upgrade test reads it.
VERSION_FILE="/usr/lib/azurelinux-bootc/version"

mkdir -p "$OUT_DIR" "$LOG_DIR"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# host CMD...: run CMD on the host. Inside a toolbox, go through flatpak-spawn.
if [ -f /run/.toolboxenv ]; then
  host() { flatpak-spawn --host "$@"; }
else
  host() { "$@"; }
fi

# host_has NAME: return 0 if the host has the command NAME.
# shellcheck disable=SC2016  # the $1 is expanded by the host shell
host_has() { host sh -c 'command -v "$1" >/dev/null 2>&1' _ "$1"; }

# host_exists PATH: return 0 if PATH exists on the host.
# shellcheck disable=SC2016  # the $1 is expanded by the host shell
host_exists() { host sh -c 'test -e "$1"' _ "$1"; }

# ssh_vm CMD...: run CMD as root inside the VM.
ssh_vm() {
  ssh -i "$SSH_KEY" -p "$SSH_PORT" \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o ConnectTimeout=5 \
    root@localhost "$@"
}

# wait_for_ssh SECONDS: return 0 when the VM answers over ssh before the deadline.
wait_for_ssh() {
  local deadline
  deadline=$(( $(date +%s) + ${1:-300} ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if ssh_vm true 2>/dev/null; then
      return 0
    fi
    sleep 5
  done
  return 1
}
