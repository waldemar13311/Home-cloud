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

tofu init
tofu plan
tofu apply -parallelism=1

tofu destroy -parallelism=1
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
