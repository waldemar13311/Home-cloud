# Включаем и настраиваем jwt Engine
resource "vault_jwt_auth_backend" "jwt" {
  type        = "jwt"
  path        = "jwt"
  description = "JWT authentication for GitLab CI/CD"
  jwks_url     = "${var.gitlab_url}/oauth/discovery/keys"
  bound_issuer = var.gitlab_url
}

# Генерируем документ политики
data "vault_policy_document" "app_policy" {
  # Политика с правилом: читай secrets/my-app-config
  # data нужно так как мы используем kv v2
  rule {
    path         = "secrets/data/my-app-config"
    capabilities = ["read"]
    description  = "Read access to app configuration"
  }
}

# Передаём сгенерированный документ в ресурс политики
resource "vault_policy" "app" {
  name   = "gitlab-project-policy"
  policy = data.vault_policy_document.app_policy.hcl
}

# Создаём роль
resource "vault_jwt_auth_backend_role" "gitlab" {
  backend             = vault_jwt_auth_backend.jwt.path
  role_name           = "gitlab"
  token_policies      = [vault_policy.app.name]

  bound_audiences     = ["${var.gitlab_url}"]
  token_ttl           = 300 # 5 минут

  user_claim          = "user_email"
  role_type           = "jwt"
  bound_claims_type   = "glob"
  bound_claims = {
    "project_id" = "${var.gitlab_project_id}"
  }
}
