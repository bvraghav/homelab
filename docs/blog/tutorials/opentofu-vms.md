---
title: "Rebuild step 5: the VMs, with OpenTofu"
subtitle: Five Debian VMs and a backup bucket from one command, with encrypted state in git and addresses in SOPS
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, opentofu, proxmox, cloud-init, backups, tutorial]
abstract: |
  The first step that's code from end to end. OpenTofu downloads a pinned
  Debian 13 cloud image to Proxmox, creates the five VMs the lab needs
  (Pi-hole, Vaultwarden and three k3s nodes), gives each one a user, an
  SSH key and its address through cloud-init, and creates the R2 bucket
  that every service backs up to. Secrets and addresses come from SOPS,
  and the state is committed to git, encrypted.
---

## The short way

Once the secrets in sections 1 to 3 exist:

```sh
ssh-add                    # the key that logs in to root@proxmox
make -C tofu init
make -C tofu plan          # read it
make -C tofu apply
git commit -m "Create the lab's VMs" tofu/terraform.tfstate
```

The rest of this post is what those commands rely on, and how to check
the result.

## Why this is needed

Every later step runs on these VMs. In the test run, they were made by
hand, and two clones ended up with the same hostname. Here they're
described once, in [`tofu/`](../../../tofu/vms.tf), and `tofu apply` makes
them the same way every time.

## What you need to know first

**What's in `tofu/`**
: `versions.tf` pins OpenTofu and the providers, and encrypts the state.
  `providers.tf` reads the secrets. `vms.tf` has the image and the VMs,
  `user-data.yaml.tftpl` their first-boot setup, and `r2.tf` the backup
  bucket. The `Makefile` runs `tofu` with the state passphrase.

**The state is in git, encrypted**
: OpenTofu's state holds every value it read, secrets included. It's
  encrypted with a passphrase from `secrets/tofu.sops.yaml`, and
  `enforced = true` stops OpenTofu from ever writing it in plain text.
  `make -C tofu check` confirms it before it's staged. Commit it after
  every apply: there's no lock, so it's for one person at a time.

**Addresses come from SOPS**
: Each VM's address is `hosts.<name>.address` in
  `secrets/network.sops.yaml`, read with the `sops` provider. Nothing in
  `tofu/` names an address.

**No template VM**
: OpenTofu downloads the Debian cloud image once, checked against its
  SHA-512, and each VM's disk is imported from it.

**cloud-init runs once**
: It sets up a VM on its first boot only. The VMs ignore later changes to
  the image or the user-data; to apply them, recreate the VM:
  `tofu apply -replace='proxmox_virtual_environment_vm.vm["pihole"]'`.

**No secrets in cloud-init**
: The user-data has a user, an SSH key and a package. Secrets reach the
  VMs over SSH later, in each service's step.

## 1. The lab's domain in the network file

OpenTofu names each VM `<name>.lab.<domain>`, and needs the domain:

```sh
sops edit secrets/network.sops.yaml
```

Add, at the top level:

```yaml
domain: lab.<domain>
```

Until Pi-hole exists (step 6), the VMs use the gateway for DNS. A `dns:`
list in the same file, if present, replaces it.

## 2. The Proxmox host

1. **Snippets on `local`.** cloud-init files are uploaded as snippets, and
   the image as an import. In **Datacenter → Storage → local → Edit**,
   **Content** must include *Snippets* and *Import*. Or, on the host:

   ```sh
   pvesm set local --content iso,vztmpl,backup,import,snippets
   ```

2. **The token's privileges.** OpenTofu reads each VM's address from the
   guest agent, which needs `VM.GuestAgent.Audit`. Run the token script
   again; it updates the role, and leaves the token alone:

   ```sh
   scripts/proxmox-tofu-token.sh --apply <proxmox-ip>
   ```

3. **SSH through ssh-agent.** The provider uploads snippets over SSH as
   `root`, and only takes keys from ssh-agent. `ssh-add`, then
   `ssh-add -l` lists the key.

4. **The name resolves.** OpenTofu calls `https://proxmox.lab.<domain>:8006`,
   so the certificate from step 4 checks out. Until Pi-hole knows it, the
   laptop's `/etc/hosts` line from step 4 does.

## 3. Cloudflare R2, for backups

The services' data goes to an R2 bucket ([why](proxmox-install.md#backups-not-here)).
OpenTofu creates the bucket; it needs a token that can.

1. **Turn on R2.** In the Cloudflare dashboard, **R2 Object Storage**.
   It asks for a payment method even on the free tier (10 GB).
