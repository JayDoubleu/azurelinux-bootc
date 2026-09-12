# Testing in QEMU

The whole loop runs on the command line. No graphical console is needed.

## The loop

```
make build            # 1. podman builds the image from Containerfile, then rpm-ostree splits it into package-aligned layers
make registry         # 2. a registry container listens on 127.0.0.1:5000
make push             # 3. skopeo signs the image and pushes it to localhost:5000/azurelinux-bootc:dev
make disk             # 4. as root on the host: pull from the registry, `bootc install to-disk` into out/disk.raw
make run-bg           # 5. QEMU boots out/disk.raw with OVMF; serial output goes to out/serial.log
make ssh              # 6. ssh root@localhost -p 2222 with out/ssh/id_ed25519
make upgrade          # 7. build v2, push, `bootc upgrade`, reboot, verify, `bootc rollback`, reboot, verify
make sig-test         # 7b. push an unsigned image, expect `bootc upgrade --check` to fail, push signed, expect pass
make switch           # 7c. move the VM to the signed image on ghcr.io, reboot, verify
make stop             # 8. stop the VM
```

Step 4 needs root on the host. The script re-runs itself with `sudo`, and from a toolbox it re-runs itself on the host through `flatpak-spawn`. Root podman has a separate image store, so the script pulls the image from the local registry instead of the user's store.

## Addresses

| From | Registry | VM ssh |
|---|---|---|
| Host | `localhost:5000` | `localhost:2222` |
| VM | `10.0.2.2:5000` | n/a |

QEMU user networking maps the host to `10.0.2.2` inside the VM. The image marks that registry as insecure in `config/etc/containers/registries.conf.d/`. `bootc install` records `10.0.2.2:5000/azurelinux-bootc:dev` as the image the VM upgrades from.

## aarch64

`ARCH=aarch64` in front of any `make` target builds and tests the arm64 image. The tag, the disk image and the chunk directory get the suffix `-arm64`. On an x86_64 host the build and the chunk step run under user-mode emulation, and the VM runs under TCG, which is slow. The host needs three extra packages: `qemu-user-static-aarch64` for the build, `qemu-system-aarch64-core` and `edk2-aarch64` for the VM. The kernel arguments in `config/usr/lib/bootc/kargs.d/` select the console per architecture. CI builds both architectures on every push.

## The same loop in CI

`.github/workflows/build.yml` runs the loop on a GitHub-hosted `ubuntu-24.04` runner for x86_64: build, local registry, signed push, `make disk`, boot under KVM, `bootc status`, `make upgrade`, `make sig-test`, then the signed push to ghcr.io. The runner needs a udev rule for `/dev/kvm`, the `ovmf` package, and `kernel.apparmor_restrict_unprivileged_userns=0` for skopeo. The `OVMF_CODE` and `OVMF_VARS_SRC` variables point at the Ubuntu firmware paths. The arm64 job only builds and pushes: the arm64 runners have no KVM, and `bootc install` cannot run under user-mode emulation. The logs land in the `qemu-logs-x86_64` artifact.

## Layers

`podman build` puts every package into one layer. `scripts/15-chunk-image.sh` runs `rpm-ostree compose build-chunked-oci` on the built image and regroups the files by package into up to 64 layers. The OCI directory `out/chunked` stays between builds so the layer boundaries stay stable. `bootc upgrade` then downloads only the layers whose packages changed.

## Signatures

The first `make build` runs `scripts/22-keys.sh`. It creates a sigstore key pair: the private key and its passphrase go to `out/keys/`, the public key to `config/etc/pki/containers/azurelinux-bootc.pub`. Both stay out of git. The build copies the public key into the image.

`make push` signs the image with the private key. The signature is stored in the registry next to the image. `config/etc/containers/policy.json` in the image rejects every image by default and accepts `10.0.2.2:5000/azurelinux-bootc` only with a valid signature from that key. The signature names the image `localhost:5000/azurelinux-bootc`, the name the host pushed to, so the policy maps the VM's name for the registry to it with `exactRepository`.

`make disk` installs with `--enforce-container-sigpolicy`. `make sig-test` checks both directions: an unsigned image is refused, the signed image is accepted.

## Switching to ghcr.io

CI pushes `ghcr.io/jaydoubleu/azurelinux-bootc:latest`, signed with the key from the repository secrets. The image policy trusts that name with the same key. `make switch` runs `bootc switch --enforce-container-sigpolicy` on the VM, reboots it, and checks the booted image, the version and the SELinux mode.

The package is private at the moment. A private package needs a token with the `read:packages` scope. The script takes the token from `gh auth token`, and writes it to `/etc/ostree/auth.json` in the VM with mode 600. The token is machine-local state under `/etc`; it is not in the image and not in the logs. To add the scope: `gh auth refresh -h github.com -s read:packages`.

## Versions

Each build takes a `VERSION` build number. The image writes it to `/usr/lib/azurelinux-bootc/version`. The upgrade test reads the booted number, builds the next one under the same tag, and checks the number after each reboot.

## Console access

- `make run` (foreground) shows the serial console on your terminal. Exit QEMU with `Ctrl-a x`.
- `make run-bg` writes the serial console to `out/serial.log`.
- Root has no password. Log in over ssh with the generated key. To unlock root on the serial console for debugging, build with `podman build --build-arg ROOT_PASSWORD=...`.

## When something fails

1. Read `out/serial.log`. It shows the firmware, the bootloader, and the kernel.
2. Read `out/logs/`. Each script writes its own log there.
3. In the VM, run `bootc status` and `journalctl -b`.
4. To start over, run `make stop`, delete `out/disk.raw`, and run `sudo make disk` again.
