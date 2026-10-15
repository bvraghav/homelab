---
title: Pinning Helm chart versions
subtitle: A step-by-step tutorial, from running releases to deliberate upgrades
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [helm, kubernetes, k3s, tutorial]
---

Why to pin is covered in [Using Helm as a tool](../tools/helm.md). This post
does it, using the homelab's three releases.

> [!NOTE]
> Assumes `kubectl` and `helm` work from your laptop (`kubectl get nodes`
> shows the cluster), and that your values files are in
> `~/homelab/k3s`.

## 1. Find the versions you're running

```bash
helm list -A
```

Read the **CHART** column. For example, `forgejo-17.3.0` means chart version
`17.3.0`. Ignore **APP VERSION**; that's the application inside, which
follows from the chart.

## 2. Record them in a deploy script

Create `~/homelab/k3s/deploy.sh` with the versions from step 1:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

KPS_VERSION="<kps-version>"
FORGEJO_VERSION="<forgejo-version>"
WOODPECKER_VERSION="<woodpecker-version>"

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --version "$KPS_VERSION" -n monitoring --create-namespace -f monitoring.yaml

helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo \
  --version "$FORGEJO_VERSION" -n forgejo -f forgejo.yaml

helm upgrade --install woodpecker oci://ghcr.io/woodpecker-ci/helm/woodpecker \
  --version "$WOODPECKER_VERSION" -n woodpecker -f woodpecker.yaml
```

Make it executable and run it once:

```bash
chmod +x deploy.sh
./deploy.sh
```

`upgrade --install` installs a release when it's missing and upgrades it
otherwise. That makes the script safe to run any number of times, which
plain `helm install` is not:

```
Error: INSTALLATION FAILED: release name check failed: cannot reuse a name that is still in use
```

With the versions you're already running, this run changes nothing except
adding a release revision.

## 3. Commit

```bash
git add deploy.sh monitoring.yaml forgejo.yaml woodpecker.yaml
git commit -m "Pin Helm chart versions"
```

> [!WARNING]
> Values files must not contain secrets. Keep passwords and OAuth
> credentials in Kubernetes Secrets, or in SOPS-encrypted files. See
> [A secret store for the homelab](../tools/secrets.md).

## 4. Check for new versions

```bash
helm repo update
helm search repo prometheus-community/kube-prometheus-stack
helm show chart oci://code.forgejo.org/forgejo-helm/forgejo | grep '^version'
helm show chart oci://ghcr.io/woodpecker-ci/helm/woodpecker | grep '^version'
```

OCI charts (Forgejo and Woodpecker) don't use `helm repo`, so `helm show
chart` asks the registry directly.

## 5. Upgrade one release on purpose

1. Read the chart's release notes, especially for a **major** version
   jump. Those often rename values.
2. Compare the new defaults with your values file:

   ```bash
   helm show values oci://code.forgejo.org/forgejo-helm/forgejo --version <new-version> > /tmp/new.yaml
   ```

3. Bump the variable in `deploy.sh`, run it, and watch the pods:

   ```bash
   ./deploy.sh
   kubectl -n forgejo get pods -w
   ```

4. Commit the bump.

## 6. Roll back if needed

```bash
helm -n forgejo history forgejo
helm -n forgejo rollback forgejo <revision>
```

Then set the version in `deploy.sh` back as well. Otherwise the next run
upgrades again.

## Troubleshooting

`cannot reuse a name that is still in use`
: You ran `helm install` on an existing release. Use `helm upgrade
  --install`. If `helm -n <ns> list -a` shows the release as `failed`, run
  `helm -n <ns> uninstall <release>` and deploy again.

A pod stuck in `Init:`
: Find the stuck init container with `kubectl -n <ns> describe pod`, then
  read its logs with `-c <name>`. In the Forgejo chart, the last init
  container is still named `configure-gitea`.

The upgrade changed more than expected
: Use [helmfile](../tools/helmfile.md), whose `helmfile diff` shows the
  changes before applying them.

## Placeholders

`<kps-version>`, `<forgejo-version>`, `<woodpecker-version>`
: Chart versions from the CHART column of `helm list -A`, without the chart
  name, e.g. `17.3.0`. Plain semantic versions only; ranges such as `^17`
  are possible in Helm but defeat the point of pinning.

`<new-version>`
: The chart version you're upgrading to, e.g. `17.4.0`.

`<ns>`, `<release>`, `<revision>`
: Kubernetes namespace (e.g. `forgejo`), Helm release name (e.g.
  `forgejo`), and a revision number from `helm history` (e.g. `3`).
