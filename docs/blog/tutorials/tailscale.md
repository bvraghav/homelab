---
title: "Rebuild step 7: Tailscale"
subtitle: The lab from anywhere, with no open ports; a subnet router on the Pi-hole VM, and split DNS for lab names
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, tailscale, dns, networking, cloud-init, tutorial]
abstract: |
  Away from home, the lab's names and addresses work over Tailscale.
  The Pi-hole VM joins the tailnet as a subnet router for the LAN, from
  code: cloud-init installs a pinned Tailscale, and an auth key pushed
  over SSH lets it join. The tailnet sends lookups for `lab.<domain>` to
  Pi-hole, so the same names and certificates work at home and away.
---

## The short way

Once the tailnet policy and the auth key exist (sections 1 and 2):

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"pihole\"]' make -C tofu plan
make -C tofu apply
git commit -m "Rebuild the Pi-hole VM, with Tailscale" tofu/terraform.tfstate
ssh-keygen -R <pihole-ip>
scripts/push-secrets.sh pihole --apply
```

Then split DNS and the clients, by hand: sections 4 and 5.

## Why this is needed

Nothing in the lab listens on the internet: no port forwards, no dynamic
DNS ([why](certs-and-dns.md#the-design)). Tailscale gives the laptop and
phone a way in from anywhere, and the subnet router makes every LAN
address reachable through it, without installing Tailscale on each VM.

## What you need to know first

**The subnet router is the Pi-hole VM**
: It's always on, it's small, and lookups for lab names end up there
  anyway. [`tofu/tailscale.tf`](../../../tofu/tailscale.tf) adds a pinned
  Tailscale (1.104.1) to its cloud-init, turns on IP forwarding, and a
  `tailscale.service` that joins the tailnet once the auth key arrives.

**It joins with a tag, `tag:lab`**
: A tagged machine belongs to the tailnet, not to a person, and its key
  doesn't expire. The policy says who may use the tag, and approves the
  router's route by itself.

**The auth key is a secret, used once**
: It's in `secrets/tailscale.sops.yaml`, and `push-secrets.sh` puts it on
  the VM. `tailscale up` reads it from a file, never an argument. After
  joining, the machine keeps its own identity; the key is needed again
  only when the VM is rebuilt.

**Rebuilding the VM makes a new machine**
: The tailnet then has the old `lab-router` too, offline. Remove it in
  the admin console, or the new one is named `lab-router-1`.

## 1. The tailnet policy

The admin console is at <https://login.tailscale.com/admin>; signing in
there the first time creates the tailnet. In **Access controls**
(<https://login.tailscale.com/admin/acls/file>), switch to the **JSON
editor**, and add inside the policy's outer braces:

```json
"tagOwners": {
  "tag:lab": ["autogroup:admin"]
},
"autoApprovers": {
  "routes": {
    "<lan-subnet>": ["tag:lab"]
  }
}
```

`tagOwners` lets admins create keys with `tag:lab`; `autoApprovers`
approves the router's route without a click. Keep the policy's existing
rules: the default allows every device to reach every other.

## 2. An auth key

**Settings → Keys → Generate auth key**
(<https://login.tailscale.com/admin/settings/keys>):

| Field | Value |
|-------|-------|
| Description | `homelab subnet router` |
| Reusable | On: each rebuild of the VM uses it again |
| Expiration | 90 days, the most it allows |
| Ephemeral | Off |
| Tags | `tag:lab` |

Store it, then close the dialog:

```sh
sops edit secrets/tailscale.sops.yaml
```

```yaml
TS_AUTHKEY: <auth-key>
```

When it expires, only a rebuild needs a new one; the running router
doesn't.

## 3. Rebuild the Pi-hole VM, and join

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"pihole\"]' make -C tofu plan
make -C tofu apply
git commit -m "Rebuild the Pi-hole VM, with Tailscale" tofu/terraform.tfstate
ssh-keygen -R <pihole-ip>
scripts/push-secrets.sh pihole --apply
```

The script pushes both of the VM's secrets, Pi-hole's password and the
auth key, and starts `pihole.service` and `tailscale.service`. In the
admin console, **Machines** shows `lab-router`, tagged `tag:lab`, with
the subnet route approved.

## 4. Split DNS

**DNS → Nameservers → Add nameserver → Custom**
(<https://login.tailscale.com/admin/dns>):

| Field | Value |
|-------|-------|
| Nameserver | `<pihole-ip>` |
| Restrict to domain | On: `lab.<domain>` |

Only lookups for `lab.<domain>` go to Pi-hole; everything else resolves
as before.

## 5. The clients

**Laptop**
: `sudo tailscale up --accept-routes`. Linux doesn't accept subnet
  routes unless asked.

**Phone**
: The Tailscale app accepts routes and uses Tailscale's DNS by default.
  On Android, *Private DNS* must be *Automatic* or *Off*.

To check, from the phone on mobile data, with Wi-Fi off: open
`https://proxmox.lab.<domain>:8006`. It loads, with no certificate
warning.

## What can go wrong

**`tailscale.service` failed: "requested tags are invalid or not permitted"**
: `tag:lab` isn't in `tagOwners`, or the key was made without it:
  sections 1 and 2.

**The machine shows up, but its route is "awaiting approval"**
: The subnet in `autoApprovers` doesn't match the LAN exactly. Approve it
  under **Machines → lab-router → Edit route settings**, and fix the
  policy.

**Away, lab names don't resolve**
: Split DNS isn't set, or the phone doesn't use Tailscale's DNS. In the
  app, check *Use Tailscale DNS*.

**Away, names resolve but nothing loads**
: The route isn't accepted. On Linux, `tailscale up --accept-routes`.

**At home, the laptop reaches the LAN through Tailscale**
: With `--accept-routes`, Linux can prefer the tailnet's route to its own
  LAN. It still works, a little slower; `tailscale up --accept-routes=false`
  while at home avoids it.

**`apt` on the VM can't find `tailscale=1.104.1`**
: Tailscale's repository dropped that version. Pick a current one from
  `apt-cache policy tailscale` and change `tailscale_version`.

## Checklist

- [ ] Policy: `tag:lab` owner, route auto-approved
- [ ] Auth key in `secrets/tailscale.sops.yaml`, committed
- [ ] Pi-hole VM rebuilt, state committed, secrets pushed
- [ ] `lab-router` in the tailnet, tagged, route approved
- [ ] Split DNS: `lab.<domain>` to `<pihole-ip>`
- [ ] Phone on mobile data opens `https://proxmox.lab.<domain>:8006`

## See also

- [Rebuild step 6: Pi-hole](pihole.md)
- [Certificates and DNS for the homelab](certs-and-dns.md)
- [`push-secrets.sh`](../../../scripts/push-secrets.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<pihole-ip>`
: Pi-hole's address: `hosts.pihole.address` in
  `secrets/network.sops.yaml`.

`<lan-subnet>`
: The LAN, e.g. `192.168.1.0/24`: `subnet` in the same file.

`<auth-key>`
: The Tailscale auth key, `tskey-auth-…`. Pasted into the `sops edit`
  editor only.
