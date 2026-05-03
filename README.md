# terraform-proxmox-lxc

OpenTofu/Terraform module for creating unprivileged LXC containers on Proxmox VE using the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider.

```hcl
module "jellyfin" {
  source = "github.com/bitoxo/terraform-proxmox-lxc"

  node_name        = "pve"
  vm_id            = 300
  hostname         = "jellyfin"
  template_file_id = proxmox_virtual_environment_download_file.template.id

  cpu_cores       = 2
  memory          = 2048
  ip_address      = "192.168.1.150/24"
  gateway         = "192.168.1.1"
  ssh_public_keys = [var.ssh_public_key]
}
```

## Managing multiple containers

Use [`examples/homelab/`](examples/homelab/) to manage all containers from a single YAML file — no HCL changes needed to add or remove a container:

```yaml
# containers.yaml
jellyfin:
  vm_id:     300
  ip_address: "192.168.1.150/24"
  cpu_cores:  2
  memory:     2048

navidrome:
  vm_id:     301
  ip_address: "192.168.1.151/24"
  nesting:    false   # per-container override
```

```bash
cd examples/homelab
cp terraform.tfvars.example terraform.tfvars
tofu apply
```

---

## Why this module?

**YAML-driven scaling.** Define every container in `containers.yaml`. Adding a new container is two lines. No HCL copy-paste, no drift.

**One-command API token setup.** `setup-proxmox-token.sh` creates the Proxmox token with the right permissions via SSH — the step that trips up most first-time users.

**Remote Terraform runs.** Set `proxmox_ssh_host` to run Terraform from your laptop. The SSH bootstrap provisioner routes through Proxmox automatically — no manual wiring needed.

**Input validation.** Static IP without gateway, `vm_id` out of range, invalid VLAN tag — all caught at `plan` time before Proxmox sees the request.

**Bind-mount protection.** API tokens can't set bind-type mounts; Proxmox rejects them. Without `lifecycle { ignore_changes = [mount_point] }`, Terraform would force-replace the container on every `plan` after you add a manual bind-mount. This module handles that silently.

---

## Quick start

```bash
# 1. Create API token (requires SSH access to Proxmox as root)
./scripts/setup-proxmox-token.sh 192.168.1.100

# 2. Deploy the basic example
cd examples/basic
cp terraform.tfvars.example terraform.tfvars  # fill in host, token, SSH key, vm_id, ip, gateway
tofu init && tofu apply
```

First apply downloads the LXC template (~200 MB) — subsequent applies skip this.

> **Running from your laptop?** Set `proxmox_ssh_host = "192.168.1.100"` in `terraform.tfvars`. Without it, the SSH bootstrap provisioner can't reach `pct` on the Proxmox host and will fail.

---

## Provider authentication

### API token (recommended)

```bash
./scripts/setup-proxmox-token.sh 192.168.1.100
# Prints ready-to-paste terraform.tfvars values
```

Requires `ssh root@192.168.1.100` to work. Uses `pveum` which ships with Proxmox.

```hcl
provider "proxmox" {
  endpoint  = "https://192.168.1.100:8006"
  api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true  # set false if you have a valid TLS certificate
}
```

<details>
<summary>Manual token creation via Proxmox UI</summary>

1. **Datacenter → Permissions → API Tokens → Add**
   - User: `root@pam`, Token ID: `terraform`, uncheck "Privilege Separation"
2. Copy the secret — shown only once
3. Grant the token permissions on `/`:
   `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Audit`, `Sys.Audit`, `Sys.Exec`

</details>

### root@pam (simpler, full admin)

```hcl
provider "proxmox" {
  endpoint = "https://192.168.1.100:8006"
  username = "root@pam"
  password = var.proxmox_password
  insecure = true
}
```

---

## Inputs

