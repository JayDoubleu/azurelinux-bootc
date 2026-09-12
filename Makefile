SHELL := /bin/bash
VERSION ?= 1

.PHONY: help check base-digest lint build chunk keys registry registry-down push disk run run-bg wait stop ssh upgrade sig-test switch vhd clean

help:
	@echo "Targets, in the order you run them:"
	@echo "  check          verify host tools"
	@echo "  base-digest    compare the pinned base image digest with the registry tag"
	@echo "  build          build the bootc image and chunk it (VERSION=$(VERSION))"
	@echo "  chunk          split the built image into package-aligned layers"
	@echo "  keys           create the sigstore signing key pair (build does this once)"
	@echo "  registry       start the local OCI registry on 127.0.0.1:5000"
	@echo "  push           sign the image and push it to the local registry"
	@echo "  disk           write the image to out/disk.raw (run on the host with sudo)"
	@echo "  run            boot out/disk.raw in QEMU on this terminal"
	@echo "  run-bg         boot out/disk.raw in QEMU in the background"
	@echo "  wait           wait until the VM answers over ssh"
	@echo "  ssh            open a root shell in the VM"
	@echo "  upgrade        build the next version, upgrade the VM, verify, roll back"
	@echo "  sig-test       check that the VM rejects an unsigned image and accepts the signed one"
	@echo "  switch         move the VM to the signed image on ghcr.io and verify the boot"
	@echo "  vhd            convert out/disk.raw to a fixed VHD for Azure"
	@echo "  stop           stop the background VM"
	@echo "  registry-down  remove the local registry"
	@echo "  lint           run shellcheck on scripts/"
	@echo "  clean          delete out/"

check:
	scripts/00-check-tools.sh

base-digest:
	scripts/05-base-digest.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -x -P SCRIPTDIR scripts/*.sh; \
	else \
	  scripts/lint-in-container.sh; \
	fi
	@if grep -rIl $$'\xe2\x80\x94' --exclude-dir=.git --exclude-dir=research --exclude-dir=out .; then \
	  echo "em-dash found"; exit 1; \
	fi

build:
	scripts/10-build-image.sh $(VERSION)
	scripts/15-chunk-image.sh

chunk:
	scripts/15-chunk-image.sh

keys:
	scripts/22-keys.sh

registry:
	scripts/20-registry.sh up

registry-down:
	scripts/20-registry.sh down

push:
	scripts/25-push.sh

disk:
	scripts/30-install-disk.sh

run:
	scripts/40-run-qemu.sh

run-bg:
	scripts/40-run-qemu.sh --background

wait:
	scripts/46-wait-ssh.sh

stop:
	scripts/41-stop-qemu.sh

ssh:
	scripts/45-ssh.sh

upgrade:
	scripts/50-upgrade-test.sh

sig-test:
	scripts/55-signature-test.sh

switch:
	scripts/60-switch-test.sh

vhd:
	scripts/70-vhd.sh

clean:
	rm -rf out
