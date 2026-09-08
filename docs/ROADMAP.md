# Roadmap

## M1: Boot in QEMU (done 2026-09-07)

Goal: `make build`, `sudo make disk` and `make run` boot an Azure Linux 4.0 bootc image to a root shell over ssh.

Done when: `bootc status` in the VM shows the booted image, and `cat /usr/lib/azurelinux-bootc/version` prints `1`.

## M2: Upgrade and roll back from a registry (done 2026-09-07)

Goal: `make upgrade` passes. The VM pulls version 2 from the local registry, reboots into it, then rolls back to version 1.

## M3: Harden

- SELinux enforcing. Done 2026-09-07.
- Signed images with a signature policy in the image. Done 2026-09-08.
- A public registry with one tag per Azure Linux snapshot.

## M4: Build in CI

- GitHub Actions builds and pushes the image on each commit.
- A boot test in CI with QEMU, if the runner supports KVM.

## M5: Package layering

- Verify `rpm-ostree install` on top of the bootc host.
- Record how layered packages affect `bootc upgrade`.

## Fallback: Azure Linux 3.0 with rpm-ostree

If 4.0 preview churn blocks M1 or M2, switch to 3.0 GA. Build the image with `rpm-ostree compose image` and update with `rpm-ostree rebase ostree-unverified-registry:...`. See `docs/decisions/0001-azurelinux-4-with-bootc.md`.

## Future

- Desktop environment. Azure Linux ships no GNOME, KDE or Sway. This needs packaging work.
- Flatpak.
- aarch64.
- Azure VM image. Convert the disk to VHD, or use bootc-image-builder.
