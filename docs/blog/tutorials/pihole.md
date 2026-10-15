---
title: "Rebuild step 6: Pi-hole"
subtitle: The lab's names on the LAN, from a VM that's all code and a password pushed over SSH
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, pihole, dns, cloud-init, networking, tutorial]
abstract: |
  Pi-hole answers for `lab.<domain>` on the LAN. Its VM is rebuilt from
  code: cloud-init installs Docker and a pinned Pi-hole image, whose
  settings and DNS records are generated from the network file in SOPS.
  The one secret, the web password, is pushed over SSH by a new script.
  Then the router hands Pi-hole out as the DNS server, and Proxmox and
  the VMs use it too.
---

## The short way

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"pihole\"]' make -C tofu plan
make -C tofu apply
git commit -m "Rebuild the Pi-hole VM" tofu/terraform.tfstate
ssh-keygen -R <pihole-ip>                 # the new VM's host key
scripts/push-secrets.sh pihole --apply
```

Then the router, Proxmox and the laptop, by hand: sections 4 to 6.

## Why this is needed

Every name in the lab, `proxmox.lab.<domain>` to `grafana.lab.<domain>`,
exists only in Pi-hole ([why](certs-and-dns.md#the-design)). Until now,
the laptop has used an `/etc/hosts` line, and the VMs had no names at
all.

## What you need to know first

**The VM is all code**
: [`tofu/pihole.tf`](../../../tofu/pihole.tf) adds Pi-hole's part to the
  VM's cloud-init: Docker, a compose file with a pinned image
  (`pihole/pihole:2026.09.0`), and a systemd unit. Pi-hole's settings are
  `FTLCONF_*` environment variables, which also locks them in the web UI.
  Nothing on the VM needs backing up: rebuilding it gives the same Pi-hole,
  minus its query history.

**The records come from the network file**
: One A record for each host in `secrets/network.sops.yaml`, plus
  `ingress` for k3s, and a CNAME for each app (`dns_cname` in
  `pihole.tf`). One record per name, never a wildcard: a wildcard would
  answer for `_acme-challenge.lab.<domain>` too, and hide the TXT records
  certificates are checked against.

**Changing a record means rebuilding the VM**
: cloud-init runs on the first boot only. To add a name, edit
  `pihole.tf` and run the short way again. It takes a few minutes, and
  the fallback DNS covers them.

**The one secret is pushed**
: The web password is in `secrets/pihole.sops.yaml`, generated straight
  into SOPS. [`push-secrets.sh`](../../../scripts/push-secrets.md) puts
  it on the VM as `/etc/homelab/pihole.env`, readable by root only.
  `pihole.service` doesn't start until it's there.

**Proxmox reruns cloud-init when its settings change**
: Changing a VM's cloud-init settings (here, its DNS servers) gives it a
  new instance ID, and cloud-init runs again on its next boot. That's
  harmless for these VMs; `ssh_deletekeys: false` keeps their SSH host
  keys.

## 1. Rebuild the Pi-hole VM

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"pihole\"]' make -C tofu plan
```

The plan replaces the Pi-hole VM, re-uploads the five snippets (now
generated from data), and changes the other four VMs' DNS servers to
Pi-hole, then the gateway. Then:

```sh
make -C tofu apply
git commit -m "Rebuild the Pi-hole VM" tofu/terraform.tfstate
```

## 2. Push the web password

The new VM has a new SSH host key. Forget the old one, then push:

```sh
ssh-keygen -R <pihole-ip>
scripts/push-secrets.sh pihole --apply
```

The script waits for cloud-init to finish installing Docker, pushes the
file, and starts `pihole.service`, which pulls the image and starts
Pi-hole.

## 3. Check it

```sh
dig +short @<pihole-ip> proxmox.lab.<domain>    # proxmox's address
dig +short @<pihole-ip> grafana.lab.<domain>    # ingress, then its address
dig +short @<pihole-ip> example.com             # the internet still works
```

The web UI is at `http://<pihole-ip>/admin`. It asks for a password only,
no username. Copy it to the clipboard without showing it; `-o` lets it be
pasted once, then clears it:

```sh
sops decrypt --extract '["FTLCONF_webserver_api_password"]' secrets/pihole.sops.yaml | wl-copy -n -o
```

