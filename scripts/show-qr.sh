#!/bin/bash
#
# WireGuard Client Configuration QR Code Display Script
# Displays a QR code that can be scanned by a smartphone.
#
# Usage (on server): ./show-qr.sh <client-name>
# Usage (locally): ./show-qr.sh <server-ip> <client-name>
#

set -e

if [ $# -eq 1 ]; then
    # Execution on server
    CLIENT_NAME="$1"

    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run with root privileges"
        echo "sudo $0 $@"
        exit 1
    fi

    CONFIG_FILE="/etc/wireguard/${CLIENT_NAME}.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Install qrencode if not already installed
    if ! command -v qrencode &> /dev/null; then
        echo "Installing qrencode..."
        apt-get update -qq && apt-get install -y qrencode
    fi

    echo "=== QR Code for ${CLIENT_NAME} ==="
    echo ""
    cat "$CONFIG_FILE" | qrencode -t ansiutf8
    echo ""
    echo "Please scan this with the WireGuard app by selecting '+' -> 'Create from QR code'"

elif [ $# -eq 2 ]; then
    # Execution from local machine
    SERVER_IP="$1"
    CLIENT_NAME="$2"
    USERNAME="${SSH_USER:-azureuser}"

    echo "Connecting to server to display QR code..."
    echo ""

    ssh -t "$USERNAME@$SERVER_IP" "sudo bash -c '
        if ! command -v qrencode &> /dev/null; then
            echo \"Installing qrencode...\"
            apt-get update -qq && apt-get install -y qrencode
        fi

        if [ ! -f /etc/wireguard/${CLIENT_NAME}.conf ]; then
            echo \"Error: Configuration file not found: /etc/wireguard/${CLIENT_NAME}.conf\"
            exit 1
        fi

        echo \"=== QR Code for ${CLIENT_NAME} ===\"
        echo \"\"
        cat /etc/wireguard/${CLIENT_NAME}.conf | qrencode -t ansiutf8
        echo \"\"
        echo \"Please scan this with the WireGuard app by selecting + -> Create from QR code\"
    '"
else
    echo "Usage:"
    echo "  Execution on server: sudo $0 <client-name>"
    echo "  Execution from local: $0 <server-ip> <client-name>"
    echo ""
    echo "Example:"
    echo "  On server: sudo $0 my-iphone"
    echo "  Local: $0 20.123.45.67 my-iphone"
    exit 1
fi
