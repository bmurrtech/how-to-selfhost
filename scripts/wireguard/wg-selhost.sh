#!/bin/bash
# Make it executable: chmod +x wg-deploy.sh
# Run with: sudo bash wg-deploy.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- Pre-flight apt lock check ---
echo "[INFO] Checking for active package operations..."
if sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "[WARN] Another process (probably cloud-init) is running apt-get."
    echo "       This happens on fresh instances while Ubuntu is still updating."
    echo "       Please wait for it to finish before running this script."
    echo
    echo "Check progress with:"
    echo "    sudo tail -f /var/log/cloud-init-output.log"
    echo
    echo "Or see apt processes:"
    echo "    ps -fp \$(sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null)"
    exit 1
fi

echo "[1/6] Updating package lists..."
apt-get update -y >/dev/null

echo "[2/6] Installing WireGuard and tools..."
apt-get install -y wireguard wireguard-tools qrencode curl >/dev/null

SERVER_IP=$(curl -s http://checkip.amazonaws.com || hostname -I | awk '{print $1}')
SERVER_PORT=51820
WG_CONF_DIR=/etc/wireguard

echo "[3/6] Generating server keys..."
SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

echo "[4/6] Creating WireGuard config..."
mkdir -p $WG_CONF_DIR
umask 077
cat > $WG_CONF_DIR/wg0.conf <<EOF
[Interface]
Address = 10.7.0.1/24
SaveConfig = true
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV_KEY
EOF

chmod 600 $WG_CONF_DIR/wg0.conf

echo "[5/6] Enabling and starting service..."
systemctl enable wg-quick@wg0 >/dev/null
systemctl start wg-quick@wg0

echo "[6/6] WireGuard is running."
echo "Server IP: $SERVER_IP"
echo "Port: $SERVER_PORT"
echo "To add a client: sudo wg-add <name>"
