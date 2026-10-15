# Scripts

Helper scripts for running the homelab. Update this file whenever a script is
added, changed or removed.

## Inventory

| Script | Purpose | Changes anything? | Runs on |
|--------|---------|-------------------|---------|
| [`laptop-tools.sh`](laptop-tools.md) | Check the rebuild's tools and print their versions; install what's missing with `--apply` | Only with `--apply` | Laptop |
| [`sops-setup.sh`](sops-setup.md) | Check the age keys and `.sops.yaml`, and that each key decrypts alone; create what's missing with `--apply` | Only with `--apply` | Laptop |
| [`dns01-test.sh`](dns01-test.md) | Dry-run a Let's Encrypt wildcard for `lab.<domain>` through DNS-01, with the token from SOPS | A temporary TXT record | Laptop |
| [`proxmox-tofu-token.sh`](proxmox-tofu-token.md) | Create OpenTofu's Proxmox user, role and token over SSH, and store the token in SOPS | Only with `--apply` | Laptop, against the Proxmox host |
| [`push-secrets.sh`](push-secrets.md) | Push a VM's secrets from SOPS to root-only files on the VM, and restart its services | Only with `--apply` | Laptop, against a lab VM |
| [`release-notes.sh`](release-notes.md) | Print a version's GitHub release title or description from `RELEASE_NOTES.md` | No | Laptop, `release` workflow |
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
