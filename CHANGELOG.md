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

[Unreleased]: https://github.com/bvraghav/homelab/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/bvraghav/homelab/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/bvraghav/homelab/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/bvraghav/homelab/releases/tag/v0.0.1
