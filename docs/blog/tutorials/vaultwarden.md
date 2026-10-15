---
title: "Rebuild step 8: Vaultwarden"
subtitle: The password vault back, behind Caddy and a wildcard certificate, backed up to R2 every night and restored by itself on a rebuild
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, vaultwarden, caddy, certificates, backups, restic, tutorial]
abstract: |
  Vaultwarden returns on its own VM, from code: Docker, a pinned
  Vaultwarden, and Caddy built with the Cloudflare DNS plugin for a
  Let's Encrypt wildcard. Its data sits on the VM's second disk, restic
  backs it up to R2 every night, and when the VM is rebuilt the latest
  backup comes back before Vaultwarden starts. Rebuilding it once, on
  purpose, is the first restore test.
---

## The short way

The first time, with sign-ups on so you can create your account:

```sh
TF_VAR_vaultwarden_signups_allowed=true \
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"vaultwarden\"]' make -C tofu plan
make -C tofu apply
ssh-keygen -R <vault-ip>
scripts/push-secrets.sh vaultwarden --apply
```

Then sections 3 to 5: your account, a first backup, and a rebuild with
sign-ups off, which restores it. Every later rebuild is the same, without
`TF_VAR_vaultwarden_signups_allowed`.

## Why this is needed

The vault holds every other password, so it's rebuilt early, and it keeps
working when the cluster doesn't: it has its own VM, with Docker, not
Kubernetes. It's also the first service with data that only exists here,
so it's where backups have to be proven.

## What you need to know first

**What's on the VM**
: [`tofu/vaultwarden.tf`](../../../tofu/vaultwarden.tf) adds to its
  cloud-init: Docker, `restic`, `sqlite3`, a compose file with
  Vaultwarden 1.37.4 and Caddy 2.11.7, the Caddyfile, and systemd units
  for the service, the backup and the restore.

**Caddy gets a wildcard certificate**
: Caddy is built on the VM with the Cloudflare DNS plugin, and asks Let's
  Encrypt for `*.lab.<domain>` through DNS-01, with the DNS token from
  step 3. A wildcard keeps `vault` out of the public certificate logs.
  Building takes a few minutes the first time, and needs the VM's 2 GB.

**The data has its own disk**
: The vault is on the VM's second disk, at `/srv/vaultwarden`. cloud-init
  formats it only if it's blank, and mounts it.

**Backups every night, restores by themselves**
: At 02:30, `vaultwarden-backup` copies the SQLite database safely
  (`.backup`), and restic sends it, with attachments and keys, to
  `homelab-backups/vaultwarden` in R2. It keeps 7 daily, 4 weekly and 3
  monthly backups. On a rebuilt VM, the disk is new and empty, and
  `vaultwarden-restore` brings back the latest backup before Vaultwarden
  starts. If it can't reach R2, Vaultwarden doesn't start at all, rather
  than start empty.

**Secrets**
: Two files go to the VM: `cloudflare` (the DNS token, for Caddy) and
  `restic` (its password and R2 key). There's no admin token: the admin
  page stays off.

**Sign-ups are off**
: Except while you create your account. `vaultwarden_signups_allowed`
  turns them on for one build.

## 1. Before you start

- **Your export.** The vault's export from before the blank box (step 4
  said to save it). It's plain text: keep it off synced folders.
- **The name.** `vault.lab.<domain>` resolves: Pi-hole has it since
  step 6. `dig +short vault.lab.<domain>`.

## 2. Build it, with sign-ups on

```sh
TF_VAR_vaultwarden_signups_allowed=true \
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"vaultwarden\"]' make -C tofu plan
```

The plan replaces the Vaultwarden VM and its snippet, nothing else.

```sh
make -C tofu apply
git commit -m "Rebuild the Vaultwarden VM" tofu/terraform.tfstate
ssh-keygen -R <vault-ip>
scripts/push-secrets.sh vaultwarden --apply
```

