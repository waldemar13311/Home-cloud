provider "vault" {
  address         = "https://vault.home:8200"
  token           = var.vault_token
  skip_tls_verify = false # tls сертификат будет проверяться
}
