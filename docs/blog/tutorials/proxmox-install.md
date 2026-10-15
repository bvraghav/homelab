---
title: "Rebuild step 4: installing Proxmox VE"
subtitle: From a blank box to a hardened, backed-up hypervisor with a trusted certificate and a token for OpenTofu
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, proxmox, opentofu, tutorial]
abstract: |
  Proxmox is the one part of the lab that can't be built from code: it's
  what the code runs against. This step installs it by hand on the blank
  box, then does everything the rest of the rebuild relies on: updates
  from the free repository, two-factor login, SSH by key only, an API
  token for OpenTofu, a backup job, and a Let's Encrypt certificate for
  the web UI.
---

## Why this is needed

Everything after this step is code: OpenTofu creates the VMs, cloud-init
and helmfile configure them. They all need a Proxmox host that's reachable,
secure, and has an API token for OpenTofu. Installing it is manual, so it's
written down here, step by step, to be repeatable anyway.

## What you need to know first

**Pi-hole doesn't exist yet**
: The host uses the router for DNS until Pi-hole is up (step 6), and is
  reached by its address until then.

**Docker belongs in VMs, not containers**
: Proxmox doesn't support Docker in LXC containers. Everything in this lab
  runs in VMs.

**The free repository is fine**
: Proxmox's enterprise repository needs a subscription. The
  no-subscription repository gets the same packages, a little later.

## 1. Prepare the USB stick

Download the latest Proxmox VE ISO and its SHA256 checksum from the
Proxmox website, then:

```sh
sha256sum proxmox-ve_<version>.iso   # must match the published checksum
lsblk                                # find the USB stick: <usb-device>
sudo dd if=proxmox-ve_<version>.iso of=<usb-device> bs=4M conv=fsync status=progress
```

> [!WARNING]
> `dd` overwrites `<usb-device>` without asking. Check it's the stick, not
> a disk, in `lsblk` first: same size, and unmounted.

## 2. Firmware settings

In the box's firmware setup:

- **Virtualization:** Intel VT-x or AMD-V, on.
- **IOMMU:** Intel VT-d or AMD-Vi, on, for passing devices to VMs later.
- **Boot order:** USB first, for the install.

## 3. Run the installer

Boot from the stick and choose the graphical install.

| Screen | Value |
|--------|-------|
| Target disk | The disk for Proxmox and VMs. One disk: **ext4** (LVM-thin for VMs). Two or more disks and plenty of RAM: ZFS mirror |
| Country, time zone, keyboard | Yours |
| Password | A strong root password, saved in the password manager |
| Email | `<email>`, for backup and update notices |
| Management interface | The wired NIC |
| Hostname (FQDN) | `proxmox.lab.<domain>` |
| IP address (CIDR) | `<proxmox-ip>/<prefix>`, from the IP plan, outside the DHCP range |
| Gateway | `<gateway-ip>` |
| DNS server | `<gateway-ip>`, until Pi-hole exists |

Install, remove the stick, reboot. Then, from the laptop, open
`https://<proxmox-ip>:8006` and log in as `root`, realm *Linux PAM*. The
browser warns about the certificate until step 9.

## 4. Updates from the free repository

1. **proxmox → Updates → Repositories**: disable the two *enterprise*
   entries (PVE and Ceph).
2. **Add → No-Subscription**.
3. **Updates → Refresh**, then **Upgrade**, which opens a shell running
   `apt full-upgrade`. Reboot if the kernel was updated.

Never use plain `apt upgrade` on Proxmox; it can leave packages half
upgraded. Use **Upgrade** or `apt full-upgrade`.

Record the version in the manifest:

```sh
pveversion
```

## 5. Two-factor login, and an admin user

For `root@pam`:

1. **Datacenter → Permissions → Two Factor → Add → TOTP**: scan the code
   with your authenticator app.
2. **Add → Recovery Keys**: save them in the password manager, and keep an
   offline copy with the backup age key.

Then a day-to-day admin user, so `root` is only for emergencies:

```sh
pveum user add admin@pve
pveum passwd admin@pve
pveum acl modify / --users admin@pve --roles Administrator
```

Log in as `admin@pve` (realm *Proxmox VE authentication server*) and give
it TOTP too.

## 6. SSH by key only

From the laptop, while password login still works:

```sh
ssh-copy-id root@<proxmox-ip>
ssh root@<proxmox-ip> true   # must log in without a password
```

Then on the host:

```sh
cat > /etc/ssh/sshd_config.d/10-keys-only.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
sshd -t && systemctl reload ssh
```

> [!WARNING]
> Keep the current session open, and check `ssh root@<proxmox-ip>` from a
> second terminal before closing it. If it fails, fix it from the first.

