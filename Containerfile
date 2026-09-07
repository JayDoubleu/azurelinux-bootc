# Azure Linux bootc image.
# Build:  make build
# Test:   see docs/TESTING.md
#
# The image starts from the Azure Linux 4.0 preview base container. It adds a kernel,
# the bootc stack, a UEFI bootloader and the services the QEMU test needs.

ARG BASE_IMAGE=mcr.microsoft.com/azurelinux-beta/base/core:4.0
FROM ${BASE_IMAGE}

# 1. Packages.
#    kernel + dracut:        boot
#    bootc ostree bootupd:   image-based updates and bootloader updates
#    bubblewrap:             bootc runs bootupctl inside a bwrap sandbox during install
#    grub2-efi-x64 shim-x64: UEFI boot
#    grub2-pc-modules:       BIOS boot; a generic install writes both loaders
#    systemd-networkd:       DHCP inside QEMU
#    openssh-server:         test access
#    selinux-policy-targeted: bootc labels the installed files with this policy
#    The preview repo is added because the beta repo lacks bubblewrap.
COPY repos/azurelinux-preview.repo /etc/yum.repos.d/
RUN dnf -y install \
      kernel \
      bootc ostree bootupd composefs bubblewrap \
      dracut dracut-config-generic \
      systemd systemd-udev systemd-networkd systemd-resolved \
      grub2-efi-x64 grub2-tools grub2-pc-modules shim-x64 efibootmgr \
      selinux-policy-targeted policycoreutils \
      openssh-server sudo passwd shadow-utils \
      xfsprogs e2fsprogs dosfstools \
      iproute iputils less vim-minimal \
    && dnf clean all

# 2. Reference bootc layout shipped with the bootc package:
#    /sysroot, /ostree -> sysroot/ostree, composefs enabled in prepare-root.conf,
#    dracut defaults, and a kernel-install config that keeps /boot empty.
RUN cp -a /usr/share/doc/bootc/baseimage/base/. / \
    && cp -a /usr/share/doc/bootc/baseimage/dracut/. / \
    && cp -a /usr/share/doc/bootc/baseimage/systemd/. /

# 3. Machine-local directories live under /var. The image holds symlinks to them.
RUN set -eux; \
    for d in home opt srv mnt; do rm -rf "/$d"; ln -s "var/$d" "/$d"; done; \
    rm -rf /root; ln -s var/roothome /root; \
    rm -rf /usr/local; ln -s ../var/usrlocal /usr/local; \
    mkdir -p /var/home /var/opt /var/srv /var/mnt /var/roothome /var/usrlocal; \
    chmod 0700 /var/roothome

# 4. Kernel. bootc expects /usr/lib/modules/<kver>/vmlinuz and an initramfs next to it.
#    Azure Linux puts vmlinuz in /boot, so move it. Then build a generic initramfs
#    with the ostree module and empty /boot.
RUN set -eux; \
    kver="$(ls /usr/lib/modules | head -n 1)"; \
    test -n "$kver"; \
    mv "/boot/vmlinuz-${kver}" "/usr/lib/modules/${kver}/vmlinuz"; \
    for f in config System.map; do \
      if [ -e "/boot/${f}-${kver}" ]; then mv "/boot/${f}-${kver}" "/usr/lib/modules/${kver}/${f}"; fi; \
    done; \
    dracut --no-hostonly --kver "$kver" --reproducible --zstd --add ostree \
      -f "/usr/lib/modules/${kver}/initramfs.img"

# 5. Bootloader files for `bootc install`. bootupd 0.2.32 reads them from
#    /usr/lib/ostree-boot/efi/EFI, maps each file to its package with `rpm -qf` on the
#    /boot/efi path, and writes /usr/lib/efi/<component>/<version>/EFI. Keep /boot/efi in
#    place for the rpm query, then empty /boot: bootc manages /boot on the installed system.
RUN set -eux; \
    mkdir -p /usr/lib/ostree-boot; \
    cp -a /boot/efi /usr/lib/ostree-boot/efi; \
    bootupctl backend generate-update-metadata; \
    rm -rf /usr/lib/ostree-boot /boot/*; \
    ls -R /usr/lib/efi | head -n 40

# 6. Local configuration: SELinux enforcing, serial console kernel args, DHCP on wired interfaces,
#    resolv.conf symlink via tmpfiles, root login by ssh key only, and the insecure
#    test registry on the QEMU host. The systemd first-boot wizard is masked: it
#    prompts on the console and blocks the boot until a key is pressed.
#    The base image locks root with "!unprovisioned" in /etc/shadow. sshd refuses a
#    locked account even for key login, so the field becomes "*": no password, not locked.
#    The build args sit here, after the package layers, so a new VERSION reuses the cache.
# VERSION is a build number. The upgrade test reads it from the running VM.
ARG VERSION=1
# ROOT_PASSWORD, if set, unlocks root on the serial console. Leave empty for key-only access.
ARG ROOT_PASSWORD=""
COPY config/ /
RUN set -eux; \
    systemctl enable systemd-networkd systemd-resolved sshd; \
    systemctl mask systemd-firstboot.service; \
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config; \
    if [ -n "${ROOT_PASSWORD}" ]; then echo "root:${ROOT_PASSWORD}" | chpasswd; else usermod -p '*' root; fi; \
    rm -f /etc/machine-id; \
    mkdir -p /usr/lib/azurelinux-bootc; \
    echo "${VERSION}" > /usr/lib/azurelinux-bootc/version

# 7. Drop build leftovers, then lint. `ostree container commit` is not used: it needs an
#    ostree repo marker that only rpm-ostree-composed images carry. ostree copies the
#    image's /var into the machine's /var on the first deployment.
RUN set -eux; \
    rm -rf /var/cache/* /var/log/* /var/tmp/* /var/lib/dnf/* /tmp/*; \
    find /boot -mindepth 1 -delete; \
    find /run -mindepth 1 -maxdepth 1 ! -name .containerenv ! -name secrets -exec rm -rf {} +
RUN bootc container lint

LABEL containers.bootc=1
LABEL org.opencontainers.image.title="Azure Linux bootc"
LABEL org.opencontainers.image.description="Azure Linux 4.0 preview as a bootable container image"
LABEL org.opencontainers.image.licenses="MIT"
