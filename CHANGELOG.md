# Changelog

All notable changes to this repository are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/). Each version is a git tag
without a prefix (e.g. `0.0.1`), created by `git flow release finish`; the
tag must match the `VERSION` file.

## [Unreleased]

## [0.0.1] - 2026-10-15

First release: the repository skeleton for rebuilding the homelab as code,
write-ups from the manual test run, and a published docs site.

### Added

- **Repository skeleton:** `README.md`, MIT `LICENCE.md`, `MANIFEST.md`
  (inventory of network, VMs, services, secret locations and backups),
  `todo.md` (rebuild plan, plus lessons from the test run), `VERSION`, and an
  empty `tofu/` for the OpenTofu code to come.
- **`.gitignore`** for OpenTofu state, plans and variable files, keys and
  certificates, kubeconfigs, decrypted SOPS files, editor files, and the docs
  build output. `.terraform.lock.hcl` stays tracked on purpose.
- **Blog** under `docs/blog/`, structured for md-preview's folder mode:
  - an index and sitemap (`MANIFEST.md`, with `README.md` linking to it as
    the folder's front page)
  - *Why this repo exists*: the story of the manual test run, and why
    declared infrastructure beats copy-pasted snippets and secrets
  - *Using Helm as a tool* and a tutorial on pinning chart versions
  - *Helmfile*
  - *TF for the homelab, in spirit*, *OpenTofu for cloud in general*, and
    *TF: good and bad use cases*
  - *A secret store for the homelab*
  - sensitive values masked, with a *Placeholders* section in each post
    explaining the masks
- **Docs site** built from `docs/` with md-preview:
  - `docs/README.md` as the landing page
  - `Makefile` targets `site`, `fetch`, `check`, `serve`, `version` and
    `clean`, shared by local builds and CI
  - `make check` fails on links to `.md` files that would be broken once
    published
  - `site/footer.lua`: every page's footer shows the site version (the tag
    on a release, otherwise `VERSION` plus `-dev`), with links to the page's
    source and commit
- **GitHub Actions workflow** (`.github/workflows/site.yml`), adapted from
  md-preview's:
  - builds on pushes to `develop` and `master`
  - builds and deploys to GitHub Pages on version tags (`1.2.3` or
    `v1.2.3`), failing if the tag doesn't match `VERSION`
  - pins pandoc 3.11 and md-preview 0.2.4, self-hosts KaTeX and mermaid,
    and writes `sitemap.xml` dated from git history

### Setup required for the first deploy

- Settings → Pages → Build and deployment → Source: **GitHub Actions**.
- Settings → Environments → `github-pages` → add a deployment **tag** rule
  `*.*.*` (by default only the default branch may deploy).

[Unreleased]: https://github.com/bvraghav/homelab/compare/0.0.1...HEAD
[0.0.1]: https://github.com/bvraghav/homelab/releases/tag/0.0.1
