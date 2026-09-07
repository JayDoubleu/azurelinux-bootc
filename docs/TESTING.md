# Testing in QEMU

The whole loop runs on the command line. No graphical console is needed.

## The loop

```
make build            # 1. podman builds the image from Containerfile
make registry         # 2. a registry container listens on 127.0.0.1:5000
make push             # 3. the image goes to localhost:5000/azurelinux-bootc:dev
make disk             # 4. as root on the host: pull from the registry, `bootc install to-disk` into out/disk.raw
make run-bg           # 5. QEMU boots out/disk.raw with OVMF; serial output goes to out/serial.log
make ssh              # 6. ssh root@localhost -p 2222 with out/ssh/id_ed25519
make upgrade          # 7. build v2, push, `bootc upgrade`, reboot, verify, `bootc rollback`, reboot, verify
make stop             # 8. stop the VM
```

Step 4 needs root on the host. The script re-runs itself with `sudo`, and from a toolbox it re-runs itself on the host through `flatpak-spawn`. Root podman has a separate image store, so the script pulls the image from the local registry instead of the user's store.

## Addresses

| From | Registry | VM ssh |
|---|---|---|
| Host | `localhost:5000` | `localhost:2222` |
| VM | `10.0.2.2:5000` | n/a |

QEMU user networking maps the host to `10.0.2.2` inside the VM. The image marks that registry as insecure in `config/etc/containers/registries.conf.d/`. `bootc install` records `10.0.2.2:5000/azurelinux-bootc:dev` as the image the VM upgrades from.

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
