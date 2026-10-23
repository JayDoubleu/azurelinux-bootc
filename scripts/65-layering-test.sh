#!/usr/bin/env bash
# Package layering and `rpm-ostree upgrade` test against a running VM.
# rpm-ostree 2026.1 before 2026.1-7.azl4 pulled a new image and exited 0 without a deployment
# (rpm-ostree issue #5567). This test makes sure that the fix stays in the image.
# Steps:
#   1. Build and push version N+1. `rpm-ostree upgrade` must stage it. Reboot, verify N+1.
#   2. `rpm-ostree upgrade` again must print "No upgrade available." and stage nothing.
#   3. `rpm-ostree install LAYER_PACKAGE`, reboot, verify the package.
#   4. Build and push N+2. `rpm-ostree upgrade` must stage it with the package. Reboot, verify both.
#   5. `rpm-ostree upgrade` again must print "No upgrade available." and stage nothing.
#   6. `rpm-ostree reset`, reboot, verify that the package is gone and `bootc upgrade --check` works.
# Precondition: the VM runs in the background, the registry is up, and the booted deployment
# has no layered packages.
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# LAYER_PACKAGE must come from the repos in the image and must not be in the image.
LAYER_PACKAGE="${LAYER_PACKAGE:-strace}"

get_version() { ssh_vm cat "$VERSION_FILE"; }

# staged: print the number of staged deployments.
staged() {
  ssh_vm rpm-ostree status --json \
    | python3 -c 'import json,sys; print(sum(1 for d in json.load(sys.stdin)["deployments"] if d.get("staged")))'
}

# booted_layers: print the layered packages of the booted deployment, separated by spaces.
booted_layers() {
  ssh_vm rpm-ostree status --json \
    | python3 -c 'import json,sys; print(" ".join(next(d for d in json.load(sys.stdin)["deployments"] if d["booted"]).get("packages", [])))'
}

reboot_and_wait() {
  log "rebooting the VM"
  ssh_vm systemctl reboot >/dev/null 2>&1 || true
  sleep 15
  wait_for_ssh "$SSH_WAIT" || die "the VM did not come back after reboot; see $SERIAL_LOG"
}

build_and_push() {
  log "building version $1"
  "$REPO_ROOT/scripts/10-build-image.sh" "$1" >/dev/null
  "$REPO_ROOT/scripts/15-chunk-image.sh" >/dev/null
  "$REPO_ROOT/scripts/25-push.sh" >/dev/null
}

# upgrade_expect_stage LOG: run `rpm-ostree upgrade` and expect a staged deployment.
upgrade_expect_stage() {
  log "running rpm-ostree upgrade in the VM"
  ssh_vm rpm-ostree upgrade > "$LOG_DIR/$1" 2>&1 || { cat "$LOG_DIR/$1"; die "FAIL: rpm-ostree upgrade exited non-zero"; }
  if [ "$(staged)" != 1 ]; then
    cat "$LOG_DIR/$1"
    die "FAIL: rpm-ostree upgrade staged no deployment (rpm-ostree issue #5567)"
  fi
  log "staged: $(tail -n 1 "$LOG_DIR/$1")"
}

# upgrade_expect_none LOG: run `rpm-ostree upgrade` with no new image and expect no change.
upgrade_expect_none() {
  log "running rpm-ostree upgrade with no new image"
  ssh_vm rpm-ostree upgrade > "$LOG_DIR/$1" 2>&1 || { cat "$LOG_DIR/$1"; die "FAIL: rpm-ostree upgrade exited non-zero"; }
  if ! grep -q "No upgrade available." "$LOG_DIR/$1" || [ "$(staged)" != 0 ]; then
    cat "$LOG_DIR/$1"
    die "FAIL: expected \"No upgrade available.\" and no staged deployment"
  fi
  log "no upgrade: $(tail -n 1 "$LOG_DIR/$1")"
}

# expect_booted VERSION PACKAGES: compare the booted version and its layered packages.
expect_booted() {
  local version layers
  version="$(get_version)"
  layers="$(booted_layers)"
  if [ "$version" != "$1" ] || [ "$layers" != "$2" ]; then
    die "FAIL: expected version $1 with layers [$2], got version $version with layers [$layers]"
  fi
  log "booted version $version, layers [$layers]"
}

log "waiting for the VM on port $SSH_PORT"
wait_for_ssh "$SSH_WAIT" || die "the VM is not reachable; run: make run-bg"
log "VM runs $(ssh_vm rpm -q rpm-ostree)"
if [ -n "$(booted_layers)" ]; then
  die "the booted deployment has layered packages [$(booted_layers)]; run rpm-ostree reset in the VM and reboot"
fi

before="$(get_version)"
build_and_push $(( before + 1 ))
upgrade_expect_stage layering-upgrade-1.log
reboot_and_wait
expect_booted $(( before + 1 )) ""
upgrade_expect_none layering-noop-1.log

log "layering ${LAYER_PACKAGE}"
ssh_vm rpm-ostree install "$LAYER_PACKAGE" > "$LOG_DIR/layering-install.log" 2>&1 \
  || { cat "$LOG_DIR/layering-install.log"; die "FAIL: rpm-ostree install ${LAYER_PACKAGE}"; }
reboot_and_wait
expect_booted $(( before + 1 )) "$LAYER_PACKAGE"
ssh_vm rpm -q "$LAYER_PACKAGE" >/dev/null || die "FAIL: ${LAYER_PACKAGE} is not installed"

build_and_push $(( before + 2 ))
upgrade_expect_stage layering-upgrade-2.log
reboot_and_wait
expect_booted $(( before + 2 )) "$LAYER_PACKAGE"
ssh_vm rpm -q "$LAYER_PACKAGE" >/dev/null || die "FAIL: ${LAYER_PACKAGE} is not installed after the upgrade"
upgrade_expect_none layering-noop-2.log

log "removing the layer with rpm-ostree reset"
ssh_vm rpm-ostree reset > "$LOG_DIR/layering-reset.log" 2>&1 \
  || { cat "$LOG_DIR/layering-reset.log"; die "FAIL: rpm-ostree reset"; }
reboot_and_wait
expect_booted $(( before + 2 )) ""
if ssh_vm rpm -q "$LAYER_PACKAGE" >/dev/null 2>&1; then
  die "FAIL: ${LAYER_PACKAGE} is still installed after rpm-ostree reset"
fi
ssh_vm bootc upgrade --check > "$LOG_DIR/layering-bootc-check.log" 2>&1 \
  || { cat "$LOG_DIR/layering-bootc-check.log"; die "FAIL: bootc upgrade --check after rpm-ostree reset"; }
ssh_vm bootc status > "$LOG_DIR/status-layering.txt"
log "PASS: rpm-ostree upgrade $before -> $(( before + 1 )) -> $(( before + 2 )) with ${LAYER_PACKAGE} layered, then reset"
