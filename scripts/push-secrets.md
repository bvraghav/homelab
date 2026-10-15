# push-secrets.sh

Push a VM's secrets from SOPS to the VM over SSH, as root-only files, and
restart the services that read them.

| | |
|-|-|
| **Script** | [`push-secrets.sh`](push-secrets.sh) |
| **Changes anything?** | Only with `--apply`: files in `/etc/homelab/` on the VM, and restarts its services |
| **Runs on** | Laptop, against a lab VM |
| **Needs** | bash, ssh, sops, git; SSH to `debian@<vm>` by key, with sudo |

## Usage

```sh
scripts/push-secrets.sh pihole            # what would be pushed
scripts/push-secrets.sh pihole --apply    # push, then restart the services
scripts/push-secrets.sh --help
```

## Options

`VM`
: The VM's name: an entry in the script's `PUSH` table, and under `hosts`
  in `secrets/network.sops.yaml`, where its address comes from.

`--apply`
: Push each of the VM's secret files, and restart the matching service.

`VM_USER` (environment)
: The user to log in as. Default: `debian`, the user cloud-init creates.

## Before you run it

- The VM exists and takes your SSH key: [step 5](../docs/blog/tutorials/opentofu-vms.md).
- SOPS is set up: [`sops-setup.sh`](sops-setup.md).

## How it works

- `PUSH` maps each VM to its secret files: `pihole` gets
  `secrets/pihole.sops.yaml`. A service's step adds its line.
- Without `--apply`, it prints each file, where it would go, and its key
  names, read from the encrypted file without decrypting it.
- With `--apply`, it waits for cloud-init to finish on the VM, so the
  services exist. Then, for each file:
  1. `sops decrypt --output-type dotenv` writes `KEY=value` lines into a
     pipe to `ssh`;
  2. on the VM, `sudo` writes them under a root-only umask to
     `/etc/homelab/<name>.env.tmp`, then moves it into place;
  3. if `<name>.service` is enabled, it's restarted. A service that waits
     for its secret has `ConditionPathExists=/etc/homelab/<name>.env`, so
     this is also its first start.
- Services read the file as an `EnvironmentFile=` or a compose `env_file`.

## Safety

- Read-only without `--apply`.
- Values travel only through pipes: never a command-line argument, the
  terminal, or a file on the laptop.
- On the VM, `/etc/homelab/` is `0700` and each file `0600`, both owned by
  root.
- A new VM's host key is accepted on first contact
  (`StrictHostKeyChecking=accept-new`), and checked from then on.

## Limitations

- A recreated VM has a new host key, and SSH refuses it. Remove the old
  one with `ssh-keygen -R <vm-ip>`, then run again.
- It doesn't remove secrets that are no longer in `PUSH`; delete them on
  the VM by hand.
- Values must fit on one line, as dotenv needs.

## See also

- [Rebuild step 6: Pi-hole](../docs/blog/tutorials/pihole.md)
- [All scripts](MANIFEST.md)

## Placeholders

`<vm>`, `<vm-ip>`
: A VM's name, and its address from `secrets/network.sops.yaml`.
