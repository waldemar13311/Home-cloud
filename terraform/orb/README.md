# terraform/orb

Модуль создаёт виртуальные машины в OrbStack и синхронизирует производные
файлы: hosts-записи dnsmasq на хосте и Ansible-инвентарь. Аналог
`terraform/multipass` на провайдере `robertdebock/orbstack`.

## Как это устроено

- `variables.tf` — **источник истины**: набор ВМ (`local.vms`) и общие
  настройки (`common_config`). Всё остальное выводится отсюда.
- `main.tf` — ресурсы:
  - `orbstack_machine.nodes` — сами ВМ (cloud-init из `cloud-init/user-data.tftpl`);
  - `local_file.dnsmasq_hosts` — генерирует `/opt/homebrew/etc/dnsmasq.hosts`
    целиком из шаблона `templates/dnsmasq-hosts.tftpl`;
  - `local_file.inventory` — генерирует `ansible/inventory.auto.yml`;
  - `terraform_data.dnsmasq_reload` — `killall -HUP dnsmasq` при изменении
    хэша контента hosts-файла;
  - `terraform_data.ssh_known_hosts_cleanup` — чистит known_hosts при
    уничтожении ВМ (с локом от параллельной гонки за known_hosts).
- `outputs.tf` — сводка по ВМ (fqdn, ip, субдомены).

Принцип: файлы `dnsmasq.hosts` и `inventory.auto.yml` — **ресурсы**, они
перезаписываются целиком при каждом изменении набора ВМ. Точечные
`destroy -target` не используются — они уничтожают и зависимые ресурсы
(сгенерированные файлы удалятся целиком).

## Отличия от multipass

- У ВМ OrbStack нет фиксированных `cpus`/`memory`/`disk` — машины динамически
  делят ресурсы хоста (лимиты через CLI `orb create --cpus/--memory/--disk`
  провайдер пока не поддерживает).
- `image` — в формате OCI-образов (`ubuntu:noble` = Ubuntu 24.04).
- Провайдер пока не поддерживает `--isolated`/`--isolate-network` —
  изолированные машины создаются вручную через `orb create`.

## Требования

- Запущенный OrbStack (провайдер общается с ним локально).
- macOS-хост: путь `/opt/homebrew/etc/dnsmasq.hosts` и dnsmasq как brew-сервис.
- dnsmasq подключает сгенерированный файл через `addn-hosts`
  (см. `/opt/homebrew/etc/dnsmasq.conf`).
- passwordless sudo для `sudo killall -HUP dnsmasq` (иначе релоад упадёт —
  apply завершится ошибкой с подсказкой).
- Чтобы сам Mac резолвил `*.home` даже при включённом корпоративном VPN
  (подменяющем основной DNS): `/etc/resolver/home` с `nameserver 127.0.0.1`.
  Проверка — `dscacheutil -q host -a name <fqdn>` (dig/nslookup файл
  `/etc/resolver` игнорируют).
- Провайдеры `robertdebock/orbstack` и `hashicorp/local` установлены вручную
  (см. корневой README).

## Внимание: общие файлы с multipass

Оба модуля пишут **одни и те же** файлы (`dnsmasq.hosts`, `inventory.auto.yml`)
и применяются поочерёдно: apply одного перезаписывает записи другого.
На стенде должен быть активен один гипервизор за раз.

## Как добавить / удалить ВМ

Добавить или удалить запись в `local.vms` в `variables.tf`, затем:

```bash
tofu -chdir=orb apply
```

dnsmasq.hosts, inventory.auto.yml и known_hosts приведутся в порядок
автоматически. Удаление ВМ из `local.vms` уничтожит её инстанс при
следующем apply.

Имена ВМ — DNS-метки (проверяется precondition): строчные буквы, цифры,
дефисы; не начинаться и не заканчиваться дефисом.
