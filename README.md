# terraform-proxmox-lxc

An OpenTofu/Terraform module for creating **unprivileged LXC containers on Proxmox VE** using the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider — ready for Docker, Ansible, and NFS mounts out of the box.

```hcl
module "jellyfin" {
  source = "github.com/your-username/terraform-proxmox-lxc"

  node_name        = "pve"
  vm_id            = 300
  hostname         = "jellyfin"
  template_file_id = proxmox_virtual_environment_download_file.debian12.id

  cpu_cores       = 2
  memory          = 2048
  ip_address      = "192.168.1.150/24"
  gateway         = "192.168.1.1"
  dns_servers     = ["192.168.1.1"]
  ssh_public_keys = [var.ssh_public_key]
}
```

## Why this module?

Creating a production-ready LXC container with the `bpg/proxmox` provider requires several non-obvious workarounds. This module handles them for you:

| Problem | What this module does |
|---|---|
| Debian 12 templates ship without `openssh-server` | Installs and starts it automatically via `pct exec`, with retry logic |
| API tokens can't set bind-type mount points | Sets `lifecycle { ignore_changes = [mount_point] }` to prevent force-replace |
| `unprivileged = true` is the right default but not obvious | Enabled by default; disable explicitly if you need privileged mode |
| `nesting` must be enabled for Docker-in-LXC | Enabled by default |
| Single DNS server is a common limitation | Accepts a list of DNS servers |

---

## Prerequisites

Before running `terraform apply`, make sure you have:

- [ ] **OpenTofu ≥ 1.0** or **Terraform ≥ 1.0** installed
- [ ] **Proxmox VE 7.x or 8.x** — tested on PVE 8.x
- [ ] **API token** configured on your Proxmox node (see below) — or `root@pam` credentials
- [ ] **SSH public key** available locally (`cat ~/.ssh/id_ed25519.pub`)
- [ ] **`pct` access for SSH bootstrap** — two options:
  - **Simple:** run Terraform directly on your Proxmox node (`ssh root@<proxmox-ip>` then run `tofu apply` there)
  - **Remote:** run Terraform on your laptop and set `proxmox_ssh_host = "<proxmox-ip>"` in your module call. This requires passwordless SSH from your machine to `root@<proxmox-ip>`. Set it up once: `ssh-copy-id root@<proxmox-ip>`

---

## Provider authentication

### Option A — API token (recommended)

Create a dedicated token in the Proxmox UI:

1. **Datacenter → Permissions → API Tokens → Add**
   - User: `root@pam` (or a dedicated user)
   - Token ID: `terraform`
   - Uncheck "Privilege Separation" for simplest setup
2. Copy the displayed secret — it's shown only once
3. Grant the token the following permissions on `/` (Datacenter → Permissions → Add → API Token Permission):
   - `VM.Allocate`, `VM.Clone`, `VM.Config.CDROM`, `VM.Config.CPU`, `VM.Config.Disk`, `VM.Config.HWType`, `VM.Config.Memory`, `VM.Config.Network`, `VM.Config.Options`, `VM.PowerMgmt`, `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Audit`, `Sys.Audit`, `Sys.Exec`

```hcl
provider "proxmox" {
  endpoint  = "https://192.168.1.100:8006"
  api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true  # set false if you have a valid TLS certificate
}
```

### Option B — root@pam (simpler, full admin access)

```hcl
provider "proxmox" {
  endpoint  = "https://192.168.1.100:8006"
  username  = "root@pam"
  password  = var.proxmox_password
  insecure  = true
}
```

---

## Quick start

```bash
git clone https://github.com/your-username/terraform-proxmox-lxc
cd terraform-proxmox-lxc/examples/basic

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox host, API token, and SSH key

terraform init
terraform plan
terraform apply
```

**First apply takes 2–5 minutes** — Proxmox downloads the Debian 12 template (~200 MB) on first use. Subsequent applies skip the download.

---

## Usage

### Single container

```hcl
module "my_service" {
  source = "github.com/your-username/terraform-proxmox-lxc"

  node_name        = "pve"
  vm_id            = 301
  hostname         = "navidrome"
  template_file_id = proxmox_virtual_environment_download_file.debian12.id

  cpu_cores       = 1
  memory          = 512
  disk_size       = 4
  storage         = "local-lvm"

  ip_address      = "192.168.1.151/24"
  gateway         = "192.168.1.1"
  dns_servers     = ["192.168.1.1", "8.8.8.8"]
  ssh_public_keys = [file("~/.ssh/id_ed25519.pub")]

  tags        = ["music"]
  description = "# Navidrome\n\n<a href=\"http://192.168.1.151:4533\">Open</a>"
}
```

### Multiple containers with for_each

