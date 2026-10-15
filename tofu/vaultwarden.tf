# Vaultwarden on its own VM: Docker, with Caddy in front for HTTPS. Caddy
# is built with the Cloudflare DNS plugin, and gets a wildcard certificate
# for *.lab.<domain> through DNS-01, so the app's name stays out of the
# public certificate logs.
#
# The vault lives on the VM's second disk, /srv/vaultwarden. Every day,
# restic backs it up to R2. When the VM is rebuilt, the disk is new and
# empty, and the latest backup is restored before Vaultwarden starts.
#
# Secrets, pushed later into /etc/homelab/: cloudflare.env (the DNS token,
# for Caddy) and restic.env (restic's password and R2 key).
# vaultwarden.service waits for both.

variable "vaultwarden_signups_allowed" {
  description = "Let anyone who reaches the vault create an account. On only to create the first one."
  type        = bool
  default     = false
}

locals {
  vaultwarden_image      = "vaultwarden/server:1.37.4"
  caddy_version          = "2.11.7"
  caddy_dns_cf           = "github.com/caddy-dns/cloudflare@v0.2.4"
  vaultwarden_dir        = "/srv/vaultwarden"
  vaultwarden_restic     = "s3:https://${data.sops_file.r2.data["account_id"]}.r2.cloudflarestorage.com/${var.backup_bucket}/vaultwarden"
  vaultwarden_conditions = <<-EOT
    ConditionPathExists=/etc/homelab/cloudflare.env
    ConditionPathExists=/etc/homelab/restic.env
  EOT

  vaultwarden_compose = {
    services = {
      vaultwarden = {
        image   = local.vaultwarden_image
        restart = "unless-stopped"
        environment = {
          DOMAIN          = "https://vault.${local.domain}"
          SIGNUPS_ALLOWED = tostring(var.vaultwarden_signups_allowed)
          # No ADMIN_TOKEN: the admin page stays off.
        }
        volumes = ["${local.vaultwarden_dir}/data:/data"]
      }
      caddy = {
        build   = "./caddy"
        image   = "homelab/caddy-cloudflare:${local.caddy_version}"
        restart = "unless-stopped"
        ports   = ["80:80", "443:443"]
        # api_token: the Cloudflare DNS token, from secrets/cloudflare.sops.yaml.
        env_file = ["/etc/homelab/cloudflare.env"]
        volumes = [
          "./Caddyfile:/etc/caddy/Caddyfile:ro",
          "${local.vaultwarden_dir}/caddy:/data",
        ]
      }
    }
  }

  vaultwarden_cloud_init = {
    packages = ["docker.io", "docker-compose", "restic", "sqlite3"]

    # The data disk: formatted only if it has no filesystem, and mounted.
    extra = {
      fs_setup = [{
        label      = "vaultwarden"
        filesystem = "ext4"
        device     = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1"
        partition  = "none"
        overwrite  = false
      }]
      mounts = [["LABEL=vaultwarden", local.vaultwarden_dir, "ext4", "defaults,nofail", "0", "2"]]
    }

    write_files = [
      {
        path    = "/opt/vaultwarden/compose.yaml"
        content = yamlencode(local.vaultwarden_compose)
      },
      {
        path    = "/opt/vaultwarden/caddy/Dockerfile"
        content = <<-EOT
          FROM caddy:${local.caddy_version}-builder AS builder
          RUN xcaddy build --with ${local.caddy_dns_cf}

          FROM caddy:${local.caddy_version}
          COPY --from=builder /usr/bin/caddy /usr/bin/caddy
        EOT
      },
      {
        # One wildcard certificate; each app is a host in it. resolvers:
        # check the TXT record at public DNS, not through Pi-hole.
        path    = "/opt/vaultwarden/Caddyfile"
        content = <<-EOT
          *.${local.domain} {
            tls {
              dns cloudflare {env.api_token}
              resolvers 1.1.1.1
            }

            @vault host vault.${local.domain}
            handle @vault {
              reverse_proxy vaultwarden:80
            }

            handle {
              abort
            }
          }
        EOT
      },
      {
        path        = "/usr/local/sbin/vaultwarden-backup"
        permissions = "0755"
        content     = <<-EOT
          #!/bin/sh
          # Back up the vault to R2. SQLite is copied with .backup, which is
          # safe while Vaultwarden runs; the live database is left out.
          set -eu
          dir=${local.vaultwarden_dir}
          mkdir -p "$dir/backup"
          sqlite3 "$dir/data/db.sqlite3" ".backup '$dir/backup/db.sqlite3'"
          rc=0
          restic cat config >/dev/null || rc=$?
          if [ "$rc" -eq 10 ]; then restic init; elif [ "$rc" -ne 0 ]; then exit "$rc"; fi
          restic backup --tag vaultwarden --exclude "$dir/data/db.sqlite3*" \
            --exclude "$dir/data/icon_cache" "$dir/data" "$dir/backup"
          restic forget --tag vaultwarden --keep-daily 7 --keep-weekly 4 \
            --keep-monthly 3 --prune
        EOT
      },
      {
        path        = "/usr/local/sbin/vaultwarden-restore"
        permissions = "0755"
        content     = <<-EOT
          #!/bin/sh
          # On a new, empty disk: restore the latest backup, if there is one.
          # Only a repository that doesn't exist (restic's exit code 10)
          # means "start empty"; any other error, like no network, stops
          # here, and Vaultwarden doesn't start.
          set -eu
          dir=${local.vaultwarden_dir}
          rc=0
          restic cat config >/dev/null || rc=$?
          if [ "$rc" -eq 10 ]; then
            echo "no backup repository yet; starting empty"
            exit 0
          elif [ "$rc" -ne 0 ]; then
            echo "can't read the backup repository (restic exit $rc)" >&2
            exit 1
          fi
          snapshots=$(restic snapshots --tag vaultwarden --latest 1 --json)
          if ! printf '%s' "$snapshots" | grep -q '"id"'; then
            echo "no backups yet; starting empty"
            exit 0
          fi
          restic restore latest --tag vaultwarden --target /
          mv "$dir/backup/db.sqlite3" "$dir/data/db.sqlite3"
          echo "restored the latest backup"
        EOT
      },
      {
        path    = "/etc/systemd/system/vaultwarden-restore.service"
        content = <<-EOT
          [Unit]
          Description=Restore the vault from R2 onto an empty disk
          RequiresMountsFor=${local.vaultwarden_dir}
          After=network-online.target
          Wants=network-online.target
          ConditionPathExists=!${local.vaultwarden_dir}/data/db.sqlite3
          ${local.vaultwarden_conditions}
          [Service]
          Type=oneshot
          EnvironmentFile=/etc/homelab/restic.env
          Environment=RESTIC_REPOSITORY=${local.vaultwarden_restic}
          Environment=RESTIC_CACHE_DIR=/var/cache/restic
          ExecStart=/usr/local/sbin/vaultwarden-restore
        EOT
      },
      {
        path    = "/etc/systemd/system/vaultwarden.service"
        content = <<-EOT
          [Unit]
          Description=Vaultwarden and Caddy, with docker compose
          Requires=docker.service
          # If the restore fails, Vaultwarden mustn't start on an empty disk.
          Requires=vaultwarden-restore.service
          After=docker.service network-online.target vaultwarden-restore.service
          RequiresMountsFor=${local.vaultwarden_dir}
          # Starts once scripts/push-secrets.sh has pushed its secrets.
          ${local.vaultwarden_conditions}
          [Service]
          Type=oneshot
          RemainAfterExit=yes
          WorkingDirectory=/opt/vaultwarden
          ExecStart=/usr/bin/docker compose up -d --build --remove-orphans
          ExecStop=/usr/bin/docker compose down
          TimeoutStartSec=20min

          [Install]
          WantedBy=multi-user.target
        EOT
      },
      {
        path    = "/etc/systemd/system/vaultwarden-backup.service"
        content = <<-EOT
          [Unit]
          Description=Back up the vault to R2
          RequiresMountsFor=${local.vaultwarden_dir}
          ConditionPathExists=${local.vaultwarden_dir}/data/db.sqlite3

          [Service]
          Type=oneshot
          EnvironmentFile=/etc/homelab/restic.env
          Environment=RESTIC_REPOSITORY=${local.vaultwarden_restic}
          Environment=RESTIC_CACHE_DIR=/var/cache/restic
          ExecStart=/usr/local/sbin/vaultwarden-backup
        EOT
      },
      {
        path    = "/etc/systemd/system/vaultwarden-backup.timer"
        content = <<-EOT
          [Unit]
          Description=Back up the vault to R2, daily

          [Timer]
          OnCalendar=*-*-* 02:30:00
          RandomizedDelaySec=15min
          Persistent=true

          [Install]
          WantedBy=timers.target
        EOT
      },
    ]

    runcmd = [
      "install -d -m 700 ${local.vaultwarden_dir}/data ${local.vaultwarden_dir}/caddy ${local.vaultwarden_dir}/backup",
      "systemctl daemon-reload",
      "systemctl enable docker vaultwarden.service vaultwarden-backup.timer",
      "systemctl start vaultwarden-backup.timer",
    ]
  }
}
