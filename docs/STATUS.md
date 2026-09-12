# Status

Read this first. Update it at the end of every session.

Last updated: 2026-09-12, session 3

## Current milestone

M1 to M5 are done. The VM boots the signed CI image from ghcr.io. What is left is in the open issues and in the Future section of `docs/ROADMAP.md`.

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
- 2026-09-08: the repository is `github.com/JayDoubleu/azurelinux-bootc` (private). Both workflows pass on `main`: `lint` in 16 s, `build` in about 4.5 min. The build pushes `ghcr.io/jaydoubleu/azurelinux-bootc:latest`, signed with the key from the repository secrets, which is the same key as `out/keys/` on this machine. The package is private, like the repository.
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

## What is unverified or broken

- Lint warning `var-tmpfiles`: `/var` content has no tmpfiles.d entries. Deferred. ostree copies the image's `/var` into the machine's `/var` on the first deployment.
- The packages are not pinned. The preview repo has no snapshots. The package list in the image is the record of what each build got.
- `bootc upgrade` refuses a deployment with layered packages: "Deployment contains local rpm-ostree modifications; cannot upgrade via bootc".
- `rpm-ostree upgrade` pulls the new image and exits 0 without a deployment. Fix submitted: https://github.com/microsoft/azurelinux/pull/18804 (microsoft/azurelinux, from the fork `JayDoubleu/azurelinux-1`). A local rebuild with the fix passed the VM test on 2026-09-12: `rpm-ostree upgrade` stages a newer image, also with `strace` layered, and prints "No upgrade available." when there is none. Cause: rpm-ostree issue #5567, an early return in `deploy_transaction_execute` that ignores the changed base image for container origins. Fixed upstream in 2026.2 (PR #5569). Azure Linux 4.0 ships 2026.1 in the preview repo and on the `4.0` spec branch (checked 2026-09-12). Workarounds verified on 2026-09-12: `rpm-ostree deploy sha256:<digest>` stages the new image; with a layered package, `rpm-ostree rebase ostree-image-signed:docker://10.0.2.2:5000/azurelinux-bootc@sha256:<digest>` stages the new image plus the layer, and a second `rpm-ostree rebase` to the tag reference moves the origin back to the tag. `rpm-ostree rebase` to the unchanged tag reference fails with "Old and new refs are equal".
- Measured on 2026-09-12 before the layer split: an upgrade that adds `tmux` downloaded 6 layers of 83.5 MB. `EXTRA_PACKAGES=tmux make upgrade` runs that test. Not measured again after the split; expected: the new package layers plus about 1.5 MB.

- 2026-09-12: aarch64 support is written, not verified. The 4.0 preview repo has all needed aarch64 packages. The Containerfile picks `grub2-efi-aa64 shim-aa64` from `TARGETARCH`. CI builds an arm64 job under emulation. A local build and boot need `qemu-user-static-aarch64`, `qemu-system-aarch64-core` and `edk2-aarch64` on the host.

## Next action

1. Watch the Azure Linux PR https://github.com/microsoft/azurelinux/pull/18804. It pins rpm-ostree to the Fedora 43 head with the fix. When it merges and the preview repo ships the new build, rebuild the image and drop the digest rebase note.
2. Future work from `docs/ROADMAP.md`: desktop environment, Flatpak, aarch64, Azure VM image.

## TODO for the user

- Install `qemu-user-static-aarch64 qemu-system-aarch64-core edk2-aarch64` on the host for local aarch64 builds and boots.
- Delete the empty repository `an unused repository`, or keep it.
- Test the VHD from `make vhd` on Azure. Needs a subscription.
- Decide whether the desktop environment and Flatpak go on the roadmap. Both need packaging work in Azure Linux 4.0 first.
- The ghcr.io package stays private for now (decided 2026-09-12). The VM keeps the token in `/etc/ostree/auth.json`.

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
- The host root filesystem is nearly full. `scripts/30-install-disk.sh` removes the pulled image from the root podman store after each install. Superseded build images in the rootless store were removed by hand on 2026-09-08.
- rpm keeps its sqlite database in WAL mode with `-shm` and `-wal` side files. Without them SQLite cannot open the database read-only, and `/usr` is read-only on the host. The Containerfile switches the database to rollback-journal mode at the end of the build.
- `rpm-ostree compose build-chunked-oci` needs the rpm database at `usr/share/rpm` and a valid OCI layout in the output directory. `scripts/15-chunk-image.sh` seeds an empty layout on the first run.
- The image policy rejects every source except the signed registry image and `containers-storage` for the install. The chunk step runs inside the image, so `scripts/15-chunk-image.sh` bind-mounts a permissive policy over `/etc/containers/policy.json` in that container.
- The signature names the image `localhost:5000/azurelinux-bootc`, the name the host pushed to. The policy maps the VM's name for the registry to it with `exactRepository`.
- Each developer has their own key pair in `out/keys/`. The public key in `config/etc/pki/containers/` is ignored by git.
- The VM is a throwaway. At the end of session 3 it runs version 8 from the local registry, no layered packages. `make stop` stops it. A host reboot stops it too; `make run-bg` starts it again from `out/disk.raw`.
- CI runs on Ubuntu 24.04. Three runner fixes: `shellcheck -x -P SCRIPTDIR` so sourced files resolve from the repository root; `kernel.apparmor_restrict_unprivileged_userns=0` so skopeo can write the rootless image store; the ghcr.io path in lowercase.
- The chunk step reads `user.component` from each file. A directory xattr alone did not carry over for `/etc`, because the commit moves `/etc` to `/usr/etc`, so the build marks every file. The image has no `setfattr`; python3 `os.setxattr` does it.
- `grep --exclude-dir` matches directory names, not paths. The local `grep` is an alias for `ugrep`, which behaves differently, so test grep flags in CI, not locally.
- An empty private repository `an unused repository` from 2026-09-07 is unused.
- Azure Linux 4.0 packaging work uses the clone at `a local clone` (branch `4.0`, remote `fork` = `JayDoubleu/azurelinux-1`) with `azldev` (Go, pinned by `.azldev-version`) and `mock` in the toolbox. `azldev comp render` and `build` both need mock. A sparse or blobless clone breaks `render`; use a full clone.
- The toolbox shares the host process table. A `pgrep -f` on the host matches the toolbox shell that runs it.
