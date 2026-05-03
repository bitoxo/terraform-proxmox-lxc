# terraform-proxmox-lxc

An OpenTofu/Terraform module for creating **unprivileged LXC containers on Proxmox VE** using the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) provider — ready for Docker, Ansible, and NFS mounts out of the box.

```hcl
module "jellyfin" {
  source = "github.com/bitoxo/terraform-proxmox-lxc"

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

## Scaling to many containers

For a full homelab with multiple containers, use the [`examples/homelab/`](examples/homelab/) setup. Define all containers in a single YAML file — adding a new container requires no HCL changes:

```yaml
# containers.yaml — add a line, run terraform apply, done.
jellyfin:
  vm_id:     300
  ip_address: "192.168.1.150/24"
  cpu_cores:  2
  memory:     2048

navidrome:
  vm_id:     301
  ip_address: "192.168.1.151/24"   # cpu/memory fall back to module defaults
```

```bash
cd examples/homelab
cp terraform.tfvars.example terraform.tfvars  # fill in once
terraform apply                               # creates all containers in parallel
```

---

## Why this module?

**The real reasons — not marketing:**

**YAML-driven scaling.** The homelab example lets you manage every container from a single `containers.yaml`. Adding a new container is two lines. No HCL changes, no copy-pasting resource blocks, no drift between containers.

**One command to get a working API token.** The `setup-proxmox-token.sh` script handles the part that trips up every first-time bpg/proxmox user — creating a token with the right permissions. Most people spend 30 minutes on this.

**Run Terraform from your laptop.** The `proxmox_ssh_host` variable wires up the SSH bootstrap provisioner for remote runs without any changes to the module itself. The provider handles the API; `pct exec` for SSH setup is routed via SSH automatically.

**Input validation that catches real mistakes.** Static IP without a gateway errors immediately at plan time. `vm_id` out of range, invalid VLAN tag — all caught before Proxmox sees the request.

**One known workaround pre-applied.** Bind-type mount points cannot be set via API token — the Proxmox API rejects them. Without `lifecycle { ignore_changes = [mount_point] }`, Terraform force-replaces the container every time you run plan after adding a bind-mount manually. This module sets that for you.

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

The easiest way is the included setup script — it SSHs to your Proxmox node and creates the token for you:

```bash
./scripts/setup-proxmox-token.sh 192.168.1.100
```

Output:
```
✓ Token created: root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Add to your terraform.tfvars:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  proxmox_host      = "192.168.1.100"
  proxmox_api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  ssh_public_key    = "ssh-ed25519 AAAA..."
```

**Requirements:** SSH access as `root` to the Proxmox node (i.e. `ssh root@192.168.1.100` works). The script uses `pveum` which ships with Proxmox — no installation needed.

Then use the token in your provider block:

```hcl
provider "proxmox" {
  endpoint  = "https://192.168.1.100:8006"
  api_token = "root@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  insecure  = true  # set false if you have a valid TLS certificate
}
```

<details>
<summary>Manual token creation (if you prefer the Proxmox UI)</summary>

1. **Datacenter → Permissions → API Tokens → Add**
   - User: `root@pam`, Token ID: `terraform`, uncheck "Privilege Separation"
2. Copy the displayed secret — it's shown only once
3. Grant the token permissions on `/` (Datacenter → Permissions → Add → API Token Permission):
   `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Audit`, `Sys.Audit`, `Sys.Exec`

</details>

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
git clone https://github.com/bitoxo/terraform-proxmox-lxc
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
  source = "github.com/bitoxo/terraform-proxmox-lxc"

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
  source   = "github.com/bitoxo/terraform-proxmox-lxc"

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
| `started` | Container running state after create | `bool` | `true` | no |
| `protection` | Prevent accidental deletion | `bool` | `false` | no |
| `pool_id` | Resource pool to assign container to | `string` | `""` | no |
| `vlan_tag` | VLAN tag (0 = disabled) | `number` | `0` | no |
| `mount_features` | Extra mount features (e.g. `["nfs"]`) | `list(string)` | `[]` | no |
| `mount_points` | Bind-mount definitions (not applied by Terraform — see Bind-mounts) | `list(object)` | `[]` | no |
| `proxmox_ssh_host` | Proxmox host IP for remote SSH bootstrap | `string` | `""` | no |
| `bootstrap_ssh` | Install+start SSH after creation (set false if image already has SSH) | `bool` | `true` | no |

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
→ After a provisioner failure, the container is **tainted** — `terraform apply` will **destroy and recreate it**. This is expected Terraform behavior. Make sure your data is not in the container before re-applying.
→ If your template already ships with SSH, set `bootstrap_ssh = false` to skip the provisioner entirely.

**Template download is slow / times out**
→ The first `terraform apply` downloads the LXC template (~100–200 MB). This can take several minutes. It is cached by Proxmox for subsequent applies.

**`Error: gateway is required when ip_address is a static IP`**
→ You set a static `ip_address` but left `gateway` empty. Add `gateway = "192.168.x.1"`.

**Containers show mount drift in `terraform plan`**
→ Expected. Bind-mounts are managed externally (via `pct set`) and are intentionally ignored in the Terraform lifecycle. This is not a bug.

**Using Terraform Cloud or a remote backend?**
→ The SSH bootstrap uses a `local-exec` provisioner, which runs on the Terraform runner — not your laptop. In Terraform Cloud, the runner cannot reach your Proxmox node unless you configure a self-hosted agent or a network tunnel. If you use a remote backend, run Terraform locally or via a machine that has network access to Proxmox.

**Proxmox VE version compatibility**
→ Tested on PVE 8.x. PVE 7.x should work but is untested — API token handling and LXC features are essentially the same. If you hit issues on 7.x, please open an issue.

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

This module was designed and developed with the assistance of [Claude](https://claude.ai) (Anthropic). AI was used throughout the process:

- Architecture and module design decisions
- Code generation and review (HCL, Bash)
- Documentation and README copy
- Multi-round review for usability, correctness, and edge cases

All generated code was reviewed and tested by the author. The module reflects real-world homelab use cases and operational experience with Proxmox VE.
