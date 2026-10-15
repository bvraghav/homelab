---
title: "Rebuild step 3: moving DNS to Cloudflare"
subtitle: The domain's DNS at a provider with an API, a token that can only edit it, and a test certificate before any hardware
author: "Raghav B. Venkataramaiyer"
date: 2026-10-15
lang: en
tags: [rebuild, dns, certificates, networking, tutorial]
abstract: |
  The lab's certificates come from Let's Encrypt through a DNS challenge,
  which needs the domain's DNS at a provider with an API. This step moves
  `<domain>`'s DNS hosting to Cloudflare without moving the domain itself,
  creates an API token that can only edit that one zone, stores it with
  SOPS, and proves the whole chain with a staging certificate from the
  laptop.
---

## Why this is needed

[Certificates and DNS for the homelab](certs-and-dns.md) explains the
design: private `lab.<domain>` names, and a Let's Encrypt wildcard issued
through DNS-01. For DNS-01, a program has to create a TXT record in
`<domain>`'s DNS, so the DNS has to be at a provider with an API. This step
gets that in place, and tests it, before any lab hardware exists.

## What you need to know first

**Only the DNS hosting moves**
: The domain stays with its registrar; only its nameservers change. That
  takes effect in hours. A registrar transfer takes days, and locks the
  domain for 60 days afterwards.

**Your website and email depend on these records**
: Whatever `<domain>` serves today keeps working only if Cloudflare has
  the same records. Check them before switching, not after.

**DNSSEC can take the domain offline**
: If DNSSEC is on, changing nameservers without turning it off first makes
  the domain stop resolving until the old DS record expires.

## 1. Add the domain to Cloudflare

1. In Cloudflare, **Add a domain**, enter `<domain>`, and pick the Free
   plan.
2. Cloudflare imports the records it can find. **Compare them, record by
   record, with the current DNS provider**, especially:
   - the website: `<domain>` and `www`,
   - email: MX, and the SPF, DKIM and DMARC TXT records.
3. Set each imported record to **DNS only** (grey cloud), unless you want
   Cloudflare's proxy in front of it. DNS only behaves as before.

Add **no** records for `lab`. The lab's names will live in Pi-hole only.

## 2. Switch the nameservers

1. If DNSSEC is on at the registrar, **turn it off** and wait for the
   registrar to confirm.
2. At the registrar, replace the nameservers with the two Cloudflare shows
   for `<domain>`.
3. Wait until Cloudflare marks the domain **Active**. Usually minutes, at
   most a day or two.
4. Check the website loads and email arrives.
5. Turn DNSSEC on in Cloudflare (**DNS → Settings**), and add the DS record
   it shows at the registrar.

## 3. Create the API token

1. **My Profile → API Tokens → Create Token**, template **Edit zone DNS**.
2. Permissions: **Zone → DNS → Edit**, and add **Zone → Zone → Read**.
3. Zone resources: **Include → Specific zone → `<domain>`**.
4. **Create Token**. It's shown only once; keep the page open for the next
   step.

Also copy the **Zone ID** from `<domain>`'s Overview page. It isn't secret,
but Proxmox's ACME client needs it in step 4.

## 4. Store it with SOPS

With [step 2](sops-age.md) done:

```sh
sops edit secrets/cloudflare.sops.yaml
```

and write, pasting the token into the editor:

```yaml
api_token: <token>
zone_id: <zone-id>
```

Save, check the value is encrypted, and commit:

```sh
grep api_token secrets/cloudflare.sops.yaml   # api_token: ENC[...]
git add secrets/cloudflare.sops.yaml
git commit -m "Add the Cloudflare DNS token"
```

Save it in the password manager too, so it survives losing both age keys.

## 5. Test a certificate from the laptop

certbot with the Cloudflare plugin asks Let's Encrypt's **staging** server
for the wildcard. Staging certificates aren't trusted, but staging has
generous rate limits, so mistakes cost nothing.

certbot reads the token from a file. Write it to `$XDG_RUNTIME_DIR`, a
private tmpfs that's gone at logout, straight from SOPS:

```sh
f="$XDG_RUNTIME_DIR/cloudflare.ini"
(umask 077
 printf 'dns_cloudflare_api_token = %s\n' \
   "$(sops decrypt --extract '["api_token"]' secrets/cloudflare.sops.yaml)" > "$f")

d="$XDG_RUNTIME_DIR/le-test"
certbot certonly --test-cert \
  --dns-cloudflare --dns-cloudflare-credentials "$f" \
  -d 'lab.<domain>' -d '*.lab.<domain>' \
  --config-dir "$d" --work-dir "$d" --logs-dir "$d"
```

It worked if certbot says *Successfully received certificate*. Then clean
up; the real certificates are issued in the lab:

```sh
rm -rf "$f" "$d"
```

While it ran, certbot created a TXT record at
`_acme-challenge.lab.<domain>` and deleted it again; Cloudflare's DNS page
should show no `lab` records afterwards.

## What can go wrong

**The website or email broke after the switch**
: A record wasn't imported. Add it in Cloudflare; it takes effect within
  minutes.

**The domain doesn't resolve at all**
: DNSSEC was still on. Remove the DS record at the registrar.

**certbot: "Error determining zone identifier" or a 403**
: The token is missing **Zone → Zone → Read**, or it's scoped to a
  different zone.

**certbot: the TXT record isn't found**
: The domain isn't Active in Cloudflare yet. Wait, and try again.

## See also

- [Rebuild step 2: secrets with SOPS and age](sops-age.md)
- [Rebuild step 4: installing Proxmox VE](proxmox-install.md)
- [Certificates and DNS for the homelab](certs-and-dns.md): how this
  token is used in the lab.
- [Back to the blog](../MANIFEST.md)

## Placeholders

`<domain>`
: Your domain, e.g. `example.com`.

`<token>`
: The Cloudflare API token. Pasted into the `sops edit` editor only, never
  on a command line.

`<zone-id>`
: `<domain>`'s Zone ID in Cloudflare, 32 hex characters.
