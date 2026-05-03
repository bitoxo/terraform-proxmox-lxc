output "containers" {
  description = "Map of all created containers with their vm_id, hostname, and IP."
  value = {
    for name, mod in module.containers : name => {
      vm_id      = mod.vm_id
      hostname   = mod.hostname
      ip_address = mod.ip_address
      ssh        = mod.ssh_command
    }
  }
}