The script waits for cloud-init, pushes both files, and starts
`vaultwarden.service`. That builds Caddy (a few minutes), finds no backup,
and starts Vaultwarden empty. Caddy then gets its certificate.

## 3. Your account

1. Open `https://vault.lab.<domain>`: no certificate warning.
2. **Create account**, with your master password.
3. **Tools → Import data**, format *Bitwarden (json)*, and choose the
   export.
4. **Settings → Security → Two-step login**: turn on an authenticator app,
   and save the recovery code offline.
5. Delete the export: `shred -u <export-file>`.

## 4. A first backup

Don't wait for 02:30:

```sh
ssh debian@<vault-ip> 'sudo systemctl start vaultwarden-backup && sudo journalctl -u vaultwarden-backup -n 5 -o cat'
```

The log ends with restic's summary, "snapshot … saved".

## 5. Sign-ups off, and the restore test

Rebuild the VM without `TF_VAR_vaultwarden_signups_allowed`: it gets a
new, empty disk, and has to restore the backup from section 4.

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"vaultwarden\"]' make -C tofu plan
make -C tofu apply
git commit -m "Vaultwarden: sign-ups off" tofu/terraform.tfstate
ssh-keygen -R <vault-ip>
scripts/push-secrets.sh vaultwarden --apply
```

Then:

```sh
ssh debian@<vault-ip> 'sudo journalctl -u vaultwarden-restore -o cat | grep -E "restor|empty|read"'
```

It names the snapshot it restored, and ends "restored the latest backup".
To check the contents too, count what's in the vault:

```sh
ssh debian@<vault-ip> 'sudo sqlite3 /srv/vaultwarden/data/db.sqlite3 "select count(*) from users; select count(*) from ciphers;"'
```

Users, then items: the same as before the rebuild. Log in at `https://vault.lab.<domain>`:
your vault, your 2FA. On the login page, **Create account** now fails:
sign-ups are off. Record the date in the manifest's backups table, as the
last restore test.

## 6. The apps

In each Bitwarden app, before logging in: **Self-hosted**, server URL
`https://vault.lab.<domain>`. Away from home, the phone reaches it through
Tailscale (step 7).

## What can go wrong

**`vaultwarden.service` fails, and `vaultwarden-restore` says "can't read the backup repository"**
: The VM can't reach R2, or the restic key is wrong. Vaultwarden stays
  down on purpose. Check `secrets/restic.sops.yaml`, push again.

**The browser warns about the certificate**
: Caddy hasn't got it yet. `sudo docker compose -f /opt/vaultwarden/compose.yaml logs caddy`
  on the VM: look for the DNS challenge. A 403 from Cloudflare means the
  token in `secrets/cloudflare.sops.yaml` can't edit the zone.

**Caddy's build fails, or the VM stops answering during it**
: Out of memory: the VM needs 2 GB to build. Check `memory` in
  `tofu/vms.tf`.

**"Registration not allowed" on the first build**
: The plan ran without `TF_VAR_vaultwarden_signups_allowed=true`. Plan
  and apply again with it.

**The app says it can't reach the server**
: Phone on mobile data without Tailscale, or Private DNS on: see step 7.

## Checklist

- [ ] VM rebuilt; `https://vault.lab.<domain>` with a trusted certificate
- [ ] Account created, export imported, 2FA on; export shredded
- [ ] First backup in R2
- [ ] Rebuilt with sign-ups off; vault restored by itself
- [ ] Apps logged in, at home and over Tailscale
- [ ] Manifest: last restore test dated

## See also

- [Rebuild step 7: Tailscale](tailscale.md)
- [Rebuild step 9: k3s](k3s.md)
- [Certificates and DNS for the homelab](certs-and-dns.md)
- [Rebuild step 4: backups, not there](proxmox-install.md#backups-not-here)
- [`push-secrets.sh`](../../../scripts/push-secrets.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<vault-ip>`
: The Vaultwarden VM's address: `hosts.vaultwarden.address` in
  `secrets/network.sops.yaml`.

`<export-file>`
: The vault export saved before the rebuild.
