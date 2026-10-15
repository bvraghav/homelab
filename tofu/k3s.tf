# k3s on three VMs: a server and two agents. cloud-init installs a pinned
# k3s with its config, but doesn't start it: the join token is pushed
# later, into /etc/homelab/k3s.env, and k3s waits for it.
#
# The server keeps its datastore in embedded etcd, and every night sends a
# snapshot to R2 (homelab-backups/k3s) by itself, with the R2 key from
# /etc/homelab/restic.env. Secrets are encrypted inside etcd, and k3s's own
# certificates and keys in the snapshot are encrypted with the token, so a
# snapshot is only of use with the token from SOPS.

locals {
  k3s_version = "v1.36.5+k3s1"
  # The install script from the same tag, pinned by checksum.
  k3s_install_url    = "https://raw.githubusercontent.com/k3s-io/k3s/v1.36.5%2Bk3s1/install.sh"
  k3s_install_sha256 = "46177d4c99440b4c0311b67233823a8e8a2fc09693f6c89af1a7161e152fbfad"

  # Agents join by address, not name: they mustn't depend on Pi-hole.
  k3s_server_url = "https://${local.net.hosts["k3s-server"].address}:6443"

  k3s_server_config = {
    "cluster-init"       = true
    "secrets-encryption" = true
    "tls-san"            = ["k3s-server.${local.domain}"]

    "etcd-snapshot-schedule-cron" = "30 2 * * *"
    "etcd-snapshot-retention"     = 7
    "etcd-s3"                     = true
    "etcd-s3-endpoint"            = "${data.sops_file.r2.data["account_id"]}.r2.cloudflarestorage.com"
    "etcd-s3-bucket"              = var.backup_bucket
    "etcd-s3-folder"              = "k3s"
  }

  k3s_agent_config = {
    server = local.k3s_server_url
  }

  # Install k3s, check the script first; enabled, but not started.
  k3s_install = [
    "curl -sfL -o /usr/local/sbin/k3s-install.sh '${local.k3s_install_url}'",
    "echo '${local.k3s_install_sha256}  /usr/local/sbin/k3s-install.sh' | sha256sum -c -",
    "INSTALL_K3S_VERSION='${local.k3s_version}' INSTALL_K3S_SKIP_START=true sh /usr/local/sbin/k3s-install.sh",
  ]

  # Holds k3s back until its secrets are pushed, and gives it them.
  k3s_dropin = {
    server = <<-EOT
      [Unit]
      ConditionPathExists=/etc/homelab/k3s.env
      ConditionPathExists=/etc/homelab/restic.env

      [Service]
      EnvironmentFile=/etc/homelab/k3s.env
      EnvironmentFile=/etc/homelab/restic.env
    EOT
    agent  = <<-EOT
      [Unit]
      ConditionPathExists=/etc/homelab/k3s.env

      [Service]
      EnvironmentFile=/etc/homelab/k3s.env
    EOT
  }

  k3s_server_cloud_init = {
    packages = []
    write_files = [
      {
        path    = "/etc/rancher/k3s/config.yaml"
        content = yamlencode(local.k3s_server_config)
      },
      {
        path    = "/etc/systemd/system/k3s.service.d/homelab.conf"
        content = local.k3s_dropin.server
      },
    ]
    runcmd = local.k3s_install
  }

  k3s_agent_cloud_init = {
    packages = []
    write_files = [
      {
        path    = "/etc/rancher/k3s/config.yaml"
        content = yamlencode(local.k3s_agent_config)
      },
      {
        path    = "/etc/systemd/system/k3s-agent.service.d/homelab.conf"
        content = local.k3s_dropin.agent
      },
    ]
    # K3S_URL makes the script install an agent; it also wants a token
    # then, which only the pushed file has: a placeholder satisfies it.
    runcmd = concat(
      slice(local.k3s_install, 0, 2),
      [
        "K3S_URL='${local.k3s_server_url}' K3S_TOKEN=placeholder INSTALL_K3S_VERSION='${local.k3s_version}' INSTALL_K3S_SKIP_START=true sh /usr/local/sbin/k3s-install.sh",
        "sed -i '/^K3S_TOKEN=/d' /etc/systemd/system/k3s-agent.service.env",
      ],
    )
  }
}
