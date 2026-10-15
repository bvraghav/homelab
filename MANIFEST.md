# Manifest

Inventory of what the homelab contains. Update it whenever something is added,
removed or upgraded. Values marked *test run* are from the first manual build
and are expected to change in the rebuild.

## Network

| Item          | Value                         | Notes                         |
|---------------|-------------------------------|-------------------------------|
| LAN subnet    | `192.168.10.0/24` (test run)  |                               |
| Local domain  | `212bn` (test run)            | consider `home.arpa` or a real domain |
| DNS           | Pi-hole (VM 101), gateway as fallback | records from `secrets/network.sops.yaml` |
| DHCP          | Router2                       | hands out Pi-hole, then the gateway |

## Hosts and VMs

| VMID | Name          | IP              | vCPU | RAM  | Disk  | Role                    |
|------|---------------|-----------------|------|------|-------|-------------------------|
| —    | proxmox       | `<ip>`          | 6    | 15 GB | 240 GB SSD | hypervisor: Proxmox VE 9.2.2, kernel 7.0.2-6-pve |
| 101  | pihole        | `<ip>`          | 1    | 512 MB | 8 GB | local DNS               |
| 102  | vaultwarden   | `<ip>`          | 1    | 1 GB | 8 GB + 4 GB data | Docker: Vaultwarden, Caddy |
| 201  | k3s-server    | `<ip>`          | 2    | 4 GB | 32 GB | k3s control plane       |
| 202  | k3s-agent1    | `<ip>`          | 2    | 3 GB | 32 GB | k3s agent               |
| 203  | k3s-agent2    | `<ip>`          | 2    | 3 GB | 32 GB | k3s agent               |

Addresses are in `secrets/network.sops.yaml`. VMs are created by
OpenTofu (`tofu/vms.tf`) from Debian 13 cloud image
`20261001-2618`, user `debian`.

## Proxmox storage

| Disk | Size | Use |
|------|------|-----|
| SSD (`sda`) | 240 GB | Proxmox: root 65 GB, swap 8 GB; `local` (ISOs, images, snippets) on root; `local-lvm` thin pool 130 GB for VM disks |
| HDD (`sdb`) | 1 TB | Not in use: an old install's LVM (`ram-vg`) is still on it. Check it for data before wiping |

## Services

| Service      | URL                       | Runs on     | Chart / image                       | Version |
|--------------|---------------------------|-------------|-------------------------------------|---------|
| Pi-hole      | `http://pihole.lab.<domain>/admin` | pihole | `pihole/pihole`            | 2026.09.0 |
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
| Cloudflare DNS API token, Zone ID | `secrets/cloudflare.sops.yaml` |
| Network: addresses, IP plan, router notes | `secrets/network.sops.yaml` |
| OpenTofu state passphrase      | `secrets/tofu.sops.yaml`          |
| Cloudflare R2 token (OpenTofu), account ID | `secrets/r2.sops.yaml` |
| restic password, R2 key for restic | `secrets/restic.sops.yaml`  |
| Pi-hole web password           | `secrets/pihole.sops.yaml`; on the VM, `/etc/homelab/pihole.env` |
| Proxmox API token, `tofu@pve!provider` | `secrets/proxmox.sops.yaml` |
| Proxmox ACME account key, Cloudflare plugin data | Proxmox host, `/etc/pve/priv/` |

## Backups

Data only: the VMs are rebuilt from code. Each dump goes to Cloudflare R2
with `restic`, encrypted.

| What                | How                                   | Schedule | Retention        | Last restore test |
|---------------------|---------------------------------------|----------|------------------|-------------------|
| Vaultwarden         | SQLite `.backup`, attachments, keys   | daily    | 7 d, 4 w, 3 m    |                   |
| k3s                 | datastore snapshot                    | daily    | 7 d, 4 w, 3 m    |                   |
| Forgejo             | `forgejo dump`                        | daily    | 7 d, 4 w, 3 m    |                   |
| Vaultwarden export  | encrypted JSON, off-site              | manual   |                  |                   |
