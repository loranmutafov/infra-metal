variable "common_name" {
  type = string
  description = "Common name for the PKI backend"
}

variable "key_type" {
  type = string
  description = "Key type for the PKI backend"
}

variable "key_bits" {
  type = string
  description = "Key bits for the PKI backend"
}

variable "country" {
  type = string
  description = "Country for the PKI backend"
}

variable "locality" {
  type = string
  description = "Locality for the PKI backend"
}

variable "max_path_length" {
  type = number
  description = "Maximum path length for the PKI backend"
}

variable "ttl" {
  type = number
  description = "TTL for the PKI backend"
}

variable "exclude_cn_from_sans" {
  type = bool
  description = "Exclude common name from SANs for the PKI backend"
}

variable "certificate" {
  type = string
  description = "Certificate for the PKI backend"
}

variable "csr" {
  type = string
  description = "CSR for the PKI backend"
}

variable "backend" {
  type = string
  description = "Backend for the PKI backend"
}

variable "type" {
  type = string
  description = "Type for the PKI backend"
}