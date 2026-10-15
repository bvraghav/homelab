---
title: Homelab
subtitle: Documentation for a Proxmox homelab described as code
author: "Raghav B. Venkataramaiyer"
lang: en
md-preview-toc: false
---

A Proxmox host running Vaultwarden, a three-node k3s cluster with
Prometheus, Grafana, Forgejo and Woodpecker CI, and a Pi-hole for local DNS.
The first build was done by hand. The goal now is to rebuild all of it from
code, quickly and repeatably.

- **[Blog](blog/README.md):** write-ups from the manual test run, and the
  tools chosen for the rebuild: Helm, helmfile, OpenTofu and secrets.
