# Roadmap

## M1: Boot in QEMU (done 2026-09-07)

Goal: `make build`, `sudo make disk` and `make run` boot an Azure Linux 4.0 bootc image to a root shell over ssh.

Done when: `bootc status` in the VM shows the booted image, and `cat /usr/lib/azurelinux-bootc/version` prints `1`.

## M2: Upgrade and roll back from a registry (done 2026-09-07)

Goal: `make upgrade` passes. The VM pulls version 2 from the local registry, reboots into it, then rolls back to version 1.

## M3: Harden

- SELinux enforcing. Done 2026-09-07.
- Signed images with a signature policy in the image. Done 2026-09-08.
- A registry outside the test host. Signed image on ghcr.io since 2026-09-08; the `bootc switch` test from the VM is pending. One tag per Azure Linux snapshot is future work.

## M4: Build in CI (done 2026-09-08)

- GitHub Actions builds, chunks, signs and pushes `ghcr.io/jaydoubleu/azurelinux-bootc:latest` on each push to `main`.
- A boot test in CI with QEMU, if the runner supports KVM.

## M5: Package layering (done 2026-09-08)

- `rpm-ostree install` works on the bootc host. Verified with `strace`.
- A layered deployment blocks `bootc upgrade`, and `rpm-ostree upgrade` does not deploy a new image on this host. See `docs/STATUS.md`.

## Fallback: Azure Linux 3.0 with rpm-ostree

If 4.0 preview churn blocks M1 or M2, switch to 3.0 GA. Build the image with `rpm-ostree compose image` and update with `rpm-ostree rebase ostree-unverified-registry:...`. See `docs/decisions/0001-azurelinux-4-with-bootc.md`.

## Future

- Desktop environment. Azure Linux ships no GNOME, KDE or Sway. This needs packaging work.
- Flatpak.
- aarch64.
- Azure VM image. Convert the disk to VHD, or use bootc-image-builder.
