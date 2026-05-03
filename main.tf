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
  # Package-manager-agnostic SSH bootstrap: tries apt-get (Debian/Ubuntu) first,
  # falls back to apk (Alpine). Safe to run on images that already have SSH.
  _bootstrap_inner = "command -v apt-get && apt-get install -y -q openssh-server && systemctl enable ssh && systemctl start ssh || command -v apk && apk add --no-cache openssh && rc-update add sshd default && rc-service sshd start"

  # If proxmox_ssh_host is set, reach pct via SSH (remote Terraform runs).
  # Otherwise call pct directly (Terraform runs on the Proxmox node itself).
  # When bootstrap_ssh is false the inner command is replaced with a no-op.
  ssh_bootstrap_cmd = var.proxmox_ssh_host != "" ? (
    "ssh -o StrictHostKeyChecking=no root@${var.proxmox_ssh_host} 'pct exec ${var.vm_id} -- sh -c \"${var.bootstrap_ssh ? local._bootstrap_inner : "true"}\"'"
    ) : (
    "pct exec ${var.vm_id} -- sh -c '${var.bootstrap_ssh ? local._bootstrap_inner : "true"}'"
  )
}

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description != "" ? var.description : var.hostname
  tags        = var.tags
  pool_id     = var.pool_id != "" ? var.pool_id : null
  protection  = var.protection

  start_on_boot = var.start_on_boot
  started       = var.started
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
    name    = "eth0"
    bridge  = var.bridge
    vlan_id = var.vlan_tag > 0 ? var.vlan_tag : null
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

  # Installs and starts SSH if not already present (skipped when bootstrap_ssh = false).
  # Retries up to 20 times (60s total) to handle slow container initialization.
  # On persistent failure the container is tainted and will be replaced on next apply.
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 20); do
        ${local.ssh_bootstrap_cmd} && echo "SSH bootstrap succeeded." && exit 0
        echo "Attempt $i/20 failed, retrying in 3s..."
        sleep 3
      done
      echo "ERROR: SSH bootstrap failed after 20 attempts."
      echo "Manual fix: pct exec ${var.vm_id} -- apt-get install -y openssh-server"
      exit 1
    EOT
  }
}
