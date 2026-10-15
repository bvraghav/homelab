# Manifest

Inventory of what the homelab contains. Update it whenever something is added,
removed or upgraded. Values marked *test run* are from the first manual build
and are expected to change in the rebuild.

## Network

| Item          | Value                         | Notes                         |
|---------------|-------------------------------|-------------------------------|
| LAN subnet    | `192.168.10.0/24` (test run)  |                               |
| Local domain  | `212bn` (test run)            | consider `home.arpa` or a real domain |
| DNS           | Pi-hole `<ip>`                |                               |
| DHCP          | router                        | hands out Pi-hole as DNS      |

## Hosts and VMs

| VMID | Name          | IP              | vCPU | RAM  | Disk  | Role                    |
|------|---------------|-----------------|------|------|-------|-------------------------|
| —    | proxmox       | `<ip>`          |      |      |       | hypervisor              |
| 9000 | debian13-tmpl | —               | 2    | 2 GB | —     | cloud-init template     |
| —    | vaultwarden   | `<ip>`          | 1    | 1 GB | 10 GB | Docker: Vaultwarden, Caddy |
| 201  | k3s-server    | `192.168.10.61` | 2    | 4 GB | 32 GB | k3s control plane       |
| 202  | k3s-agent1    | `192.168.10.62` | 2    | 4 GB | 32 GB | k3s agent               |
| 203  | k3s-agent2    | `192.168.10.63` | 2    | 4 GB | 32 GB | k3s agent               |
| —    | pihole        | `<ip>`          |      |      |       | local DNS               |

## Services

| Service      | URL                       | Runs on     | Chart / image                       | Version |
|--------------|---------------------------|-------------|-------------------------------------|---------|
| Vaultwarden  | `https://vault.212bn`     | vaultwarden | `vaultwarden/server`                |         |
| Caddy        | —                         | vaultwarden | `caddy:2`                           |         |
| k3s          | `https://192.168.10.61:6443` | k3s VMs  | —                                   | v1.36.5+k3s1 |
| Prometheus + Grafana | `http://grafana.212bn` | k3s    | `prometheus-community/kube-prometheus-stack` |  |
| Forgejo      | `http://forgejo.212bn`, SSH `:2222` | k3s | `oci://code.forgejo.org/forgejo-helm/forgejo` | 17.3.0 |
| Woodpecker   | `http://ci.212bn`         | k3s         | `oci://ghcr.io/woodpecker-ci/helm/woodpecker` |   |

## Tools (laptop)

| Tool       | Package                  | Version |
|------------|--------------------------|---------|
| OpenTofu   | `opentofu`               | 1.13.1  |
| SOPS       | `sops`                   | 3.13.3  |
| age        | `age`                    | 1.3.2   |
| Helm       | `helm`                   | 4.3.0   |
| helmfile   | `helmfile`               | 1.8.0   |
| kubectl    | `kubectl`                | 1.37.1  |
| certbot    | `certbot`, `certbot-dns-cloudflare` | 5.8.0 |
| Tailscale  | `tailscale`              | 1.102.4 |
| jq         | `jq`                     | 1.8.2 |
| ShellCheck | `shellcheck`             | 0.11.0  |
| helm-diff  | Helm plugin, `helmfile init` | 3.15.13 |
| helm-secrets | Helm plugin, `helmfile init` | 4.7.4 |

## Secrets (locations only, never values)

| Secret                         | Stored in                         |
|--------------------------------|-----------------------------------|
| Proxmox root password, 2FA recovery | Vaultwarden + offline copy   |
| Vaultwarden master password, 2FA recovery | offline only            |
| Vaultwarden `ADMIN_TOKEN`      |                                   |
| Caddy local CA (`root.key`)    | vaultwarden VM `caddy-data/`      |
| k3s node token                 | k3s-server `/var/lib/rancher/k3s/server/node-token` |
| kubeconfig                     | laptop `~/.kube/config`           |
| Forgejo admin                  | k8s secret `forgejo/forgejo-admin` |
| Woodpecker OAuth client        | k8s secret `woodpecker/woodpecker-forgejo` |
| age key (SOPS), daily          | laptop `~/.config/sops/age/keys.txt` |
| age key (SOPS), backup         | offline USB stick + paper copy    |

## Backups

| What                | How                     | Schedule | Retention | Last restore test |
|---------------------|-------------------------|----------|-----------|-------------------|
| All VMs             | Proxmox vzdump snapshot |          |           |                   |
| Vaultwarden export  | encrypted JSON, off-site |         |           |                   |
