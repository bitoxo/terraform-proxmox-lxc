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

resource "proxmox_virtual_environment_download_file" "template" {
  node_name    = var.proxmox_node
  content_type = "vztmpl"
  datastore_id = var.template_datastore_id
  url          = var.template_url
}

module "containers" {
  for_each = local.containers
  source   = "../.."

  node_name        = var.proxmox_node
  template_file_id = proxmox_virtual_environment_download_file.template.id
  proxmox_ssh_host = var.proxmox_host

  # Per-container identity (required in containers.yaml)
  vm_id    = each.value.vm_id
  hostname = each.key

  # Resource sizing — per-container override or module default
  cpu_cores = lookup(each.value, "cpu_cores", 1)
  memory    = lookup(each.value, "memory", 512)
  disk_size = lookup(each.value, "disk_size", 4)
  storage   = lookup(each.value, "storage", var.storage)

  # Network — per-container override or global tfvars value
  ip_address  = each.value.ip_address
  gateway     = lookup(each.value, "gateway", var.gateway)
  dns_servers = lookup(each.value, "dns_servers", var.dns_servers)
  bridge      = lookup(each.value, "bridge", var.bridge)
  vlan_tag    = lookup(each.value, "vlan_tag", var.vlan_tag)

  # Container behaviour — per-container override or module default
  os_type       = lookup(each.value, "os_type", "debian")
  unprivileged  = lookup(each.value, "unprivileged", true)
  nesting       = lookup(each.value, "nesting", true)
  start_on_boot = lookup(each.value, "start_on_boot", true)
  started       = lookup(each.value, "started", true)
  pool_id       = lookup(each.value, "pool_id", "")
  protection    = lookup(each.value, "protection", false)

  # Advanced
  mount_features = lookup(each.value, "mount_features", [])
  mount_points   = lookup(each.value, "mount_points", [])

  # Metadata
  tags        = lookup(each.value, "tags", [])
  description = lookup(each.value, "description", "")

  ssh_public_keys = [var.ssh_public_key]
}
