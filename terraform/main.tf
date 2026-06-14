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
    "gitlab"    = { cpus = 4, memory = "10G", disk = "60G" }
    "vault"     = { cpus = 1, memory = "1G",  disk = "20G" }
    "k3s-node"  = { cpus = 4, memory = "6G",  disk = "40G" }

  //  "nginx"  = { cpus = 2, memory = "4G", disk = "25G" }
  //  "master" = { cpus = 2, memory = "4G", disk = "40G" }
  //  "slave1" = { cpus = 2, memory = "4G", disk = "40G" }
  //  "slave2" = { cpus = 2, memory = "4G", disk = "40G" }
  }

  # Общие настройки
  common_config = {
    domain     = "home"
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
    dns_server = local.common_config.dns_server
  })

  # Автоматическое добавление A записей в dnsmasq при создании
  provisioner "local-exec" {
    command = <<EOT
      # Удаляем старую запись, если она есть
      sed -i '' '/ ${each.key}.${local.common_config.domain}/d' /opt/homebrew/etc/dnsmasq.hosts
      # Добавляем новую: IP FQDN ShortName
      echo "${self.ipv4[0]} ${self.name}.${local.common_config.domain} ${self.name}" >> /opt/homebrew/etc/dnsmasq.hosts
      # Перечитка конфига dnsmasq без рестарта
      sudo killall -HUP dnsmasq
    EOT
  }

  # Удаляем запись при уничтожении
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      # 1. Находим полный FQDN машины в файле до того, как удалить строку
      # Ищет строку, где есть пробел, имя машины, точка и что угодно дальше, и берет второе слово (FQDN)
      FQDN=$(awk -v name="${self.name}" '$0 ~ " " name "\\." {print $2}' /opt/homebrew/etc/dnsmasq.hosts)

      # 2. Удаляем строку из dnsmasq
      # Удалит строку, где после пробела идет имя машины, точка и любой домен
      sed -i '' '/ ${self.name}\./d' /opt/homebrew/etc/dnsmasq.hosts
      sudo killall -HUP dnsmasq

      # 3. Чистим SSH-ключи
      # По короткому имени
      ssh-keygen -R ${self.name}
      
      # По длинному имени (если awk его нашел)
      [ -n "$FQDN" ] && ssh-keygen -R $FQDN
      
      # По IP-адресу
      ssh-keygen -R ${self.ipv4[0]}
    EOT
  }
}

output "vm_details" {
  value = {
    for name, instance in multipass_instance.nodes : name => {
      fqdn = "${name}.${local.common_config.domain}"
      ip   = instance.ipv4[0]
    }
  }
}
