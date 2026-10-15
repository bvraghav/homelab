# TODO

Goal: rebuild the whole homelab from this repo with minimal manual steps.
Status: `[ ]` open, `[~]` in progress, `[x]` done, `[-]` dropped.

## 0. Repo and groundwork

- [x] Create repo skeleton (README, LICENCE, .gitignore, MANIFEST, todo)
- [x] Fill in identity placeholders in `LICENCE.md`
- [x] Push repo to a remote: GitHub `bvraghav/homelab`
- [x] Write up the manual test run in `docs/blog/`
- [x] Publish `docs/` to GitHub Pages (workflow + Makefile)
- [x] Enable Pages (Source: GitHub Actions)
- [x] Allow version tags to deploy: github-pages environment, tag rule `v*.*.*`
- [x] Release 0.0.1, *Groundwork*: docs site deployed from tag `v0.0.1`
- [x] Script and tutorial for scrubbing history (`scripts/scrub-history.sh`)
- [x] Clean secrets out of shell history: laptop, k3s VMs, Proxmox host
- [x] Release 0.0.2, *Clean Slate*: scrub script, scripts on the docs site
- [x] Releases from tags: `release` workflow + `scripts/release-notes.sh` (0.0.3)
- [x] Publish changelog, release notes and licence with the docs (0.0.4)
- [x] Fix a published release's notes without moving its tag (manual run)
- [x] Write up the release workflow in `docs/blog/`
- [x] Rebuild step 1: tools on the laptop (`scripts/laptop-tools.sh`);
      versions in `MANIFEST.md`
- [x] Rebuild step 2: SOPS + age, a laptop key and an offline backup key
      (`scripts/sops-setup.sh`); `.sops.yaml` committed
- [x] Rebuild step 3: `<domain>`'s DNS at Cloudflare, a one-zone API token
      in `secrets/cloudflare.sops.yaml`, DNS-01 dry run passed
      (`scripts/dns01-test.sh`)
- [x] Rebuild step 4: Proxmox VE 9.2.2 on the blank box, updates from the
      no-subscription repository, TOTP, SSH by key only, OpenTofu's token
      in `secrets/proxmox.sops.yaml`, Let's Encrypt certificate for the UI
- [x] Rebuild step 5: OpenTofu (`tofu/`) creates the Debian 13 image, five
      VMs with cloud-init, and the R2 backup bucket; state encrypted in
      git; network plan, R2 token and restic's key in SOPS
- [x] Rebuild step 6: Pi-hole on VM 101, all code; web password pushed
      with `scripts/push-secrets.sh`; DHCP and Proxmox use it
- [x] Rebuild step 7: Tailscale subnet router `lab-router` on the Pi-hole
      VM, tagged, with split DNS for `lab.<domain>`
- [x] Rebuild step 8: Vaultwarden behind Caddy with a wildcard
      certificate; nightly restic backups to R2; restore test passed
      (2026-10-15)
- [x] Rebuild step 9: k3s on three VMs, token from SOPS, Secrets
      encrypted, nightly etcd snapshots in R2

## 1. Network setup

Decide:

- [x] Local domain: a subdomain of a real domain (`lab.<domain>`), answered
      by Pi-hole on the LAN; only DNS-01 TXT records are public
- [x] Certificates: Let's Encrypt wildcard (`*.lab.<domain>`) through
      DNS-01 at a DNS provider with an API; no local CA, no DDNS, nothing
      listening on the internet. A wildcard keeps app names out of the
      public Certificate Transparency logs
- [x] Remote access: Tailscale; no DDNS and no port forwards (never the
      Proxmox UI on 8006, or SSH)
- [x] IP plan: one LAN; the second router in AP mode runs DHCP, the first
      (modem, gateway, WiFi) has its DHCP off. Addresses are kept
      encrypted, in `secrets/network.sops.yaml`; OpenTofu reads them
- [x] Where Pi-hole runs: a VM on Proxmox. Local names then depend on the
      Proxmox host being up, so DHCP also hands out a fallback DNS

Set up:

- [x] Second router in AP mode with DHCP; first router's DHCP off
- [x] DHCP hands out Pi-hole as the DNS server, a public one second
- [x] Move the domain's DNS to a provider with an API (nameservers only;
      the registrar can stay)
- [x] DNS API token scoped to editing that zone; stored per section 2
- [x] Pi-hole: static IP, start on boot, upstream DNS, local records for
      `lab.<domain>` (an A record for the ingress, CNAMEs for each app),
      generated from `secrets/network.sops.yaml` (`tofu/pihole.tf`)
- [x] Tailscale: a subnet router on the Pi-hole VM advertising the LAN,
      tagged `tag:lab`, route auto-approved; split DNS for `lab.<domain>`
      to Pi-hole (`tofu/tailscale.tf`, auth key in SOPS)
- [ ] Verify name resolution: laptop, phone (Android Private DNS off or
      automatic), at home and over Tailscale; nodes and pods once they
      exist
- [ ] Record the network in `MANIFEST.md` without addresses; document the
      plan in `docs/`

## 2. Decisions before rebuilding

- [x] Secrets: SOPS + age now (OpenBao + External Secrets maybe later)
- [x] Who builds what: OpenTofu creates the VMs; cloud-init configures
      them, up to "k3s is running"; helmfile installs everything inside
      k3s. Vaultwarden stays on its own VM (Docker, no Helm), so it works
      when the cluster doesn't
- [x] Secrets into VMs: pushed over SSH after the first boot, from SOPS
      on the laptop, not through cloud-init. Keeps them off Proxmox's
      snippets storage and out of tofu state, and a secret can be rotated
      without recreating the VM
