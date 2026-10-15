# Scripts

Helper scripts for running the homelab. Update this file whenever a script is
added, changed or removed.

## Inventory

| Script | Purpose | Changes anything? | Runs on | Needs |
|--------|---------|-------------------|---------|-------|
| [`scrub-history.sh`](scrub-history.sh) | Find shell history entries that look like secrets, values masked; remove them with `--apply` | Only with `--apply` | Laptop, k3s VMs, Proxmox host | bash, GNU awk/sed/coreutils, `pgrep` |

## `scrub-history.sh`

```sh
scripts/scrub-history.sh                          # list matches; changes nothing
scripts/scrub-history.sh --apply                  # private backup, then remove whole entries
scripts/scrub-history.sh --file ~/.bash_history   # another history file
scripts/scrub-history.sh --pattern 'hunter2|K10'  # extra case-insensitive patterns
scripts/scrub-history.sh --help
```

- **Before `--apply`:** run `unset HISTFILE` in the shell you use, and close
  other terminals. A running shell can write the old history back.
- **Formats:** a file with `zsh` in its name is read as zsh history, where
  a multi-line entry continues on lines ending in `\`; anything else is read
  as bash history, one command per line.
- **Safety:** with `--apply`, it refuses to run while other shells of the
  same kind are open, unless `--force`. The backup it leaves contains the
  secrets; delete it once a new terminal's history looks right.
- **Not covered:** copies in backups, synced history and other machines, and
  rotating exposed secrets.
- **Walkthrough:** [How to scrub shell history to clean
  secrets](../docs/blog/tutorials/scrub-history.md).

## Conventions for new scripts

- **Safe by default:** read-only unless a flag like `--apply` is given.
- **Self-documenting:** a header comment with usage and options, printed
  by `--help`.
- **Strict bash:** `#!/usr/bin/env bash` and `set -euo pipefail`.
- **No secrets** in arguments, output or the script itself; mask values when
  printing.
- **Executable,** and listed in the inventory above with what it changes and
  where it runs.
