#!/bin/bash
#
# WireGuard Client Setup Script (for local execution)
# Run this script on your local machine to automate client configuration.
#
# Usage: ./setup-client.sh <server-ip> [client-name] [client-ip]
#

set -e

SERVER_IP="${1}"
CLIENT_NAME="${2:-$(hostname)}"
CLIENT_IP="${3}"
USERNAME="${SSH_USER:-azureuser}"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server-ip> [client-name] [client-ip]"
    echo ""
    echo "Example: $0 20.123.45.67"
    echo "Example: $0 20.123.45.67 my-laptop 10.100.0.3"
    exit 1
fi

echo "=== WireGuard Client Automatic Setup ==="
echo "Server IP: $SERVER_IP"
echo "Client Name: $CLIENT_NAME"
echo "Client IP: ${CLIENT_IP:-Auto-assigned}"
echo ""

# Upload script to server
echo "[1/3] Uploading script to server..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ssh "$USERNAME@$SERVER_IP" "mkdir -p ~/wireguard-scripts"
scp "$SCRIPT_DIR/add-client.sh" "$USERNAME@$SERVER_IP:~/wireguard-scripts/"

# Execute client addition script on server
echo "[2/3] Running client configuration on server..."
ssh "$USERNAME@$SERVER_IP" "sudo bash ~/wireguard-scripts/add-client.sh '$CLIENT_NAME' '$CLIENT_IP'"

# Download configuration file
echo "[3/3] Downloading configuration file..."
mkdir -p ~/wireguard-configs
ssh "$USERNAME@$SERVER_IP" "sudo cat /etc/wireguard/${CLIENT_NAME}.conf" > ~/wireguard-configs/"${CLIENT_NAME}.conf"

echo ""
echo "✓ Setup complete!"
echo ""
echo "=== Configuration File ==="
echo "~/wireguard-configs/${CLIENT_NAME}.conf"
echo ""
echo "=== Next Steps ==="
echo ""
echo "[Desktop (Windows/Mac/Linux)]"
echo "1. Install WireGuard app: https://www.wireguard.com/install/"
echo "2. In the app, click 'Add Tunnel' -> 'Import from file'"
echo "3. Select ~/wireguard-configs/${CLIENT_NAME}.conf"
echo "4. Click 'Activate'"
echo ""
echo "[Smartphone (iOS/Android)]"
echo "Option A - Scan QR Code:"
echo "  ssh $USERNAME@$SERVER_IP 'sudo apt-get install -y qrencode && sudo cat /etc/wireguard/${CLIENT_NAME}.conf | qrencode -t ansiutf8'"
echo "  Scan the displayed QR code with the WireGuard app"
echo ""
echo "Option B - Import File:"
echo "  1. Transfer ~/wireguard-configs/${CLIENT_NAME}.conf to your smartphone"
echo "  2. In the WireGuard app, tap '+' -> 'Create from file or archive'"
echo ""
