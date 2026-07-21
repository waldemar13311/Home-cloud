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

  # Автоматическое добавление A записей в dnsmasq и хоста в Ansible inventory при создании
  provisioner "local-exec" {
    command = <<EOT
      INVENTORY="${path.module}/../../ansible/inventory.yml"
      LOCKDIR="/tmp/terraform-ansible-inventory.lock"

      # --- dnsmasq ---
      # Удаляем старую запись, если она есть
      sed -i '' '/ ${each.key}.${local.common_config.domain}/d' /opt/homebrew/etc/dnsmasq.hosts
      # Добавляем новую: IP FQDN ShortName
      echo "${self.ipv4[0]} ${self.name}.${local.common_config.domain} ${self.name}" >> /opt/homebrew/etc/dnsmasq.hosts
      # Перечитка конфига dnsmasq без рестарта
      sudo killall -HUP dnsmasq

      # --- ansible inventory ---
      # Блокировка на случай параллельного for_each
      while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.1; done
      # Удаляем старую запись хоста (две строки), если есть
      sed -i '' "/^    ${each.key}:\$/,/^      ansible_host:/d" "$INVENTORY"
      # Добавляем хост в конец файла
      printf '    %s:\n      ansible_host: %s.%s\n' \
        "${each.key}" "${each.key}" "${local.common_config.domain}" >> "$INVENTORY"
      rmdir "$LOCKDIR"
    EOT
  }

  # Удаляем запись при уничтожении
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      INVENTORY="${path.module}/../../ansible/inventory.yml"
      LOCKDIR="/tmp/terraform-ansible-inventory.lock"

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

      # 4. Удаляем хост из Ansible inventory
      while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.1; done
      sed -i '' "/^    ${self.name}:\$/,/^      ansible_host:/d" "$INVENTORY"
      rmdir "$LOCKDIR"
    EOT
  }
}
