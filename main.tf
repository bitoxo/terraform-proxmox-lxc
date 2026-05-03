terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70"
    }
  }
  required_version = ">= 1.0"
}

resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.node_name
  vm_id        = var.vm_id
  description  = var.description != "" ? var.description : var.hostname
  tags         = var.tags

  start_on_boot = true
  started       = true
  unprivileged  = true

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  initialization {
    hostname = var.hostname

    dns {
      servers = [var.dns_server]
    }

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.ip_address == "dhcp" ? null : var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  features {
    nesting = var.nesting
    mount   = length(var.mount_features) > 0 ? var.mount_features : null
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      read_only = mount_point.value.read_only
    }
  }

  # Bind-mounts must be set via `pct set` (the API token lacks permission for bind-type mounts).
  # This prevents Terraform from force-replacing the container on every plan.
  lifecycle {
    ignore_changes = [mount_point]
  }

  # Debian 12 cloud templates ship without openssh-server.
  # This provisioner installs and starts it so Ansible can connect immediately.
  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      pct exec ${var.vm_id} -- bash -c \
        "apt-get install -y -q openssh-server && systemctl enable ssh && systemctl start ssh"
    EOT
  }
}
