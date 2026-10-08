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

  # Имя ВМ станет частью FQDN и попадёт в regex в provisioner-скриптах,
  # поэтому оно обязано быть корректной DNS-меткой: иначе dnsmasq/inventory
  # сломаются молча, уже после применения плана.
  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", each.key))
      error_message = "Имя ВМ '${each.key}' должно быть корректной DNS-меткой: строчные буквы, цифры, дефисы; начинаться и заканчиваться буквой или цифрой."
    }
  }

  # Автоматическое добавление записей при создании
  provisioner "local-exec" {
    command = <<EOT
      INVENTORY="${path.module}/../../ansible/inventory.yml"
      LOCKDIR="/tmp/terraform-ansible-inventory.lock"

      # Генерируем строку алиасов для dnsmasq
      # Получится: "argocd.k3s-node.home vault.k3s-node.home "
      SUBDOMAINS="%{ for sub in lookup(each.value, "subdomains", []) }${sub}.${each.key}.${local.common_config.domain} %{ endfor }"

      # --- dnsmasq ---
      # Флаг -i.bak универсален: понимается и BSD sed (macOS), и GNU sed (Linux).
      # Вариант -i '' из BSD на Linux сломается, а -i без суффикса — на macOS.
      # Бэкап создаётся на обеих платформах, поэтому сразу удаляем его.
      sed -i.bak "/ ${each.key}\.${local.common_config.domain}/d" /opt/homebrew/etc/dnsmasq.hosts
      /bin/rm -f /opt/homebrew/etc/dnsmasq.hosts.bak
      # Внимание: путь /opt/homebrew/etc и dnsmasq как сервис — мак-специфичные вещи,
      # на Linux-хосте хосты и reload dnsmasq настраиваются иначе.

      # Добавляем в файл: IP, FQDN, ShortName и дальше все субдомены в эту же строку
      echo "${self.ipv4[0]} ${self.name}.${local.common_config.domain} ${self.name} $SUBDOMAINS" >> /opt/homebrew/etc/dnsmasq.hosts
      sudo killall -HUP dnsmasq

      # --- ansible inventory ---
      while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.1; done

      # УМНОЕ УДАЛЕНИЕ: Удаляем блок текущего хоста (4 пробела) и все его вложенные свойства (6+ пробелов)
      # -i.bak — универсальный флаг для BSD и GNU sed (см. комментарий выше)
      sed -i.bak -e "/^    ${each.key}:/,/^    [a-zA-Z]/ { /^    ${each.key}:/d; /^      /d; }" "$INVENTORY"
      /bin/rm -f "$INVENTORY.bak"

      # Записываем базовые данные хоста
      printf '    %s:\n      ansible_host: %s.%s\n' \
        "${each.key}" "${each.key}" "${local.common_config.domain}" >> "$INVENTORY"

      # Записываем субдомены, если они есть
      %{ if length(lookup(each.value, "subdomains", [])) > 0 }
      printf '      subdomains:\n' >> "$INVENTORY"
      %{ for sub in lookup(each.value, "subdomains", []) }
      printf '        - %s\n' "${sub}" >> "$INVENTORY"
      %{ endfor }
      %{ endif }

      rmdir "$LOCKDIR"
    EOT
  }

  # Удаляем запись при уничтожении
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      INVENTORY="${path.module}/../../ansible/inventory.yml"
      LOCKDIR="/tmp/terraform-ansible-inventory.lock"

      # 1. Берем главный FQDN (второе слово на строке)
      FQDN=$(awk -v name="${self.name}" '$0 ~ " " name "\\." {print $2}' /opt/homebrew/etc/dnsmasq.hosts)

      # 2. Удаляем строку целиком (субдомены удалятся вместе с ней, так как они на одной строке)
      # -i.bak — универсальный флаг для BSD и GNU sed (см. комментарий выше)
      sed -i.bak "/ ${self.name}\./d" /opt/homebrew/etc/dnsmasq.hosts
      /bin/rm -f /opt/homebrew/etc/dnsmasq.hosts.bak
      sudo killall -HUP dnsmasq

      # 3. Чистим SSH-ключи (добавил 2>/dev/null, чтобы скрипт не падал, если ключа нет)
      ssh-keygen -R ${self.name} 2>/dev/null || true
      [ -n "$FQDN" ] && ssh-keygen -R $FQDN 2>/dev/null || true
      ssh-keygen -R ${self.ipv4[0]} 2>/dev/null || true

      # 4. Удаляем хост и его дочерние элементы из Ansible inventory
      while ! mkdir "$LOCKDIR" 2>/dev/null; do sleep 0.1; done

      # То же умное удаление: убираем хост при destroy
      # -i.bak — универсальный флаг для BSD и GNU sed (см. комментарий выше)
      sed -i.bak -e "/^    ${self.name}:/,/^    [a-zA-Z]/ { /^    ${self.name}:/d; /^      /d; }" "$INVENTORY"
      /bin/rm -f "$INVENTORY.bak"

      rmdir "$LOCKDIR"
    EOT
  }
}
