variable "node_name" {
  description = "Name of the Proxmox node to create the container on (e.g. \"pve\")."
  type        = string
}

variable "vm_id" {
  description = "Unique container ID (CTID). Must be between 100 and 999999999."
  type        = number
  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "vm_id must be between 100 and 999999999."
  }
}

variable "hostname" {
  description = "Hostname of the container."
  type        = string
}

variable "template_file_id" {
  description = "ID of the CT template resource (e.g. from proxmox_virtual_environment_download_file)."
  type        = string
}

variable "os_type" {
  description = "OS type of the template. Common values: \"debian\", \"ubuntu\", \"alpine\", \"unmanaged\"."
  type        = string
  default     = "debian"
}

variable "storage" {
  description = "Datastore ID for the root disk (e.g. \"local\", \"local-lvm\")."
  type        = string
  default     = "local"
}

variable "cpu_cores" {
  description = "Number of CPU cores."
  type        = number
  default     = 1
  validation {
    condition     = var.cpu_cores >= 1
    error_message = "cpu_cores must be at least 1."
  }
}

variable "memory" {
  description = "Memory in MB."
  type        = number
  default     = 512
  validation {
    condition     = var.memory >= 16
    error_message = "memory must be at least 16 MB."
  }
}

variable "disk_size" {
  description = "Root disk size in GB."
  type        = number
  default     = 4
  validation {
    condition     = var.disk_size >= 1
    error_message = "disk_size must be at least 1 GB."
  }
}

variable "ip_address" {
  description = "Static IP with prefix length (e.g. \"192.168.1.100/24\") or \"dhcp\"."
  type        = string
  default     = "dhcp"
}

variable "gateway" {
  description = "Default gateway IP. Required when ip_address is not \"dhcp\". Ignored when ip_address is \"dhcp\"."
  type        = string
  default     = ""
  validation {
    condition     = var.ip_address == "dhcp" || var.gateway != ""
    error_message = "gateway is required when ip_address is a static IP."
  }
  validation {
    condition     = !(var.ip_address == "dhcp" && var.gateway != "")
    error_message = "gateway must be empty when ip_address is \"dhcp\" — it will be ignored otherwise."
  }
}

variable "bridge" {
  description = "Network bridge to attach the container to (e.g. \"vmbr0\")."
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "List of DNS server IP addresses."
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
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

variable "unprivileged" {
  description = "Run the container as unprivileged (recommended). Disable only if you specifically need privileged mode."
  type        = bool
  default     = true
}

variable "nesting" {
  description = "Enable nesting. Required for running Docker inside the container."
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Automatically start the container when the Proxmox host boots."
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
    Bind-mount point definitions (informational). These are intentionally ignored by Terraform's
    lifecycle because the Proxmox API does not allow API tokens to set bind-type mounts — they
    must be configured via `pct set` on the host (e.g. from an Ansible task). See README for details.
  EOT
  type = list(object({
    volume    = string
    path      = string
    read_only = optional(bool, false)
  }))
  default = []
}

variable "proxmox_ssh_host" {
  description = <<-EOT
    SSH address of the Proxmox host used for the SSH bootstrap provisioner (e.g. \"192.168.1.100\").
    Required when Terraform runs on a different machine than the Proxmox host.
    Leave empty if Terraform runs directly on the Proxmox node.
  EOT
  type    = string
  default = ""
}
