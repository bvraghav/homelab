# laptop-tools.sh

Check that the laptop has every tool the rebuild needs, print their
versions for the manifest, and install what's missing with `--apply`.

| | |
|-|-|
| **Script** | [`laptop-tools.sh`](laptop-tools.sh) |
| **Changes anything?** | Only with `--apply`: installs packages, enables `tailscaled`, installs Helm plugins |
| **Runs on** | Laptop (Arch Linux) |
| **Needs** | bash, pacman; sudo for `--apply` |

## Usage

```sh
scripts/laptop-tools.sh            # check, and print the version table
scripts/laptop-tools.sh --apply    # install what's missing, then check
scripts/laptop-tools.sh --help
```

## Options

`--apply`
: Install the missing packages with `sudo pacman -S --needed`, enable and
  start `tailscaled`, and run `helmfile init` for helmfile's Helm plugins.

## Before you run it

- Arch Linux, with the official repositories enabled.

## How it works

- Each tool is a command and the package that provides it. A tool counts
  as present when its command is on `PATH`; `certbot-dns-cloudflare` has no
  command, so it's checked with `pacman -Q`.
- Versions come from `pacman -Q`, without the package release (`1.8.0-1`
  gives `1.8.0`), printed as Markdown rows for the *Tools* table in
  [`MANIFEST.md`](../MANIFEST.md).
- It exits non-zero while anything is missing.

## Safety

- Read-only without `--apply`.
- `--apply` only installs; it never removes or downgrades a package.

## Limitations

- Arch only. On another distribution, install the packages in the
  [step 1 post](../docs/blog/tutorials/laptop-tools.md)'s table by hand.
- It doesn't log in to Tailscale; `sudo tailscale up --accept-routes` does,
  when the lab's subnet router exists.

## See also

- [Rebuild step 1: tools on the laptop](../docs/blog/tutorials/laptop-tools.md)
- [All scripts](MANIFEST.md)