- [x] Backups: data, not VM images. A systemd timer on each VM dumps its
      service's data, and `restic` sends it, encrypted, to an S3 bucket
      (Cloudflare R2); retention 7 daily, 4 weekly, 3 monthly. No
      Proxmox backup job: the VMs are rebuilt from code

## 3. Proxmox host (manual, documented)

- [x] Destroy the test-run VMs (k3s nodes, Vaultwarden, template); no
      secrets from the test run carry over
- [x] Install Proxmox VE; record version in MANIFEST
- [x] 2FA for `root@pam`; create `admin@pve`
- [x] SSH keys only for root (`PermitRootLogin prohibit-password`)
- [x] API token for OpenTofu (dedicated user + role):
      `scripts/proxmox-tofu-token.sh`
- [-] ~~Backup storage and backup job~~: replaced by per-service data
      backups to S3 (section 2)

## 4. OpenTofu: infrastructure

- [x] `tofu/`: providers (`bpg/proxmox`, `sops`, `cloudflare`) pinned;
      state local and committed to git; secrets and addresses from SOPS
- [x] State encryption, enforced; passphrase in `secrets/tofu.sops.yaml`
- [x] R2 bucket for backups (`cloudflare` provider, its own token in
      `secrets/r2.sops.yaml`); restic's key, limited to the bucket, and
      its password in `secrets/restic.sops.yaml`
- [x] Debian 13 cloud image, pinned by checksum, imported into each VM;
      no template
- [x] Cloud-init: user, SSH key, static IP, nameserver, search domain
- [x] VM: Pi-hole
- [x] VM: Vaultwarden (from the cloud image, not ISO), with its data on a
      separate disk, so the VM can be recreated without losing the vault
- [x] VMs: k3s server + 2 agents (unique hostnames!)
- [x] k3s join token generated up front and kept in SOPS, so agents never
      read it off the server

## 5. In-VM configuration (cloud-init)

cloud-init runs only on a VM's first boot; changing it means recreating
the VM.


- [x] Pi-hole: Docker, pinned image, settings as `FTLCONF_*` variables;
      web password pushed; no backup needed, it's all code
- [x] Vaultwarden VM: Docker, compose file, Caddyfile; Caddy built with
      the DNS provider's plugin, for the wildcard cert through DNS-01
      (`tofu/vaultwarden.tf`); data on its own disk; no admin page
- [x] k3s server install, pinned version (`INSTALL_K3S_VERSION`); agents
      join with the token from SOPS
- [x] qemu-guest-agent on all VMs
- [~] Backup timers (`restic` to R2; repository password and key pushed
      from SOPS): Vaultwarden (SQLite `.backup`, `attachments/`,
      `rsa_key*`) written; k3s: etcd snapshots to R2 by k3s itself; no Pi-hole (all
      code)
- [ ] A notice when a backup fails (`OnFailure=`); needs a way to send it
- [x] `scripts/push-secrets.sh <vm>`: each SOPS secret for that VM, piped
      over SSH into a root-only file; lists what it would push without
      `--apply`
- [x] cloud-init installs services without their secrets; k3s with
      `INSTALL_K3S_SKIP_START`, started once the token is pushed

## 6. k3s workloads

- [~] helmfile with pinned chart versions (`helmfile/`)
- [~] CoreDNS: forward local domain to Pi-hole (`coredns-custom`)
- [~] cert-manager: wildcard cert for `*.lab.<domain>` through DNS-01,
      used by Traefik's ingresses
- [~] kube-prometheus-stack (Grafana + Prometheus)
- [ ] Forgejo (SQLite, SSH on 2222, webhook ALLOWED_HOST_LIST)
- [ ] Mirror or move this repo to the rebuilt Forgejo (needs the item above)
- [ ] Woodpecker (Forgejo OAuth, kubernetes backend)
- [ ] Forgejo backup: `forgejo dump` on a schedule, to R2 with `restic`
- [ ] Secrets via SOPS, no `--from-literal` in shell

## 7. Verification and operations

- [x] Restore test: rebuild the Vaultwarden VM; it restores the latest
      backup by itself (`vaultwarden-restore`)
- [ ] Restore test: rebuild k3s, restore its snapshot and Forgejo
      (an in-place restore from R2 passed on 2026-10-16)
- [ ] Timed rebuild from scratch; record time-to-build here
- [ ] HTTPS for Grafana, Forgejo, Woodpecker
- [ ] Phone access to Vaultwarden

## Lessons from the test run

- Docker in LXC is unsupported by Proxmox; use VMs.
- `$` in Vaultwarden's `ADMIN_TOKEN` must be doubled (`$$`) in compose.
- Editing a bind-mounted Caddyfile needs `docker compose restart caddy`.
- Cloning VMs with the same `--name` gives duplicate hostnames; k3s rejects them.
- Join commands from docs had the wrong subnet; parameterise IPs.
- Cloud-init nameserver defaulted to the Proxmox host's; set it explicitly.
- Traefik owns ports 80/443 on k3s nodes; use Ingress, not LoadBalancer.
- Forgejo chart init container is still named `configure-gitea`.
- `helm install` on an existing release fails; use `helm upgrade --install`.
- GitHub environment deployment rules take globs (`v*.*.*`), not regexes.
- Releasing through a pull request skips git flow's back-merge; merge `master`
  into `develop` by hand.
- git flow's tag prefix must match the tags in use (`v`); pass git flow the
  bare version.
- **Re-run** replays a workflow run's original event (same tag, commit and
  workflow file); use **Run workflow** to pick up changes.
