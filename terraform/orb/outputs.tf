output "vm_details" {
  value = {
    for name, instance in orbstack_machine.nodes : name => {
      fqdn = "${name}.${local.common_config.domain}"
      ip   = instance.ip_address
      # Проходимся по списку субдоменов и формируем для каждого FQDN
      subdomains_fqdn = [
        for sub in lookup(local.vms[name], "subdomains", []) :
        "${sub}.${name}.${local.common_config.domain}"
      ]
    }
  }
}
