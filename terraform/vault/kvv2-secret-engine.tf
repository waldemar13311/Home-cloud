// Включаем kvv2 Secrets Engine с именем secrets
resource "vault_mount" "kvv2-secrets" {
  path        = "secrets"
  type        = "kv"
  description = "KV Version 2 Secrets Engine"

  options = {
    version = "2"
  }
}

// Создаём простой секрет в этом движке
resource "vault_kv_secret_v2" "example" {
  mount               = vault_mount.kvv2-secrets.path
  name                = "my-app-config"
  cas                 = 1
  delete_all_versions = true
  data_json           = jsonencode({
    username = "admin"
    password = "supersecretpassword"
  })
}
