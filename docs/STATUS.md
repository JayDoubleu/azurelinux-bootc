# Status

Read this first. Update it at the end of every session.

Last updated: 2026-10-23

## Current milestone

M1 to M5 are done, the repository is public, and CI runs the full test loop for x86_64 under KVM and for aarch64 under TCG. What is left is in the open issues and in the Future section of `docs/ROADMAP.md`.

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
- 2026-09-08: `make build` runs `rpm-ostree compose build-chunked-oci` after the podman build. The image has 65 package-aligned layers. A version bump downloads 2 layers of 63 MB instead of the whole package layer. See `docs/decisions/0002-chunked-layers-with-rpm-ostree.md`.
- 2026-09-08: `rpm -qa` works on the booted host and lists 306 packages. The rpm database sits at `/usr/share/rpm` in rollback-journal mode.
- 2026-09-08: `bootc status` shows `version: '1'` from the `org.opencontainers.image.version` label.
- 2026-09-08: the repository is `github.com/JayDoubleu/azurelinux-bootc`. Both workflows pass on `main`: `lint` in 16 s, `build` in about 4.5 min. The build pushes `ghcr.io/jaydoubleu/azurelinux-bootc:latest`, signed with the key from the repository secrets, which matches the public key in the image. The package is private at the moment.
- 2026-09-08: the image policy trusts `ghcr.io/jaydoubleu/azurelinux-bootc` with that key. The VM runs version 4 with this policy and resolves ghcr.io.
- 2026-09-08: the build scripts remove the image a tag pointed at before, so the rootless store holds one `build` and one `dev` image.
- 2026-09-08: package layering (M5). `rpm-ostree install strace` on the booted host pulls the package from the preview repo and stages a layered deployment. After a reboot `strace` works. `rpm-ostree reset` removes the layer and the host is bootc-compatible again. Logs: `out/logs/layering-attempt-*.txt`.
- 2026-09-08: `bootc upgrade` after a `bootc rollback`. The rolled-back-from image stays as `cachedUpdate`; `bootc upgrade --check` compares the registry with that cache and reports "No changes" when nothing new is to download. `bootc upgrade` then deploys the cached image, and a newer registry image is fetched as usual.
- 2026-09-12: the layer split works. `user.component` xattrs put `/usr/lib/azurelinux-bootc` (5 kB), `/etc` (4.9 MB) and the bootupd payload (2.5 MB) into their own layers; the initramfs bin is 52 MB. Measured with `make upgrade`: a version bump downloads 2 layers of 1.5 MB (was 63 MB), a config change with one new file under `/etc` downloads 3 layers of 6.7 MB. The first build after the change repacked 22 layers of 167 MB once. See `docs/decisions/0004-split-the-unpackaged-layer-with-component-xattrs.md`.
- 2026-09-12: `make vhd` writes a fixed VHD from `out/disk.raw` with `qemu-img convert -O vpc -o subformat=fixed,force_size`. The VM must be stopped first. Not tested on Azure.
- 2026-09-12: CI pushes `latest`, `v<run>` and `<YYYYMMDD>` tags, each signed. Verified on ghcr.io: `latest`, `v7`, `20260912`.
- 2026-09-12: `make switch` passes. `bootc switch --enforce-container-sigpolicy ghcr.io/jaydoubleu/azurelinux-bootc:latest` on the VM needed 5 of 65 layers (81.9 MB): the chunk step gave the CI build and the local build 60 identical layers. After the reboot the VM runs version 5 from ghcr.io, enforcing, signature checked by the policy, no failed unit, and `bootc upgrade --check` works against ghcr.io. The private package is read with a `read:packages` token in `/etc/ostree/auth.json`.
- 2026-09-08: images are signed. `make build` creates a sigstore key pair once, `make push` signs with skopeo, the image carries the public key and a policy that rejects everything except a signed `10.0.2.2:5000/azurelinux-bootc`. `make disk` installs with `--enforce-container-sigpolicy`. `make sig-test` passes: the VM refuses an unsigned image with "A signature was required, but no signature exists" and accepts the signed one. `make upgrade` passes with signed images.
- 2026-09-07: the Containerfile pins the base image by digest (tag `4.0.2026052700`). `make base-digest` compares the pin with the `4.0` tag. The build reuses the cached layers with the pin. The image records its package list in `/usr/lib/azurelinux-bootc/packages` (302 packages).

