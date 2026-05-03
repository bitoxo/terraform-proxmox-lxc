#!/usr/bin/env bash
# Creates a Proxmox API token with the required permissions and prints
# the ready-to-use terraform.tfvars snippet.
#
# Usage:
#   ./scripts/setup-proxmox-token.sh <proxmox-host>
#   ./scripts/setup-proxmox-token.sh 192.168.1.100
#
# Requirements:
#   - SSH access as root to your Proxmox node
#   - pveum (ships with Proxmox, no install needed)

set -euo pipefail

PROXMOX_HOST="${1:-}"
TOKEN_ID="terraform"
USER="root@pam"

if [[ -z "$PROXMOX_HOST" ]]; then
  echo "Usage: $0 <proxmox-host>"
  echo "  e.g. $0 192.168.1.100"
  exit 1
fi

echo "→ Connecting to ${PROXMOX_HOST} ..."
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"${PROXMOX_HOST}" true 2>/dev/null \
  || { echo "ERROR: Cannot SSH into root@${PROXMOX_HOST}. Check your SSH key / network."; exit 1; }

echo "→ Creating API token '${TOKEN_ID}' for ${USER} ..."

# Create token (--privsep 0 = same privileges as the user, no separate ACL needed)
TOKEN_OUTPUT=$(ssh root@"${PROXMOX_HOST}" \
  "pveum user token add ${USER} ${TOKEN_ID} --privsep 0 2>&1 || true")

# Extract UUID from output (format: "value │ <uuid>")
TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)

if [[ -z "$TOKEN_SECRET" ]]; then
  # Token may already exist — delete and recreate
  echo "→ Token already exists, recreating ..."
  ssh root@"${PROXMOX_HOST}" "pveum user token remove ${USER} ${TOKEN_ID} 2>/dev/null || true"
  TOKEN_OUTPUT=$(ssh root@"${PROXMOX_HOST}" \
    "pveum user token add ${USER} ${TOKEN_ID} --privsep 0")
  TOKEN_SECRET=$(echo "$TOKEN_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
fi

if [[ -z "$TOKEN_SECRET" ]]; then
  echo "ERROR: Could not extract token secret. Raw output:"
  echo "$TOKEN_OUTPUT"
  exit 1
fi

API_TOKEN="${USER}!${TOKEN_ID}=${TOKEN_SECRET}"

echo ""
echo "✓ Token created: ${API_TOKEN}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Add to your terraform.tfvars:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  proxmox_host      = \"${PROXMOX_HOST}\""
echo "  proxmox_api_token = \"${API_TOKEN}\""
echo "  ssh_public_key    = \"\$(cat ~/.ssh/id_ed25519.pub)\""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NOTE: This token uses root@pam with --privsep 0 (full admin)."
echo "      Fine for a homelab. For production, create a dedicated"
echo "      user with least-privilege permissions (see README)."
