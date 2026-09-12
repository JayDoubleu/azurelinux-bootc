# Azure Linux bootc

An experiment: build a bootable [Azure Linux](https://github.com/microsoft/azurelinux) image that works like Fedora Silverblue. The operating system is a container image. Updates come from an OCI registry. Each update is atomic and can be rolled back.

Status: experimental. Nothing here is supported by Microsoft.

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

`.github/workflows/build.yml` builds, chunks, signs and pushes the image to `ghcr.io/jaydoubleu/azurelinux-bootc:latest` on each push to `main`. The image policy trusts that name with the same key. The package is private at the moment; `make switch` takes a token with the `read:packages` scope from `gh auth token`. A fork must change the image name in `scripts/lib.sh` (`GHCR_IMAGE_REF`) and the trust scope in `config/etc/containers/policy.json`. Set the secrets `SIGSTORE_PRIVATE_KEY`, `SIGSTORE_PASSPHRASE` and `SIGSTORE_PUBLIC_KEY` from `out/keys/` and `config/etc/pki/containers/` to sign with a fixed key. Without them each run signs with a throwaway key.

## Requirements

Host tools:

- podman 5 or later
- qemu-system-x86_64 with KVM
- OVMF firmware (`edk2-ovmf` on Fedora)
- ssh-keygen

Run `scripts/00-check-tools.sh` to verify.

## Quick start

```
make check       # verify host tools
make build       # build the bootc container image
make registry    # start a local OCI registry on port 5000
make push        # push the image to the local registry
make disk        # write the image to out/disk.raw (re-runs itself with sudo on the host)
make run         # boot out/disk.raw in QEMU on the command line
make upgrade     # build v2, push it, upgrade the VM, verify, roll back
make sig-test    # check that the VM refuses an unsigned image
make switch      # move the VM to the signed image on ghcr.io
```

Each target is a script in `scripts/`. Read the script before you run it.

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
