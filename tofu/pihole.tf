# Pi-hole on its VM: Docker, with a pinned image and its settings in
# environment variables (FTLCONF_*), which also locks them in the web UI.
# The lab's names are generated from secrets/network.sops.yaml. The web
# password is pushed later, into /etc/homelab/pihole.env; pihole.service
# waits for it.

locals {
  pihole_image = "pihole/pihole:2026.09.0"

  # One A record per host in the network file, and ingress for k3s.
  # Traefik answers on every k3s node; the server will do.
  dns_a = merge(
    { for name, h in local.net.hosts : name => h.address },
    { ingress = local.net.hosts["k3s-server"].address },
  )

  # Apps are names for a machine that serves them. No wildcard: it would
  # also answer for _acme-challenge.lab.<domain>.
  dns_cname = {
    vault   = "vaultwarden"
    grafana = "ingress"
    forgejo = "ingress"
    ci      = "ingress"
  }

  pihole_compose = {
    services = {
      pihole = {
        image          = local.pihole_image
        container_name = "pihole"
        # The host's network: Pi-hole sees each client's real address.
        network_mode = "host"
        restart      = "unless-stopped"
        environment = {
          TZ                    = "UTC"
          FTLCONF_dns_upstreams = "1.1.1.1;1.0.0.1"
          # Answer every interface: queries also come through Tailscale
          # (step 7). Nothing outside the LAN reaches this VM.
          FTLCONF_dns_listeningMode = "ALL"
          FTLCONF_dns_hosts = join(";", [
            for name, addr in local.dns_a : "${addr} ${name}.${local.domain}"
          ])
          FTLCONF_dns_cnameRecords = join(";", [
            for name, target in local.dns_cname : "${name}.${local.domain},${target}.${local.domain}"
          ])
        }
        env_file = ["/etc/homelab/pihole.env"]
        volumes  = ["/opt/pihole/etc-pihole:/etc/pihole"]
      }
    }
  }

  pihole_cloud_init = {
    packages = ["docker.io", "docker-compose"]
    write_files = [
      {
        path    = "/opt/pihole/compose.yaml"
        content = yamlencode(local.pihole_compose)
      },
      {
        # systemd-resolved's stub holds port 53 on the loopback.
        path    = "/etc/systemd/resolved.conf.d/no-stub.conf"
        content = "[Resolve]\nDNSStubListener=no\n"
      },
      {
        path    = "/etc/systemd/system/pihole.service"
        content = <<-EOT
          [Unit]
          Description=Pi-hole, with docker compose
          Requires=docker.service
          After=docker.service network-online.target
          # Starts once scripts/push-secrets.sh has pushed the web password.
          ConditionPathExists=/etc/homelab/pihole.env

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          WorkingDirectory=/opt/pihole
          ExecStart=/usr/bin/docker compose up -d --remove-orphans
          ExecStop=/usr/bin/docker compose down

          [Install]
          WantedBy=multi-user.target
        EOT
      },
    ]
    runcmd = [
      "ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf",
      "systemctl restart systemd-resolved",
      "systemctl daemon-reload",
      "systemctl enable docker pihole.service",
    ]
  }
}
