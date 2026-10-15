#!/usr/bin/env bash
# dns01-test.sh: prove that the Cloudflare token in SOPS can get a Let's
# Encrypt certificate for lab.DOMAIN and *.lab.DOMAIN through DNS-01. A
# certbot dry run against the staging server: no certificate is kept, and
# no rate limit is spent. The token never reaches a command line or disk.
#
# Usage:
#   dns01-test.sh DOMAIN
#   dns01-test.sh --secret secrets/cloudflare.sops.yaml DOMAIN
#
#   DOMAIN          your domain, e.g. example.com; the lab is lab.DOMAIN
#   --secret FILE   SOPS file with the token under api_token
#                   (default: secrets/cloudflare.sops.yaml)
#
# Changes: a TXT record at _acme-challenge.lab.DOMAIN, created and deleted
# by certbot while it runs.
# Docs: scripts/dns01-test.md

set -euo pipefail

secret=secrets/cloudflare.sops.yaml
domain=''

die() { echo "dns01-test: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --secret)  (($# >= 2)) || die "--secret needs a file"; secret=$2; shift 2 ;;
    -h|--help) usage 0 ;;
    -*)        echo "dns01-test: unknown option: $1" >&2; usage 1 >&2 ;;
    *)         [[ -z $domain ]] || die "only one DOMAIN, please"; domain=$1; shift ;;
  esac
done

[[ -n $domain ]] || { echo "dns01-test: DOMAIN is required" >&2; usage 1 >&2; }
[[ $domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || die "not a domain: $domain"
for c in sops certbot; do
  command -v "$c" >/dev/null || die "$c not found; see scripts/laptop-tools.sh"
done
certbot plugins 2>/dev/null | grep -q dns-cloudflare \
  || die "certbot's Cloudflare plugin is missing: certbot-dns-cloudflare"
[[ -f $secret ]] || die "no such file: $secret; see scripts/dns01-test.md"

# certbot reads the token from a file. Keep it, and certbot's state, in a
# private directory on tmpfs, removed however the script ends.
base=${XDG_RUNTIME_DIR:-/tmp}
work=$(mktemp -d "$base/dns01-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"

token=$(sops decrypt --extract '["api_token"]' "$secret") \
  || die "can't read api_token from $secret"
(umask 077; printf 'dns_cloudflare_api_token = %s\n' "$token" >"$work/cloudflare.ini")
unset token

echo "Asking Let's Encrypt staging for lab.$domain and *.lab.$domain (dry run)"
certbot certonly --dry-run --non-interactive --agree-tos \
  --register-unsafely-without-email \
  --dns-cloudflare --dns-cloudflare-credentials "$work/cloudflare.ini" \
  -d "lab.$domain" -d "*.lab.$domain" \
  --config-dir "$work" --work-dir "$work" --logs-dir "$work"

echo "DNS-01 works: the token can issue certificates for *.lab.$domain"
