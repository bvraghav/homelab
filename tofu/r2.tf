# The bucket restic sends every service's data to. Its access key, limited
# to this bucket, is made in the Cloudflare dashboard and kept in
# secrets/restic.sops.yaml; see the step 5 post.

resource "cloudflare_r2_bucket" "backups" {
  account_id = data.sops_file.r2.data["account_id"]
  name       = var.backup_bucket
  # Asia-Pacific: the nearest R2 has to India. Only a hint, honoured when
  # the bucket is created; R2 can't be pinned to a country.
  location = "apac"

  lifecycle {
    prevent_destroy = true
  }
}