## 7. An API token for OpenTofu

OpenTofu (the `bpg/proxmox` provider) logs in with an API token of its
own user, whose role has only the privileges it needs. On the host:

```sh
pveum role add TofuProvision -privs "Datastore.Allocate Datastore.AllocateSpace \
Datastore.AllocateTemplate Datastore.Audit Pool.Allocate SDN.Use Sys.Audit \
Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM \
VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType \
VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt"
pveum user add tofu@pve
pveum acl modify / --users tofu@pve --roles TofuProvision
pveum user token add tofu@pve provider --privsep 0
```

The privileges change between Proxmox versions; if `pveum` rejects one,
check the provider's documentation for the current list.

The last command prints the token's secret **once**. Put it straight into
SOPS from the laptop:

```sh
sops edit secrets/proxmox.sops.yaml
```

```yaml
api_token: tofu@pve!provider=<token-secret>
```

The provider reads it from `PROXMOX_VE_API_TOKEN`. Some of its operations,
such as uploading cloud-init snippets, also use SSH to the host; the key
from step 6 covers that.

## 8. Backups

Backups on the same disk as the VMs aren't backups. Add storage that
survives the disk: a second disk, a NAS share, or a Proxmox Backup Server.

1. **Datacenter → Storage → Add**: *Directory* (a mounted second disk),
   *NFS*/*SMB* (a NAS) or *Proxmox Backup Server*. Content: **Backup**.
2. **Datacenter → Backup → Add**:

   | Field | Value |
   |-------|-------|
   | Storage | The one from above |
   | Schedule | Daily, at a quiet hour, e.g. `02:00` |
   | Selection | All |
   | Mode | Snapshot |
   | Compression | ZSTD |
   | Retention | Keep daily 7, weekly 4, monthly 3 |
   | Notification | Email `<email>` on failure |

3. Record the schedule and retention in the manifest's backups table.

There are no VMs yet, so the first runs back up nothing; the job is ready
for step 5. A backup isn't proven until it's restored, which the task list
tests once the VMs exist.

## 9. A trusted certificate for the web UI

Proxmox has an ACME client built in, and it can use the Cloudflare token
from [step 3](dns-to-cloudflare.md):

1. **Datacenter → ACME → Accounts → Add**: Let's Encrypt V2, `<email>`.
2. **Datacenter → ACME → Challenge Plugins → Add**: DNS API *Cloudflare
   Managed DNS*, with API data:

   ```
   CF_Token=<token>
   CF_Zone_ID=<zone-id>
   ```

3. **proxmox → System → Certificates → ACME → Add**: challenge type DNS,
   the Cloudflare plugin, domain `proxmox.lab.<domain>`.
4. **Order Certificates Now**. Proxmox renews it by itself.

The certificate names `proxmox.lab.<domain>`, so that name appears in the
public Certificate Transparency logs;
[Certificates and DNS](certs-and-dns.md) explains the alternative.

Until Pi-hole knows the name (step 6), `https://<proxmox-ip>:8006` still
warns, because the certificate doesn't match the address. To use the name
already, add a line to the laptop's `/etc/hosts`:

```
<proxmox-ip>  proxmox.lab.<domain>
```

and remove it once Pi-hole is up.

## Checklist

- [ ] Web UI at `https://proxmox.lab.<domain>:8006`, no warning
- [ ] Updates from the no-subscription repository; version in the manifest
- [ ] TOTP for `root@pam` and `admin@pve`; recovery keys saved
- [ ] SSH by key only
- [ ] `tofu@pve` token in `secrets/proxmox.sops.yaml`
- [ ] Backup storage and a daily job

## See also

- [Rebuild step 3: moving DNS to Cloudflare](dns-to-cloudflare.md)
- [Certificates and DNS for the homelab](certs-and-dns.md)
- [TF: good and bad use cases](../tools/tofu-use-cases.md): why Proxmox
  itself is installed by hand.
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<version>`
: The Proxmox VE release in the ISO's name, e.g. `9.1-1`.

`<usb-device>`
: The USB stick's device, e.g. `/dev/sdb`; the whole device, not a
  partition like `/dev/sdb1`.

`<email>`
: Where Proxmox and Let's Encrypt send notices.

`<domain>`
: Your domain, e.g. `example.com`.

`<proxmox-ip>`, `<prefix>`
: The host's static address from the IP plan, and the LAN's prefix
  length, e.g. `24`.

`<gateway-ip>`
: The LAN's gateway, the router.

`<token-secret>`
: The secret `pveum user token add` prints, a UUID. Pasted into the
  `sops edit` editor only.

`<token>`, `<zone-id>`
: The Cloudflare API token and Zone ID, from `secrets/cloudflare.sops.yaml`.
