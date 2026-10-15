#!/usr/bin/env bash
# sops-setup.sh: check the SOPS + age setup: the laptop's age key, the
# offline backup key, and .sops.yaml encrypting to both; then prove that
# each key can decrypt on its own. Creates what's missing only with
# --apply. Never prints a private key.
#
# Usage:
#   sops-setup.sh --backup-key FILE            check
#   sops-setup.sh --backup-key FILE --apply    create what's missing, then check
#
#   --backup-key FILE   the offline backup key, e.g. on a mounted USB stick
#   --apply             create the laptop key, the backup key, .sops.yaml and
#                       the secrets/ folder if they don't exist; never
#                       overwrites one that does
#
# The laptop key is $SOPS_AGE_KEY_FILE, or ~/.config/sops/age/keys.txt.
# Run it from anywhere inside the repository.
# Docs: scripts/sops-setup.md

set -euo pipefail

backup=''
apply=0

die() { echo "sops-setup: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --backup-key) (($# >= 2)) || die "--backup-key needs a file"; backup=$2; shift 2 ;;
    --apply)      apply=1; shift ;;
    -h|--help)    usage 0 ;;
    *)            echo "sops-setup: unknown option: $1" >&2; usage 1 >&2 ;;
  esac
done

[[ -n $backup ]] || { echo "sops-setup: --backup-key is required" >&2; usage 1 >&2; }
for c in sops age-keygen git; do
  command -v "$c" >/dev/null || die "$c not found; see scripts/laptop-tools.sh"
done

root=$(git rev-parse --show-toplevel) || die "not inside the repository"
cd "$root"
laptop=${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}
config=.sops.yaml
problems=0

# Make an age key at $1, unless it exists. The private key goes straight to
# the file, readable only by you.
make_key() {
  local file=$1
  [[ -e $file ]] && return 0
  if ((apply)); then
    # A new folder only: an existing one, like a USB mount point, keeps its mode.
    [[ -d $(dirname "$file") ]] || install -m 700 -d "$(dirname "$file")"
    # age-keygen prints only the public key, or its error, to stderr.
    if ! (umask 077; age-keygen -o "$file") 2>&1 | sed 's/^/          /'; then
      die "couldn't create $file (see above)"
    fi
    echo "created:  $file"
  else
    echo "missing:  $file (--apply creates it)"
    problems=1
  fi
}

make_key "$laptop"
make_key "$backup"
((problems)) && exit 1

laptop_pub=$(age-keygen -y "$laptop")
backup_pub=$(age-keygen -y "$backup")
echo "laptop:   $laptop_pub"
echo "backup:   $backup_pub"

if [[ ! -e $config ]]; then
  if ((apply)); then
    cat >"$config" <<EOF
creation_rules:
  - path_regex: \.sops\.(ya?ml|json|env)$
    age: $laptop_pub,$backup_pub
EOF
    echo "created:  $config"
  else
    echo "missing:  $config (--apply creates it)"
    exit 1
  fi
fi

# Where secret files go; sops edit doesn't create folders.
if [[ ! -d secrets ]]; then
  if ((apply)); then
    mkdir secrets
    touch secrets/.gitkeep
    echo "created:  secrets/"
  else
    echo "missing:  secrets/ (--apply creates it)"
    problems=1
  fi
fi

for pub in "$laptop_pub" "$backup_pub"; do
  grep -qF "$pub" "$config" || { echo "problem:  $config doesn't list $pub"; problems=1; }
done
((problems)) && die "fix $config, then run 'sops updatekeys' on every secret file"

# Round trip: encrypt a throwaway value through .sops.yaml's rule, and
# decrypt it with each key alone. Nothing is written to the repository.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
printf 'check: ok\n' \
  | sops encrypt --filename-override secrets/check.sops.yaml /dev/stdin >"$tmp"
for key in "$laptop" "$backup"; do
  out=$(SOPS_AGE_KEY_FILE=$key sops decrypt --input-type yaml --output-type yaml "$tmp" 2>/dev/null || true)
  if [[ $out == 'check: ok' ]]; then
    echo "decrypts: $key"
  else
    echo "problem:  $key can't decrypt"
    problems=1
  fi
done

((problems)) && exit 1
echo "SOPS is ready: either key decrypts everything encrypted to $config"
