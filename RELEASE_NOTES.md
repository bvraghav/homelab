# Release notes

The full list of changes is in [`CHANGELOG.md`](CHANGELOG.md). Each release
has a short title and a one-line subtitle, the same in both files.

## 0.0.4: Paper Trail (2026-10-15)

*The changelog, release notes and licence, published with the docs.*

The docs site now carries the project's own records alongside the blog and
the scripts, so a reader can see what changed, and under what terms, without
leaving it.

### Highlights

- **What's new, Changelog and Licence** pages on the docs site, linked from
  the landing page under *Project*. Each is the repository's own file,
  symlinked into `docs/`, so there's one copy of each.
- **The version in every page's footer** links to the release notes.
- **Release notes can be corrected after a release.** A manual run of the
  `release` workflow reads the notes from the branch it's started on, so a
  published release can be updated without moving its tag. The 0.0.3 notes
  were reworded this way.

## 0.0.3: Autopilot (2026-10-15)

*GitHub releases are created automatically from version tags.*

Until now, each GitHub release was written by hand after pushing a tag.
From this release on, pushing a version tag is enough: the release's title
and notes come from `RELEASE_NOTES.md` in the repository.

### Highlights

- **Releases from tags.** A new `release` workflow runs on every `vX.Y.Z`
  tag. It checks the tag against `VERSION` and the changelog, then creates
  the GitHub release, or updates it if one exists. It can also be run by
  hand for an existing tag.
- **Notes from `RELEASE_NOTES.md`.** The title is `v` plus the version's
  heading here, without the date; the description is the section's text,
  followed by a *Full Changelog* link from the previous version tag.
- **Preview before tagging.** `scripts/release-notes.sh --body --repo <url>
  X.Y.Z` prints exactly what the release will say.

### Release cycle from now on

```sh
git flow release start X.Y.Z
# bump VERSION; add X.Y.Z sections to CHANGELOG.md and RELEASE_NOTES.md
git flow release finish -m "X.Y.Z: Title" X.Y.Z
git push upstream master develop vX.Y.Z
```

Use the bare version with git flow (`X.Y.Z`); it adds the `v` to the tag.

## 0.0.2: Clean Slate (2026-10-15)

*Scrub secrets from shell history, and publish the scripts with the docs.*

Building the homelab by hand left secrets in shell history: an admin
password, an OAuth secret, a cluster join token. This release cleans them up
and starts a home for helper scripts. The test-run cluster itself will be
destroyed and rebuilt from scratch, so no secret from it carries over.

### Highlights

- **`scripts/scrub-history.sh`.** Lists shell history entries that look like
  secrets, with values masked, and removes them with `--apply`, whole
  multi-line entries included, after a private backup. It refuses to run
  while other shells could write the old history back.
- **A tutorial** on scrubbing shell history by hand: finding secrets without
  printing them, cleaning other copies, and keeping secrets out of history
  with a zsh hook.
- **Scripts on the docs site.** Each script has its own page, following one
  template, and `scripts/MANIFEST.md` lists them all. Links on those pages
  work both on GitHub and on the site.

### Upgrade notes

- Tags now use a `v` prefix, as `v0.0.1` already did. For a clone made
  before this release, run `git config gitflow.prefix.versiontag v` so
  `git flow release finish` creates `v`-prefixed tags.

## 0.0.1: Groundwork (2026-10-15)

*Repository skeleton, test-run write-ups and a published docs site.*

The first release. The homelab was built once by hand, as a test run:
Vaultwarden on Proxmox, a three-node k3s cluster with Prometheus, Grafana,
Forgejo and Woodpecker CI, and a Pi-hole for local DNS. Everything worked,
but only after a string of small, avoidable mistakes. This release starts
the repository that will rebuild all of it from code.

### Highlights

- **A home for the rebuild.** A repository skeleton with an inventory of the
  lab (`MANIFEST.md`), a rebuild plan with the lessons from the test run
  (`todo.md`), and a place for the OpenTofu code (`tofu/`).
- **Eight write-ups from the test run** in `docs/blog/`: why declared
  infrastructure beats copy-pasted snippets and secrets, Helm and pinning
  chart versions, helmfile, where OpenTofu fits for a homelab and for the
  cloud, what it should and shouldn't describe, and options for a homelab
  secret store. Sensitive values are masked, and every mask is explained.
- **A published docs site.** `docs/` is built with md-preview and deployed to
  GitHub Pages whenever a version tag is pushed. Every page's footer shows
  the version it was built from.

### Before the first deploy

The deploy for this tag needs two one-time settings in the GitHub repository:

1. **Settings → Pages → Build and deployment → Source:** GitHub Actions.
2. **Settings → Environments → `github-pages` → Deployment branches and
   tags:** add a tag rule `*.*.*`. By default only the default branch may
   deploy, so without this rule the deploy job is rejected.

If the deploy fails, set these and re-run the workflow for the tag.

### Known limitations

- No infrastructure code yet; `tofu/` is empty. The OpenTofu work is the
  next milestone in `todo.md`.
- The homelab itself is still the hand-built test run, so the values in
  `MANIFEST.md` are marked as expected to change.
