# The VMs. Each one's disk starts from the Debian cloud image; cloud-init
# sets the user, SSH key, address and the guest agent on first boot.
# Addresses come from secrets/network.sops.yaml, under hosts.<name>.

locals {
  # Memory in MiB, disks in GiB; data_disk 0 means none. The host has
  # 6 cores and 15 GiB, and 130 GiB of thin-provisioned local-lvm.
  vms = {
    pihole      = { id = 101, cores = 1, memory = 512, disk = 8, data_disk = 0 }
    vaultwarden = { id = 102, cores = 1, memory = 1024, disk = 8, data_disk = 4 }
    k3s-server  = { id = 201, cores = 2, memory = 4096, disk = 32, data_disk = 0 }
    k3s-agent1  = { id = 202, cores = 2, memory = 3072, disk = 32, data_disk = 0 }
    k3s-agent2  = { id = 203, cores = 2, memory = 3072, disk = 32, data_disk = 0 }
  }

  dns_servers = try(local.net.dns, [local.net.gateway])
}

# Debian 13, pinned to one build and its checksum. To upgrade, change both
# from https://cloud.debian.org/images/cloud/trixie/ (SHA512SUMS).
resource "proxmox_download_file" "debian13" {
  node_name          = var.node
  datastore_id       = var.file_datastore
  content_type       = "import"
  url                = "https://cloud.debian.org/images/cloud/trixie/20261001-2618/debian-13-genericcloud-amd64-20261001-2618.qcow2"
  file_name          = "debian-13-genericcloud-amd64-20261001-2618.qcow2"
  checksum           = "f46f0671a6e5bdec5291ab8972bae2f10e5408c2f64a74078f11efc2f06a436a9d0313ed50e0472542eeabf780e9f7c792ac0a314c6c20507fcd9fd81b468c3d"
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = local.vms

  node_name    = var.node
  datastore_id = var.file_datastore
  content_type = "snippets"

  source_raw {
    file_name = "${each.key}-user-data.yaml"
    data = templatefile("${path.module}/user-data.yaml.tftpl", {
      hostname = each.key
      fqdn     = "${each.key}.${local.domain}"
      user     = var.vm_user
      ssh_key  = trimspace(file(pathexpand(var.ssh_public_key_file)))
    })
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms

  name      = each.key
  node_name = var.node
  vm_id     = each.value.id
  on_boot   = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "scsi0"
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.debian13.id
    size         = each.value.disk
    discard      = "on"
    iothread     = true
  }

  # Vaultwarden's data, on its own disk, so the system disk can be
  # replaced without touching it. Formatted and mounted by cloud-init in
  # step 8.
  dynamic "disk" {
    for_each = each.value.data_disk > 0 ? [each.value.data_disk] : []
    content {
      interface    = "scsi1"
      datastore_id = var.vm_datastore
      size         = disk.value
      discard      = "on"
      iothread     = true
    }
  }

  network_device {
    bridge = var.bridge
  }

  initialization {
    datastore_id = var.vm_datastore

    dns {
      domain  = local.domain
      servers = local.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${local.net.hosts[each.key].address}/${local.net.prefix}"
        gateway = local.net.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  lifecycle {
    # cloud-init runs only on first boot; a new image or user-data
    # shouldn't recreate a running VM by surprise.
    ignore_changes = [disk[0].import_from, initialization[0].user_data_file_id]
  }
}

output "vms" {
  description = "VM names and IDs; addresses stay in SOPS."
  value       = { for k, v in proxmox_virtual_environment_vm.vm : k => v.vm_id }
}
