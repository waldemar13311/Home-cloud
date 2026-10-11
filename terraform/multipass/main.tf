resource "multipass_instance" "nodes" {
  for_each = local.vms

  name  = each.key
  image = "24.04"

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
# При пересоздании ВМ с новым IP старая запись чистится автоматически
resource "terraform_data" "ssh_known_hosts_cleanup" {
  for_each = {
    for name, inst in multipass_instance.nodes :
    name => "${name}::${name}.${local.common_config.domain}::${inst.ipv4[0]}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = join(" ; ", [for h in split("::", each.key) : "ssh-keygen -R ${h} 2>/dev/null || true"])
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
    command = "sudo killall -HUP dnsmasq"
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
