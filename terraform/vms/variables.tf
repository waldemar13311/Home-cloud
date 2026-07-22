locals {
  # То, что меняется
  vms = {
    "gitlab"    = {
      cpus    = 4,
      memory  = "14G",
      disk    = "60G"
      subdomains  = ["registry"]
    }
    // "vault"     = { cpus = 1, memory = "1G",  disk = "20G" }
    # "k3s-node"  = {
    #   cpus        = 4,
    #   memory      = "6G",
    #   disk        = "40G",
    #   subdomains  = ["argocd"]
    # }
    # "nginx"     = { cpus = 2, memory = "4G", disk = "25G" }


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
