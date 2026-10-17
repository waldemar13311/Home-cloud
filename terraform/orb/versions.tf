terraform {
  required_version = ">= 1.11.6"

  required_providers {
    orbstack = {
      source  = "robertdebock/orbstack"
      version = "~> 3.1.2"
    }
    # Генерация ansible/inventory.auto.yml
    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
  }
}
