---
title: "Rebuild step 10b: Forgejo and Woodpecker"
subtitle: The lab's own Git forge and CI on k3s, behind the wildcard certificate, with Forgejo dumped to R2 every night
author: "Raghav B. Venkataramaiyer"
date: 2026-10-16
lang: en
tags: [rebuild, k3s, helmfile, forgejo, woodpecker, backups, restic, tutorial]
abstract: |
  The two apps the lab exists for come back on k3s: Forgejo, a Git
  forge, and Woodpecker, CI that logs in through it. Both are releases in
  the same helmfile as the platform. Forgejo keeps its data in SQLite on a
  node's disk, and a nightly job dumps it to R2 with restic. Woodpecker
  waits until there's an OAuth app for it in Forgejo, which is the one
  thing done by hand.
---

## The short way

```sh
make -C helmfile apply                     # Forgejo, and its backup job
```

Then, by hand: log in to Forgejo, create an OAuth app for Woodpecker, and
store it (sections 2 and 3). Then:

```sh
make -C helmfile apply                     # now Woodpecker too
```

## Why this is needed

This repository is meant to live on the lab's own forge, and be built by
its own CI (step 11). In the test run, both were installed by hand with
`helm install`, the OAuth secret typed into `--from-literal`, and
Forgejo's data wasn't backed up at all.

## What you need to know first

**Step 10a comes first**
: Both apps get HTTPS from 10a's wildcard certificate, and Woodpecker
  reaches `forgejo.lab.<domain>` through 10a's CoreDNS forward.

**Forgejo**
: Chart 17.3.0 (Forgejo 15.0.10, rootless), from
  [`values/forgejo.yaml.gotmpl`](../../../helmfile/values/forgejo.yaml.gotmpl):
  SQLite on a 10 GiB volume, the web UI at `forgejo.lab.<domain>`, SSH on
  port 2222, sign-ups off. The admin is `forgejo-admin`, with its password
  in `secrets/forgejo.sops.yaml`, generated straight into SOPS. Webhooks
  may go to `ci.lab.<domain>`; Forgejo refuses other private addresses.

**Forgejo's backup**
: The `forgejo-backup` release is a CronJob. At 02:45, `forgejo dump`
  writes one zip of the repositories, the database and the config, and
  restic sends it to `homelab-backups/forgejo` in R2, with the same
  password and key as Vaultwarden's backup. It keeps 7 daily, 4 weekly and
  3 monthly. The volume is on one node's disk, so the job runs on that
  node.

**Woodpecker waits for its OAuth app**
: Chart 3.7.5 (Woodpecker 3.19.0), from
  [`values/woodpecker.yaml.gotmpl`](../../../helmfile/values/woodpecker.yaml.gotmpl).
  It logs users in through Forgejo, with an OAuth app that can only be
  made once Forgejo runs. Until `secrets/woodpecker.sops.yaml` exists, the
  helmfile leaves Woodpecker out. Pipelines run as pods in the
  `woodpecker` namespace; the chart makes the agent's secret itself.

**Woodpecker isn't backed up**
: Its database holds pipeline history and settings for repositories,
  which are cheap to redo. Pipelines themselves live in the repositories.

## 1. Forgejo

```sh
make -C helmfile diff
make -C helmfile apply
```

The diff adds `forgejo` and `forgejo-backup`, and leaves Woodpecker out.
When it's done, `https://forgejo.lab.<domain>` shows Forgejo, with no
certificate warning. Log in as `forgejo-admin`, with the password copied,
not shown:

```sh
sops decrypt --extract '["gitea"]["admin"]["password"]' secrets/forgejo.sops.yaml | wl-copy -n -o
```

Sign-ups are off: to work as yourself rather than as the admin, create
your account under **Site administration → User accounts → Create user
account**. Add your SSH key under **Settings → SSH / GPG keys**.

## 2. An OAuth app for Woodpecker

As `forgejo-admin`, **Settings → Applications → Create a new OAuth2
application**:

