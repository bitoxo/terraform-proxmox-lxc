terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider authentication
#
# Option A — API token (recommended, least privilege)
#   Create a token in Proxmox UI: Datacenter → Permissions → API Tokens
#   Required token privileges: VM.Allocate, VM.Config.*, Datastore.AllocateSpace,
#   Sys.Exec (for pct exec, or run Terraform directly on the Proxmox node)
#
# Option B — root@pam (simpler, but full admin access)
#   Replace api_token with: username = "root@pam" / password = var.proxmox_password
# ---------------------------------------------------------------------------
provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:8006"
  api_token = var.proxmox_api_token
  insecure  = true   # set false if your Proxmox node has a valid TLS certificate
}

# ---------------------------------------------------------------------------
# Download the Debian 12 template once.
# This takes several minutes on first apply (the tarball is ~200 MB).
# On subsequent applies Proxmox skips the download if the file already exists.
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "debian12" {
  node_name    = var.proxmox_node
  content_type = "vztmpl"
  datastore_id = "local"
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

# ---------------------------------------------------------------------------
# Create a single LXC container using the module.
# ---------------------------------------------------------------------------
module "jellyfin" {
  source = "../.."

  node_name        = var.proxmox_node
  vm_id            = 300
  hostname         = "jellyfin"
  template_file_id = proxmox_virtual_environment_download_file.debian12.id

  cpu_cores  = 2
  memory     = 2048
  disk_size  = 8
  storage    = "local-lvm"

  ip_address      = "192.168.1.150/24"
  gateway         = "192.168.1.1"
  dns_servers     = ["192.168.1.1"]
  ssh_public_keys = [var.ssh_public_key]

  tags        = ["media"]
  description = "# Jellyfin\n\n<a href=\"http://192.168.1.150:8096\" target=\"_blank\">http://192.168.1.150:8096</a>"
  nesting     = true   # required for Docker-in-LXC

  # If you run Terraform from your laptop instead of directly on the Proxmox node,
  # set this to your Proxmox host IP so the SSH bootstrap provisioner can reach it.
  # proxmox_ssh_host = var.proxmox_host
}

output "container_ip" {
  description = "IP address of the created container."
  value       = module.jellyfin.ip_address
}

output "ssh_command" {
  description = "SSH command to connect to the container."
  value       = "ssh root@${module.jellyfin.ip_address}"
}
