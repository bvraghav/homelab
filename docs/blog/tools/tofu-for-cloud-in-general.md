---
title: OpenTofu for cloud in general
subtitle: Does OpenTofu work for AWS too? Yes, and here's how it relates to Terraform
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [opentofu, terraform, aws, cloud]
---

Learning OpenTofu for a Proxmox homelab raises a practical question: does the
skill carry over to AWS and other clouds? It does.

## What OpenTofu is

OpenTofu is a fork of Terraform, created in 2023 when HashiCorp moved
Terraform to a more restrictive licence. It's now an open-source project
under the Linux Foundation.

## What stays the same

**Providers**
: The AWS provider (`hashicorp/aws`) is available through OpenTofu's
  registry, as are Azure, GCP, Cloudflare, Proxmox and the rest.

**Language**
: `.tf` files in HCL. Most Terraform code and tutorials work unchanged; you
  type `tofu` instead of `terraform`.

**Workflow**
: `tofu init`, `tofu plan`, `tofu apply`.

**State backends**
: Including S3 for storing state on AWS.

## What differs

**Additions**
: OpenTofu has a few features of its own, notably **state encryption**.
  State files can contain secrets, so this matters for a homelab and for a
  cloud account alike.

**Divergence**
: The projects have been drifting apart since the fork. Each has gained
  features the other lacks, so very new Terraform-only syntax may not work
  in OpenTofu, and vice versa.

**Hosted service**
: HCP Terraform (formerly Terraform Cloud) is Terraform-only. OpenTofu works
  with other CI setups, for example Woodpecker in this homelab.

## A tiny example

The same shape of code describes a homelab VM or a cloud resource. Only the
provider changes:

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

provider "aws" {
  region = "<aws-region>"
}

resource "aws_s3_bucket" "backups" {
  bucket = "<bucket-name>"
}
```

```bash
tofu init && tofu plan && tofu apply
```

## Recommendation

For a homelab and personal AWS use, OpenTofu is a good default. Language,
providers and workflow are the same, so the knowledge transfers directly. If
a job or team uses Terraform, the switch is mostly typing `terraform`
instead of `tofu`.

For how this applies to the homelab specifically, see [TF for the homelab,
in spirit](tofu-for-homelab.md).

## Placeholders

`<aws-region>`
: An AWS region code, e.g. `eu-central-1` or `ap-south-1`. The code only,
  not the display name ("Europe (Frankfurt)").

`<bucket-name>`
: A globally unique S3 bucket name, e.g. `example-homelab-backups-7f3a`:
  3–63 characters, lowercase letters, digits, `-` and `.`, starting and
  ending with a letter or digit. It must be unique across all AWS accounts,
  not just yours.
