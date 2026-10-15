# TODO

Goal: rebuild the whole homelab from this repo with minimal manual steps.
Status: `[ ]` open, `[~]` in progress, `[x]` done.

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
      (modem, gateway, WiFi) has its DHCP off. Addresses are kept out of
      the repo, in `private/network.md` (git-ignored)
- [ ] Where Pi-hole runs: its own device, or a VM on Proxmox (then local
      names depend on the Proxmox host being up; hand out a fallback DNS)

Set up:

- [x] Second router in AP mode with DHCP; first router's DHCP off
- [ ] DHCP hands out Pi-hole as the DNS server
- [ ] Move the domain's DNS to a provider with an API (nameservers only;
      the registrar can stay)
- [ ] DNS API token scoped to editing that zone; stored per section 2
- [ ] Pi-hole: static IP, start on boot, upstream DNS, local records for
      `lab.<domain>` (an A record for the ingress, CNAMEs for each app)
- [ ] Tailscale: a subnet router on a lab node advertising the LAN; split
      DNS for `lab.<domain>` to Pi-hole
- [ ] Verify name resolution: laptop, phone (Android Private DNS off or
      automatic), at home and over Tailscale; nodes and pods once they
      exist
- [ ] Record the network in `MANIFEST.md` without addresses; document the
      plan in `docs/`

## 2. Decisions before rebuilding

- [ ] Secrets: SOPS + age now; OpenBao + External Secrets later?
- [x] Who builds what: OpenTofu creates the VMs; cloud-init configures
      them, up to "k3s is running"; helmfile installs everything inside
      k3s. Vaultwarden stays on its own VM (Docker, no Helm), so it works
      when the cluster doesn't
- [x] Secrets into VMs: pushed over SSH after the first boot, from SOPS
      on the laptop, not through cloud-init. Keeps them off Proxmox's
      snippets storage and out of tofu state, and a secret can be rotated
      without recreating the VM

## 3. Proxmox host (manual, documented)

- [ ] Destroy the test-run VMs (k3s nodes, Vaultwarden, template); no
      secrets from the test run carry over
- [ ] Install Proxmox VE; record version in MANIFEST
- [ ] 2FA for `root@pam`; create `admin@pve`
- [ ] SSH keys only for root (`PermitRootLogin prohibit-password`)
- [ ] API token for OpenTofu (dedicated user + role):
      `scripts/proxmox-tofu-token.sh`
- [ ] Backup storage and backup job

## 4. OpenTofu: infrastructure

- [ ] `tofu/` skeleton: providers (`bpg/proxmox`), versions, backend
- [ ] Enable state encryption
- [ ] Debian 13 cloud image download + template
- [ ] Cloud-init: user, SSH key, static IP, nameserver, search domain
- [ ] VM: Pi-hole, if it runs on Proxmox (see section 1)
- [ ] VM: Vaultwarden (from template, not ISO), with its data on a
      separate disk, so the VM can be recreated without losing the vault
- [ ] VMs: k3s server + 2 agents (unique hostnames!)
- [ ] k3s join token generated up front and kept in SOPS, so agents never
      read it off the server

## 5. In-VM configuration (cloud-init)

cloud-init runs only on a VM's first boot; changing it means recreating
the VM.


- [ ] Pi-hole install, if it runs on Proxmox; records per section 1
- [ ] Vaultwarden VM: Docker, compose file, Caddyfile; Caddy built with
      the DNS provider's plugin, for the wildcard cert through DNS-01
- [ ] k3s server install, pinned version (`INSTALL_K3S_VERSION`); agents
      join with the token from SOPS
- [ ] qemu-guest-agent on all VMs
- [ ] `scripts/push-secrets.sh <vm>`: each SOPS secret for that VM, piped
      over SSH into a root-only file; lists what it would push without
      `--apply`
- [ ] cloud-init installs services without their secrets; k3s with
      `INSTALL_K3S_SKIP_START`, started once the token is pushed

## 6. k3s workloads

- [ ] helmfile (or tofu helm provider) with pinned chart versions
- [ ] CoreDNS: forward local domain to Pi-hole (`coredns-custom`)
- [ ] cert-manager: wildcard cert for `*.lab.<domain>` through DNS-01,
      used by Traefik's ingresses
- [ ] kube-prometheus-stack (Grafana + Prometheus)
- [ ] Forgejo (SQLite, SSH on 2222, webhook ALLOWED_HOST_LIST)
- [ ] Mirror or move this repo to the rebuilt Forgejo (needs the item above)
- [ ] Woodpecker (Forgejo OAuth, kubernetes backend)
- [ ] Secrets via SOPS, no `--from-literal` in shell

## 7. Verification and operations

- [ ] Restore test: Vaultwarden VM from backup
- [ ] Restore test: a k3s node from backup
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
