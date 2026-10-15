# Scripts

Helper scripts for running the homelab. Update this file whenever a script is
added, changed or removed.

## Inventory

| Script | Purpose | Changes anything? | Runs on |
|--------|---------|-------------------|---------|
| [`scrub-history.sh`](scrub-history.md) | Find shell history entries that look like secrets, values masked; remove them with `--apply` | Only with `--apply` | Laptop, k3s VMs, Proxmox host |

## Conventions for new scripts

- **Safe by default:** read-only unless a flag like `--apply` is given.
- **Self-documenting:** a header comment with usage and options, printed
  by `--help`.
- **Strict bash:** `#!/usr/bin/env bash` and `set -euo pipefail`.
- **No secrets** in arguments, output or the script itself; mask values when
  printing.
- **Executable,** and listed in the inventory above, linking to its page.
- **A page per script:** `<name>.md` next to `<name>.sh`, with the same
  sections as [`scrub-history.md`](scrub-history.md):

  | Section | Contents |
  |---------|----------|
  | Title and summary | `# <name>.sh`, one sentence on what it does |
  | Facts table | Script link, whether it changes anything, where it runs, what it needs |
  | Usage | The common commands, one per line, with comments |
  | Options | A definition list, one entry per option |
  | Before you run it | Preconditions |
  | How it works | Enough to trust the output |
  | Safety | What protects you, and what it leaves behind |
  | Limitations | What it doesn't do |
  | See also | Related docs, and a link back to this list |

  Leave out a section only if it would be empty.
