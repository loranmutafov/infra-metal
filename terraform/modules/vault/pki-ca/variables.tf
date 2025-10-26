variable "name" {
    type = string
    description = "Name of the PKI backend"
}

variable "mount_path" {
    type = string
    description = "Path of the PKI backend"
}

variable "description" {
    type = string
    description = "Description of the PKI backend"
}

variable "parent_pki_mount_path" {
  type = string
  description = "Mount of PKI parent CA. Empty means this is a root CA."
}

variable "vault_addr" {
  type    = string
  default = "https://metal-nina:8200"
}

variable "default_lease_ttl_seconds" {
  type = number
  description = "Default lease TTL for the PKI backend"
}

variable "max_lease_ttl_seconds" {
  type = number
  description = "Maximum lease TTL for the PKI backend"
}

locals {
  default_10y_in_sec = 315360000
  default_5y_in_sec  = 157680000
  default_3y_in_sec  = 94608000
  default_1y_in_sec  = 31536000
  default_1d_in_sec  = 86400
  default_1h_in_sec  = 3600
}
