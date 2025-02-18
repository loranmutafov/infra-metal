terraform {
  required_version = ">= 1.0.0" # Ensure that the Terraform version is 1.0.0 or higher

  cloud {
    organization = "rea-cluster"

    workspaces {
      name = "cluster-of-rea"
    }
  }
}

module "rea_vault" {
  source = "./rea-vault"
}
