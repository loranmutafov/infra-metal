terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2.0"
    }
    onepassword = {
      source = "1Password/onepassword"
      version = "2.1.2"
    }
    google = {
      source = "hashicorp/google"
      version = "6.11.2"
    }
  }
}

provider "onepassword" {
  account               = "RFMRXE3UDZEE7GLID5VXDFD7HI"
  op_cli_path           = "op" # Default is `op`
}

provider "vault" {
  address         = var.vault_addr
  token           = data.onepassword_item.rea_metal_vault_token.section[2].field[0].value
  skip_tls_verify = true
}
