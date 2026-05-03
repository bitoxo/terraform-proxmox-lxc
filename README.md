# terraform-proxmox-lxc

A Terraform/OpenTofu module for creating unprivileged LXC containers on Proxmox VE using the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider.

## Why this module?

The `bpg/proxmox` provider is the recommended provider for Proxmox VE (the older Telmate provider has compatibility issues with PVE 8.x), but creating production-ready LXC containers requires a handful of non-obvious workarounds:

- **SSH bootstrap**: Debian 12 cloud templates ship without `openssh-server`. This module installs and starts it automatically via `pct exec` so Ansible (or any other provisioner) can connect immediately after `terraform apply`.
- **Bind-mount lifecycle**: The Proxmox API does not allow API tokens to set `bind`-type mount points — only `root@pam` can. This module sets `lifecycle { ignore_changes = [mount_point] }` so Terraform doesn't force-replace containers when bind-mounts are managed externally (e.g. via `pct set` in Ansible).
- **Unprivileged by default**: All containers are created unprivileged (`unprivileged = true`). UID mapping (`container UID 0 = host UID 100000`) is the correct security posture for Docker-in-LXC setups.
- **Nesting enabled by default**: Required for running Docker inside an LXC container.

## Requirements

| Tool | Version |
|------|---------|
| OpenTofu / Terraform | >= 1.0 |
| bpg/proxmox provider | >= 0.70 |
| Proxmox VE | 8.x recommended |

## Usage

```hcl
module "my_container" {
  source = "github.com/your-username/terraform-proxmox-lxc"

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

  tags   = ["media"]
  nesting = true
}
```

See [`examples/basic/`](examples/basic/) for a full working example including provider configuration and a Debian 12 template download.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `node_name` | Proxmox node name | `string` | — | yes |
| `vm_id` | Container ID (CTID) | `number` | — | yes |
| `hostname` | Container hostname | `string` | — | yes |
| `template_file_id` | CT template resource ID | `string` | — | yes |
| `dns_server` | DNS server IP | `string` | — | yes |
| `ssh_public_keys` | SSH public keys for root | `list(string)` | — | yes |
| `storage` | Datastore for root disk | `string` | `"local"` | no |
| `cpu_cores` | Number of CPU cores | `number` | `1` | no |
| `memory` | Memory in MB | `number` | `512` | no |
| `disk_size` | Root disk size in GB | `number` | `4` | no |
| `ip_address` | Static IP with prefix or `"dhcp"` | `string` | `"dhcp"` | no |
| `gateway` | Default gateway | `string` | `""` | no |
| `bridge` | Network bridge | `string` | `"vmbr0"` | no |
| `description` | Proxmox UI notes (Markdown/HTML) | `string` | `""` | no |
| `tags` | Container tags | `list(string)` | `[]` | no |
| `nesting` | Enable nesting (needed for Docker) | `bool` | `true` | no |
| `mount_features` | Extra mount features e.g. `["nfs"]` | `list(string)` | `[]` | no |
| `mount_points` | Bind-mount definitions (lifecycle-ignored) | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vm_id` | CTID of the created container |
| `hostname` | Hostname |
| `ip_address` | Configured IP address |
| `node_name` | Proxmox node |

## Bind-mounts

Bind-mounts (host path → container path) cannot be set via the Proxmox API with a regular API token. Manage them with `pct set` directly on the Proxmox host — for example via an Ansible task:

```yaml
- name: Add bind-mount
  command: >
    pct set {{ ct_id }} --mp0
    /opt/data/myservice,mp=/opt/myservice/data
  delegate_to: localhost
  when: not mount_exists.stdout
```

The module's `mount_points` variable and the `lifecycle { ignore_changes }` block exist for documentation purposes and to prevent Terraform from destroying containers when mounts are managed externally.

## Running Docker inside LXC

This module creates unprivileged containers with nesting enabled — the correct setup for Docker-in-LXC. After provisioning, install Docker normally inside the container. No additional LXC config changes are needed for basic usage.

For GPU passthrough (e.g. for hardware transcoding), additional host-level `lxc.cgroup2.devices.allow` and `lxc.mount.entry` config is required — see the Proxmox documentation.

## License

MIT
