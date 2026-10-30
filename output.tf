# The domain's wait_for_ip already blocks until a DHCP lease exists
data "libvirt_domain_interface_addresses" "vm" {
  for_each = local.hostnames

  domain = libvirt_domain.vm[each.key].name
  source = "lease"
}

output "network_interface" {
  description = "SSH connection commands for each node"
  value = {
    for k, v in data.libvirt_domain_interface_addresses.vm :
    k => "ssh ${v.interfaces[0].addrs[0].addr} -p ${local.ssh_port}"
  }
}
