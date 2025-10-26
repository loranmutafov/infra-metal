# step 1.1 and 1.2
resource "vault_mount" "pki_mount" {
  path                      = var.mount_path
  type                      = "pki"

  description               = var.description

  default_lease_ttl_seconds = var.default_lease_ttl_seconds
  max_lease_ttl_seconds     = var.max_lease_ttl_seconds
}
