# Azure Linux as a Silverblue-style rpm-ostree distribution

Date: 2026-09-07

## Answer

Yes, it is possible. Azure Linux already packages the full stack that
Fedora Silverblue uses, and OCI transport is built in. There are two
routes.

## Route A: Azure Linux 4.0 preview with bootc (recommended)

Azure Linux 4.0 is derived from Fedora spec files. The preview repo
ships the bootc stack today.

| Package                  | Version in 4.0 preview          |
|--------------------------|----------------------------------|
| bootc                    | 1.13.0                           |
| rpm-ostree               | 2026.1                           |
| ostree                   | 2025.7, built with composefs     |
| bootupd                  | 0.2.32                           |
| podman / skopeo / buildah| 5.8.0 / 1.22.0 / 1.43.0          |
| kernel                   | 6.18.x                           |
| systemd / systemd-ukify  | 258.4                            |
| grub2-efi-x64 / shim-x64 | present                          |

Base container image:

```
mcr.microsoft.com/azurelinux-beta/base/core:4.0
```

Package repo:

```
https://packages.microsoft.com/azurelinux/4/preview/base/x86_64
```

The workflow is the same as Fedora bootc:

1. Write a Containerfile that starts from the base image. Install
   kernel, bootc, ostree, bootupd, dracut, systemd, selinux-policy and
   your package set. Set `LABEL containers.bootc=1`.
2. Build with podman and push to any OCI registry.
3. Create the first disk image with `bootc install to-disk` or
   bootc-image-builder.
4. Ship updates by pushing a new image tag. Clients run
   `bootc upgrade`. Package layering with `rpm-ostree install` still
   works on top.

Caveat: 4.0 is in development. The README states "Azure Linux 4 is
still in development". There is no GA date. The preview repo already
shows several kernel rebuilds in flight. Expect breakage.

## Route B: Azure Linux 3.0 GA with rpm-ostree native containers

Azure Linux 3.0 is supported. It ships rpm-ostree 2024.4 and ostree
2024.5. It does not ship bootc or composefs. rpm-ostree 2024.4 includes
the ostree-ext container code, so the OCI transport works without
bootc.

Build an OCI image from a treefile:

```
rpm-ostree compose image --format=oci <treefile.yaml> <output>
```

Client update:

```
rpm-ostree rebase ostree-unverified-registry:<registry>/<image>:<tag>
```

Use the `ostree-image-signed:` prefix with a signing policy for
verified images.

This is how Silverblue worked between Fedora 37 and 40. The base is
stable. You must produce the initial bootable disk image yourself with
`ostree admin deploy` and grub2. That is more manual work than Route A.

## Constraints that apply to both routes

- Azure Linux ships no desktop environment. Neither 3.0 nor 4.0
  packages GNOME, KDE or Sway. Only mesa and Xwayland are present.
  "Like Silverblue" can mean the update model only, or you must
  package a desktop yourself.
- Azure Linux 4.0 has a bootc spec but no bootc-image-builder spec.
  Use the upstream bootc-image-builder container, or run
  `bootc install to-disk` inside a privileged podman container, to
  create disk images.

## Verified facts

- Azure Linux 3.0 SPECS contain `ostree` 2024.5 and `rpm-ostree`
  2024.4. The ostree spec carries Photon-derived patches that rename
  the osname to azurelinux and add grub2 integration.
- Azure Linux 4.0 uses a new `specs/<letter>/<name>` layout and
  contains `bootc`, `rpm-ostree`, `ostree`, `composefs`, `bootupd`,
  `podman`, `skopeo`, `buildah`, `osbuild` and `image-builder`.
- The 4.0 preview repo at packages.microsoft.com is live and holds
  15203 packages, including all of the above.
- The `azurelinux-beta/base/core` image on MCR has 4.0 tags dated
  May 2026.
- The 4.0 `azurelinux-repos` package points the production repo at
  `https://packages.microsoft.com/azurelinux/4/prod/base/$basearch`.
  That path returned HTTP 404 on 2026-09-07. Only the preview path is
  published.

## Sources

- Azure Linux 4.0 README:
  https://github.com/microsoft/azurelinux/tree/4.0
- Fedora OstreeNativeContainerStable change:
  https://fedoraproject.org/wiki/Changes/OstreeNativeContainerStable
- rpm-ostree ostree native containers:
  https://coreos.github.io/rpm-ostree/container/
- bootc image requirements:
  https://bootc.dev/bootc/bootc-images.html
- RHEL 10 Image Mode on Azure quick start:
  https://techcommunity.microsoft.com/blog/linuxandopensourceblog/red-hat-enterprise-linux-10-image-mode-on-azure-quick-start-guide/4414257
