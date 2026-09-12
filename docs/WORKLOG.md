# Work log

Append one entry per session. Newest at the bottom. Keep each entry short: what was done, what happened, what is next.

## 2026-09-07, session 1

- Verified upstream facts: Azure Linux 3.0 ships ostree 2024.5 and rpm-ostree 2024.4. Azure Linux 4.0 beta ships bootc 1.13, rpm-ostree 2026.1, ostree 2025.7 with composefs, bootupd 0.2.32. A dnf dry run inside `mcr.microsoft.com/azurelinux-beta/base/core:4.0` resolved the whole bootc package set.
- Found that the Azure Linux kernel package puts `vmlinuz` in `/boot`, not in `/usr/lib/modules/<kver>/`. The Containerfile moves it.
- Found that the bootc package ships a reference base layout under `/usr/share/doc/bootc/baseimage/`. The Containerfile copies it.
- Wrote decision 0001: build on 4.0 with bootc, keep 3.0 with rpm-ostree as the fallback.
- Wrote the scaffold: CLAUDE.md, README, LICENSE, CONTRIBUTING, Makefile, scripts/, Containerfile, config/, docs/.
- Host tools verified: podman 5.8.4, QEMU 10.2.2, OVMF, KVM. Claude runs in a toolbox and reaches them with flatpak-spawn.
- Built the image. Six attempts. Fixes in order: bootupd metadata before emptying `/boot`; stage `/boot/efi` under `/usr/lib/ostree-boot/efi` for bootupd 0.2.32; resolv.conf symlink via tmpfiles because podman bind-mounts it; drop `ostree container commit`; delete the hidden hmac file in `/boot` and build leftovers in `/run`.
- Result: `localhost/azurelinux-bootc:dev`, 1.3 GB, lint passes with one deferred warning (`var-tmpfiles`). Pushed to `localhost:5000/azurelinux-bootc:dev`.
- Blocked on `sudo make disk`, which needs root on the host.
- Next: the user runs `sudo make disk` on the host, then `make run-bg` and `scripts/45-ssh.sh bootc status`.
- The user authorised sudo on the host. `flatpak-spawn --host sudo -n` works. `scripts/30-install-disk.sh` now re-runs itself on the host with sudo.
- Disk install attempt 1 failed in bootupd: bootc 1.13 runs `bootupctl` in a bwrap sandbox and the image had no bubblewrap. The beta repo lacks bubblewrap; the preview repo has it. Added `repos/azurelinux-preview.repo`, `bubblewrap` and `grub2-pc-modules`. Install attempt 2 succeeded.
- Boot 1 stopped at the systemd first-boot wizard on the serial console. Masked `systemd-firstboot.service`. Switched the QEMU serial console to a socket with a log file and added `scripts/42-qemu-monitor.sh`, `scripts/43-serial.sh`, `scripts/46-wait-ssh.sh`.
- Boot 2 reached sshd, but key login failed. Mounted the disk on the host: the key was in place. Cause: root's shadow field is `!unprovisioned`, which sshd treats as locked. The Containerfile now sets it to `*`. Enabled a persistent journal.
- Boot 3: M1 done. `bootc status` in the VM shows the booted image from `10.0.2.2:5000/azurelinux-bootc:dev`, version 1, kernel 6.18.45-1.3.azl4.
- M2 attempt 1 and 2 failed in the version 2 build: `ARG VERSION` at the top invalidated the package layer, and host DNS failed for a few minutes. Moved the build args below the package layers.
- M2 attempt 3 passed. `bootc upgrade` pulled version 2 from the local registry, the VM rebooted into version 2, `bootc rollback` returned it to version 1. Each reboot took about 16 seconds.
- State at the end of the session: the VM runs in the background on version 1 with version 2 staged as the rollback target. `make stop` stops it. Nothing is committed.

## 2026-09-07, session 2

