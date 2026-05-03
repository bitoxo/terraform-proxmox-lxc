terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.70"
    }
  }
  required_version = ">= 1.0"
}

locals {
  # If proxmox_ssh_host is set, run pct exec via SSH (for remote Terraform runs).
  # Otherwise run pct exec directly (Terraform runs on the Proxmox node itself).
  ssh_bootstrap_cmd = var.proxmox_ssh_host != "" ? (
    "ssh -o StrictHostKeyChecking=no root@${var.proxmox_ssh_host} 'pct exec ${var.vm_id} -- bash -c \"apt-get install -y -q openssh-server && systemctl enable ssh && systemctl start ssh\"'"
  ) : (
    "pct exec ${var.vm_id} -- bash -c 'apt-get install -y -q openssh-server && systemctl enable ssh && systemctl start ssh'"
  )
}

resource "proxmox_virtual_environment_container" "this" {
  node_name    = var.node_name
  vm_id        = var.vm_id
  description  = var.description != "" ? var.description : var.hostname
  tags         = var.tags

  start_on_boot = var.start_on_boot
  started       = true
  unprivileged  = var.unprivileged

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  initialization {
    hostname = var.hostname

    dns {
      servers = var.dns_servers
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

  # Bind-mounts must be managed via `pct set` on the host because the Proxmox API
  # does not allow API tokens to configure bind-type mount points. This lifecycle
  # rule prevents Terraform from force-replacing the container due to mount drift.
  lifecycle {
    ignore_changes = [mount_point]
  }

  # Debian 12 (and most standard LXC templates) ship without openssh-server.
  # This provisioner installs it so the container is immediately reachable via SSH.
  # Retries up to 10 times (30s total) to handle slow container initialization.
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 10); do
        ${local.ssh_bootstrap_cmd} && echo "SSH bootstrap succeeded." && exit 0
        echo "Attempt $i/10 failed, retrying in 3s..."
        sleep 3
      done
      echo "ERROR: SSH bootstrap failed after 10 attempts."
      echo "Manual fix: pct exec ${var.vm_id} -- apt-get install -y openssh-server"
      exit 1
    EOT
  }
}
