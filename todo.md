# TODO

Goal: rebuild the whole homelab from this repo with minimal manual steps.
Status: `[ ]` open, `[~]` in progress, `[x]` done.

## 0. Repo and groundwork

- [x] Create repo skeleton (README, LICENCE, .gitignore, MANIFEST, todo)
- [x] Fill in identity placeholders in `LICENCE.md`
- [ ] Push repo to a remote (Forgejo after rebuild; elsewhere until then)
- [x] Write up the manual test run in `docs/blog/`
- [x] Publish `docs/` to GitHub Pages (workflow + Makefile)
- [ ] Enable Pages (Source: GitHub Actions) once the remote exists
- [ ] Allow version tags to deploy: github-pages environment, tag rule `*.*.*`
- [ ] Clean secrets out of shell history (`grep from-literal ~/.zsh_history`)

## 1. Decisions before rebuilding

- [ ] Local domain: `home.arpa`, or a subdomain of a real domain
- [ ] Certificates: real domain + Let's Encrypt DNS-01, or a local CA
- [ ] Remote access: Tailscale / WireGuard / none
- [ ] IP plan: static ranges outside DHCP for hosts and VMs
- [ ] Secrets: SOPS + age now; OpenBao + External Secrets later?

## 2. Proxmox host (manual, documented)

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
