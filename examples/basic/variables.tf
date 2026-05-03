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

variable "vm_id" {
  description = "Container ID (CTID). Must be unique on your Proxmox node."
  type        = number
  default     = 300
}

variable "ip_address" {
  description = "Static IP with prefix length (e.g. \"192.168.1.100/24\") or \"dhcp\"."
  type        = string
  default     = "dhcp"
}

variable "gateway" {
  description = "Default gateway. Required when ip_address is a static IP."
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS server IPs."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "storage" {
  description = "Datastore for the container root disk (e.g. \"local\", \"local-lvm\", \"local-zfs\")."
  type        = string
  default     = "local-lvm"
}

variable "template_url" {
  description = <<-EOT
    URL of the Debian LXC template to download.
    Find current URLs at: https://images.linuxcontainers.org/images/debian/
    or on your Proxmox node: pveam update && pveam available --section system | grep debian
  EOT
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "proxmox_ssh_host" {
  description = "Proxmox host IP for SSH bootstrap (required when running Terraform from your laptop). Leave empty if running Terraform directly on the Proxmox node."
  type        = string
  default     = ""
}

variable "template_datastore_id" {
  description = "Datastore where the LXC template is stored (e.g. \"local\", \"local-zfs\"). Must support the \"vztmpl\" content type."
  type        = string
  default     = "local"
}
