# 0004: Split the unpackaged layer with user.component xattrs

Date: 2026-09-12
Status: accepted

## Context

Decision 0002 chunks the image by package. Files that no package owns land in one layer. rpm-ostree marks that bucket and the initramfs with the highest change frequency, and ostree-ext puts every such component into one bin (`chunking.rs`, `basic_packing`). In this image that bin held the 53 MB initramfs, all of `/etc` (22 MB, because the commit moves `/etc` to `/usr/etc` and the package lookup then misses it), the bootupd payload (6 MB) and the version file. One tar stream holds the bin, so a change to the version file changed the layer digest and every version bump downloaded 61 MB.

rpm-ostree reads the `user.component` xattr on a directory and gives every path below it its own exclusive layer (`container.rs`, `create_meta`; documented in `docs/build-chunked-oci.md`). The initramfs cannot be marked: the walk skips it.

## Decision

The last build step sets `user.component` on four directories and every file below them with `os.setxattr` from python3, because the image has no `setfattr`. A directory xattr alone did not carry over for `/etc`; the commit moves it to `/usr/etc`. The four are:

- `/usr/lib/azurelinux-bootc` as `azurelinux-bootc`: the version and package files.
- `/etc` as `etc`: configuration, including package-owned files such as `hwdb.bin`.
- `/usr/lib/efi` and `/usr/lib/bootupd` as `bootupd`: the bootloader payload.

The initramfs stays in the high-frequency bin with the small remainder of `/var`.

## Consequences

- Measured on 2026-09-12: a version bump downloads 2 layers of 1.5 MB, a config change with one new file under `/etc` downloads 3 layers of 6.7 MB. Before the split both cost 63 MB.
- The first build after the change repacks the image once: 22 layers, 167 MB.
- The initramfs layer changes only when the initramfs changes. dracut runs with `--reproducible`, and a rebuild of the same inputs gave the same layer digest.
- Three exclusive layers count against the 64-layer limit.
- rpm-ostree 2026.1 cannot reuse the previous packing when exclusive components exist (fixed in bootc `c29c97e62`, in rpm-ostree 2026.3). Packing is deterministic for an unchanged package set, so a version bump still reuses the package layers. A package update may move packages between bins until Azure Linux ships rpm-ostree 2026.3.
- The xattrs reach the deployed host as PAX headers. They have no effect there.

## Alternatives

- Read the version from the image label and drop the version file. A pure bump would then download nothing, but a config or bootupd change would still cost the whole bin. Not needed with the split.
- `--max-layers` above the component count gives every component a layer. 310 layers break `podman run` on the image.
- A synthetic RPM that owns the initramfs. Depends on NEVRA sort order against the initramfs component name. Fragile.
