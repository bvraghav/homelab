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

## 1. Decisions before rebuilding

- [ ] Local domain: `home.arpa`, or a subdomain of a real domain
- [ ] Certificates: real domain + Let's Encrypt DNS-01, or a local CA
- [ ] Remote access: Tailscale / WireGuard / none
- [ ] IP plan: static ranges outside DHCP for hosts and VMs
- [ ] Secrets: SOPS + age now; OpenBao + External Secrets later?

## 2. Proxmox host (manual, documented)

- [ ] Destroy the test-run VMs (k3s nodes, Vaultwarden, template); no
      secrets from the test run carry over
- [ ] Install Proxmox VE; record version in MANIFEST
- [ ] 2FA for `root@pam`; create `admin@pve`
- [ ] SSH keys only for root (`PermitRootLogin prohibit-password`)
- [ ] API token for OpenTofu (dedicated user + role)
- [ ] Backup storage and backup job

## 3. OpenTofu: infrastructure

- [ ] `tofu/` skeleton: providers (`bpg/proxmox`), versions, backend
- [ ] Enable state encryption
- [ ] Debian 13 cloud image download + template
- [ ] Cloud-init: user, SSH key, static IP, nameserver, search domain
- [ ] VM: Pi-hole
- [ ] VM: Vaultwarden (from template, not ISO)
- [ ] VMs: k3s server + 2 agents (unique hostnames!)
- [ ] Import or recreate existing VMs

## 4. In-VM configuration (cloud-init / Ansible)

- [ ] Pi-hole install + local DNS records
- [ ] Vaultwarden VM: Docker, compose file, Caddyfile
- [ ] k3s server install; agents join with token
- [ ] qemu-guest-agent on all VMs

## 5. k3s workloads

- [ ] helmfile (or tofu helm provider) with pinned chart versions
- [ ] CoreDNS: forward local domain to Pi-hole (`coredns-custom`)
- [ ] kube-prometheus-stack (Grafana + Prometheus)
- [ ] Forgejo (SQLite, SSH on 2222, webhook ALLOWED_HOST_LIST)
- [ ] Mirror or move this repo to the rebuilt Forgejo (needs the item above)
- [ ] Woodpecker (Forgejo OAuth, kubernetes backend)
- [ ] Secrets via SOPS, no `--from-literal` in shell

## 6. Verification and operations

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
