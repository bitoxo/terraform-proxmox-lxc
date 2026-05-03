variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to install in the container"
  type        = string
}