2. **A token for OpenTofu.** **My Profile → API Tokens → Create Token →
   Custom token**:

   | Field | Value |
   |-------|-------|
   | Name | `homelab-tofu-r2` |
   | Permissions | Account · Workers R2 Storage · Edit |
   | Account resources | Include · your account |

   This is a new token. The DNS token from step 3 stays limited to DNS.
3. **Store it,** with the account ID (on the R2 overview page):

   ```sh
   sops edit secrets/r2.sops.yaml
   ```

   ```yaml
   account_id: <account-id>
   api_token: <r2-token>
   ```

## 4. Plan and apply

```sh
ssh-add
make -C tofu init
make -C tofu plan
```

The plan should create 12 things: the image, five snippets, five VMs and
the bucket. Then:

```sh
make -C tofu apply
git commit -m "Create the lab's VMs" tofu/terraform.tfstate
```

`apply` takes a few minutes: each VM boots, installs the guest agent, and
reports its address. `make apply` ends with "state is encrypted" and
stages the state; commit it.

## 5. Check the VMs

In **Datacenter → proxmox**, the five VMs run, numbered 101, 102 and
201–203. For each one:

```sh
ssh debian@<vm-ip> 'cloud-init status --wait; hostname -f'
```

It should print `status: done` and `<name>.lab.<domain>`. The VM's
**Summary** shows its address, which the guest agent reports.

## 6. A key for restic

The VMs back up with `restic`, using a key that can only read and write
the bucket. Its password is already in `secrets/restic.sops.yaml`; add
the key:

1. In **R2 Object Storage → Manage API tokens → Create Account API
   token**: permission **Object Read & Write**, applied to
   `homelab-backups` only.
2. Cloudflare shows an *Access Key ID* and a *Secret Access Key*, once:

   ```sh
   sops edit secrets/restic.sops.yaml
   ```

   ```yaml
   AWS_ACCESS_KEY_ID: <access-key-id>
   AWS_SECRET_ACCESS_KEY: <secret-access-key>
   ```

Each service's step pushes this file to its VM, and backs up to
`s3:https://<account-id>.r2.cloudflarestorage.com/homelab-backups/<vm>`.

## What can go wrong

**`ssh-add`: "Could not open a connection to your authentication agent"**
: No ssh-agent is running. For this shell, `eval "$(ssh-agent -s)"`. For
  every session, on Arch: `systemctl --user enable --now ssh-agent`, and
  `export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"` in the shell's
  startup file.

**`apply` stops on the snippets with an SSH error**
: ssh-agent has no key, or not the one `root@proxmox` accepts. `ssh-add`,
  then `ssh root@<proxmox-ip> true`.

**"storage 'local' does not support content-type 'snippets'"**
: Section 2, step 1.

**`apply` waits a long time on a VM, then times out**
: The guest agent didn't report in. Check the VM's console: cloud-init
  might still be installing it, or the VM has no route to the Debian
  mirrors. The VM is created anyway; the next apply picks it up.

**Permission errors from the API, e.g. `VM.GuestAgent.Audit`**
: The role is older than the script; section 2, step 2.

**"error decrypting state"**
: `tofu` ran without the passphrase. Use `make -C tofu …`, which passes
  it from SOPS.

## Checklist

- [ ] `domain` in `secrets/network.sops.yaml`
- [ ] Snippets and Import on `local`; the role has `VM.GuestAgent.Audit`
- [ ] R2 on, `secrets/r2.sops.yaml` committed
- [ ] Five VMs, each with `cloud-init status: done` and its own name
- [ ] Bucket `homelab-backups` exists
- [ ] `tofu/terraform.tfstate` committed; `make -C tofu check` passes
- [ ] restic's key in `secrets/restic.sops.yaml`, committed

## See also

- [Rebuild step 4: installing Proxmox VE](proxmox-install.md)
- [TF: good and bad use cases](../tools/tofu-use-cases.md)
- [`proxmox-tofu-token.sh`](../../../scripts/proxmox-tofu-token.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<proxmox-ip>`, `<vm-ip>`
: Addresses from `secrets/network.sops.yaml`: `hosts.proxmox.address`,
  and `hosts.<name>.address`.

`<account-id>`
: Your Cloudflare account ID, 32 hex characters.

`<r2-token>`
: The Cloudflare token from section 3. Pasted into the `sops edit` editor
  only.

`<access-key-id>`, `<secret-access-key>`
: R2's S3 credentials for restic, from section 6. Pasted into the
  `sops edit` editor only.
