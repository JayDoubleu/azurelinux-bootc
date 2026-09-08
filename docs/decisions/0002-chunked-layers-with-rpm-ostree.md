# 0002: Split the image into package-aligned layers with rpm-ostree

Date: 2026-09-08
Status: accepted

## Context

`podman build` puts every package into the one layer that runs `dnf install`. That layer is 1.2 GB. A config change after it costs a few kilobytes, but an update of one package changes the whole layer, and every machine downloads 1.2 GB.

Fedora and CentOS bootc images solve this with `rpm-ostree compose build-chunked-oci`. It reads the rpm database in the image, groups the files by package, and writes up to 64 layers. It keeps the layer boundaries stable between builds when it can read the previous manifest.

The command needs the rpm database at `usr/share/rpm`. Azure Linux keeps it at `usr/lib/sysimage/rpm`.

## Decision

- `scripts/10-build-image.sh` builds `azurelinux-bootc:build` with podman as before.
- `scripts/15-chunk-image.sh` runs `rpm-ostree compose build-chunked-oci --rootfs` inside the built image. The image root is mounted read-only at `/rootfs` with a podman image mount, so the copy has no container run-time files. The output goes to the OCI directory `out/chunked`, which stays between builds, and is imported as `azurelinux-bootc:dev`.
- The image carries rpm-ostree. The Containerfile moves the rpm database to `/usr/share/rpm` and leaves `/usr/lib/sysimage/rpm` as a symlink, as Fedora bootc images do.
- The Containerfile switches the rpm database from WAL to rollback-journal mode at the end of the build. SQLite cannot open a WAL database read-only without its side files, and `/usr` is read-only on the booted system.

## Consequences

- `make build` takes about one minute longer.
- The image has about 65 layers. A version bump downloads about 63 MB: the layers that hold the changed metadata and the ostree commit. A package update downloads that plus the layers of the changed packages.
- The chunked image starts from an empty image config. The chunk script copies the labels of the built image over.
- `out/chunked` grows with old blobs. `make clean` removes it, and the next build starts without a previous manifest.

## Alternatives

- `--from` instead of `--rootfs`. It reads the image from containers-storage with a podman mount, which needs root or a nested user namespace. The image mount from the host is simpler.
- Building the whole image with `rpm-ostree compose image` from a treefile. This drops the Containerfile, which is the interface we want to keep.
- More podman layers by hand, one `dnf install` per group. Fragile, and a package update still changes a whole group.
