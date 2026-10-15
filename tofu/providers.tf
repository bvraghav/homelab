# Secrets and addresses come from SOPS files; the sops provider decrypts
# them with the laptop's age key. Their values end up in the state, which
# is why the state is encrypted.

provider "sops" {}

data "sops_file" "network" {
  source_file = "${path.module}/../secrets/network.sops.yaml"
}

data "sops_file" "proxmox" {
  source_file = "${path.module}/../secrets/proxmox.sops.yaml"
}

data "sops_file" "r2" {
  source_file = "${path.module}/../secrets/r2.sops.yaml"
}

locals {
  net    = yamldecode(data.sops_file.network.raw)
  domain = local.net.domain # lab.<domain>
}

# Reached by name: the certificate from step 4 is for proxmox.lab.<domain>.
# Until Pi-hole knows the name, the laptop's /etc/hosts does.
provider "proxmox" {
  endpoint  = "https://proxmox.${local.domain}:8006/"
  api_token = data.sops_file.proxmox.data["api_token"]

  # Uploading snippets needs SSH; the key comes from ssh-agent.
  ssh {
    agent    = true
    username = "root"
  }
}

provider "cloudflare" {
  api_token = data.sops_file.r2.data["api_token"]
}
