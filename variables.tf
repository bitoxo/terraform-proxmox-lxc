variable "node_name" {
  description = "Name of the Proxmox node to create the container on."
  type        = string
}

variable "vm_id" {
  description = "Unique container ID (CTID). Must be between 100 and 999999999."
  type        = number
}

variable "hostname" {
  description = "Hostname of the container."
  type        = string
}

variable "template_file_id" {
  description = "ID of the CT template to clone from (e.g. from proxmox_virtual_environment_download_file)."
  type        = string
}

variable "storage" {
  description = "Datastore ID for the root disk."
  type        = string
  default     = "local"
}

variable "cpu_cores" {
  description = "Number of CPU cores."
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory in MB."
  type        = number
  default     = 512
}

variable "disk_size" {
  description = "Root disk size in GB."
  type        = number
  default     = 4
}

variable "ip_address" {
  description = "Static IP address with prefix length (e.g. 192.168.1.100/24) or \"dhcp\"."
  type        = string
  default     = "dhcp"
}

variable "gateway" {
  description = "Default gateway. Required when ip_address is not \"dhcp\"."
  type        = string
  default     = ""
}

variable "bridge" {
  description = "Network bridge to attach the container to."
  type        = string
  default     = "vmbr0"
}

variable "dns_server" {
  description = "DNS server IP address."
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to install for the root user."
  type        = list(string)
}

variable "description" {
  description = "Container description shown in the Proxmox UI (supports Markdown and HTML links). Defaults to hostname."
  type        = string
  default     = ""
}

variable "tags" {
  description = "List of tags to apply to the container."
  type        = list(string)
  default     = []
}

variable "nesting" {
  description = "Enable nesting. Required for running Docker inside the container."
  type        = bool
  default     = true
}

variable "mount_features" {
  description = "Additional mount features to enable (e.g. [\"nfs\"] or [\"nfs\", \"cifs\"])."
  type        = list(string)
  default     = []
}

variable "mount_points" {
  description = <<-EOT
    Bind-mount points to attach to the container. Note: these are intentionally ignored by
    Terraform's lifecycle (see main.tf) because the Proxmox API does not allow bind-type mounts
    via API tokens — they must be set via `pct set` on the host directly.
  EOT
  type = list(object({
    volume    = string
    path      = string
    read_only = optional(bool, false)
  }))
  default = []
}
