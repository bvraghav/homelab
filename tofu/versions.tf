# OpenTofu and provider versions, and state encryption.
#
# The state is kept in git, so it's encrypted, always: `enforced` makes
# OpenTofu refuse to write it in plain text. The passphrase is in
# secrets/tofu.sops.yaml; the Makefile passes it as TF_VAR_state_passphrase.

terraform {
  required_version = "~> 1.13.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.0"
    }
  }

  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
