# Status

Read this first. Update it at the end of every session.

Last updated: 2026-09-07, session 2

## Current milestone

M1 and M2 are done. M3 (harden) is in progress: SELinux enforcing is done. See `docs/ROADMAP.md`.

## What works (verified, with date)

- 2026-09-07: `make build` produces `localhost/azurelinux-bootc:dev` (1.3 GB). `bootc container lint` passes 12 checks with 1 warning (`var-tmpfiles`).
- 2026-09-07: `make registry` and `make push` work. The registry at `localhost:5000` holds `azurelinux-bootc:dev`.
- 2026-09-07: `make disk` works. It re-runs itself on the host with sudo. `bootc install to-disk` writes GPT, ESP, XFS root, and the grub EFI and BIOS loaders through bootupd.
- 2026-09-07: `make run-bg` boots the disk with OVMF. GRUB 2.12 loads kernel 6.18.45-1.3.azl4. systemd-networkd gets DHCP. sshd answers on port 2222 with the generated key.
- 2026-09-07: in the VM, `bootc status` shows the booted image `10.0.2.2:5000/azurelinux-bootc:dev`, store `ostreeContainer`. `/usr/lib/azurelinux-bootc/version` prints `1`.
- 2026-09-07: SELinux runs enforcing. `getenforce` prints `Enforcing` after a fresh install and after the upgrade test. No unit fails. The only AVC denials are `sshd_keygen_t` asking for the `sys_resource` capability; key generation still works.
- 2026-09-07: the VM can reach the local registry: `skopeo inspect --tls-verify=false docker://10.0.2.2:5000/azurelinux-bootc:dev` works.
- 2026-09-07: `make upgrade` passes. The VM ran `bootc upgrade`, pulled version 2 from `10.0.2.2:5000`, rebooted into version 2 in about 16 seconds, ran `bootc rollback`, and rebooted into version 1. Logs: `out/logs/upgrade.log`, `out/logs/status-*.txt`.
- 2026-09-07: a version bump reuses the cached package layers. The second upgrade run reported `layers already present: 9; layers needed: 2 (2.5 kB)`.
- 2026-09-07: `make check` and `make lint` pass.
- 2026-09-07: the Containerfile pins the base image by digest (tag `4.0.2026052700`). `make base-digest` compares the pin with the `4.0` tag. The build reuses the cached layers with the pin. The image records its package list in `/usr/lib/azurelinux-bootc/packages` (302 packages).

## What is unverified or broken

- Lint warning `var-tmpfiles`: `/var` content has no tmpfiles.d entries. Deferred. ostree copies the image's `/var` into the machine's `/var` on the first deployment.
- The packages are not pinned. The preview repo has no snapshots. The package list in the image is the record of what each build got.
- A config change downloads only small layers. A package update changes the single 1.2 GB package layer and downloads all of it. Chunking with `rpm-ostree compose build-chunked-oci` (present in rpm-ostree 2026.1) is the planned fix.

## Next action

1. Split the image into chunked layers so a package update downloads only the changed packages.
2. Sign the image with a sigstore key and verify the signature in the VM with a policy in the image.
3. Add a CI build.
4. M5: test package layering with rpm-ostree.

## Environment notes

- Claude runs in a Fedora toolbox. Scripts call host tools with `flatpak-spawn --host`.
- The user authorised sudo on the host for this loop. sudo is set up on the host. See `CLAUDE.md`.
- The Bash tool shell is zsh. Do not `source scripts/lib.sh` inline; run the scripts, which have a bash shebang.
- Host DNS failed once for a few minutes. If a build fails with "Could not resolve hostname", retry.
- The 4.0 beta base container uses the repo path `azurelinux/4.0/beta/base` (`$releasever` is `4.0`). The preview repo path is `azurelinux/4/preview/base`, with a literal `4`. `repos/azurelinux-preview.repo` adds it because the beta repo lacks bubblewrap. Packages now come from the preview repo where it is newer.
- The 4.0 kernel package ships `vmlinuz` under `/boot`. The Containerfile moves it.
- bootupd 0.2.32 reads EFI files from `/usr/lib/ostree-boot/efi/EFI` and needs `/boot/efi` present for `rpm -qf`. The Containerfile copies `/boot/efi` there before `bootupctl backend generate-update-metadata`.
- bootc 1.13 runs `bootupctl` inside a bwrap sandbox during install, so the image needs `bubblewrap`. A generic install writes both BIOS and EFI loaders, so it needs `grub2-pc-modules`.
- `ostree container commit` does not work in this image. It needs an ostree repo marker under `/sysroot` that only rpm-ostree-composed images carry.
- podman bind-mounts `/etc/resolv.conf` during the build. The resolv.conf symlink is created at boot by a tmpfiles rule instead.
- `systemd-firstboot.service` prompts on the serial console and blocks the boot. It is masked.
- The base image locks root with `!unprovisioned` in `/etc/shadow`. sshd refuses a locked account even for key login. The Containerfile sets the field to `*`.
- The QEMU serial console is a unix socket with a log file. `scripts/43-serial.sh` types into it. `scripts/42-qemu-monitor.sh` talks to the QEMU monitor.
- There is no `bootc-base-imagectl` in the 4.0 bootc package.
