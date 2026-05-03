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
#   Run: ./scripts/setup-proxmox-token.sh <proxmox-ip>
#
# Option B — root@pam (simpler, full admin access)
#   Replace api_token with: username = "root@pam" / password = var.proxmox_password
# ---------------------------------------------------------------------------
provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:8006"
  api_token = var.proxmox_api_token
  insecure  = true # set false if your Proxmox node has a valid TLS certificate
}

# ---------------------------------------------------------------------------
# Download the LXC template once.
# This takes several minutes on first apply (~200 MB tarball).
# Proxmox skips the download on subsequent applies if the file already exists.
# ---------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "template" {
  node_name    = var.proxmox_node
  content_type = "vztmpl"
  datastore_id = var.template_datastore_id
  url          = var.template_url
}

# ---------------------------------------------------------------------------
# Create a single LXC container using the module.
# All values come from terraform.tfvars — no edits to this file needed.
# ---------------------------------------------------------------------------
module "jellyfin" {
  source = "../.."

  node_name        = var.proxmox_node
  vm_id            = var.vm_id
  hostname         = "jellyfin"
  template_file_id = proxmox_virtual_environment_download_file.template.id

  cpu_cores = 2
  memory    = 2048
  disk_size = 8
  storage   = var.storage

  ip_address      = var.ip_address
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ssh_public_keys = [var.ssh_public_key]

  tags        = ["media"]
  description = "# Jellyfin\n\n<a href=\"http://${split("/", var.ip_address)[0]}:8096\" target=\"_blank\">Open Jellyfin</a>"
  nesting     = true # required for Docker-in-LXC

  # If you run Terraform from your laptop instead of directly on the Proxmox node,
  # uncomment and set this to your Proxmox host IP.
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
