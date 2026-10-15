---
title: How to scrub shell history to clean secrets
subtitle: Find secrets your shell saved, remove them safely, rotate them, and stop it happening again
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [secrets, zsh, bash, shell, tutorial]
abstract: |
  Building the homelab by hand meant typing secrets on the command line, and
  the shell saved every one of them to its history file. This tutorial finds
  them without printing them, removes them without corrupting the file or
  losing the edit to a running shell, cleans the other places they were
  copied to, and sets up the shell so it doesn't happen again.
---

## Why this is needed

Commands like this one, from the Forgejo setup, put a password straight into
`~/.zsh_history`:

```bash
kubectl -n forgejo create secret generic forgejo-admin \
  --from-literal=username=<user> \
  --from-literal=password='<password>'
```

So did the k3s agent join command (`K3S_TOKEN=<node-token>`) and the
Woodpecker OAuth secret. The history file is plain text. It gets copied into
backups and dotfile repos, and sometimes synced to other machines.

> [!WARNING]
> Scrubbing removes the secret from **this file from now on**. It doesn't
> remove copies already made by backups, syncing or other machines. If a
> secret may have been copied, **rotate it** (step 7). Scrubbing alone isn't
> enough.

## What you need to know first

**A running shell can undo your edit**
: zsh keeps history in memory and writes it back to the file, on exit or
  after each command, depending on `INC_APPEND_HISTORY` and `SHARE_HISTORY`.
  If another terminal is open, it can write the secrets back after you've
  removed them. So close the others, and stop the shell you work in from
  writing history at all (step 1).

**Entries can span several lines**
: zsh saves a multi-line command, like the one above, as several lines in
  the file, each ending in a backslash. Deleting a single matching line
  leaves the rest of the entry behind and garbles the next commands. The
  method in step 4 removes whole entries.

**The file format**
: With `EXTENDED_HISTORY` set, each entry starts with `: <timestamp>:0;`
  followed by the command. Without it, each entry is just the command. Both
  work with the steps below.

## The short way: the script

The repository has a script that does steps 2 to 4 for you. It lists by
default and changes nothing until you add `--apply`:

```zsh
unset HISTFILE                                   # step 1 still applies
scripts/scrub-history.sh                         # list matches, values masked
scripts/scrub-history.sh --apply                 # private backup, then remove whole entries
scripts/scrub-history.sh --file ~/.bash_history  # a bash history instead
scripts/scrub-history.sh --pattern 'hunter2|K10' # add your own patterns
```

With `--apply`, it refuses to run while other shells of the same kind are
open, because they could write the old history back. Close them, or pass
`--force` if you're sure. It prints where the backup is; delete it once a new
terminal's history looks right (step 6). Steps 7 and 8 are still up to you.

The rest of this tutorial does the same by hand, explaining each step.

## 1. Stop history from being written

Close every other terminal and tmux pane running zsh. In the one you keep:

```zsh
unset HISTFILE          # this shell no longer reads or writes the history file
```

Commands you type from now on aren't saved, and this shell won't write the
old secrets back when it exits.

## 2. Find the secrets, without printing them

Define what a secret-looking command is. Adjust the list for your setup:

```zsh
pat='from-literal|password|passwd|secret|token|api[-_]?key|client[-_]?secret|AGE-SECRET-KEY|PRIVATE KEY|argon2'
```

List the matching lines, with every `=value` and quoted string masked, so
the secrets don't end up on screen, in scrollback or in a screenshot:

```zsh
grep -inE "$pat" ~/.zsh_history \
  | sed -E "s/=[^ ]+/=****/g; s/'[^']*'/'****'/g; s/\"[^\"]*\"/\"****\"/g" \
  | cut -c1-120
```

Read through the list. It will also match harmless commands such as
`kubectl get secret`. That's fine: removing a few harmless entries costs
nothing. If something on the list must stay, make `pat` more specific.

Count the matches, so you can check your work afterwards:

```zsh
grep -ciE "$pat" ~/.zsh_history
```

## 3. Make a private backup

The backup contains the same secrets, so keep it private and short-lived:

```zsh
umask 077
cp ~/.zsh_history ~/.zsh_history.bak
```

You'll delete it in step 6, once the cleaned file works.

## 4. Remove whole matching entries

This `awk` script reads the file one **entry** at a time, joining lines that
end in a backslash, and drops every entry that matches the pattern:

```zsh
tmp=$(mktemp ~/.zsh_history.XXXXXX)      # created readable by you only

LC_ALL=C awk -v pat="$pat" '
  { entry = entry $0 "\n" }
  /\\$/ { next }                          # continued on the next line
  {
    if (tolower(entry) !~ tolower(pat)) printf "%s", entry
    entry = ""
  }
  END { if (entry != "" && tolower(entry) !~ tolower(pat)) printf "%s", entry }
' ~/.zsh_history > "$tmp" && mv "$tmp" ~/.zsh_history
```

`LC_ALL=C` matters. zsh stores non-ASCII characters in its own internal
encoding, and in a UTF-8 locale `awk` can stumble over those bytes.

