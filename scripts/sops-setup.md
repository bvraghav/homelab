# sops-setup.sh

Check the SOPS + age setup, a laptop key, an offline backup key and a
`.sops.yaml` encrypting to both, and prove each key can decrypt on its own;
create what's missing with `--apply`.

| | |
|-|-|
| **Script** | [`sops-setup.sh`](sops-setup.sh) |
| **Changes anything?** | Only with `--apply`: creates missing keys and `.sops.yaml`, never overwrites |
| **Runs on** | Laptop |
| **Needs** | bash, sops, age, git; the backup USB stick mounted |

## Usage

```sh
scripts/sops-setup.sh --backup-key <usb-mount>/homelab-backup.agekey           # check
scripts/sops-setup.sh --backup-key <usb-mount>/homelab-backup.agekey --apply   # set up
scripts/sops-setup.sh --help
```

## Options

`--backup-key FILE`
: The offline backup key. Required, so the backup is checked every time,
  not just once.

`--apply`
: Create the laptop key, the backup key, `.sops.yaml` and the `secrets/`
  folder, each only if it doesn't exist yet.

## Before you run it

- Mount the backup USB stick.
- Run it from anywhere inside the repository.
- The laptop key is `$SOPS_AGE_KEY_FILE` if set, otherwise
  `~/.config/sops/age/keys.txt`, where sops looks by default.

## How it works

- Keys are made with `age-keygen`, straight into their files with mode
  `600`. A new folder for a key gets mode `700`; an existing one, like the
  stick's mount point, is left alone.
- `.sops.yaml` gets one rule: files named `*.sops.yaml`, `*.sops.json` or
  `*.sops.env` are encrypted to both public keys.
- An existing `.sops.yaml` must list both public keys, or the script stops.
- `secrets/` is where secret files go. `sops edit` doesn't create folders,
  so the script does, with a `.gitkeep` so the folder is committed.
- The round trip encrypts a throwaway value through that rule, then
  decrypts it twice, with `SOPS_AGE_KEY_FILE` set to each key alone. Both
  must succeed.

## Safety

- Read-only without `--apply`, and `--apply` never overwrites a key or
  `.sops.yaml`.
- It prints public keys only. Private keys go from `age-keygen` straight to
  their files.
- The round trip's encrypted value lives in a temporary file outside the
  repository, deleted on exit.

## Limitations

- It doesn't re-encrypt existing secret files after a key change; run
  `sops updatekeys` on each, as the
  [step 2 post](../docs/blog/tutorials/sops-age.md) shows.
- It doesn't make the paper copy of the backup key.

## See also

- [Rebuild step 2: secrets with SOPS and age](../docs/blog/tutorials/sops-age.md)
- [All scripts](MANIFEST.md)

## Placeholders

`<usb-mount>`
: Where the backup USB stick is mounted, e.g. `/run/media/<user>/<label>`.
