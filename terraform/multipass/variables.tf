variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу, который добавляется на все ВМ"
  type        = string
  # Раскрытие ~ делается через pathexpand() в main.tf
  default = "~/.ssh/id_ed25519.pub"
}

locals {
  # То, что меняется
  vms = {
    # "test-vm-1"           = { cpus = 2, memory = "4G", disk = "25G" }
    # "test-vm-2"           = { cpus = 2, memory = "4G", disk = "25G" }

    # Для тестов VPN
    # "proxy"           = { cpus = 2, memory = "4G", disk = "25G" }
    # "proxy-worker-1"  = { cpus = 2, memory = "4G", disk = "25G" }
    # "nginx"           = { cpus = 2, memory = "4G", disk = "25G" }
    # "client"          = { cpus = 1, memory = "2G", disk = "10G" }

    # Сервисы
    # "gitlab"   = {
    #   cpus        = 4,
    #   memory      = "14G",
    #   disk        = "60G"
    #   subdomains  = ["registry"]
    # }

    # "vault"     = {
    #   cpus        = 1,
    #   memory      = "1G",
    #   disk        = "20G"
    # }

    # "k3s-node"  = {
    #   cpus        = 4,
    #   memory      = "6G",
    #   disk        = "40G",
    #   subdomains  = ["argocd"]
    # }

    # "master" = { cpus = 2, memory = "4G", disk = "40G" }
    # "slave1" = { cpus = 2, memory = "4G", disk = "40G" }
    # "slave2" = { cpus = 2, memory = "4G", disk = "40G" }
  }

  # Общие настройки
  common_config = {
    domain     = "home"
    dns_server = "192.168.1.25"
  }
}
