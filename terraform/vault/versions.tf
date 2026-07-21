terraform {
  required_version = ">= 1.11.6"

  required_providers {
    vault = {
      source = "opentofu/vault"
      version = "5.10.1"
    }
  }
}
