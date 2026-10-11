terraform {
  required_version = ">= 1.11.6"

  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "1.7.0"
    }
    # Генерация ansible/inventory.auto.yml.
    # Бинарники берутся из зеркала opentofu/terraform-provider-local на GitHub:
    # у оригинального hashicorp/terraform-provider-local в релизах только исходники.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
  }
}
