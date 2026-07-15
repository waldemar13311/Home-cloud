# Home Cloud

Инфраструктурный проект для развёртывания домашнего облака в локальной среде.

## Что делает проект

- поднимает виртуальные машины в Multipass (например, `master` и `nginx`);
- настраивает базовую сетевую конфигурацию и DNS-имена;
- применяет Ansible-плейбуки для установки Docker, Nginx и т.д. (будет пополняться);
- разворачивает внутреннюю PKI для TLS между узлами домашнего окружения.

## Из чего состоит

- `terraform/` — создание и удаление виртуальных машин;
- `ansible/playbooks/` — прикладная настройка хостов и сервисов;
- `ansible/roles/home_cloud_pki/` — роль для выпуска и доставки внутренних сертификатов.

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
```

## Tofu команды
```bash
cd terraform

tofu -chdir=vms init
tofu -chdir=vms plan
tofu -chdir=vms apply -parallelism=1

# На удаление какая-то из этих команд
tofu -chdir=vms destroy -parallelism=1 -target='multipass_instance.nodes["k3s-node"]'
tofu destroy -parallelism=1 -target=multipass_instance.nodes["k3s-node"]
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

## Лицензия

This project is licensed under the **AGPL-3.0-or-later**.
