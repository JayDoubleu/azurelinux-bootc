# AGENTS.md

Instructions for coding agents that work in this repository. `CLAUDE.md` imports this file.

Project: Azure Linux bootc. A bootable Azure Linux image with atomic updates delivered from an OCI registry. Read `README.md` for the loop and `docs/TESTING.md` for the test steps.

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

- Remove all mannered prose. No filler, no praise, no hedging.
- Write plain English in the spirit of ASD-STE100 Simplified Technical English.
- Use short sentences, the active voice, and simple tenses.
- One word, one meaning. Use the same term for the same thing every time.
- Put the condition before the instruction.
- Define each technical term at first use.
- Never use em-dashes (U+2014). Do not use `--` as a substitute. Rephrase the sentence.
- Use British spelling in prose. Keep code identifiers, package names and quoted output as they are.

## Working rules

- Every target in `Makefile` is a script in `scripts/`. Read the script before you run it. `scripts/lib.sh` holds the shared settings.
- `make disk` needs root for loop devices and mounts. Do not run other steps as root.
- Build output goes in `out/`. It is ignored by git, together with the signing keys.
- Run `make lint` before you commit. CI runs the same shellcheck and an em-dash check.
- The scripts detect a Fedora toolbox and run host tools through `flatpak-spawn --host`. On a plain host they run the tools directly.
- Machine-specific notes belong in a private, git-ignored `CLAUDE.local.md`, not here.
