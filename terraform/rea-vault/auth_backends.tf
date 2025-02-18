resource "vault_auth_backend" "userpass" {
  type = "userpass"

  tune {
    max_lease_ttl      = "24h"
    listing_visibility = "hidden"
  }
}