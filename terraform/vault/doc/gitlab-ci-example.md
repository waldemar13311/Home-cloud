## gitlab-ci
Для получения секретов из GitLab проекта, примерный код pipeline будет такой:
```yml
default:
  tags:
    - docker

stages:
  - get-secrets-from-vault

get-secrets-job:
  stage: get-secrets-from-vault
  image: hashicorp/vault:2.0
  id_tokens:
    VAULT_ID_TOKEN:
      aud: "https://gitlab.home"
  variables:
    VAULT_ADDR: "https://vault.home:8200"
    VAULT_CACERT: "/etc/pki/ca-trust/source/anchors/root_ca.crt"
    VAULT_ROLE: "gitlab"
    VAULT_SKIP_VERIFY: "false" # сертификат будет проверяться
    VAULT_SECRET_PATH: "secrets/my-app-config"
  before_script:
    - |
      echo "Checking JWT token..."
      echo "VAULT_ID_TOKEN: ${VAULT_ID_TOKEN:-(empty)}"
  script:
    - |
      echo "Trying to authenticate with Vault..."
      export VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=$VAULT_ROLE jwt=$VAULT_ID_TOKEN)
      echo "Vault Token prefix (first 20 chars): ${VAULT_TOKEN:0:20}..."

      export USERNAME_VALUE=$(vault kv get -field=username $VAULT_SECRET_PATH)
      export PASSWORD_VALUE=$(vault kv get -field=password $VAULT_SECRET_PATH)

      echo "Полученный секрет: $USERNAME_VALUE"
      echo "Полученный секрет: $PASSWORD_VALUE"
```
