terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.proxmox_host}:8006"
  api_token = var.proxmox_api_token
  insecure  = true
}

# ---------------------------------------------------------------------------
# All containers are defined in containers.yaml.
# To add a new container: edit containers.yaml, run terraform apply.
# No HCL changes needed.
# ---------------------------------------------------------------------------
locals {
  containers = yamldecode(file("${path.module}/containers.yaml"))
}

resource "proxmox_virtual_environment_download_file" "debian12" {
  node_name    = var.proxmox_node
  content_type = "vztmpl"
  datastore_id = "local"
  url          = var.debian_template_url
}

module "containers" {
  for_each = local.containers
  source   = "../.."

  node_name        = var.proxmox_node
  template_file_id = proxmox_virtual_environment_download_file.debian12.id
  proxmox_ssh_host = var.proxmox_host

  # Per-container values from containers.yaml
  vm_id       = each.value.vm_id
  hostname    = each.key
  ip_address  = each.value.ip_address
  description = lookup(each.value, "description", "")
  tags        = lookup(each.value, "tags", [])
  protection  = lookup(each.value, "protection", false)

  # Resource sizing — falls back to module defaults if not set in YAML
  cpu_cores = lookup(each.value, "cpu_cores", 1)
  memory    = lookup(each.value, "memory", 512)
  disk_size = lookup(each.value, "disk_size", 4)
  storage   = var.storage

  # Shared network settings for all containers
  gateway         = var.gateway
  dns_servers     = var.dns_servers
  ssh_public_keys = [var.ssh_public_key]
  bridge          = var.bridge
  vlan_tag        = var.vlan_tag
}