- Committed the scaffold as `1072f3e`.
- Checked the journal of the permissive VM across all boots. The only AVC denials were `sshd_keygen_t` asking for the `sys_resource` capability. The policy has substitution rules for `/var/roothome`, `/var/usrlocal` and `/sysroot/tmp`, and every checked file carried the expected label.
- Set `SELINUX=enforcing` in the Containerfile. Rebuilt version 1 with the cached package layers, reinstalled the disk, booted. `getenforce` printed `Enforcing`, no unit failed, sshd generated its host keys.
- `make upgrade` passed in enforcing mode. The version bump downloaded 2 layers of 2.5 kB, so the `ARG VERSION` placement works.
- Pinned the base image by digest. Tag `4.0` and tag `4.0.2026052700` share the digest `sha256:63ef5dda...`. Added `scripts/05-base-digest.sh` and `make base-digest`, which compare the pin with the tag and can rewrite the pin. The image now records its package list. Rebuilt, reinstalled, booted enforcing, and `make upgrade` passed again with 2 layers of 5.7 kB.
- Added rpm-ostree to the image and `scripts/15-chunk-image.sh`. It runs `rpm-ostree compose build-chunked-oci --rootfs /rootfs` inside the built image with a podman image mount, writes `out/chunked`, and imports the result as the `dev` tag. Three fixes: seed an empty OCI layout before the first run; move the rpm database to `/usr/share/rpm` with a symlink at `/usr/lib/sysimage/rpm`; switch the database from WAL to rollback-journal mode, because `rpm -qa` failed on the read-only host without the WAL side files.
- Result on 2026-09-08: 65 layers, a version bump downloads 2 layers of 63 MB, `make upgrade` passes, `rpm -qa` lists 306 packages on the host.
- The host root filesystem ran out of space during an install. Removed this project's superseded images from both podman stores. The install script now removes the pulled image after use.
- Added image signing. `scripts/22-keys.sh` creates a sigstore key pair, `scripts/25-push.sh` signs with `skopeo copy --sign-by-sigstore-private-key`, the image carries the public key, a policy with `default: reject`, and a registries.d file that enables sigstore attachments. `scripts/30-install-disk.sh` passes `--enforce-container-sigpolicy`. `scripts/55-signature-test.sh` pushes an unsigned variant and expects a refusal, then the signed image and expects acceptance.
- Two fixes: the chunk container needs a permissive policy, because the strict image policy rejected rpm-ostree's own output directory; the first loop pushed a stale image, which showed that enforcement refuses the base policy with "default of insecureAcceptAnything; refusing usage".
- Result on 2026-09-08: `make sig-test` and `make upgrade` pass with signed images.
- Added `.github/workflows/build.yml`: build, chunk, sign, push to ghcr.io. `REGISTRY_FROM_HOST` in `scripts/lib.sh` selects the registry, and TLS verification is off only for localhost. The workflow is not verified: no remote exists yet.
- The build scripts now remove the image a tag pointed at before, and the signature test removes its unsigned variant. Verified with a build: both tags moved and the old images were gone.
- M5: `rpm-ostree install strace` works on the booted host and survives a reboot. `bootc upgrade` refuses the layered deployment. `rpm-ostree upgrade` prints "Pulling manifest" and exits without a new deployment, both with and without a layer; tried three times with versions 2 and 3 in the registry. `rpm-ostree reset` restores a bootc-compatible host, and `bootc upgrade` then moves it to version 3.
- Found the `cachedUpdate` behaviour after `bootc rollback`: `bootc upgrade --check` compares the registry with the cached image, not with the booted one.
- Wrote decision 0003 for the signing design. The VM ends the session on version 3.
- Created the private repository `JayDoubleu/azurelinux-bootc`, set the three signing secrets from the local key, and pushed. Four CI fixes in a row: `shellcheck -x -P SCRIPTDIR`, the AppArmor user namespace sysctl for skopeo on Ubuntu 24.04, the lowercase ghcr.io path, and `--exclude-dir=research` for the em-dash check. Both workflows pass. The signed image is at `ghcr.io/jaydoubleu/azurelinux-bootc:latest`, private.
- Added the ghcr.io scope to the image policy. The VM runs version 4 with it. The `bootc switch` test waits for a token with `read:packages` or a public package.

## 2026-09-12, session 3

- The user added `read:packages` to the `gh` token. The host had rebooted, so the VM was down; `make run-bg` brought it back on version 4.
- Wrote the token to `/etc/ostree/auth.json` in the VM and ran `bootc switch --enforce-container-sigpolicy ghcr.io/jaydoubleu/azurelinux-bootc:latest`. Only 5 of 65 layers (81.9 MB) were new. The VM booted version 5 from ghcr.io, enforcing, with the signature checked.
- Added `scripts/60-switch-test.sh` and `make switch`. It writes the auth file from `gh auth token`, switches, reboots and verifies. Ran it once: PASS.
- M1 to M5 are done. Open: the 63 MB unpackaged layer, `rpm-ostree upgrade` on this host, dated tags.
- Research agent found the `rpm-ostree upgrade` cause: issue #5567, fixed in 2026.2. Confirmed in the VM: `upgrade` stages nothing, `rebase` to the same tag fails with "Old and new refs are equal", `deploy sha256:<digest>` works, and a rebase to `...@sha256:<digest>` with `strace` layered boots version 5 with `strace` and `tmux`. A second rebase to the tag restores the tag origin. `rpm-ostree reset` cleans up.
- CI tags verified on ghcr.io: `latest`, `v7`, `20260912`. `make vhd` works with the VM stopped. Measured an upgrade that adds `tmux`: 6 layers, 83.5 MB.
- Recreated the local registry to drop a 3.4 GB volume. `podman volume prune` also removed 33 unused volumes from other projects; reported to the user.
- Research agent traced the 63 MB layer: rpm-ostree puts the initramfs and every unpackaged file, including all of `/etc`, into one bin, and one changed file changes the whole layer. Marked `/usr/lib/azurelinux-bootc`, `/etc`, `/usr/lib/efi` and `/usr/lib/bootupd` with `user.component` xattrs in the Containerfile. A directory xattr on `/etc` did not take; marking each file did. Result: a version bump downloads 1.5 MB, a config change 6.7 MB. Decision 0004.
- Opened microsoft/azurelinux issue #18802 for the rpm-ostree 2026.1 bug. Recorded the user's decisions: package stays private, empty repository and Azure test and desktop stay on the user's TODO.
- Added aarch64: `ARCH` in `scripts/lib.sh` selects the platform, tag suffix, disk, firmware and QEMU binary; the Containerfile picks the bootloader packages from `TARGETARCH`; kargs.d has one console file per architecture; the CI matrix builds both under emulation. The x86_64 loop was re-run after the refactor.
