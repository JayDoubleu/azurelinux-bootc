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