```hcl
locals {
  containers = {
    jellyfin  = { vm_id = 300, ip = "192.168.1.150", cpu = 2, memory = 2048 }
    navidrome = { vm_id = 301, ip = "192.168.1.151", cpu = 1, memory = 512  }
    vaultwarden = { vm_id = 302, ip = "192.168.1.152", cpu = 1, memory = 256 }
  }
}

module "containers" {
  for_each = local.containers
  source   = "github.com/your-username/terraform-proxmox-lxc"

  node_name        = "pve"
  vm_id            = each.value.vm_id
  hostname         = each.key
  template_file_id = proxmox_virtual_environment_download_file.debian12.id

  cpu_cores       = each.value.cpu
  memory          = each.value.memory
  ip_address      = "${each.value.ip}/24"
  gateway         = "192.168.1.1"
  dns_servers     = ["192.168.1.1"]
  ssh_public_keys = [file("~/.ssh/id_ed25519.pub")]
}
```

### Running from a remote machine

If Terraform runs on your laptop instead of the Proxmox node, set `proxmox_ssh_host` so the bootstrap provisioner connects via SSH:

```hcl
module "my_container" {
  source = "..."
  # ... other vars ...
  proxmox_ssh_host = "192.168.1.100"  # your Proxmox host IP
}
```

This requires passwordless SSH access from your machine to `root@192.168.1.100`.

---

## Bind-mounts

Bind-mounts (attaching a host directory into the container) cannot be configured via the Proxmox API with a regular API token — only `root@pam` with filesystem access can do this. The recommended approach is to manage bind-mounts separately, for example with Ansible:

```yaml
- name: Add bind-mount
  shell: |
    grep -q "mp0:" /etc/pve/lxc/{{ ct_id }}.conf || \
    pct set {{ ct_id }} --mp0 /opt/data/myservice,mp=/opt/myservice/data
  delegate_to: localhost
```

The `mount_points` variable and `lifecycle { ignore_changes = [mount_point] }` in this module exist to prevent Terraform from force-replacing the container when mounts are managed externally.

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `node_name` | Proxmox node name | `string` | — | yes |
| `vm_id` | Container ID (100–999999999) | `number` | — | yes |
| `hostname` | Container hostname | `string` | — | yes |
| `template_file_id` | CT template resource ID | `string` | — | yes |
| `ssh_public_keys` | SSH public keys for root | `list(string)` | — | yes |
| `dns_servers` | DNS server IPs | `list(string)` | `["8.8.8.8","8.8.4.4"]` | no |
| `os_type` | Template OS type | `string` | `"debian"` | no |
| `storage` | Datastore for root disk | `string` | `"local"` | no |
| `cpu_cores` | CPU cores | `number` | `1` | no |
| `memory` | Memory in MB | `number` | `512` | no |
| `disk_size` | Root disk size in GB | `number` | `4` | no |
| `ip_address` | Static IP with prefix or `"dhcp"` | `string` | `"dhcp"` | no |
| `gateway` | Default gateway (required for static IP) | `string` | `""` | no |
| `bridge` | Network bridge | `string` | `"vmbr0"` | no |
| `description` | Proxmox UI notes (Markdown/HTML) | `string` | `""` | no |
| `tags` | Container tags | `list(string)` | `[]` | no |
| `unprivileged` | Run as unprivileged container | `bool` | `true` | no |
| `nesting` | Enable nesting (needed for Docker) | `bool` | `true` | no |
| `start_on_boot` | Start container on host boot | `bool` | `true` | no |
| `mount_features` | Extra mount features (e.g. `["nfs"]`) | `list(string)` | `[]` | no |
| `mount_points` | Bind-mount definitions (lifecycle-ignored) | `list(object)` | `[]` | no |
| `proxmox_ssh_host` | Proxmox host IP for remote SSH bootstrap | `string` | `""` | no |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | CTID of the created container |
| `hostname` | Hostname |
| `ip_address` | Configured IP address |
| `node_name` | Proxmox node |

---

## Troubleshooting

**`Error: 500 Can't create container`**
→ Check that your API token has `VM.Allocate` and `Datastore.AllocateSpace` permissions on `/`.

**`Error: TLS certificate verification failed`**
→ Set `insecure = true` in the provider block (Proxmox uses a self-signed cert by default).

**SSH bootstrap fails / Ansible can't connect after apply**
→ If `proxmox_ssh_host` is set: ensure passwordless SSH works first: `ssh root@<proxmox-ip> "pct list"`.
→ Install SSH manually on the Proxmox host:
```bash
pct exec <vm_id> -- apt-get install -y openssh-server && pct exec <vm_id> -- systemctl start ssh
```
→ After manual fix, run `terraform apply` again — the container is tainted after a provisioner failure and will be replaced. This is expected Terraform behaviour.

**Template download is slow / times out**
→ The first `terraform apply` downloads the Debian 12 template (~200 MB). This can take several minutes depending on your internet connection. It is cached by Proxmox for subsequent applies.

**`Error: gateway is required when ip_address is a static IP`**
→ You set a static `ip_address` but left `gateway` empty. Add `gateway = "192.168.x.1"`.

**Containers show mount drift in `terraform plan`**
→ Expected. Bind-mounts are managed externally (via `pct set`) and are intentionally ignored in the Terraform lifecycle. This is not a bug.

---

## Requirements

| Tool | Version |
|---|---|
| OpenTofu / Terraform | >= 1.0 |
| bpg/proxmox provider | >= 0.70 |
| Proxmox VE | 7.x / 8.x |

## License

MIT
