#!/usr/bin/env bash
# proxmox-tofu-token.sh: give OpenTofu its own Proxmox user, role and API
# token, over SSH from the laptop, and store the token straight into SOPS.
# Without --apply, only reports what exists and what would be created. The
# token's secret is never printed and never on a command line.
#
# Usage:
#   proxmox-tofu-token.sh HOST            report
#   proxmox-tofu-token.sh --apply HOST    create what's missing, store the token
#
#   HOST            the Proxmox host, reachable as root@HOST by SSH key
#   --apply         create the role, the user, its permission and the token;
#                   write the token to the secret file
#   --secret FILE   where the token goes (default: secrets/proxmox.sops.yaml),
#                   under api_token, as user@realm!tokenid=secret
#
# An existing token is never replaced; delete it on the host first
# (pveum user token remove tofu@pve provider) to make a new one.
# Docs: scripts/proxmox-tofu-token.md

set -euo pipefail

USER_ID='tofu@pve'
TOKEN_ID='provider'
ROLE='TofuProvision'
# What the bpg/proxmox provider needs to create VMs from templates.
PRIVS='Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate
Datastore.Audit Pool.Allocate SDN.Use Sys.Audit Sys.Console Sys.Modify
VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit
VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory
VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt'

secret=secrets/proxmox.sops.yaml
apply=0
host=''

die() { echo "proxmox-tofu-token: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --apply)   apply=1; shift ;;
    --secret)  (($# >= 2)) || die "--secret needs a file"; secret=$2; shift 2 ;;
    -h|--help) usage 0 ;;
    -*)        echo "proxmox-tofu-token: unknown option: $1" >&2; usage 1 >&2 ;;
    *)         [[ -z $host ]] || die "only one HOST, please"; host=$1; shift ;;
  esac
done

[[ -n $host ]] || { echo "proxmox-tofu-token: HOST is required" >&2; usage 1 >&2; }
for c in ssh sops jq; do
  command -v "$c" >/dev/null || die "$c not found"
done

pve() { ssh -o BatchMode=yes "root@$host" "$@"; }

pve true 2>/dev/null || die "can't SSH to root@$host by key; see the Proxmox post, step 6"
pve command -v pveum >/dev/null || die "$host doesn't look like a Proxmox host (no pveum)"

privs=$(tr '\n' ' ' <<<"$PRIVS")
has_role=$(pve pveum role list --output-format json | jq --arg r "$ROLE" 'any(.[]; .roleid == $r)')
has_user=$(pve pveum user list --output-format json | jq --arg u "$USER_ID" 'any(.[]; .userid == $u)')
has_token=false
if [[ $has_user == true ]]; then
  has_token=$(pve pveum user token list "$USER_ID" --output-format json \
    | jq --arg t "$TOKEN_ID" 'any(.[]; .tokenid == $t)')
fi

report() { printf '%-8s %s\n' "$1" "$2"; }
state() { if [[ $1 == true ]]; then report exists "$2"; else report missing "$2"; fi; }
state "$has_role" "role $ROLE"
state "$has_user" "user $USER_ID"
state "$has_token" "token $USER_ID!$TOKEN_ID"
state "$([[ -f $secret ]] && echo true)" "secret file $secret"

if ((!apply)); then
  [[ $has_token == true ]] || echo "Run with --apply to create what's missing."
  exit 0
fi

if [[ $has_role == true ]]; then
  pve pveum role modify "$ROLE" --privs "'$privs'"
  report updated "role $ROLE privileges"
else
  pve pveum role add "$ROLE" --privs "'$privs'"
  report created "role $ROLE"
fi
if [[ $has_user != true ]]; then
  pve pveum user add "$USER_ID" --comment "'OpenTofu (bpg/proxmox)'"
  report created "user $USER_ID"
fi
pve pveum acl modify / --users "$USER_ID" --roles "$ROLE"
report set "permission: $USER_ID is $ROLE on /"

if [[ $has_token == true ]]; then
  echo "Token $USER_ID!$TOKEN_ID exists and isn't replaced; $secret is unchanged."
  exit 0
fi

# The secret goes from the host's JSON straight into sops on stdin: never
# printed, never an argument, never in a plain-text file.
[[ ! -e $secret ]] || die "$secret exists; move it away first, or it would be overwritten"
mkdir -p "$(dirname "$secret")"
pve pveum user token add "$USER_ID" "$TOKEN_ID" --privsep 0 --output-format json \
  | jq -r '"api_token: \(."full-tokenid")=\(.value)"' \
  | sops encrypt --filename-override "$secret" /dev/stdin >"$secret.tmp"
mv "$secret.tmp" "$secret"
report created "token $USER_ID!$TOKEN_ID, stored in $secret"
echo "Commit $secret; OpenTofu reads it as PROXMOX_VE_API_TOKEN."
