#!/bin/bash
#
# WireGuard Client Addition Script
# Run on the server side to automatically configure a new client
#
# Usage: ./add-client.sh <client-name> [client-ip]
#

set -e

# Root privilege check (must be first — file access requires root)
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with root privileges"
   echo "sudo $0 $@"
   exit 1
fi

CLIENT_NAME="${1:-client1}"
WG_INTERFACE="wg0"
CONFIG_DIR="/etc/wireguard"

SERVER_PUBLIC_IP=$(curl -s https://ifconfig.me)
SERVER_PORT="51820"

# Generate client key pair (independent of IP, so done before acquiring the lock)
echo "[1/4] Generating client key pair..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Get server public key
echo "[2/4] Retrieving server information..."
SERVER_PUBLIC_KEY=$(cat "$CONFIG_DIR/server_public.key")

# Acquire exclusive lock to prevent IP collisions when multiple clients are added simultaneously.
# The lock is held until wg-quick saves the updated config, after which the next invocation
# will see the new peer and correctly increment from it.
exec 200>"$CONFIG_DIR/.add-client.lock"
flock -x 200

# Automatically determine the next available IP if not provided
if [ -z "$2" ]; then
    echo "No IP provided, searching for the next available IP..."
    # Read used IPs directly from the config file (reliable even when wg0 is down)
    LAST_IP=$(grep -o "10\.100\.0\.[0-9]\+" "$CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null \
        | cut -d. -f4 | sort -n | tail -1 || echo "")
    if [ -z "$LAST_IP" ]; then
        # No peers in config yet; start with .2 (server is .1)
        CLIENT_IP="10.100.0.2"
    else
        NEXT_OCTET=$((LAST_IP + 1))
        if [ "$NEXT_OCTET" -gt 254 ]; then
            echo "Error: No available IPs left in 10.100.0.0/24 (all .2-.254 are used)"
            exit 1
        fi
        CLIENT_IP="10.100.0.$NEXT_OCTET"
    fi
    echo "Next available IP found: $CLIENT_IP"
else
    CLIENT_IP="$2"
fi

echo "=== WireGuard Client Configuration ==="
echo "Client Name: $CLIENT_NAME"
echo "Client IP: $CLIENT_IP/32"
echo ""

# Add peer to server
echo "[3/4] Adding client to server..."
wg set "$WG_INTERFACE" peer "$CLIENT_PUBLIC_KEY" allowed-ips "$CLIENT_IP/32"
wg-quick save "$WG_INTERFACE"

# Release lock after config is saved — the next concurrent invocation can now safely proceed
flock -u 200

# Generate client config file
echo "[4/4] Generating client configuration file..."
CLIENT_CONFIG_PATH="$CONFIG_DIR/${CLIENT_NAME}.conf"

cat > "$CLIENT_CONFIG_PATH" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONFIG_PATH"

echo ""
echo "✓ Client configuration complete!"
echo ""
echo "=== Configuration File Location ==="
echo "$CLIENT_CONFIG_PATH"
echo ""
echo "=== Next Steps ==="
echo "1. Download the configuration file to your local machine:"
echo "   ssh azureuser@$SERVER_PUBLIC_IP 'sudo cat $CLIENT_CONFIG_PATH' > ~/${CLIENT_NAME}.conf"
echo ""
echo "2. For desktop clients:"
echo "   - In the WireGuard app, click 'Add Tunnel' -> 'Import from file'"
echo "   - Select the downloaded ${CLIENT_NAME}.conf"
echo ""
echo "3. For smartphones:"
echo "   - Generate QR code: sudo cat $CLIENT_CONFIG_PATH | qrencode -t ansiutf8"
echo "   - Or: sudo sh -c 'apt-get install -y qrencode && cat $CLIENT_CONFIG_PATH | qrencode -t ansiutf8'"
echo "   - In the WireGuard app, tap '+' -> 'Create from QR code'"
echo ""
