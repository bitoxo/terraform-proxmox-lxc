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
  description = "SSH public key to install in all containers for root access."
  type        = string
}

variable "gateway" {
  description = "Default gateway for all containers (can be overridden per container in containers.yaml)."
  type        = string
}

variable "dns_servers" {
  description = "Default DNS servers for all containers (can be overridden per container in containers.yaml)."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "bridge" {
  description = "Default network bridge for all containers (can be overridden per container in containers.yaml)."
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "Default VLAN tag for all containers. Set to 0 to disable (can be overridden per container in containers.yaml)."
  type        = number
  default     = 0
}

variable "storage" {
  description = "Default datastore for container root disks (can be overridden per container in containers.yaml)."
  type        = string
  default     = "local-lvm"
}

variable "template_url" {
  description = <<-EOT
    URL of the LXC template to download.
    Find current URLs at: https://images.linuxcontainers.org/images/debian/
    or on your Proxmox node: pveam update && pveam available --section system | grep debian
  EOT
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "template_datastore_id" {
  description = "Datastore where the LXC template is stored (e.g. \"local\", \"local-zfs\"). Must support the \"vztmpl\" content type."
  type        = string
  default     = "local"
}
