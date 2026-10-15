# homelab

Infrastructure-as-code and notes for a Proxmox homelab, so the whole lab
can be rebuilt quickly and repeatably.

## What runs here

- **Proxmox VE**, with Debian cloud-init templates for all VMs
- **Vaultwarden** behind Caddy, in a Docker VM
- **k3s** (one server, two agents): Prometheus, Grafana, Forgejo, Woodpecker CI
- **Pi-hole** for local DNS

## Layout

| Path | Purpose |
|------|---------|
| `tofu/` | OpenTofu code for VMs, cloud-init and releases |
| `docs/` | Docs and blog, published to GitHub Pages |
| `site/`, `Makefile` | Docs build: `make site` |
| `scripts/` | Helper scripts; see `scripts/MANIFEST.md` |
| `.github/` | CI: docs site, and releases from tags |
| `todo.md` | Tasks and rebuild progress |
| `MANIFEST.md` | Inventory of hosts, services and versions |
| `CHANGELOG.md`, `RELEASE_NOTES.md` | Changes and notes per release |

## Secrets

No plaintext secrets are committed. See `.gitignore`; encrypted secrets will
use SOPS + age.

## Licence

MIT. See `LICENCE.md`.
