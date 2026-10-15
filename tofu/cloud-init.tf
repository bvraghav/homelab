# First-boot setup for every VM: a base (name, user, SSH key, guest
# agent), plus what its role adds (e.g. pihole.tf). Built as data and
# written as YAML, so a role only lists its packages, files and commands.
# No secrets: they're pushed over SSH afterwards (scripts/push-secrets.sh).

locals {
  ssh_key = trimspace(file(pathexpand(var.ssh_public_key_file)))

  # Each role's additions: packages, write_files and runcmd, appended to
  # the base's. A VM without a role gets the base only.
  roles = {
    pihole = local.pihole_cloud_init
  }

  user_data = {
    for name, vm in local.vms : name => {
      hostname         = name
      fqdn             = "${name}.${local.domain}"
      manage_etc_hosts = true
      timezone         = "UTC"

      users = [{
        name                = var.vm_user
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        lock_passwd         = true
        ssh_authorized_keys = [local.ssh_key]
      }]
      ssh_pwauth   = false
      disable_root = true
      # Keep the host keys if cloud-init runs again: Proxmox gives the VM a
      # new instance ID whenever its cloud-init settings change.
      ssh_deletekeys = false

      package_update  = true
      package_upgrade = true
      packages        = concat(["qemu-guest-agent"], try(local.roles[name].packages, []))
      write_files     = try(local.roles[name].write_files, [])
      runcmd          = concat(["systemctl enable --now qemu-guest-agent"], try(local.roles[name].runcmd, []))
    }
  }
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.vms

  node_name    = var.node
  datastore_id = var.file_datastore
  content_type = "snippets"

  source_raw {
    file_name = "${each.key}-user-data.yaml"
    data      = "#cloud-config\n${yamlencode(local.user_data[each.key])}"
  }
}
