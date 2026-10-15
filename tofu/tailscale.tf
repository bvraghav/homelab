# Tailscale's subnet router, on the Pi-hole VM: it's always on, and the
# tailnet's lookups for lab.<domain> go to Pi-hole beside it. Advertises
# the LAN, so lab addresses are reachable from anywhere on the tailnet.
# The auth key is pushed later, into /etc/homelab/tailscale.env;
# tailscale.service waits for it, then joins.

locals {
  tailscale_version = "1.104.1"

  tailscale_cloud_init = {
    packages = []
    write_files = [
      {
        # Written last (defer), after the base packages are installed: until
        # runcmd fetches its key, it would break apt-get update.
        path    = "/etc/apt/sources.list.d/tailscale.list"
        content = "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main\n"
        defer   = true
      },
      {
        # A subnet router forwards packets between the tailnet and the LAN.
        path    = "/etc/sysctl.d/99-tailscale.conf"
        content = "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n"
      },
      {
        path    = "/etc/systemd/system/tailscale.service"
        content = <<-EOT
          [Unit]
          Description=Join the tailnet as the lab's subnet router
          Requires=tailscaled.service
          After=tailscaled.service network-online.target
          # Starts once scripts/push-secrets.sh has pushed the auth key.
          ConditionPathExists=/etc/homelab/tailscale.env

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          # The key goes to tailscale as a file, not an argument, so it
          # never shows in the process list.
          ExecStartPre=/bin/sh -c 'umask 077; sed -n "s/^TS_AUTHKEY=//p" /etc/homelab/tailscale.env >/run/tailscale-authkey'
          ExecStart=/usr/bin/tailscale up --auth-key=file:/run/tailscale-authkey \
            --advertise-routes=${local.net.subnet} --advertise-tags=tag:lab \
            --hostname=lab-router --accept-dns=false
          ExecStartPost=/bin/rm -f /run/tailscale-authkey

          [Install]
          WantedBy=multi-user.target
        EOT
      },
    ]
    runcmd = [
      "curl -fsSL -o /usr/share/keyrings/tailscale-archive-keyring.gpg https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg",
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale=${local.tailscale_version}",
      "apt-mark hold tailscale",
      "sysctl --system",
      "systemctl daemon-reload",
      "systemctl enable --now tailscaled",
      "systemctl enable tailscale.service",
    ]
  }
}
