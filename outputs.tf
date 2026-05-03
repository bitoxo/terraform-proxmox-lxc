output "vm_id" {
  description = "The CTID of the created container."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "hostname" {
  description = "Hostname of the container."
  value       = proxmox_virtual_environment_container.this.initialization[0].hostname
}

output "ip_address" {
  description = "Configured IP address (static or 'dhcp')."
  value       = var.ip_address
}

output "node_name" {
  description = "Proxmox node the container was created on."
  value       = proxmox_virtual_environment_container.this.node_name
}
