# Comparison of the two feasibility answers

Date: 2026-09-07. Compares `2026-09-07-claude-feasibility.md` and `2026-09-07-codex-feasibility.md`. The codex file is kept as written.

## Where they agree

- Both say the goal is feasible.
- Both identify ostree native containers in rpm-ostree as the OCI transport, and bootc as the upstream direction.
- Both say the main work is making a base image that boots: kernel, initramfs, bootloader, ostree layout, and a first disk image.
- Both propose the same first milestone: a minimal VM boots version A, upgrades to version B from a registry, and rolls back.
- Both put a desktop environment in later work.

## Where they differ

| Topic | Claude | Codex |
|---|---|---|
| Starting point | Azure Linux 4.0 preview with bootc | rpm-ostree with OCI transport; evaluate bootc if layering is not needed |
| Evidence | Checked which Azure Linux release ships which package | Did not check Azure Linux versions |
| 4.0 status | Flags 4.0 as in development | Not mentioned |
| 3.0 limits | Notes 3.0 has no bootc or composefs | Not mentioned |
| Layering | Deferred to a later milestone | Notes bootc refuses to upgrade after rpm-ostree layering |

## Resolution

Decision record 0001 picks the 4.0 bootc route because 4.0 already ships the full stack. The codex point about layering is valid and becomes milestone M5. The codex compose and rebase commands apply to the 3.0 fallback route.
