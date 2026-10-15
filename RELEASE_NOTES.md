# Release notes

The full list of changes is in [`CHANGELOG.md`](CHANGELOG.md). Each release
has a short title and a one-line subtitle, the same in both files.

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
