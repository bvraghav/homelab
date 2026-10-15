# scrub-history.sh

Find shell history entries that look like secrets, with values masked, and
remove them with `--apply`.

| | |
|-|-|
| **Script** | [`scrub-history.sh`](scrub-history.sh) |
| **Changes anything?** | Only with `--apply` |
| **Runs on** | Laptop, k3s VMs, Proxmox host |
| **Needs** | bash, GNU awk/sed/coreutils, `pgrep` |

## Usage

```sh
scripts/scrub-history.sh                          # list matches; changes nothing
scripts/scrub-history.sh --apply                  # private backup, then remove whole entries
scripts/scrub-history.sh --file ~/.bash_history   # another history file
scripts/scrub-history.sh --pattern 'hunter2|K10'  # extra case-insensitive patterns
scripts/scrub-history.sh --help
```

## Options

`--file PATH`
: The history file. Default: `~/.zsh_history` if it exists, otherwise
  `~/.bash_history`.

`--pattern REGEX`
: An extra case-insensitive extended regex, added to the built-in one
  (`from-literal`, `password`, `secret`, `token`, `api-key`, `AGE-SECRET-KEY`,
  `PRIVATE KEY`, `argon2`, …).

`--apply`
: Back up the file privately, then remove every matching entry.

`--force`
: With `--apply`, run even if other shells of the same kind are open.

## Before you run it

- Run `unset HISTFILE` in the shell you use, and close other terminals. A
  running shell can write the old history back.

## How it works

- A file with `zsh` in its name is read as zsh history, where a multi-line
  entry continues on lines ending in `\`. Anything else is read as bash
  history, one command per line. Whole entries are matched and removed.
- Matches are listed with every `=value` and quoted string masked.

## Safety

- Read-only unless `--apply` is given.
- With `--apply`, it refuses to run while other shells of the same kind are
  open, unless `--force`. The open-shells check counts every such process
  you own, not only terminals.
- The backup it leaves contains the secrets. Delete it once a new terminal's
  history looks right.

## Limitations

- Copies in backups, synced history and other machines aren't touched.
- Exposed secrets still need rotating.

## See also

- [How to scrub shell history to clean
  secrets](../docs/blog/tutorials/scrub-history.md), the full walkthrough.
- [All scripts](MANIFEST.md)
