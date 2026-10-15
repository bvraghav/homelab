variable "state_passphrase" {
  description = "Encrypts the state and plans. From secrets/tofu.sops.yaml."
  type        = string
  sensitive   = true
}

variable "node" {
  description = "The Proxmox node's name."
  type        = string
  default     = "proxmox"
}

variable "vm_datastore" {
  description = "Where VM disks and cloud-init drives go."
  type        = string
  default     = "local-lvm"
}

variable "file_datastore" {
  description = "Where the cloud image and cloud-init snippets go; needs the Import and Snippets content types."
  type        = string
  default     = "local"
}

variable "bridge" {
  description = "The bridge the VMs join, on the LAN."
  type        = string
  default     = "vmbr0"
}

variable "vm_user" {
  description = "The user cloud-init creates on every VM, with sudo."
  type        = string
  default     = "debian"
}

variable "ssh_public_key_file" {
  description = "The laptop's public key, allowed to log in as vm_user."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "backup_bucket" {
  description = "The R2 bucket restic backs up to."
  type        = string
  default     = "homelab-backups"
}
