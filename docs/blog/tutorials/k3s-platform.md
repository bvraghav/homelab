---
title: "Rebuild step 10a: the platform on k3s"
subtitle: Lab names inside pods, one wildcard certificate for every Ingress, and Grafana; all from a helmfile with pinned charts
author: "Raghav B. Venkataramaiyer"
date: 2026-10-16
lang: en
tags: [rebuild, k3s, helmfile, cert-manager, dns, grafana, tutorial]
abstract: |
  Before any app runs on k3s, three things go in underneath them:
  CoreDNS forwards lab names to Pi-hole, cert-manager gets one Let's
  Encrypt wildcard that Traefik serves for every Ingress, and
  kube-prometheus-stack brings Prometheus and Grafana. All of it is one
  helmfile with pinned charts, its secrets from SOPS.
---

## The short way

```sh
make -C helmfile diff      # read it
make -C helmfile apply
```

Then check: section 4.

## Why this is needed

Apps on k3s (step 10b) need three things they shouldn't each set up
themselves: names for the lab's machines, HTTPS, and somewhere to see
how the cluster is doing. In the test run these were `kubectl apply` and
`helm install` by hand, with a token typed into `--from-literal`. Here
they're one file, [`helmfile/helmfile.yaml.gotmpl`](../../../helmfile/helmfile.yaml.gotmpl).

## What you need to know first

**What's in `helmfile/`**
: `helmfile.yaml.gotmpl` lists the releases with pinned chart versions.
  `charts/` has two small local charts, for what no public chart does:
  `coredns-lab` and `lab-certs`. `values/` has each chart's settings. The
  `Makefile` runs helmfile.

**Secrets and addresses come from SOPS**
: helmfile reads the domain and Pi-hole's address from
  `secrets/network.sops.yaml`, and helm-secrets decrypts each release's
  secrets: the Cloudflare token for `lab-certs`, Grafana's admin password
  (`secrets/grafana.sops.yaml`, generated straight into SOPS) for
  kube-prometheus-stack. Nothing is typed.

**CoreDNS forwards lab names to Pi-hole**
: k3s's CoreDNS reads extra server blocks from the `coredns-custom`
  ConfigMap. `coredns-lab` adds one: `lab.<domain>` goes to Pi-hole,
  everything else as before.

**One certificate for every app**
: cert-manager gets `*.lab.<domain>` from Let's Encrypt through DNS-01,
  with the step 3 token, and checks TXT records at public DNS, not through
  CoreDNS and Pi-hole. The certificate lives in `kube-system`, and a
  Traefik `TLSStore` makes it the default: an Ingress needs only a host
  and a `tls` entry, no certificate of its own.

**Metrics are kept a week, not backed up**
: Prometheus keeps 7 days on a node's disk. A rebuild starts them afresh.
  Alertmanager is off until there's somewhere to send alerts, and k3s's
  built-in components that the chart can't scrape are left out, so they
  don't show as down.

## 1. Before you start

- `kubectl get nodes` shows three Ready nodes (step 9).
- `grafana.lab.<domain>` resolves: it's a CNAME to `ingress` in Pi-hole
  since step 6.

## 2. See what it would do

```sh
make -C helmfile diff
```

The first time, it adds four releases: `coredns-lab`, `cert-manager`,
`lab-certs` and `kube-prometheus-stack`, with every object in them. The
values of Secrets are hidden.

## 3. Apply

```sh
make -C helmfile apply
```

Releases go in order: `lab-certs` waits for cert-manager, whose CRDs it
uses. kube-prometheus-stack takes a few minutes to pull its images.

## 4. Check it

```sh
kubectl -n kube-system get certificate lab-wildcard     # READY: True
kubectl run -it --rm dnscheck --image=busybox:1.37 --restart=Never -- \
  nslookup proxmox.lab.<domain>                          # Pi-hole's answer
```

The certificate takes a minute or two: cert-manager creates a TXT record
at Cloudflare, waits for it to show in public DNS, and Let's Encrypt
checks it.

Then open `https://grafana.lab.<domain>`: no certificate warning. Log in
as `admin`, with the password copied, not shown:

```sh
sops decrypt --extract '["grafana"]["adminPassword"]' secrets/grafana.sops.yaml | wl-copy -n -o
```

**Dashboards → Kubernetes / Compute Resources / Cluster** shows the three
nodes.

## What can go wrong

**`lab-certs`: no matches for kind "ClusterIssuer"**
: cert-manager's CRDs aren't there yet. `crds.enabled: true` in
  `values/cert-manager.yaml` installs them; apply again.

**The certificate stays `READY: False`**
: `kubectl describe certificaterequest -n kube-system`, then the
  challenge: `kubectl get challenges -A`. "Cloudflare … 403" means the
  token can't edit the zone. A challenge stuck on "propagation check"
  means cert-manager is asking the wrong DNS: check its `extraArgs`.

**Grafana shows Traefik's own certificate**
: The `TLSStore` points at a Secret that doesn't exist yet: the
  certificate isn't ready. It switches by itself once it is.

**Pods can't resolve lab names**
: `kubectl -n kube-system get configmap coredns-custom -o yaml` should
  have a `lab.server` block; CoreDNS reloads it within a minute.

## Checklist

- [ ] `make -C helmfile diff` shows no changes after the apply
- [ ] `lab-wildcard` certificate `READY: True`, from Let's Encrypt
- [ ] A pod resolves `proxmox.lab.<domain>`
- [ ] `https://grafana.lab.<domain>` with no warning; admin login works
- [ ] Grafana shows the three nodes

## See also

- [Rebuild step 9: k3s](k3s.md)
- [Certificates and DNS for the homelab](certs-and-dns.md)
- [Helmfile](../tools/helmfile.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.
