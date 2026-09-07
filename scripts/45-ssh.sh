#!/usr/bin/env bash
# Open a shell in the VM, or run a command there.
# Usage: 45-ssh.sh [COMMAND...]
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ssh_vm "$@"
