# Home Cloud

Инфраструктурный проект для развёртывания домашнего облака в локальной среде.

## Что делает проект

- поднимает виртуальные машины в Multipass (например, `master` и `nginx`);
- настраивает базовую сетевую конфигурацию и DNS-имена;
- применяет Ansible-плейбуки для установки Docker, Nginx и т.д. (будет пополняться);
- разворачивает внутреннюю PKI для TLS между узлами домашнего окружения.

## Из чего состоит

- `terraform/` - создание и удаление виртуальных машин;
- `ansible/playbooks/` - прикладная настройка хостов и сервисов;
- `ansible/roles/home_cloud_pki/` - роль для выпуска и доставки внутренних сертификатов.

## Типовой сценарий использования

1. Подготовить Python-окружение и зависимости Ansible.
2. Поднять инфраструктуру в локальном гипервизоре.
3. Применить нужные Ansible-плейбуки (Docker, PKI, Nginx).
4. Проверить, что узлы доступны по доменным именам и сервисы работают.

## Для кого этот репозиторий

Для домашней лаборатории и учебных задач: быстро собрать стенд, отработать инфраструктурные практики и иметь воспроизводимое окружение.

## Подготовка окружения
```bash
uv sync
source .venv/bin/activate

cd ansible
ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml

# Настройка todoroff/multipass
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/todoroff/multipass/1.7.0/darwin_arm64/

wget https://github.com/todoroff/terraform-provider-multipass/releases/download/1.7.0/terraform-provider-multipass_1.7.0_darwin_arm64.zip && \
unzip terraform-provider-multipass_1.7.0_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/todoroff/multipass/1.7.0/darwin_arm64 && \
rm terraform-provider-multipass_1.7.0_darwin_arm64.zip


# Настройка opentofu/vault
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/opentofu/vault/5.10.1/darwin_arm64/

wget https://github.com/opentofu/terraform-provider-vault/releases/download/v5.10.1/terraform-provider-vault_5.10.1_darwin_arm64.zip && \
unzip terraform-provider-vault_5.10.1_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/opentofu/vault/5.10.1/darwin_arm64 && \
rm terraform-provider-vault_5.10.1_darwin_arm64.zip


# Настройка gitlabhq/gitlab
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/gitlabhq/gitlab/19.2.0/darwin_arm64/

wget https://github.com/gitlabhq/terraform-provider-gitlab/releases/download/v19.2.0/terraform-provider-gitlab_19.2.0_darwin_arm64.zip && \
unzip terraform-provider-gitlab_19.2.0_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/gitlabhq/gitlab/19.2.0/darwin_arm64 && \
rm terraform-provider-gitlab_19.2.0_darwin_arm64.zip


# Настройка hashicorp/local
# В архиве бинарник без версии в имени, а filesystem mirror требует имя с версией,
# поэтому после unzip его нужно переименовать.
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.9.1/darwin_arm64/

wget https://github.com/opentofu/terraform-provider-local/releases/download/v2.9.1/terraform-provider-local_2.9.1_darwin_arm64.zip && \
unzip terraform-provider-local_2.9.1_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.9.1/darwin_arm64 && \
mv ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.9.1/darwin_arm64/terraform-provider-local \
   ~/.terraform.d/plugins/registry.opentofu.org/hashicorp/local/2.9.1/darwin_arm64/terraform-provider-local_v2.9.1 && \
rm terraform-provider-local_2.9.1_darwin_arm64.zip


# Настройка opentofu/null
mkdir -p ~/.terraform.d/plugins/registry.opentofu.org/opentofu/null/3.3.0/darwin_arm64/

wget https://github.com/opentofu/terraform-provider-null/releases/download/v3.3.0/terraform-provider-null_3.3.0_darwin_arm64.zip && \
unzip terraform-provider-null_3.3.0_darwin_arm64.zip -d ~/.terraform.d/plugins/registry.opentofu.org/opentofu/null/3.3.0/darwin_arm64 && \
rm terraform-provider-null_3.3.0_darwin_arm64.zip
```

## Tofu команды
```bash
cd terraform

tofu -chdir=multipass init
tofu -chdir=multipass plan
# -parallelism=1 больше не нужен (нужно проверить !): общих файлов (dnsmasq.hosts,
# ansible-инвентарь), за которые могли бы гоняться инстансы, нет -
# они генерируются Terraform целиком после создания всех ВМ
tofu -chdir=multipass apply

# На удаление
# -parallelism=1 для destroy можно оставить: при параллельном удалении
# нескольких ВМ provisioner-ы known_hosts могли бы гоняться за ~/.ssh/known_hosts
tofu -chdir=multipass destroy -parallelism=1 -target='multipass_instance.nodes["k3s-node"]'
```

## Multipass команды
```bash
multipass list
multipass purge
```

## Secrets
```bash
cd ansible
ansible-playbook playbooks/home_cloud_pki.ansible.yml
```

### .gitlab-ci.yml в GitLab проектах с использованием Home Cloud PKI
Так как сертификаты на серверах подписаны Home Cloud PKI, в пайплайнах для контейнеров перед использованием необходимо обновить бандл сертификатов. Пример реализации для разных дистрибутивов:
```yml
stages:
  - ubuntu_test
  - alpine_test
  - fedora_test

test_ubuntu_job:
  stage: ubuntu_test
  image: ubuntu:noble
  tags:
    - docker
  script:
    - echo "Привет из контейнера Ubuntu!"
    - apt-get update -qq && apt-get install -y curl dnsutils
    - nslookup gitlab.home
    - curl -I https://gitlab.home/users/sign_in

test_alpine_job:
  stage: alpine_test
  image: alpine:latest
  tags:
    - docker
  script:
    - echo "Привет из контейнера Alpine!"
    - apk add --no-cache -q curl bind-tools ca-certificates && update-ca-certificates
    - nslookup gitlab.home
    - curl -I https://gitlab.home/users/sign_in

test_fedora_job:
  stage: fedora_test
  image: fedora:latest
  tags:
    - docker
  script:
    - echo "Привет из контейнера Fedora!"
    - dnf install -y -q --nodocs curl bind-utils && update-ca-trust extract
    - nslookup gitlab.home
    - curl -I https://gitlab.home/users/sign_in
```

## License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.
