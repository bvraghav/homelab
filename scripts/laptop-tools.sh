#!/usr/bin/env bash
# laptop-tools.sh: check that the laptop has every tool the rebuild needs,
# and print their versions as rows for MANIFEST.md's Tools table. Installs
# what's missing only with --apply. Arch Linux (pacman).
#
# Usage:
#   laptop-tools.sh            check, and print a version table
#   laptop-tools.sh --apply    also install what's missing (sudo pacman),
#                              enable tailscaled, and run `helmfile init`
#
# Exits non-zero if anything is missing (without --apply) or still missing
# (with it).
# Docs: scripts/laptop-tools.md

set -euo pipefail

# command:package:name, in the order of MANIFEST.md's Tools table.
TOOLS=(
  tofu:opentofu:OpenTofu
  sops:sops:SOPS
  age:age:age
  helm:helm:Helm
  helmfile:helmfile:helmfile
  kubectl:kubectl:kubectl
  certbot:certbot:certbot
  :certbot-dns-cloudflare:certbot-dns-cloudflare
  tailscale:tailscale:Tailscale
  jq:jq:jq
  shellcheck:shellcheck:ShellCheck
)

apply=0

die() { echo "laptop-tools: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --apply)   apply=1; shift ;;
    -h|--help) usage 0 ;;
    *)         echo "laptop-tools: unknown option: $1" >&2; usage 1 >&2 ;;
  esac
done

command -v pacman >/dev/null || die "pacman not found; this script is for Arch Linux"

# Packages whose command (or, without one, the package) is missing.
missing() {
  local entry cmd pkg
  for entry in "${TOOLS[@]}"; do
    IFS=: read -r cmd pkg _ <<<"$entry"
    if [[ -n $cmd ]]; then
      command -v "$cmd" >/dev/null || echo "$pkg"
    else
      pacman -Q "$pkg" >/dev/null 2>&1 || echo "$pkg"
    fi
  done
}

mapfile -t todo < <(missing)

if ((apply)); then
  if ((${#todo[@]})); then
    echo "Installing: ${todo[*]}"
    sudo pacman -S --needed "${todo[@]}"
  fi
  if ! systemctl is-enabled --quiet tailscaled 2>/dev/null; then
    echo "Enabling tailscaled"
    sudo systemctl enable --now tailscaled
  fi
  echo "Installing helmfile's Helm plugins"
  helmfile init
  mapfile -t todo < <(missing)
fi

# The version table, for MANIFEST.md.
echo
echo "| Tool | Package | Version |"
echo "|------|---------|---------|"
for entry in "${TOOLS[@]}"; do
  IFS=: read -r _ pkg name <<<"$entry"
  if version=$(pacman -Q "$pkg" 2>/dev/null); then
    version=${version#* }
    version=${version%-*}   # drop the package release, e.g. -1
  else
    version='missing'
  fi
  # shellcheck disable=SC2016  # the backticks are Markdown, not a command
  printf '| %s | `%s` | %s |\n' "$name" "$pkg" "$version"
done

if ((${#todo[@]})); then
  echo
  echo "laptop-tools: missing: ${todo[*]}" >&2
  ((apply)) || echo "laptop-tools: run with --apply to install them" >&2
  exit 1
fi