> [!TIP]
> To remove only a handful of entries, opening the file in an editor and
> deleting them by hand works just as well. Use the line numbers from step 2,
> and remember that a multi-line entry continues on every line that ends in
> a backslash.

## 5. Check the result

```zsh
grep -ciE "$pat" ~/.zsh_history          # should print 0
wc -l ~/.zsh_history ~/.zsh_history.bak  # the new file should be a little shorter
```

Open a **new** terminal, which reads the cleaned file, and check that your
history still works: press the up arrow, try `Ctrl-R`, run `history | tail`.

## 6. Delete the backup

Once the new terminal's history looks right:

```zsh
shred -u ~/.zsh_history.bak     # or plain rm on SSDs and copy-on-write filesystems
```

On SSDs and on filesystems like btrfs or ZFS, `shred` can't guarantee the
old blocks are overwritten. That's one more reason to rotate anything that
mattered.

Then close the terminal where you ran `unset HISTFILE`.

## 7. Clean the other copies, and rotate

The history file on your laptop is rarely the only copy.

**Other machines**
: Secrets typed over SSH are in **those** machines' history files. In this
  homelab, the k3s join command, with `K3S_TOKEN`, was run on both agents,
  and `qm` commands ran as root on the Proxmox host. The Debian cloud images
  use bash, so run the bash version of these steps (below) on each VM and on
  the host.

**Terminal scrollback and tmux**
: `tmux clear-history` in each pane, and clear or close terminal windows
  that showed secrets.

**Backups and snapshots**
: Laptop backups (borg, restic, Timeshift, btrfs snapshots) still hold the
  old history file. You usually can't edit those, which is why rotating
  matters.

**History sync tools and dotfile repos**
: If you use something like atuin, or keep your history file in a dotfiles
  repository, the secret has already left the machine.

**Rotate what was exposed.** For this homelab:

| Secret | How to rotate it |
|--------|------------------|
| Forgejo admin password | Change it in Forgejo (Settings → Account), then update the `forgejo-admin` Kubernetes secret so a fresh install matches |
| Woodpecker OAuth client secret | Regenerate it on the OAuth app in Forgejo, update the `woodpecker-forgejo` secret, and restart the Woodpecker server |
| k3s node token | `k3s token rotate` on the server, then update the token on each agent (in `/etc/systemd/system/k3s-agent.service.env`) and restart `k3s-agent` |
| Vaultwarden admin token | Generate a new hash with `vaultwarden hash`, replace `ADMIN_TOKEN` in the compose file, and recreate the container |

## 8. Stop it happening again

Add this to `~/.zshrc`:

```zsh
# A command typed with a leading space isn't saved to history.
setopt HIST_IGNORE_SPACE

# Never save commands that look like they carry a secret.
zshaddhistory() {
  emulate -L zsh
  [[ ${1:l} != *(--from-literal|password=|passwd=|token=|secret=|api_key=|apikey=)* ]]
}
```

`zshaddhistory` runs before every command is saved. When it returns non-zero
(the pattern matched), the command isn't written to the history file. `${1:l}`
lowercases the command, so `PASSWORD=` and `K3S_TOKEN=` are caught too.

Better still, keep secret values off the command line entirely:

```zsh
# Prompt without echoing; only the variable name is saved to history.
read -rs 'pw?Forgejo admin password: '; echo
kubectl -n forgejo create secret generic forgejo-admin \
  --from-literal=username=<user> \
  --from-literal=password="$pw"
unset pw
```

With the hook above, this command isn't saved either, because it contains
`--from-literal`. That's harmless, since the value isn't in it.

- For files, use `--from-file`, from a file on a tmpfs such as
  `/run/user/<uid>`, and delete it afterwards.
- For secrets that belong in the repository, use SOPS + age. See [A secret
  store for the homelab](../tools/secrets.md).

## For bash and fish

**bash** (the k3s VMs and the Proxmox host)

: ```bash
  unset HISTFILE                      # step 1
  grep -inE "$pat" ~/.bash_history | sed -E 's/=[^ ]+/=****/g'   # step 2
  sed -i -E "/$pat/Id" ~/.bash_history                             # step 4
  ```

  bash saves one line per command, so deleting matching lines is enough.
  To prevent it in future, add `HISTCONTROL=ignorespace` (or `ignoreboth`)
  to `~/.bashrc`.

**fish**

: ```fish
  history search --contains password      # review
  history delete --contains password      # interactive delete
  ```

  Start a command with a space to keep it out of history.

## Placeholders

`<user>`
: The Forgejo admin username, e.g. `jdoe`. Lowercase letters, digits, `-`,
  `_` and `.`. `admin` is reserved by Forgejo.

`<password>`
: The admin password. It's shown here only to illustrate the mistake; type
  it at the `read -rs` prompt instead.

`<node-token>`
: The k3s join token from `/var/lib/rancher/k3s/server/node-token` on the
  server. A long string starting with `K10`, followed by hex characters and
  colons.

`<uid>`
: Your numeric user ID, e.g. `1000`; `id -u` prints it. `/run/user/<uid>`
  is a private tmpfs that disappears at logout.
