output "vm_details" {
  value = {
    for name, instance in multipass_instance.nodes : name => {
      fqdn = "${name}.${local.common_config.domain}"
      ip   = instance.ipv4[0]
    }
  }
}
