# 0001: Use Azure Linux 4.0 preview with bootc for the first milestones

Date: 2026-09-07
Status: accepted

## Context

The goal is an Azure Linux system that updates like Fedora Silverblue, with updates delivered as OCI images. Two routes exist.

Azure Linux 3.0 is generally available. It ships rpm-ostree 2024.4 and ostree 2024.5. It does not ship bootc or composefs. rpm-ostree 2024.4 can build an OCI image from a treefile and can rebase a system from a registry. Making the first bootable disk needs manual ostree deployment and bootloader work.

Azure Linux 4.0 is in development. Its beta repo ships bootc 1.13, rpm-ostree 2026.1, ostree 2025.7 with composefs, bootupd, podman and skopeo. Its base container image is `mcr.microsoft.com/azurelinux-beta/base/core:4.0`. A dry run on 2026-09-07 resolved the whole bootc package set. This is the same stack Fedora Silverblue uses today.

## Decision

Build on Azure Linux 4.0 preview with bootc. Use `bootc install to-disk` for the first disk image and `bootc upgrade` for updates.

## Consequences

- The Containerfile follows the upstream bootc image contract. Most of the work is small distribution fixes, such as moving `vmlinuz` out of `/boot`.
- The preview repo changes without notice. Pin the base image by digest once M1 passes.
- Package layering with rpm-ostree is a later milestone, not a starting point.

## Alternatives

Azure Linux 3.0 with `rpm-ostree compose image` and `rpm-ostree rebase`. Stable base, more manual work. Kept as the fallback in `docs/ROADMAP.md`.
