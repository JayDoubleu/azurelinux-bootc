# CLAUDE.md

Project: Azure Linux bootc. A bootable Azure Linux image with atomic updates delivered from an OCI registry.

## Start of every run

1. Read `docs/STATUS.md`. It holds the current state and the next action.
2. Read the last entry in `docs/WORKLOG.md`.
3. Read `docs/decisions/` before you change the approach.

## End of every run

1. Update `docs/STATUS.md`: what works, what is broken, the next action, the date.
2. Append an entry to `docs/WORKLOG.md`.
3. If you changed the approach, add a record in `docs/decisions/`.

## Writing style

These rules apply to all text: replies, docs, code comments, commit messages.

- Remove all mannered prose. No filler, no praise, no hedging, no AI slop.
- Write plain English in the spirit of ASD-STE100 Simplified Technical English.
- Use short sentences, the active voice, and simple tenses.
- One word, one meaning. Use the same term for the same thing every time.
- Put the condition before the instruction.
- Define each technical term at first use.
- Never use em-dashes (U+2014). Do not use `--` as a substitute. Rephrase the sentence.
- Use British spelling in prose. Keep code identifiers, package names and quoted output as they are.

## Environment

- Claude Code runs in a Fedora toolbox. `podman`, `qemu` and OVMF live on the host.
- Run host commands with `flatpak-spawn --host <command>`. The scripts in `scripts/` do this for you.
- The user has given explicit permission to run `sudo` on the host to complete the objectives in this repository. Use it for `sudo make disk` and for loop device, mount and QEMU work. Do not use it for anything outside this repository's build and test loop.
- If `sudo` needs a password and no terminal is available, ask the user to run the command with the `!` prefix, for example `! flatpak-spawn --host sudo make disk`.
- Build output goes in `out/`. It is ignored by git.
