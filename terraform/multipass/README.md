# terraform/multipass

Модуль создаёт виртуальные машины в Multipass и синхронизирует производные
файлы: hosts-записи dnsmasq на хосте и Ansible-инвентарь.

## Как это устроено

- `variables.tf` - **источник истины**: набор ВМ (`local.vms`) и общие настройки (`common_config`). Всё остальное выводится отсюда.
- `main.tf` - ресурсы:
  - `multipass_instance.nodes` - сами ВМ (cloud-init из `cloud-init/user-data.tftpl`);
  - `local_file.dnsmasq_hosts` - генерирует `/opt/homebrew/etc/dnsmasq.hosts` целиком из шаблона `templates/dnsmasq-hosts.tftpl`;
  - `local_file.inventory` - генерирует `ansible/inventory.auto.yml`;
  - `terraform_data.dnsmasq_reload` - `killall -HUP dnsmasq` при изменении хэша контента hosts-файла;
  - `terraform_data.ssh_known_hosts_cleanup` - чистит known_hosts при уничтожении ВМ.
- `outputs.tf` - сводка по ВМ (fqdn, ip, субдомены).

Принцип: файлы `dnsmasq.hosts` и `inventory.auto.yml` - **ресурсы**, они перезаписываются целиком при каждом изменении набора ВМ. Точечные `destroy -target` не используются - они уничтожают и зависимые ресурсы
(сгенерированные файлы удалятся целиком).

## Требования

- macOS-хост: путь `/opt/homebrew/etc/dnsmasq.hosts` и dnsmasq как brew-сервис - мак-специфичны; на Linux-хосте hosts-файл и reload dnsmasq настраиваются иначе.
- dnsmasq подключает сгенерированный файл через `addn-hosts` (см. `/opt/homebrew/etc/dnsmasq.conf`).
- passwordless sudo для `sudo killall -HUP dnsmasq` (иначе релоад упадёт - apply завершится ошибкой с подсказкой).
- Провайдер `hashicorp/local` установлен вручную (см. корневой README).

## Как добавить / удалить ВМ

Добавить или удалить запись в `local.vms` в `variables.tf`, затем:

```bash
tofu -chdir=multipass apply
```

dnsmasq.hosts, inventory.auto.yml и known_hosts приведутся в порядок автоматически. Удаление ВМ из `local.vms` уничтожит её инстанс при следующем apply.

Имена ВМ - DNS-метки (проверяется precondition): строчные буквы, цифры, дефисы; не начинаться и не заканчиваться дефисом.

## Что генерируется автоматически

| Файл | Ресурс | Потребитель |
|---|---|---|
| `/opt/homebrew/etc/dnsmasq.hosts` | `local_file.dnsmasq_hosts` | dnsmasq (addn-hosts) |
| `ansible/inventory.auto.yml` | `local_file.inventory` | ansible.cfg (`inventory = inventory.yml, inventory.auto.yml`) |

Эти файлы не редактировать руками и не коммитить (см. `.gitignore`).
