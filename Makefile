SHELL := /bin/bash
VERSION ?= 1

.PHONY: help check base-digest lint build chunk registry registry-down push disk run run-bg wait stop ssh upgrade clean

help:
	@echo "Targets, in the order you run them:"
	@echo "  check          verify host tools"
	@echo "  base-digest    compare the pinned base image digest with the registry tag"
	@echo "  build          build the bootc image and chunk it (VERSION=$(VERSION))"
	@echo "  chunk          split the built image into package-aligned layers"
	@echo "  registry       start the local OCI registry on 127.0.0.1:5000"
	@echo "  push           push the image to the local registry"
	@echo "  disk           write the image to out/disk.raw (run on the host with sudo)"
	@echo "  run            boot out/disk.raw in QEMU on this terminal"
	@echo "  run-bg         boot out/disk.raw in QEMU in the background"
	@echo "  wait           wait until the VM answers over ssh"
	@echo "  ssh            open a root shell in the VM"
	@echo "  upgrade        build the next version, upgrade the VM, verify, roll back"
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
	  shellcheck scripts/*.sh; \
	else \
	  scripts/lint-in-container.sh; \
	fi

build:
	scripts/10-build-image.sh $(VERSION)
	scripts/15-chunk-image.sh

chunk:
	scripts/15-chunk-image.sh

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

clean:
	rm -rf out