| Name | Type | Default | Required | Description |
|---|---|---|---|---|
| `node_name` | `string` | — | yes | Proxmox node name |
| `vm_id` | `number` | — | yes | Container ID (100–999999999) |
| `hostname` | `string` | — | yes | Container hostname |
| `template_file_id` | `string` | — | yes | CT template resource ID |
| `ssh_public_keys` | `list(string)` | — | yes | SSH public keys for root |
| `cpu_cores` | `number` | `1` | no | CPU cores |
| `memory` | `number` | `512` | no | Memory in MB |
| `disk_size` | `number` | `4` | no | Root disk size in GB |
| `storage` | `string` | `"local"` | no | Datastore for root disk |
| `ip_address` | `string` | `"dhcp"` | no | Static IP with prefix or `"dhcp"` |
| `gateway` | `string` | `""` | no | Default gateway (required for static IP) |
| `dns_servers` | `list(string)` | `["8.8.8.8","8.8.4.4"]` | no | DNS servers |
| `bridge` | `string` | `"vmbr0"` | no | Network bridge |
| `vlan_tag` | `number` | `0` | no | VLAN tag (0 = disabled) |
| `os_type` | `string` | `"debian"` | no | OS type (`debian`, `ubuntu`, `alpine`, `unmanaged`) |
| `unprivileged` | `bool` | `true` | no | Run as unprivileged container |
| `nesting` | `bool` | `true` | no | Enable nesting (required for Docker) |
| `start_on_boot` | `bool` | `true` | no | Start on Proxmox host boot |
| `started` | `bool` | `true` | no | Start container after creation |
| `protection` | `bool` | `false` | no | Prevent accidental deletion |
| `pool_id` | `string` | `""` | no | Resource pool |
| `mount_features` | `list(string)` | `[]` | no | Mount features (e.g. `["nfs"]`) |
| `mount_points` | `list(object)` | `[]` | no | Bind-mount definitions (not applied by Terraform — see below) |
| `tags` | `list(string)` | `[]` | no | Container tags |
| `description` | `string` | `""` | no | Proxmox UI description (Markdown/HTML) |
| `proxmox_ssh_host` | `string` | `""` | no | Proxmox host IP for remote SSH bootstrap |
| `bootstrap_ssh` | `bool` | `true` | no | Install SSH after creation (set false if image already has SSH) |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | Container ID |
| `hostname` | Hostname |
| `ip_address` | Configured IP address |
| `node_name` | Proxmox node |
| `ssh_command` | Ready-to-use SSH command |

---

## Bind-mounts

API tokens cannot configure bind-type mounts — Proxmox rejects them. Manage bind-mounts via `pct set` on the host (e.g. in an Ansible task):

```bash
grep -q "mp0:" /etc/pve/lxc/<ct_id>.conf || \
  pct set <ct_id> --mp0 /host/path,mp=/container/path
```

The `mount_points` variable exists for documentation. `lifecycle { ignore_changes = [mount_point] }` prevents Terraform from force-replacing the container when mounts are managed externally.

---

## Troubleshooting

**`Error: 500 Can't create container`**
→ API token missing `VM.Allocate` or `Datastore.AllocateSpace` on `/`.

**`Error: TLS certificate verification failed`**
→ Set `insecure = true` in the provider block (Proxmox uses a self-signed cert by default).

**SSH bootstrap fails**
→ Verify `ssh root@<proxmox-ip> "pct list"` works first.
→ On failure, the container is **tainted** — next `tofu apply` will destroy and recreate it.
→ Manual fix: `pct exec <vm_id> -- apt-get install -y openssh-server`
→ If your template already has SSH: set `bootstrap_ssh = false`.

**Containers show mount drift in `tofu plan`**
→ Expected — bind-mounts are managed externally and intentionally ignored.

**Terraform Cloud / remote backends**
→ `local-exec` runs on the Terraform runner. In Terraform Cloud, the runner can't reach your Proxmox node without a self-hosted agent or tunnel. Run Terraform locally instead.

**PVE 7.x**
→ Tested on PVE 8.x. PVE 7.x should work but is untested.

---

## Requirements

| Tool | Version |
|---|---|
| OpenTofu / Terraform | >= 1.0 |
| bpg/proxmox provider | >= 0.70 |
| Proxmox VE | 7.x / 8.x |

## License

MIT

---

## Contributors

<a href="https://github.com/bitoxo/terraform-proxmox-lxc/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=bitoxo/terraform-proxmox-lxc" />
</a>

---

## AI Disclosure

Designed and built with [Claude](https://claude.ai) (Anthropic) — architecture, code generation, review, and documentation. All output reviewed and tested by the author.
