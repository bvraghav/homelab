---
title: "Rebuild step 2: secrets with SOPS and age"
subtitle: A key on the laptop, a backup key offline, and encrypted secrets committed with everything else
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, secrets, sops, age, tutorial]
abstract: |
  The first secrets of the rebuild arrive in step 3, a DNS API token, and
  step 4, a Proxmox API token. Before either exists, this step sets up the
  place they go: an age key on the laptop, a second one kept offline,
  and a .sops.yaml that encrypts every secret file to both. Encrypted
  files are committed like any other; only the keys stay out of the
  repository.
---

## Why this is needed

In the test run, secrets were typed on the command line and ended up in
shell history (see
[How to scrub shell history](scrub-history.md)). The rebuild needs a
place for each secret *before* it's created, so it goes straight there.
[A secret store for the homelab](../tools/secrets.md) chose SOPS + age:
values encrypted inside YAML files, committed to the repository, and
decrypted only where they're used.

## What you need to know first

**Two keys, either one decrypts**
: Every secret file is encrypted to two age public keys: one on the
  laptop, used every day, and a backup kept offline. Lose the laptop, and
  the backup still decrypts everything. Lose both, and every secret in
  the repository is gone for good.

**Public keys are not secret; private keys are**
: The public keys go in `.sops.yaml`, committed. The private keys never
  touch the repository. `.gitignore` already ignores `keys.txt`, `age.key`
  and `*.agekey` in case one strays in.

**Encrypted is not invisible**
: SOPS encrypts the values, not the key names or the file names, and the
  repository is public. Name things plainly (`api_token`), never with
  anything that is itself a secret. And a value that was ever committed
  stays in Git's history: if a private key leaks, rotate the secrets, not
  just the key.

## 1. The laptop's key

SOPS looks for age keys in `~/.config/sops/age/keys.txt`:

```sh
install -m 700 -d ~/.config/sops/age
(umask 077; age-keygen -o ~/.config/sops/age/keys.txt)
```

`age-keygen` prints the public key, `age1…`. Print it again any time with:

```sh
age-keygen -y ~/.config/sops/age/keys.txt
```

## 2. The backup key, offline

Generate the backup key straight onto a USB stick, so it never sits on
the laptop's disk:

```sh
age-keygen -o <usb-mount>/homelab-backup.agekey
```

Note its public key, unmount the stick, and keep it somewhere safe, away
from the laptop. For a second copy, print the file and store the paper
with it; it's one short line.

## 3. Tell SOPS which keys to use

`.sops.yaml` at the repository root:

```yaml
creation_rules:
  - path_regex: \.sops\.(ya?ml|json|env)$
    age: <laptop-public-key>,<backup-public-key>
```

Any file named `*.sops.yaml`, `*.sops.json` or `*.sops.env` is now
encrypted to both keys. Secrets go under `secrets/`, one file per service,
e.g. `secrets/cloudflare.sops.yaml`.

## 4. Try it, and test the backup

```sh
mkdir -p secrets
sops edit secrets/example.sops.yaml     # write: hello: world
cat secrets/example.sops.yaml           # values are ENC[AES256_GCM,...]
sops decrypt secrets/example.sops.yaml  # hello: world
```

`sops edit` opens the decrypted file in `$EDITOR` and encrypts it again on
save; the plain text exists only in a temporary file while you edit.

Now check that the backup key alone can decrypt it, with the stick
mounted again:

```sh
SOPS_AGE_KEY_FILE=<usb-mount>/homelab-backup.agekey \
  sops decrypt secrets/example.sops.yaml
```

If both work, delete the example and commit `.sops.yaml`:

```sh
rm secrets/example.sops.yaml
git add .sops.yaml
git commit -m "Encrypt secrets to the laptop and backup age keys"
```

## 5. Using a secret without writing it down

Later steps use secrets in one of these ways, none of which puts the value
on a command line:

| Need | Command |
|------|---------|
| Edit or add a secret | `sops edit secrets/<name>.sops.yaml` |
| One value, inside a script | `"$(sops decrypt --extract '["api_token"]' secrets/<name>.sops.yaml)"` |
| Environment variables for one command | `sops exec-env secrets/<name>.sops.env '<command>'` |
| Helm values | helm-secrets, through helmfile |
| OpenTofu variables | the `carlpett/sops` provider |

A `$(...)` is saved to history as typed, so the history keeps the command
and never the value.

## When a key changes

To add or replace a key, change `.sops.yaml`, then re-encrypt every file to
the new set:

```sh
for f in secrets/*.sops.*; do sops updatekeys -y "$f"; done
```

A removed key can still decrypt old versions in Git's history, so if a key
was removed because it leaked, rotate the secrets too.

## See also

- [Rebuild step 1: tools on the laptop](laptop-tools.md)
- [Rebuild step 3: moving DNS to Cloudflare](dns-to-cloudflare.md): the
  first secret.
- [A secret store for the homelab](../tools/secrets.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<usb-mount>`
: Where the USB stick is mounted, e.g. `/run/media/<user>/<label>`.

`<laptop-public-key>`, `<backup-public-key>`
: The two age public keys, each `age1` followed by 58 characters. Not
  secret.

`<name>`
: A secret file's name, after the service it belongs to, e.g.
  `cloudflare`.

`<command>`
: The command that needs the variables, e.g. `docker compose up -d`.
