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

## Подготовка огружения

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

## Multipass команды

```bash
multipass list
multipass purge
```

## Tofu команды
```bash
tofu destroy -parallelism=1
tofu plan
tofu apply -parallelism=1
```