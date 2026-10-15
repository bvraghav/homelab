# homelab

Infrastructure-as-code and notes for a Proxmox-based homelab, written so the
whole lab can be torn down and rebuilt quickly and repeatably.

## What runs here

- **Proxmox VE** host, with Debian cloud-init templates for all VMs
- **Vaultwarden** behind Caddy, in its own Docker VM
- **k3s** cluster (one server, two agents) running Prometheus + Grafana,
  Forgejo and Woodpecker CI
- **Pi-hole** for local DNS

## Layout

| Path          | Purpose                                          |
|---------------|--------------------------------------------------|
| `tofu/`       | OpenTofu code for VMs, cloud-init and releases   |
| `docs/`       | Documentation; `docs/blog/` for write-ups        |
| `todo.md`     | Task list and rebuild progress                   |
| `MANIFEST.md` | Inventory of hosts, services and versions        |

## Secrets

No plaintext secrets are committed. See `.gitignore`; encrypted secrets will
use SOPS + age.

## Licence

MIT. See `LICENCE.md`.
