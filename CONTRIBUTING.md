# Contributing

## Before you open a pull request

1. Run `make lint`. It runs shellcheck on `scripts/`.
2. Run `make build`. The image must build.
3. If you changed a script in the test loop, run the loop in QEMU and record the result in `docs/WORKLOG.md`.

## Writing rules

All text in this repository follows the rules in `AGENTS.md`. Short sentences. Active voice. No em-dashes.

## Decisions

If you change the approach, add a record in `docs/decisions/`. Copy the format of the existing records.
