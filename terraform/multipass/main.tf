resource "multipass_instance" "nodes" {
  for_each = local.vms

  name  = each.key
  image = local.common_config.image

  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloud_init = templatefile("${path.module}/cloud-init/user-data.tftpl", {
    # ssh ключ добавится на все ВМ
    ssh_key    = file(pathexpand(var.ssh_public_key_path))
    hostname   = each.key
    domain     = local.common_config.domain
    dns_server = local.common_config.dns_server
  })

  # Имя ВМ станет частью FQDN, поэтому оно обязано быть корректной
  # DNS-меткой: иначе dnsmasq/inventory сломаются молча,
  # уже после применения плана.
  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", each.key))
      error_message = "Имя ВМ '${each.key}' должно быть корректной DNS-меткой: строчные буквы, цифры, дефисы; начинаться и заканчиваться буквой или цифрой."
    }
  }

  # Записи в known_hosts, dnsmasq.hosts и ansible-инвентаре при уничтожении
  # пересоздаются сами - см. terraform_data.ssh_known_hosts_cleanup,
  # local_file.dnsmasq_hosts и local_file.inventory ниже.
}

# Очистка known_hosts от имён, FQDN и IP уничтожаемых ВМ.
resource "terraform_data" "ssh_known_hosts_cleanup" {
  for_each = multipass_instance.nodes

  triggers_replace = [each.value.ipv4[0]]

  input = {
    name = each.key
    fqdn = "${each.key}.${local.common_config.domain}"
    ip   = each.value.ipv4[0]
  }

  provisioner "local-exec" {
    when = destroy
    # Выводим ошибки: видно, какая запись удалилась, а какая нет.
    # Провал одной записи не роняет весь destroy (|| echo), но виден в выводе.
    #
    # Лок обязателен: ssh-keygen -R переписывает known_hosts ЦЕЛИКОМ
    # (через known_hosts.old), поэтому параллельные вызовы из разных
    # элементов ресурса теряют удаления друг друга - наблюдали вживую
    # как "link known_hosts to known_hosts.old: File exists".
    command = join("\n", concat([
      "LOCK=\"$HOME/.ssh/.tofu-known-hosts.lock\"",
      "i=0",
      "while ! mkdir \"$LOCK\" 2>/dev/null; do sleep 0.2; i=$((i+1)); if [ $i -gt 50 ]; then echo 'known_hosts: не дождались лока' >&2; exit 1; fi; done",
      "trap 'rmdir \"$LOCK\" 2>/dev/null' EXIT",
      ], [
      for h in [self.output.name, self.output.fqdn, self.output.ip] :
      "echo \"known_hosts: убираю ${h}\"; ssh-keygen -R ${h} || echo \"ПРЕДУПРЕЖДЕНИЕ: не удалось убрать ${h} из known_hosts\" >&2"
    ]))
  }
}

# dnsmasq.hosts генерируется целиком на каждом изменении состояния.
# Внимание: путь /opt/homebrew/etc и dnsmasq как сервис - мак-специфичные.
# На Linux-хосте хосты и reload dnsmasq настраиваются иначе.
resource "local_file" "dnsmasq_hosts" {
  filename        = "/opt/homebrew/etc/dnsmasq.hosts"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/dnsmasq-hosts.tftpl", {
    domain = local.common_config.domain
    vms = {
      for name, inst in multipass_instance.nodes : name => {
        ip         = inst.ipv4[0]
        subdomains = lookup(local.vms[name], "subdomains", [])
      }
    }
  })
}

# Перезапуск dnsmasq нужен после любого изменения hosts-файла, поэтому
# вешаем его на хэш контента: provisioner у local_file при обновлении
# контента не вызывается, а terraform_data - пересоздаётся.
resource "terraform_data" "dnsmasq_reload" {
  triggers_replace = [local_file.dnsmasq_hosts.content_sha1]

  provisioner "local-exec" {
    # fail, а не continue по умолчанию: иначе при неудаче релоада apply
    # пройдёт зелёным, а dnsmasq продолжит отдавать устаревшие записи
    command    = <<EOT
      if sudo killall -HUP dnsmasq; then
        echo "dnsmasq успешно перечитал hosts-файл, DNS-записи обновлены"
      else
        echo "Не удалось перечитать конфиг dnsmasq (killall -HUP). Частые причины:" >&2
        echo "  1. dnsmasq не запущен:       brew services list | grep dnsmasq" >&2
        echo "  2. sudo запрашивает пароль:  нужен passwordless sudo для этого пользователя" >&2
        echo "DNS-записи обновлены на диске, но dnsmasq продолжит отдавать старые," >&2
        echo "пока не выполните 'sudo killall -HUP dnsmasq' вручную." >&2
        exit 1
      fi
    EOT
    on_failure = fail
  }
}

# Ansible-инвентарь генерируется целиком на каждом изменении состояния.
# ansible.cfg читает его вместе со статическим ansible/inventory.yml
# (см. inventory = ... в ansible/ansible.cfg).
resource "local_file" "inventory" {
  filename        = "${path.module}/../../ansible/inventory.auto.yml"
  file_permission = "0644"

  content = yamlencode({
    all = {
      hosts = {
        for name, inst in multipass_instance.nodes : name => merge(
          { ansible_host = "${name}.${local.common_config.domain}" },
          length(lookup(local.vms[name], "subdomains", [])) > 0 ?
          { subdomains = lookup(local.vms[name], "subdomains", []) } : {}
        )
      }
    }
  })
}