On X11, `xclip -selection clipboard` instead of `wl-copy -n -o`.

Save it in Vaultwarden once that's back (step 8).

## 4. Hand out Pi-hole on the LAN

In Router2's DHCP settings:

| Field | Value |
|-------|-------|
| Primary DNS | `<pihole-ip>` |
| Secondary DNS | `<gateway-ip>`, Router1 |

Devices pick it up when their lease renews; reconnecting does it now.

The secondary keeps the internet working while Pi-hole or Proxmox is down.
The cost: a device may ask it now and then, and get no answer for a lab
name. If that happens often, leave the secondary out.

## 5. Proxmox uses Pi-hole

In **proxmox → System → DNS**:

| Field | Value |
|-------|-------|
| Search domain | `lab.<domain>` |
| DNS server 1 | `<pihole-ip>` |
| DNS server 2 | `<gateway-ip>` |

## 6. The laptop

Once the laptop has a new lease, `dig +short grafana.lab.<domain>`
answers without `@`.

**Keep** the `proxmox.lab.<domain>` line in `/etc/hosts` from step 4.
Pi-hole runs on Proxmox: when its VM is shut down for a rebuild, the
laptop would lose the name, and OpenTofu would lose Proxmox halfway
through the rebuild.

The other VMs use Pi-hole after their next reboot, or when they're rebuilt
in their own steps.

## What can go wrong

**`push-secrets.sh`: "can't SSH"**
: The VM was rebuilt and has a new host key. `ssh-keygen -R <pihole-ip>`.

**`dig` times out**
: Pi-hole isn't running. On the VM, `systemctl status pihole.service` and
  `sudo docker logs pihole`. If the unit says *condition failed*, the
  password wasn't pushed: section 2.

**Pi-hole's log: "address already in use" on port 53**
: systemd-resolved's stub listener is still on. cloud-init turns it off
  with `/etc/systemd/resolved.conf.d/no-stub.conf`; check it's there,
  then `sudo systemctl restart systemd-resolved pihole`.

**Devices still use other DNS servers**
: The DHCP server hands out something else. On a Linux laptop,
  `nmcli -g DHCP4.OPTION device show <device> | tr '|' '\n' | grep domain_name_servers`
  shows what it got. Check Router2's *DHCP* (LAN) settings, not its
  WAN or internet DNS settings, which some routers show nearby.

**Rebuilding the Pi-hole VM fails: "VM shutdown … error while waiting for task"**
: The laptop found Proxmox through Pi-hole, and lost it when Pi-hole's VM
  shut down. Put `proxmox.lab.<domain>` back in `/etc/hosts` (section 6),
  then plan and apply again.

**Lab names work on the laptop but not on the phone**
: Android's *Private DNS* set to a provider bypasses Pi-hole; set it to
  *Automatic* or *Off*.

**The web UI rejects the password**
: Typed from the screen, it's easy to get wrong; copy it as in section 3.
  To check what Pi-hole expects, without showing it:
  `sops decrypt --extract '["FTLCONF_webserver_api_password"]' secrets/pihole.sops.yaml | jq -Rc '{password: .}' | curl -s --data @- http://<pihole-ip>/api/auth`
  says `"valid":true` when it matches.

**A name answers NXDOMAIN now and then**
: The device asked the secondary DNS: section 4.

## Checklist

- [ ] Pi-hole VM rebuilt; state committed
- [ ] Web password pushed; `pihole.service` running
- [ ] `dig @<pihole-ip>` answers for the lab's names and for the internet
- [ ] Router2's DHCP hands out Pi-hole, then the gateway
- [ ] Proxmox uses Pi-hole, search domain `lab.<domain>`
- [ ] Laptop resolves lab names through Pi-hole; `proxmox` stays in `/etc/hosts`

## See also

- [Rebuild step 5: the VMs, with OpenTofu](opentofu-vms.md)
- [Rebuild step 7: Tailscale](tailscale.md)
- [Certificates and DNS for the homelab](certs-and-dns.md)
- [`push-secrets.sh`](../../../scripts/push-secrets.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<pihole-ip>`, `<gateway-ip>`
: Addresses from `secrets/network.sops.yaml`: `hosts.pihole.address`,
  and `gateway`.
