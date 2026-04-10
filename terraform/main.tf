terraform {
  required_version = ">= 1.11.6"

  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "1.7.0"
    }
  }
}

locals {
  # То, что меняется
  vms = {
    "master" = { ip = "192.168.64.110", cpus = 2, memory = "4G", disk = "40G" }
    "slave1" = { ip = "192.168.64.111", cpus = 2, memory = "4G", disk = "40G" }
    "slave2" = { ip = "192.168.64.112", cpus = 2, memory = "4G", disk = "40G" }
  }

  # Общие настройки
  common_config = {
    domain     = "home"
    mask       = "24"
    dns_server = "192.168.1.25"
  }
}

resource "multipass_instance" "nodes" {
  for_each = local.vms

  name  = each.key
  image = "24.04"

  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloud_init = templatefile("${path.module}/cloud-init/user-data.tftpl", {
    # ssh ключ добавится на все ВМ
    ssh_key    = file("~/.ssh/id_ed25519.pub")
    hostname   = each.key
    domain     = local.common_config.domain
    static_ip  = each.value.ip
    mask       = local.common_config.mask
    dns_server = local.common_config.dns_server
  })

  # Автоматическое добавление A записей в dnsmasq при создании
  provisioner "local-exec" {
    command = <<EOT
      # Удаляем старую запись, если она есть (идемпотентность)
      sed -i '' '/ ${each.key}.${local.common_config.domain}/d' /opt/homebrew/etc/dnsmasq.hosts
      # Добавляем новую: IP FQDN ShortName
      echo "${each.value.ip} ${each.key}.${local.common_config.domain} ${each.key}" >> /opt/homebrew/etc/dnsmasq.hosts
      # Пречитка конфига dnsmasq без рестарта
      sudo killall -HUP dnsmasq
    EOT
  }

  # Удаляем запись при уничтожении
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      sed -i '' '/ ${self.name}/d' /opt/homebrew/etc/dnsmasq.hosts
      sudo killall -HUP dnsmasq
    EOT
  }
}

output "vm_details" {
  value = {
    for name, instance in multipass_instance.nodes : name => {
      # Выбираем из списка только тот IP, который НЕ совпадает со статикой
      dynamic_multipass_ip = [for ip in instance.ipv4 : ip if ip != local.vms[name].ip][0]
      static_ip            = local.vms[name].ip
    }
  }
}
