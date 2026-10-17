variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу, который добавляется на все ВМ"
  type        = string
  # Раскрытие ~ делается через pathexpand() в main.tf,
  # потому что в default переменной функции вызывать нельзя.
  default = "~/.ssh/id_ed25519.pub"
}

locals {
  # То, что меняется.
  # Отличие от multipass: у OrbStack нет фиксированных cpus/memory/disk -
  # машины динамически делят ресурсы хоста. Настройки ВМ: image
  # (переопределяет common_config.image), subdomains.
  vms = {
    # Для тестов VPN
    # "proxy"           = { image = "ubuntu:noble" }
    # "proxy-worker-1"  = { image = "ubuntu:noble" }
    # "nginx"           = { image = "ubuntu:noble" }
    # "client"          = { image = "ubuntu:noble" }

    # Сервисы
    # "gitlab"   = { image = "ubuntu:noble", subdomains = ["registry"] }
    # "vault"    = { image = "ubuntu:noble" }
    # "k3s-node" = { image = "ubuntu:noble", subdomains = ["argocd"] }

    # "test-vm-1" = { image = "ubuntu:noble" }
    # "test-vm-2" = { image = "ubuntu:noble" }
  }

  # Общие настройки
  common_config = {
    image = "ubuntu:noble" # Ubuntu 24.04 LTS
    # DNS для машин: dnsmasq на хосте (слушает 0.0.0.0).
    # 192.168.139.3 - адрес Mac в сети OrbStack (bridge100), напрямую
    # доступный машинам без NAT. Подсеть OrbStack фиксирована системой
    # и не настраивается (ни в провайдере, ни в OrbStack).
    domain     = "home"
    dns_server = "192.168.139.3"
  }
}
