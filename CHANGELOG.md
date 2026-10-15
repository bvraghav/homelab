# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/). Each version is a git tag
with a `v` prefix (e.g. `v0.0.1`), created by `git flow release finish`;
without the `v`, it must match the `VERSION` file. Each version has a short title and a
one-line subtitle, which `RELEASE_NOTES.md` uses too.

For a readable summary of each release, see
[`RELEASE_NOTES.md`](RELEASE_NOTES.md).

## [Unreleased]

### Added

- `.gitignore`: `private/`, for local-only notes such as the network
  address plan.
- Tutorial *Certificates and DNS for the homelab, from a blank box*: lab
  names in Pi-hole, a Tailscale subnet router with split DNS, Caddy and
  cert-manager with a Let's Encrypt wildcard through DNS-01, in build
  order; the DNS move and Proxmox's own certificate are in the step posts
  below.
- The rebuild, step by step: posts for steps 1 to 4, *Tools on the
  laptop*, *Secrets with SOPS and age*, *Moving DNS to Cloudflare* and
  *Installing Proxmox VE*, listed in order in the blog index.
- `MANIFEST.md`: a *Tools* table with the laptop's tool versions.
- Scripts for rebuild steps 1 to 4, each with its page, and used by the
  step posts: `laptop-tools.sh` (check and install the tools, print their
  versions), `sops-setup.sh` (age keys and `.sops.yaml`, with a decrypt
  test per key), `dns01-test.sh` (a staging dry run of the wildcard
  through DNS-01) and `proxmox-tofu-token.sh` (OpenTofu's Proxmox user,
  role and token, piped straight into SOPS).

### Changed

- `todo.md`: network setup is the first task section, split into
  decisions and setup. Decided: a `lab.<domain>` subdomain, a Let's
  Encrypt wildcard through DNS-01, Tailscale for remote access (no DDNS,
  no port forwards), and one LAN with DHCP on the second router in AP
  mode. New tasks for the DNS provider, its API token, the Tailscale
  subnet router and split DNS, Caddy's DNS plugin and cert-manager.
  Also decided: OpenTofu builds the VMs, cloud-init configures them up to
  a running k3s, helmfile installs what runs in it, and Vaultwarden stays
  on its own VM. New tasks: how secrets reach the VMs, Vaultwarden's
  separate data disk, a k3s join token generated up front in SOPS, and a
  pinned k3s version; importing the test-run VMs is dropped.

## [0.1.0] - 2026-10-15 - Release Train

*The release workflow, written up, and fixing notes after the fact for free.*

### Added

- Blog post *Releases from tags*: the release cycle with git flow and the
  `release` workflow, fixing a published release's notes without touching
  its tag, and what tripped us up.

### Changed

- `site/site.lua`: links from any docs page that leave `docs/` are mapped to
  their published page or to the repository, so posts can link to
  `scripts/` the way that works on GitHub.
- `todo.md`: releases 0.0.2 to 0.0.4 and the release workflow ticked off;
  two more lessons.

## [0.0.4] - 2026-10-15 - Paper Trail

*The changelog, release notes and licence, published with the docs.*

### Added

- The changelog, release notes and licence are published with the docs,
  through symlinks under `docs/`, and linked from the landing page under
  *Project*.
- The version in every page's footer links to the release notes.

### Changed

- `release` workflow: a manual run reads `RELEASE_NOTES.md` from the branch
  it's started on, so a release's notes can be fixed without moving its tag.

### Fixed

- 0.0.3 release notes: "come from this file" read oddly on GitHub; they now
  name `RELEASE_NOTES.md`.

## [0.0.3] - 2026-10-15 - Autopilot

*GitHub releases are created automatically from version tags.*

### Added

- `.github/workflows/release.yml`: pushing a version tag creates the GitHub
  release, or updates it, with its title and description from
  `RELEASE_NOTES.md` and a "Full Changelog" link. Can also be run by hand
  for an existing tag.
- `scripts/release-notes.sh` and its page: print a version's release title
  or description, to preview a release locally.

## [0.0.2] - 2026-10-15 - Clean Slate

*Scrub secrets from shell history, and publish the scripts with the docs.*

### Added

- `scripts/scrub-history.sh`: list shell history entries that look like
  secrets, values masked; `--apply` removes whole entries after a private
  backup.
- Tutorial `docs/blog/tutorials/scrub-history.md`, linked from the blog index
  and the secrets post.
- `scripts/MANIFEST.md` (with `scripts/README.md` linking to it): inventory
  of scripts and conventions for new ones.
- `scripts/scrub-history.md`: the script's page, and the template for every
  script's page.
- Scripts published on the docs site through the `docs/scripts` symlink.
- `site/site.lua`, replacing `site/footer.lua`: also rewrites links in
  symlinked folders, so they work both on GitHub and on the site.

### Changed

- `todo.md`: mirroring the repo to Forgejo moved after the Forgejo rebuild;
  secret rotation dropped in favour of destroying the test-run VMs.
- Tags use a `v` prefix (`gitflow.prefix.versiontag`), matching `v0.0.1`.

### Fixed

- Changelog links pointed at tag `0.0.1`; the tag is `v0.0.1`.

## [0.0.1] - 2026-10-15 - Groundwork

*Repository skeleton, test-run write-ups and a published docs site.*

### Added

- `README.md`, MIT `LICENCE.md`, `MANIFEST.md` (homelab inventory),
  `todo.md` (rebuild plan and test-run lessons), `VERSION`, `tofu/`.
- `.gitignore` for OpenTofu state, plans and variable files, keys and
  certificates, kubeconfigs, decrypted SOPS files, editor files and docs build
  output; `.terraform.lock.hcl` stays tracked.
- Blog under `docs/blog/`: index and sitemap (`MANIFEST.md`, `README.md`
  symlink), `misc/motivation.md`, `tools/helm.md`, `tutorials/helm.md`,
  `tools/helmfile.md`, `tools/tofu-for-homelab.md`,
  `tools/tofu-for-cloud-in-general.md`, `tools/tofu-use-cases.md`,
  `tools/secrets.md`.
- Docs site from `docs/` with md-preview: `docs/README.md` landing page;
  `Makefile` targets `site`, `fetch`, `check`, `serve`, `version`, `clean`;
  `make check` for links to `.md` files.
- `site/footer.lua`: page footer with site version, source and commit.
- `.github/workflows/site.yml`: build on pushes to `develop` and `master`;
  build and deploy to GitHub Pages on version tags (`1.2.3`, `v1.2.3`);
  tag must match `VERSION`; pins pandoc 3.11 and md-preview 0.2.4;
  self-hosted KaTeX and mermaid; `sitemap.xml` from git history.
- `CHANGELOG.md` and `RELEASE_NOTES.md`.

[Unreleased]: https://github.com/bvraghav/homelab/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bvraghav/homelab/compare/v0.0.4...v0.1.0
[0.0.4]: https://github.com/bvraghav/homelab/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/bvraghav/homelab/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/bvraghav/homelab/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/bvraghav/homelab/releases/tag/v0.0.1
