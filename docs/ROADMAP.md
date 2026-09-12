# Roadmap

## M1: Boot in QEMU (done 2026-09-07)

Goal: `make build`, `sudo make disk` and `make run` boot an Azure Linux 4.0 bootc image to a root shell over ssh.

Done when: `bootc status` in the VM shows the booted image, and `cat /usr/lib/azurelinux-bootc/version` prints `1`.

## M2: Upgrade and roll back from a registry (done 2026-09-07)

Goal: `make upgrade` passes. The VM pulls version 2 from the local registry, reboots into it, then rolls back to version 1.

## M3: Harden (done 2026-09-12)

- SELinux enforcing. Done 2026-09-07.
- Signed images with a signature policy in the image. Done 2026-09-08.
- A registry outside the test host. The VM boots the signed image from ghcr.io since 2026-09-12. One tag per Azure Linux snapshot is future work.

## M4: Build in CI (done 2026-09-08)

- GitHub Actions builds, chunks, signs and pushes `ghcr.io/jaydoubleu/azurelinux-bootc:latest` on each push to `main`.
- A boot test in CI with QEMU under KVM: install, boot, upgrade and rollback, signature test. Added 2026-09-12 for x86_64.

## M5: Package layering (done 2026-09-08)

- `rpm-ostree install` works on the bootc host. Verified with `strace`.
- A layered deployment blocks `bootc upgrade`. `rpm-ostree upgrade` is broken in rpm-ostree 2026.1 (upstream issue #5567). A rebase to a digest reference is the workaround. See `docs/STATUS.md`.

## Fallback: Azure Linux 3.0 with rpm-ostree

If 4.0 preview churn blocks M1 or M2, switch to 3.0 GA. Build the image with `rpm-ostree compose image` and update with `rpm-ostree rebase ostree-unverified-registry:...`. See `docs/decisions/0001-azurelinux-4-with-bootc.md`.

## Future

- Desktop environment. Checked on 2026-09-12: the 4.0 preview repo has no compositor, display manager, session, portal or audio server. Only `xorg-x11-server-Xwayland` and `mesa-dri-drivers` exist. GNOME, KDE, Sway and their dependencies need packaging first.
- Flatpak. Not in the 4.0 preview repo either. Same packaging work.
- aarch64. Done 2026-09-12: CI builds, installs and boots it on the native `ubuntu-24.04-arm` runner under TCG. User-mode emulation on x86_64 cannot run `bootc install`.
- Azure VM image. `make vhd` writes a fixed VHD from `out/disk.raw`. Not tested on Azure.
