# proxmox-tofu-token.sh

Give OpenTofu its own Proxmox user, role and API token, from the laptop
over SSH, and store the token straight into SOPS.

| | |
|-|-|
| **Script** | [`proxmox-tofu-token.sh`](proxmox-tofu-token.sh) |
| **Changes anything?** | Only with `--apply`: on the Proxmox host, and `secrets/proxmox.sops.yaml` |
| **Runs on** | Laptop, against the Proxmox host |
| **Needs** | bash, ssh, jq, sops; SSH to `root@<proxmox-ip>` by key |

## Usage

```sh
scripts/proxmox-tofu-token.sh <proxmox-ip>           # what exists, what's missing
scripts/proxmox-tofu-token.sh --apply <proxmox-ip>   # create it, store the token
scripts/proxmox-tofu-token.sh --help
```

## Options

`HOST`
: The Proxmox host's address or name.

`--apply`
: Create the role `TofuProvision` (or update its privileges), the user
  `tofu@pve`, its permission on `/`, and the token `tofu@pve!provider`;
  write the token to the secret file.

`--secret FILE`
: Where the token goes. Default: `secrets/proxmox.sops.yaml`, under
  `api_token`, in the form `tofu@pve!provider=<secret>` that
  `PROXMOX_VE_API_TOKEN` expects.

## Before you run it

- SSH to `root@<proxmox-ip>` works by key: step 6 of the
  [Proxmox post](../docs/blog/tutorials/proxmox-install.md).
- SOPS is set up: [`sops-setup.sh`](sops-setup.md).
- Run it from the repository root, so `.sops.yaml` is found.

## How it works

- Every Proxmox command runs as `ssh root@HOST pveum …`, with
  `BatchMode`, so it fails instead of asking for a password.
- It reads `pveum`'s JSON output with `jq` to see what already exists.
- The role's privileges are the ones the `bpg/proxmox` provider needs to
  create VMs from templates. With `--apply`, an existing role gets exactly
  this list.
- The token is created with privilege separation off, so it has the
  user's permissions. `pveum`'s JSON goes through `jq` into
  `sops encrypt` on stdin, and only the encrypted file is written.

## Safety

- Read-only without `--apply`.
- The token's secret is shown by Proxmox only once, and here it's never
  shown at all: it goes from the host to `sops` through a pipe, not an
  argument, a terminal or a plain-text file.
- An existing token is never replaced, and an existing secret file is
  never overwritten; the script stops instead.

## Limitations

- If Proxmox rejects a privilege name (they change between versions),
  `pveum role add` fails; update `PRIVS` in the script from the provider's
  documentation.
- To rotate the token: remove it on the host
  (`pveum user token remove tofu@pve provider`), move the secret file
  away, and run with `--apply` again.

## See also

- [Rebuild step 4: installing Proxmox VE](../docs/blog/tutorials/proxmox-install.md)
- [All scripts](MANIFEST.md)

## Placeholders

`<proxmox-ip>`
: The Proxmox host's address, from the IP plan.
