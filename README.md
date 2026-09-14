# Azure Linux bootc

An experiment: build a bootable [Azure Linux](https://github.com/microsoft/azurelinux) image that works like Fedora Silverblue. The operating system is a container image. Updates come from an OCI registry. Each update is atomic and can be rolled back.

Status: experimental. Nothing here is supported by Microsoft. An official bootc base image is requested upstream in [microsoft/azurelinux#18817](https://github.com/microsoft/azurelinux/issues/18817).

## How it works

- [bootc](https://bootc.dev) boots and updates a system from an OCI container image.
- The image starts from the Azure Linux 4.0 preview base container and adds a kernel, bootc, ostree and a bootloader.
- The base image is pinned by digest. `make base-digest` reports when the `4.0` tag moves. The packages come from the unpinned preview repo; the image records the installed versions in `/usr/lib/azurelinux-bootc/packages`.
- `rpm-ostree compose build-chunked-oci` regroups the image into package-aligned layers, so an update downloads only the changed packages.
- `bootc install to-disk` writes the image to a disk file.
- QEMU boots the disk file with UEFI firmware.
- A local registry serves a second image version. The VM runs `bootc upgrade`, reboots, then `bootc rollback`.
- The image is signed with a sigstore key. A policy in the image makes `bootc upgrade` refuse unsigned images.

See `docs/ROADMAP.md` for milestones and `docs/decisions/` for why we chose this path.

## CI

`.github/workflows/build.yml` builds, chunks, signs and pushes the image on each push to `main`. It derives the registry path from the repository owner, so a fork pushes to its own `ghcr.io/<owner>/azurelinux-bootc`. Set the three secrets `SIGSTORE_PRIVATE_KEY`, `SIGSTORE_PASSPHRASE` and `SIGSTORE_PUBLIC_KEY` from `out/keys/` and `config/etc/pki/containers/`, so every run signs with the same key. Without them each run signs with a throwaway key that no machine can verify.

A fork must also change two values before `make switch` works: `GHCR_IMAGE_REF` in `scripts/lib.sh` and the trust scope in `config/etc/containers/policy.json`. The policy in the image trusts only the key that built the image.

The package `ghcr.io/jaydoubleu/azurelinux-bootc` is private. `make switch` reads it with a token that has the `read:packages` scope, taken from `gh auth token`.

## Requirements

Host tools:

- podman 5 or later
- skopeo
- qemu-system-x86_64 with KVM, and qemu-img
- OVMF firmware (`edk2-ovmf` on Fedora, `ovmf` on Ubuntu)
- ssh-keygen
- python3, for the serial console and monitor helpers
- `gh`, only for `make switch` while the image package is private

Run `make check` to verify. On Ubuntu, set the firmware paths once: `export OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd OVMF_VARS_SRC=/usr/share/OVMF/OVMF_VARS_4M.fd`. Ubuntu 24.04 also needs `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0` for skopeo.

## Quick start

```
make check       # verify host tools
make build       # build the bootc container image (creates the signing key on the first run)
make registry    # start a local OCI registry on port 5000
make push        # sign the image and push it to the local registry
make disk        # write the image to out/disk.raw (re-runs itself with sudo on the host)
make run-bg      # boot out/disk.raw in QEMU in the background; make ssh opens a root shell
make upgrade     # build v2, push it, upgrade the VM, verify, roll back
make sig-test    # check that the VM refuses an unsigned image
make stop        # stop the VM
```

Each target is a script in `scripts/`. Read the script before you run it.

`make switch` moves the VM to the signed image on ghcr.io. The policy in the image trusts only the key that built it, so this step works only with your own fork, CI and secrets. See `docs/TESTING.md`.

`ARCH=aarch64 make build` builds the arm64 image. See `docs/TESTING.md`.

## Repository layout

| Path | Purpose |
|---|---|
| `Containerfile` | The bootc image definition |
| `config/` | Files copied into the image |
| `scripts/` | Build and test steps, numbered in run order |
| `docs/STATUS.md` | Current state and next action. Read this first |
| `docs/ROADMAP.md` | Milestones |
| `docs/WORKLOG.md` | Append-only log of each work session |
| `docs/decisions/` | Architecture decision records |
| `docs/research/` | Feasibility notes |
| `out/` | Build output, ignored by git |

## Licence

MIT. See `LICENSE`.
