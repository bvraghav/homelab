# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/). Each version is a git tag
without a prefix (e.g. `0.0.1`), created by `git flow release finish`; the
tag must match the `VERSION` file. Each version has a short title and a
one-line subtitle, which `RELEASE_NOTES.md` uses too.

For a readable summary of each release, see
[`RELEASE_NOTES.md`](RELEASE_NOTES.md).

## [Unreleased]

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

[Unreleased]: https://github.com/bvraghav/homelab/compare/0.0.1...HEAD
[0.0.1]: https://github.com/bvraghav/homelab/releases/tag/0.0.1
