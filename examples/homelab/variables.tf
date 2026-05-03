variable "proxmox_host" {
  description = "IP or hostname of your Proxmox node."
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name (shown in the sidebar, usually \"pve\")."
  type        = string
  default     = "pve"
}

variable "proxmox_api_token" {
  description = "API token: user@realm!tokenid=UUID"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for root access to all containers."
  type        = string
}

variable "gateway" {
  description = "Default gateway for all containers."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for all containers."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "bridge" {
  description = "Network bridge for all containers."
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN tag for all containers. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "storage" {
  description = "Datastore for all container root disks."
  type        = string
  default     = "local-lvm"
}

variable "debian_template_url" {
  description = "URL of the Debian LXC template. Find current: pveam update && pveam available --section system | grep debian"
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}
