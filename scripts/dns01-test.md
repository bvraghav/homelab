# dns01-test.sh

Prove that the Cloudflare token in SOPS can get a Let's Encrypt
certificate for `lab.<domain>` and `*.lab.<domain>`, with a dry run against
the staging server.

| | |
|-|-|
| **Script** | [`dns01-test.sh`](dns01-test.sh) |
| **Changes anything?** | Only a TXT record at `_acme-challenge.lab.<domain>`, created and deleted while it runs |
| **Runs on** | Laptop |
| **Needs** | bash, sops, certbot, certbot-dns-cloudflare; `secrets/cloudflare.sops.yaml` |

## Usage

```sh
scripts/dns01-test.sh <domain>                                   # the usual
scripts/dns01-test.sh --secret secrets/other.sops.yaml <domain>  # another token
scripts/dns01-test.sh --help
```

## Options

`DOMAIN`
: Your domain, e.g. `example.com`. The certificate asked for is
  `lab.DOMAIN` plus `*.lab.DOMAIN`.

`--secret FILE`
: The SOPS file holding the token under `api_token`. Default:
  `secrets/cloudflare.sops.yaml`.

## Before you run it

- `<domain>` is **Active** in Cloudflare.
- The token is stored with SOPS, as in step 4 of the
  [step 3 post](../docs/blog/tutorials/dns-to-cloudflare.md).
- Run it from the repository root, or pass `--secret` with a full path.

## How it works

- It decrypts the token with `sops decrypt --extract` into a variable, and
  writes certbot's credentials file into a fresh, private directory under
  `$XDG_RUNTIME_DIR`, a tmpfs.
- `certbot certonly --dry-run` asks the staging server for the
  certificate. certbot creates the TXT record through the Cloudflare API,
  waits for it to appear, lets Let's Encrypt check it, and deletes it.
- A dry run keeps no certificate and doesn't count against Let's Encrypt's
  production rate limits.

## Safety

- The token is never an argument or printed. The credentials file and
  certbot's state are deleted when the script ends, however it ends.
- The ACME account is registered without an email, and thrown away with
  the rest.

## Limitations

- It tests the token and DNS-01, not the lab's own clients (cert-manager,
  Caddy, Proxmox), which have their own setup.
- Cloudflare only.

## See also

- [Rebuild step 3: moving DNS to Cloudflare](../docs/blog/tutorials/dns-to-cloudflare.md)
- [Certificates and DNS for the homelab](../docs/blog/tutorials/certs-and-dns.md)
- [All scripts](MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.
