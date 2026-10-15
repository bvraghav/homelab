---
title: "Rebuild step 1: tools on the laptop"
subtitle: Everything the rebuild drives from the laptop, installed and checked in one go
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, tools, opentofu, sops, helm, tutorial]
abstract: |
  The rebuild runs from the laptop: OpenTofu creates the VMs, SOPS and age
  keep the secrets, Helm and helmfile install the workloads, and kubectl
  talks to the cluster. This first step installs all of them on Arch
  Linux, checks each one works, and records the versions, before the box
  is even switched on.
---

## Why this is needed

The test run installed tools as they came up, halfway through other steps.
Doing it first means every later step can assume them, and the versions
can be recorded once, next to everything else in the manifest.

## What gets installed

| Tool | Package | Used for | First needed in |
|------|---------|----------|-----------------|
| `tofu` | `opentofu` | VMs and templates on Proxmox | Step 5 |
| `sops` | `sops` | Encrypting secrets in the repository | [Step 2](sops-age.md) |
| `age`, `age-keygen` | `age` | The keys SOPS encrypts with | [Step 2](sops-age.md) |
| `helm` | `helm` | Installing charts on k3s | Step 10 |
| `helmfile` | `helmfile` | All of k3s's charts, as one file | Step 10 |
| `kubectl` | `kubectl` | Talking to k3s | Step 9 |
| `certbot` | `certbot`, `certbot-dns-cloudflare` | Testing a DNS-01 certificate | [Step 3](dns-to-cloudflare.md) |
| `tailscale` | `tailscale` | Reaching the lab from anywhere | Step 7 |
| `shellcheck` | `shellcheck` | Checking `scripts/` | Any time |

## 1. Install

All of them are in Arch's official repositories:

```sh
sudo pacman -S --needed opentofu sops age helm helmfile kubectl \
  certbot certbot-dns-cloudflare tailscale shellcheck
```

`--needed` skips what's already up to date. The OpenTofu package is
`opentofu`; its command is `tofu`.

## 2. Helm plugins for helmfile

`helmfile diff` and `helmfile apply` need the `helm-diff` plugin, and
SOPS-encrypted values need `helm-secrets`. helmfile installs what it needs:

```sh
helmfile init
helm plugin list   # should list diff and secrets
```

If `helmfile init` can't install a plugin, install it with
`helm plugin install <plugin-repo-url>` and run `helmfile init` again.

## 3. Tailscale's daemon

The client needs its daemon running. Log in now, or when the lab's subnet
router exists in step 7:

```sh
sudo systemctl enable --now tailscaled
sudo tailscale up --accept-routes
```

`--accept-routes` lets the laptop use the routes the lab advertises later.

## 4. Check, and record the versions

```sh
tofu version
sops --version
age --version
helm version --short
helmfile version
kubectl version --client
certbot --version
tailscale version
shellcheck --version
```

Every command should print a version. Record them in the *Tools* table
of [`MANIFEST.md`](../../../MANIFEST.md), so a rebuild a year from now
knows what this one used.

## Keeping the versions steady

Arch updates these with the rest of the system, which mostly doesn't
matter: what has to stay fixed is pinned elsewhere.

- OpenTofu providers are pinned in `.terraform.lock.hcl`, which is
  committed.
- Chart versions are pinned in the helmfile; see
  [Using Helm as a tool](../tools/helm.md).
- k3s's version is set when it's installed, not by the laptop.

If an update to `tofu` or `helm` itself breaks something, `downgrade` (from
the AUR) or the package cache in `/var/cache/pacman/pkg/` gets the old
version back.

## See also

- [Rebuild step 2: secrets with SOPS and age](sops-age.md)
- [A secret store for the homelab](../tools/secrets.md): why SOPS and age.
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<plugin-repo-url>`
: A Helm plugin's repository, e.g. `https://github.com/databus23/helm-diff`
  for `helm-diff`.
