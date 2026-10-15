#!/usr/bin/env bash
# push-secrets.sh: push a VM's secrets from SOPS to the VM, over SSH. Each
# secret file becomes /etc/homelab/<name>.env on the VM, readable by root
# only. Then each <name>.service, and the VM's own <vm>.service, is
# restarted to read them, if the VM has it. Without --apply, lists what it
# would push: file and key names, never values. Values never reach a
# command line, the screen or the laptop's disk.
#
# Usage:
#   push-secrets.sh VM            what would be pushed
#   push-secrets.sh VM --apply    push, then restart the services
#
#   VM        a VM's name, e.g. pihole: an entry in PUSH below, and under
#             hosts in secrets/network.sops.yaml
#   --apply   push the files, then restart each enabled <name>.service
#             and <vm>.service
#
# Logs in as $VM_USER (default: debian), with sudo. Run it from anywhere
# inside the repository.
# Docs: scripts/push-secrets.md

set -euo pipefail

# Which secret files go to which VM: secrets/<name>.sops.yaml for each name.
declare -A PUSH=(
  [pihole]="pihole tailscale"
  [vaultwarden]="cloudflare restic"
)

user=${VM_USER:-debian}
vm=''
apply=0

die() { echo "push-secrets: $*" >&2; exit 1; }

usage() { sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"; exit "${1:-0}"; }

while (($#)); do
  case $1 in
    --apply)   apply=1; shift ;;
    -h|--help) usage 0 ;;
    -*)        echo "push-secrets: unknown option: $1" >&2; usage 1 >&2 ;;
    *)         [[ -z $vm ]] || die "only one VM, please"; vm=$1; shift ;;
  esac
done

[[ -n $vm ]] || { echo "push-secrets: VM is required" >&2; usage 1 >&2; }
[[ -v PUSH[$vm] ]] || die "nothing to push to $vm; VMs with secrets: ${!PUSH[*]}"
for c in sops ssh git; do
  command -v "$c" >/dev/null || die "$c not found; see scripts/laptop-tools.sh"
done

root=$(git rev-parse --show-toplevel) || die "not inside the repository"
cd "$root"

for name in ${PUSH[$vm]}; do
  [[ -f secrets/$name.sops.yaml ]] || die "missing: secrets/$name.sops.yaml"
done

# Key names come from the encrypted file itself: no decryption needed.
keys() { grep -oE '^[A-Za-z_][A-Za-z0-9_]*:' "$1" | grep -v '^sops:' | tr -d : | paste -sd ' '; }

for name in ${PUSH[$vm]}; do
  printf '%-30s -> %s:/etc/homelab/%s.env  (%s)\n' \
    "secrets/$name.sops.yaml" "$vm" "$name" "$(keys "secrets/$name.sops.yaml")"
done
if ((!apply)); then
  echo "Run with --apply to push."
  exit 0
fi

addr=$(sops decrypt --extract "[\"hosts\"][\"$vm\"][\"address\"]" secrets/network.sops.yaml) \
  || die "no hosts.$vm.address in secrets/network.sops.yaml"

# A new VM's host key is accepted on first contact, and checked after that.
on_vm() {
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
    "$user@$addr" "$@"
}
on_vm true || die "can't SSH to $user@$vm by key. Recreated? Its host key changed:
  ssh-keygen -R <its address>, then try again"

# A new VM may still be installing its services; they must exist first.
echo "waiting:   cloud-init on $vm"
on_vm "cloud-init status --wait >/dev/null" || die "cloud-init failed on $vm; see cloud-init status --long"

for name in ${PUSH[$vm]}; do
  # Decrypted into the pipe, written on the VM under a root-only umask,
  # then moved into place, so a service never reads half a file.
  sops decrypt --output-type dotenv "secrets/$name.sops.yaml" \
    | on_vm "sudo install -d -m 700 /etc/homelab \
        && sudo sh -c 'umask 077; cat >/etc/homelab/$name.env.tmp \
        && mv /etc/homelab/$name.env.tmp /etc/homelab/$name.env'"
  echo "pushed:    /etc/homelab/$name.env"
done

# Each file's service, then the VM's own, each once: the VM's service may
# need several files.
declare -A done_units=()
for unit in ${PUSH[$vm]} "$vm"; do
  [[ -v done_units[$unit] ]] && continue
  done_units[$unit]=1
  if on_vm "systemctl is-enabled --quiet $unit.service 2>/dev/null"; then
    echo "restarting: $unit.service"
    on_vm "sudo systemctl restart $unit.service"
  fi
done