- 2026-09-12: the QEMU loop runs in CI. On the `ubuntu-24.04` runner the x86_64 job builds, chunks, signs, installs to a disk, boots under KVM, checks `bootc status`, SELinux and the version, runs the upgrade and rollback test and the signature test, and pushes to ghcr.io, in 15 minutes. The arm64 job builds under emulation in 32 minutes. Actions are pinned by commit and Dependabot bumps them.
- 2026-09-12: the repository is public. The build workflow skips changes to docs only.
- 2026-09-12: the arm64 CI job runs on the native `ubuntu-24.04-arm` runner. `bootc install to-disk` completes natively, and the disk boots under same-architecture TCG in 3 minutes 40 seconds: `aarch64`, SELinux enforcing, `bootc status` fine. The full loop runs there too: install, boot, upgrade, rollback and signature test pass in 29 minutes, and a version bump downloads 2 layers of 1.8 MB.
- 2026-09-12: the aarch64 image builds in CI under emulation in 34 minutes and is on ghcr.io as `latest-arm64`, `v<run>-arm64` and `<date>-arm64`: architecture `arm64`, 65 layers, version 13. The Containerfile picks `grub2-efi-aa64 shim-aa64` from `TARGETARCH`.
- 2026-10-23: `rpm-ostree upgrade` works. Azure Linux closed microsoft/azurelinux#18804 on 2026-10-22: the 4.0 branch pins rpm-ostree to the Fedora 43 dist-git commit `1e217ba`, which carries the backports of coreos/rpm-ostree#5569 and #5575. The preview repo ships it as `rpm-ostree-2026.1-7.azl4` since 2026-10-08, for x86_64 and aarch64. `make layering` passed locally: `rpm-ostree upgrade` staged version 3, printed "No upgrade available." with no new image, staged version 4 with `strace` layered, and `rpm-ostree reset` restored a host that `bootc upgrade --check` accepts. The same test failed on an image with `rpm-ostree-2026.1-4.azl4`: the upgrade pulled 6 layers and staged nothing. CI runs `make layering` on x86_64.
- 2026-10-23: the preview repo moved the bootc stack to bootc 1.16.13, ostree 2026.2 and bootupd 0.2.35. The Containerfile builds with them unchanged. `make upgrade` and `make sig-test` pass, SELinux is enforcing and no unit fails. The CI run on 2026-10-14 used the same packages and passed on both architectures.

## What is unverified or broken

- Lint warning `var-tmpfiles`: `/var` content has no tmpfiles.d entries. Deferred. ostree copies the image's `/var` into the machine's `/var` on the first deployment.
- The packages are not pinned. The preview repo has no snapshots. The package list in the image is the record of what each build got.
- `bootc upgrade` refuses a deployment with layered packages: "Deployment contains local rpm-ostree modifications; cannot upgrade via bootc". Such a host updates with `rpm-ostree upgrade`.
- The aarch64 disk install does not work under user-mode emulation on an x86_64 host. `bootc install to-disk` re-executes itself into the host mount namespace, and `setns` fails for an emulated process: "Re-exec in host mountns: setns: Invalid argument". The install and the boot test need a native arm64 machine, for example the `ubuntu-24.04-arm` runner in CI.
- Measured on 2026-09-12 before the layer split: an upgrade that adds `tmux` downloaded 6 layers of 83.5 MB. `EXTRA_PACKAGES=tmux make upgrade` runs that test. Not measured again after the split; expected: the new package layers plus about 1.5 MB.

## Next action

1. Watch the upstream feature request https://github.com/microsoft/azurelinux/issues/18817 for an official Azure Linux bootc base image. If the project adopts one, rebase this Containerfile on it.
2. Future work from `docs/ROADMAP.md`: desktop environment, Flatpak, aarch64, Azure VM image.

## Environment notes

- The scripts detect a Fedora toolbox with `/run/.toolboxenv` and run host tools through `flatpak-spawn --host`. `make disk` re-runs itself with `sudo` for loop devices and mounts.
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
- rpm keeps its sqlite database in WAL mode with `-shm` and `-wal` side files. Without them SQLite cannot open the database read-only, and `/usr` is read-only on the host. The Containerfile switches the database to rollback-journal mode at the end of the build.
- `rpm-ostree compose build-chunked-oci` needs the rpm database at `usr/share/rpm` and a valid OCI layout in the output directory. `scripts/15-chunk-image.sh` seeds an empty layout on the first run.
- The image policy rejects every source except the signed registry image and `containers-storage` for the install. The chunk step runs inside the image, so `scripts/15-chunk-image.sh` bind-mounts a permissive policy over `/etc/containers/policy.json` in that container.
- The signature names the image `localhost:5000/azurelinux-bootc`, the name the host pushed to. The policy maps the VM's name for the registry to it with `exactRepository`.
- Each developer has their own key pair in `out/keys/`. The public key in `config/etc/pki/containers/` is ignored by git.
- CI runs on Ubuntu 24.04. Three runner fixes: `shellcheck -x -P SCRIPTDIR` so sourced files resolve from the repository root; `kernel.apparmor_restrict_unprivileged_userns=0` so skopeo can write the rootless image store; the ghcr.io path in lowercase.
- The chunk step reads `user.component` from each file. A directory xattr alone did not carry over for `/etc`, because the commit moves `/etc` to `/usr/etc`, so the build marks every file. The image has no `setfattr`; python3 `os.setxattr` does it.
