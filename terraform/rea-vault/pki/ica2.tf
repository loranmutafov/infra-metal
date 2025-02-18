resource "vault_mount" "rea_metal_v1_ica2_v1" {
  path                      = "rea-metal/v1/ica2/v1"
  type                      = "pki"
  description               = "PKI engine hosting intermediate CA2 v1 for the Metal Vault of Rea"
  default_lease_ttl_seconds = local.default_1hr_in_sec
  max_lease_ttl_seconds     = local.default_3y_in_sec
}

resource "vault_pki_secret_backend_intermediate_cert_request" "rea_metal_v1_ica2_v1" {
  backend = vault_mount.rea_metal_v1_ica2_v1.path

  type        = "internal"
  common_name = "Vault of Rea Intermediate CA2 v1"
  key_type    = "rsa"
  key_bits    = "4096"
  country     = "BG"
  locality    = "Varna"

  depends_on = [
    vault_mount.rea_metal_v1_ica2_v1,
  ]
}

resource "vault_pki_secret_backend_root_sign_intermediate" "rea_metal_v1_sign_ica2_v1_by_ica1_v1" {
  backend = vault_mount.rea_metal_v1_ica1_v1.path
  csr     = vault_pki_secret_backend_intermediate_cert_request.rea_metal_v1_ica2_v1.csr

  common_name          = "Vault of Rea Intermediate CA2 v1.1"
  exclude_cn_from_sans = true
  country              = "BG"
  locality             = "Varna"
  max_path_length      = 1
  ttl                  = local.default_1y_in_sec

  depends_on = [
    vault_mount.rea_metal_v1_ica1_v1,
    vault_pki_secret_backend_intermediate_cert_request.rea_metal_v1_ica2_v1,
  ]
}

resource "vault_pki_secret_backend_intermediate_set_signed" "rea_metal_v1_ica2_v1_signed_cert" {
  backend = vault_mount.rea_metal_v1_ica2_v1.path

  certificate = format(
    "%s\n%s",
    vault_pki_secret_backend_root_sign_intermediate.rea_metal_v1_sign_ica2_v1_by_ica1_v1.certificate,
    file("${path.module}/cacerts/vault-of-rea-intermediate-ca1-v1.cert"),
  )

  depends_on = [
    vault_pki_secret_backend_root_sign_intermediate.rea_metal_v1_sign_ica2_v1_by_ica1_v1,
  ]
}
