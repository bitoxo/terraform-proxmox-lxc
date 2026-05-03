terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.100:8006"   # your Proxmox host
  username = "root@pam"
  password = var.proxmox_password
  insecure = true                            # set false if you have a valid TLS cert
}

# Download a Debian 12 template once
resource "proxmox_virtual_environment_download_file" "debian12" {
  node_name    = "pve"
  content_type = "vztmpl"
  datastore_id = "local"
  url          = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

# Create a container using the module
module "jellyfin" {
  source = "../.."   # points to the module root when used locally
  # source = "your-github-username/proxmox-lxc/proxmox"  # once published on Terraform Registry

  node_name        = "pve"
  vm_id            = 300
  hostname         = "jellyfin"
  template_file_id = proxmox_virtual_environment_download_file.debian12.id

  cpu_cores  = 2
  memory     = 2048
  disk_size  = 8
  storage    = "local-lvm"

  ip_address      = "192.168.1.150/24"
  gateway         = "192.168.1.1"
  dns_server      = "192.168.1.1"
  ssh_public_keys = [var.ssh_public_key]

  tags        = ["media"]
  description = "# Jellyfin\n\n<a href=\"http://192.168.1.150:8096\" target=\"_blank\">http://192.168.1.150:8096</a>"

  # Enable nesting for Docker-in-LXC
  nesting = true

  # Enable NFS mounts (if you have a NAS)
  mount_features = ["nfs"]
}

output "jellyfin_ip" {
  value = module.jellyfin.ip_address
}
