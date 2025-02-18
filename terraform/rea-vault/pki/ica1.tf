resource "vault_mount" "rea_metal_v1_ica1_v1" {
  path                      = "rea-metal/v1/ica1/v1"
  type                      = "pki"
  description               = "PKI engine hosting intermediate CA1 v1 for the Metal Vault of Rea"
  default_lease_ttl_seconds = local.default_1hr_in_sec
  max_lease_ttl_seconds     = local.default_3y_in_sec
}

resource "vault_pki_secret_backend_intermediate_cert_request" "rea_metal_v1_ica1_v1" {
  depends_on   = [vault_mount.rea_metal_v1_ica1_v1]
  backend      = vault_mount.rea_metal_v1_ica1_v1.path

  type         = "internal"
  common_name  = "Vault of Rea Intermediate CA1 v1"
  key_type     = "rsa"
  key_bits     = "4096"
  country      = "BG"
  locality     = "Varna"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "rea_metal_va1_ica1_v1_signed_cert" {
  depends_on   = [vault_mount.rea_metal_v1_ica1_v1]
  backend      = vault_mount.rea_metal_v1_ica1_v1.path

  certificate = file("${path.module}/cacerts/vault-of-rea-intermediate-ca1-v1.cert")
}