| Field | Value |
|-------|-------|
| Application name | `Woodpecker` |
| Redirect URIs | `https://ci.lab.<domain>/authorize` |
| Confidential client | On |

Forgejo shows a *Client ID* and a *Client secret*; the secret only once.

## 3. Store it, and install Woodpecker

```sh
sops edit secrets/woodpecker.sops.yaml
```

```yaml
WOODPECKER_FORGEJO_CLIENT: <client-id>
WOODPECKER_FORGEJO_SECRET: <client-secret>
```

```sh
git add secrets/woodpecker.sops.yaml && git commit -m "Woodpecker's OAuth app in Forgejo"
make -C helmfile apply
```

The diff now adds `woodpecker-forgejo` (the Secret) and `woodpecker`.
Open `https://ci.lab.<domain>`, **Login**, and authorize Woodpecker in
Forgejo. `forgejo-admin` is Woodpecker's admin; to make your own account
one too, add it to `WOODPECKER_ADMIN` in the values.

## 4. Check it

**SSH.** Create an empty repository `test` in Forgejo, then:

```sh
git clone ssh://git@forgejo.lab.<domain>:2222/<user>/test.git
```

**A first backup.** Don't wait for 02:45:

```sh
kubectl -n forgejo create job --from=cronjob/forgejo-backup forgejo-backup-first
kubectl -n forgejo logs -f job/forgejo-backup-first -c restic
```

The log ends with restic's "snapshot … saved". Then
`kubectl -n forgejo delete job forgejo-backup-first`.

**CI.** In Woodpecker, **Add repository**, pick `test`, and push a
`.woodpecker.yaml`:

```yaml
steps:
  - name: hello
    image: alpine:3.22
    commands:
      - echo hello from the lab
```

The pipeline runs, and its step's log says hello.

## Restoring Forgejo

A restore takes the latest dump from R2, and puts it back on Forgejo's
volume: `restic restore latest --tag forgejo`, unzip, then copy the
repositories and `forgejo.db` into place while Forgejo is stopped. The
whole procedure is tested in step 12, with the rest of the cluster.

## What can go wrong

**Woodpecker isn't installed**
: `secrets/woodpecker.sops.yaml` doesn't exist yet: section 3.
  `helmfile list` shows it as `INSTALLED: false` until then.

**`woodpecker-forgejo`: "WOODPECKER_FORGEJO_CLIENT is missing"**
: The SOPS file is there, but a key is misnamed or empty.

**Woodpecker login: "redirect_uri mismatch"**
: The OAuth app's redirect URI isn't exactly
  `https://ci.lab.<domain>/authorize`.

**Pushes don't trigger pipelines; Forgejo's webhook log says "not allowed"**
: Forgejo refuses webhooks to private addresses not in
  `ALLOWED_HOST_LIST`; it must be `ci.lab.<domain>`.

**Woodpecker can't reach Forgejo: "no such host"**
: CoreDNS doesn't forward `lab.<domain>` to Pi-hole: check step 10a.

**`git clone` over SSH hangs**
: Port 2222 isn't open on the node `forgejo.lab.<domain>` points at.
  `kubectl -n forgejo get svc forgejo-ssh` should show an external
  address.

**The backup job fails in `dump`**
: `kubectl -n forgejo logs job/<name> -c dump`. Forgejo's own logs say
  more: `kubectl -n forgejo logs deploy/forgejo`.

## Checklist

- [ ] `https://forgejo.lab.<domain>`; admin login works
- [ ] Your own account and SSH key; `git clone` over port 2222
- [ ] OAuth app made; `secrets/woodpecker.sops.yaml` committed
- [ ] `https://ci.lab.<domain>`; login through Forgejo
- [ ] A pipeline runs
- [ ] A first Forgejo backup in R2

## See also

- [Rebuild step 10a: the platform on k3s](k3s-platform.md)
- [Rebuild step 8: Vaultwarden](vaultwarden.md), for the other restic
  backup
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<user>`
: Your Forgejo username.

`<client-id>`, `<client-secret>`
: The OAuth app's credentials from section 2. Pasted into the `sops edit`
  editor only.
