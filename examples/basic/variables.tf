variable "proxmox_host" {
  description = "IP or hostname of your Proxmox node (e.g. \"192.168.1.100\")."
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name (visible in the Proxmox UI sidebar, usually \"pve\")."
  type        = string
  default     = "pve"
}

variable "proxmox_api_token" {
  description = "API token in the format: user@realm!tokenid=UUID (e.g. \"root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\")."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to install in the container for root access."
  type        = string
}

variable "debian_template_url" {
  description = <<-EOT
    URL of the Debian LXC template to download.
    Find current URLs at: https://images.linuxcontainers.org/images/debian/
    or on your Proxmox node: pveam update && pveam available --section system | grep debian
  EOT
  type    = string
  default = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}
