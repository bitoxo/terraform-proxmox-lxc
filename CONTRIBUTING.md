# Contributing

Contributions are welcome. This is a homelab-focused module, so practical fixes and real-world improvements are valued over theoretical completeness.

## What makes a good contribution

- **Bug fixes** — something that breaks for a real Proxmox setup
- **Compatibility** — tested on a PVE version, OS template, or provider version not yet covered
- **Documentation** — clearer explanations, better troubleshooting steps, corrected outdated info
- **Example improvements** — edge cases that trip people up in practice

## What doesn't fit

- Features that only apply to a single user's setup
- Application-level container config (Docker Compose, service setup) — that belongs in Ansible or separate tooling
- Complexity for its own sake

## How to contribute

1. **Open an issue first** for anything non-trivial — aligning on the approach before writing code saves everyone time
2. Fork, branch, make your change
3. Run `tofu fmt -recursive` before committing
4. Open a PR with a short description of what and why

## Running the checks locally

```bash
tofu fmt -recursive
tofu validate
cd examples/basic  && tofu init -backend=false && tofu validate
cd examples/homelab && tofu init -backend=false && tofu validate
```

These are the same checks CI runs on every push.
