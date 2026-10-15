---
title: "Rebuild step 9: k3s"
subtitle: A three-node cluster from code, a join token that never touches the VMs' disks until it's needed, and nightly etcd snapshots to R2
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, k3s, kubernetes, cloud-init, backups, tutorial]
abstract: |
  The k3s cluster comes back on three VMs: a server and two agents.
  cloud-init installs a pinned k3s with its config but doesn't start it;
  the join token, generated up front into SOPS, is pushed over SSH, and
  only then does k3s start. The server keeps its state in embedded etcd,
  encrypts Secrets inside it, and sends a snapshot to R2 every night.
---

## The short way

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"k3s-server\"] -replace=proxmox_virtual_environment_vm.vm[\"k3s-agent1\"] -replace=proxmox_virtual_environment_vm.vm[\"k3s-agent2\"]' make -C tofu plan
make -C tofu apply
git commit -m "Rebuild the k3s VMs" tofu/terraform.tfstate
ssh-keygen -R <k3s-server-ip>; ssh-keygen -R <k3s-agent1-ip>; ssh-keygen -R <k3s-agent2-ip>
scripts/push-secrets.sh k3s-server --apply      # the server first
scripts/push-secrets.sh k3s-agent1 --apply
scripts/push-secrets.sh k3s-agent2 --apply
```

Then the kubeconfig, and a check: sections 3 and 4.

## Why this is needed

Grafana, Forgejo and Woodpecker run on k3s (step 10). In the test run, the
nodes were installed by hand, joined with a token read off the server, and
two of them first came up with the same hostname. Here each node is code,
and the token comes from SOPS.

## What you need to know first

**What's on the VMs**
: [`tofu/k3s.tf`](../../../tofu/k3s.tf) adds to their cloud-init: k3s's
  config in `/etc/rancher/k3s/config.yaml`, the install script from the
  release's own tag (checked against its SHA-256), and k3s
  `v1.36.5+k3s1`, installed but not started.

**The token is generated up front**
: `secrets/k3s.sops.yaml` holds `K3S_TOKEN`, made straight into SOPS.
  `push-secrets.sh` puts it in `/etc/homelab/k3s.env` on each node, and a
  systemd drop-in keeps k3s from starting until it's there. The agents
  never read it off the server.

**Agents find the server by address**
: Not by name: the cluster mustn't depend on Pi-hole being up.

**etcd, and its snapshots in R2**
: The server runs embedded etcd (`cluster-init`), with Secrets encrypted
  inside it. At 02:30 every night it saves a snapshot to
  `homelab-backups/k3s` in R2, with the same R2 key as restic, and keeps
  the last 7. k3s's own certificates and keys in a snapshot are encrypted
  with the token, so a snapshot is useless without `secrets/k3s.sops.yaml`.
  Unlike restic's backups, the rest of a snapshot isn't encrypted before
  it leaves; it holds the cluster's objects, which come from this repo
  anyway.

**Volumes aren't in the snapshot**
: Data in persistent volumes, like Forgejo's, lives on the nodes' disks.
  Each app that has some backs it up itself (step 10).

## 1. Rebuild the three VMs

```sh
TF_CLI_ARGS_plan='-replace=proxmox_virtual_environment_vm.vm[\"k3s-server\"] -replace=proxmox_virtual_environment_vm.vm[\"k3s-agent1\"] -replace=proxmox_virtual_environment_vm.vm[\"k3s-agent2\"]' make -C tofu plan
```

The plan replaces the three k3s VMs and their snippets.

```sh
make -C tofu apply
git commit -m "Rebuild the k3s VMs" tofu/terraform.tfstate
```

## 2. Push the token, server first

Forget the old host keys, then push:

```sh
ssh-keygen -R <k3s-server-ip>
ssh-keygen -R <k3s-agent1-ip>
ssh-keygen -R <k3s-agent2-ip>
scripts/push-secrets.sh k3s-server --apply
scripts/push-secrets.sh k3s-agent1 --apply
scripts/push-secrets.sh k3s-agent2 --apply
```

The server gets the token and the R2 key, and starts `k3s.service`. Each
agent gets the token, and starts `k3s-agent.service`, which joins the
server.

## 3. The kubeconfig

Copy the server's kubeconfig to the laptop, pointing at the server's name
instead of `127.0.0.1`. It holds the cluster's admin key: it goes through
a pipe into a file only you can read.

```sh
mkdir -p ~/.kube
(umask 077; ssh debian@<k3s-server-ip> sudo cat /etc/rancher/k3s/k3s.yaml \
  | sed 's#https://127.0.0.1:6443#https://k3s-server.lab.<domain>:6443#' \
  > ~/.kube/config)
```

This replaces `~/.kube/config`; move an old one aside first. The name is
in the server's certificate (`tls-san`), so `kubectl` checks it.

## 4. Check it

```sh
kubectl get nodes -o wide
```

Three nodes, `Ready`, each with its own name, all `v1.36.5+k3s1`. Then:

```sh
kubectl -n kube-system get pods     # coredns, traefik, metrics-server: Running
ssh debian@<k3s-server-ip> 'sudo k3s etcd-snapshot save --name first' 
```

The snapshot command saves one now, rather than at 02:30, and uploads it
to R2. `sudo k3s etcd-snapshot ls` on the server lists it with an `s3`
location.

## What can go wrong

**`k3s.service` doesn't start, "condition failed"**
: The token or the R2 key wasn't pushed: section 2.

**An agent stays out of `kubectl get nodes`**
: On the agent, `sudo journalctl -u k3s-agent -n 20`. "token" errors mean
  it has a different token from the server's; push both again.
  "connection refused" means the server isn't up yet.

**`kubectl`: "x509: certificate is valid for …, not …"**
: The kubeconfig points at a name the server's certificate doesn't have.
  Use `k3s-server.lab.<domain>`, as in section 3.

**The snapshot isn't in R2**
: On the server, `sudo journalctl -u k3s | grep -i s3`. A 403 means the
  R2 key in `secrets/restic.sops.yaml` can't write to the bucket.

## Checklist

- [ ] Three k3s VMs rebuilt; state committed
- [ ] Token and R2 key pushed; server first
- [ ] `kubectl get nodes`: three, Ready, unique names, `v1.36.5+k3s1`
- [ ] Kubeconfig on the laptop, pointing at `k3s-server.lab.<domain>`
- [ ] A first etcd snapshot in R2

## See also

- [Rebuild step 8: Vaultwarden](vaultwarden.md)
- [`push-secrets.sh`](../../../scripts/push-secrets.md)
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<k3s-server-ip>`, `<k3s-agent1-ip>`, `<k3s-agent2-ip>`
: The nodes' addresses: `hosts.<name>.address` in
  `secrets/network.sops.yaml`.
