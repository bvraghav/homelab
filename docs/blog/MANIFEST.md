---
title: Homelab blog
subtitle: Index and sitemap of write-ups from building, breaking and rebuilding the homelab
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
md-preview-toc: true
tags: [homelab, index]
---

Notes that came out of the first, manual build of the homelab: a Proxmox
host running Vaultwarden, a three-node k3s cluster with Prometheus, Grafana,
Forgejo and Woodpecker CI, and a Pi-hole for local DNS. The first build was a
test run. These posts record what was learned, so the rebuild can be
declarative, repeatable and quick.

> [!TIP]
> New here? Start with [the motivation](misc/motivation.md), then follow the
> reading order below.

## Reading order

```mermaid
flowchart LR
  M[Motivation] --> H[Helm as a tool]
  H --> HT[Helm tutorial]
  H --> HF[Helmfile]
  M --> T1[TF for homelab]
  T1 --> T2[TF for cloud]
  T1 --> T3[TF use cases]
  T3 --> S[Secrets]
  S --> SH[Scrub history]
  M --> RW[Releases from tags]
  HF --> S
```

1. [Why this repo exists](misc/motivation.md)
2. [Using Helm as a tool](tools/helm.md), then [the Helm tutorial](tutorials/helm.md)
3. [Helmfile](tools/helmfile.md)
4. [TF for the homelab, in spirit](tools/tofu-for-homelab.md)
5. [OpenTofu for cloud in general](tools/tofu-for-cloud-in-general.md)
6. [TF: good and bad use cases](tools/tofu-use-cases.md)
7. [A secret store for the homelab](tools/secrets.md)
8. [How to scrub shell history to clean secrets](tutorials/scrub-history.md)
9. [Releases from tags](tools/release-workflow.md)

## All posts

### Miscellaneous

| Post | Summary | Date |
|------|---------|------|
| [Why this repo exists](misc/motivation.md) | The history of the manual test run, and why "steps to build up" as snippets and secrets loses to a declarative description | 2026-10-15 |

### Tools

| Post | Summary | Date |
|------|---------|------|
| [Using Helm as a tool](tools/helm.md) | Why chart versions must be pinned, and the shape of a pinned workflow | 2026-10-15 |
| [Helmfile](tools/helmfile.md) | What helmfile adds over a deploy script: diff before apply, one file of desired state | 2026-10-15 |
| [TF for the homelab, in spirit](tools/tofu-for-homelab.md) | How helmfile compares with Terraform, and where OpenTofu fits in a homelab | 2026-10-15 |
| [OpenTofu for cloud in general](tools/tofu-for-cloud-in-general.md) | OpenTofu versus Terraform on AWS and other clouds | 2026-10-15 |
| [TF: good and bad use cases](tools/tofu-use-cases.md) | Which parts of the homelab OpenTofu should and should not describe | 2026-10-15 |
| [A secret store for the homelab](tools/secrets.md) | An SSM SecureString equivalent: SOPS + age, OpenBao, Infisical | 2026-10-15 |
| [Releases from tags](tools/release-workflow.md) | git flow, a VERSION file and one workflow; and fixing a published release's notes without touching its tag, for free | 2026-10-15 |

### Tutorials

| Post | Summary | Date |
|------|---------|------|
| [Pinning Helm chart versions](tutorials/helm.md) | Step by step: find versions, a deploy script, upgrades and rollbacks | 2026-10-15 |
| [How to scrub shell history to clean secrets](tutorials/scrub-history.md) | Find secrets in shell history without printing them, remove whole entries, rotate, and prevent it with a zsh hook | 2026-10-15 |

## By tag

`helm`
: [Helm as a tool](tools/helm.md) · [Helm tutorial](tutorials/helm.md) · [Helmfile](tools/helmfile.md)

`opentofu`
: [Motivation](misc/motivation.md) · [TF for homelab](tools/tofu-for-homelab.md) · [TF for cloud](tools/tofu-for-cloud-in-general.md) · [TF use cases](tools/tofu-use-cases.md)

`secrets`
: [Motivation](misc/motivation.md) · [Secrets](tools/secrets.md) · [Scrub shell history](tutorials/scrub-history.md)

`releases`
: [Releases from tags](tools/release-workflow.md)

`kubernetes`
: [Helm as a tool](tools/helm.md) · [Helm tutorial](tutorials/helm.md) · [Helmfile](tools/helmfile.md) · [Secrets](tools/secrets.md)

## Building the blog

The blog is a plain folder of Markdown inside `docs/`, rendered with
[md-preview](https://bvraghav.github.io/md-preview/). From the repository
root:

```sh
md-preview docs/blog          # live preview of the blog, with a file tree
make serve                    # build all of docs/ and serve it at localhost:8000
```

GitHub Actions builds the site on every push to `develop` or `master`, and
publishes it to GitHub Pages for every version tag, with a `sitemap.xml`
dated from each post's last git commit. Every page's footer shows the
version it was built from: the tag for a release, or the `VERSION` file
plus `-dev` in between.

## Adding a post

1. Put it under `misc/`, `tools/` or `tutorials/`.
2. Give it frontmatter: `title`, `subtitle`, `author`, `date`, `tags`, and an
   `abstract` for longer posts.
3. Mask anything sensitive, and explain each mask in a *Placeholders*
   section at the end of the post.
4. Add a row to the right table above, and to the tags.
