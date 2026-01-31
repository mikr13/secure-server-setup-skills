#!/bin/bash
#
# UFW Firewall Setup Script
# Configures UFW firewall on Ubuntu/Debian systems
#
# WARNING: This script modifies firewall rules.
# Always ensure SSH is allowed before enabling!
#

set -e  # Exit on error

echo "========================================="
echo "  UFW Firewall Setup Script"
echo "========================================="
echo ""
echo "This script will configure UFW firewall with:"
echo "  - Default deny incoming"
echo "  - Default allow outgoing"
echo "  - Allow SSH"
echo "  - Allow HTTP/HTTPS (optional)"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Install UFW if not present
echo ""
echo "[1/5] Checking UFW installation..."
if ! command -v ufw &> /dev/null; then
    echo "UFW not found. Installing..."
    apt update
    apt install ufw -y
else
    echo "UFW is already installed"
fi

# Set default policies
echo ""
echo "[2/5] Setting default policies..."
ufw default deny incoming
ufw default allow outgoing
echo "✓ Default policies set (deny incoming, allow outgoing)"

# Get current SSH port
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
fi

# Allow SSH
echo ""
echo "[3/5] Allowing SSH on port $SSH_PORT..."
ufw allow $SSH_PORT/tcp
echo "✓ SSH allowed on port $SSH_PORT"

# Ask about HTTP/HTTPS
echo ""
echo "[4/5] Web server configuration..."
read -p "Allow HTTP (port 80)? (yes/no): " ALLOW_HTTP
if [ "$ALLOW_HTTP" == "yes" ]; then
    ufw allow 80/tcp
    echo "✓ HTTP allowed on port 80"
fi

read -p "Allow HTTPS (port 443)? (yes/no): " ALLOW_HTTPS
if [ "$ALLOW_HTTPS" == "yes" ]; then
    ufw allow 443/tcp
    echo "✓ HTTPS allowed on port 443"
fi

# Ask about additional ports
echo ""
read -p "Do you need to allow any additional ports? (yes/no): " ADDITIONAL
if [ "$ADDITIONAL" == "yes" ]; then
    echo "Enter ports to allow (comma-separated, e.g., 3000,8080):"
    read -p "Ports: " PORTS
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo "$port" | xargs)  # Trim whitespace
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            ufw allow $port/tcp
            echo "✓ Allowed port $port/tcp"
        fi
    done
fi

# Enable UFW
echo ""
echo "[5/5] Enabling UFW..."
echo ""
echo "WARNING: UFW will now be enabled."
echo "Make sure SSH is working in another terminal!"
echo ""
read -p "Enable UFW now? (yes/no): " ENABLE

if [ "$ENABLE" == "yes" ]; then
    ufw --force enable
    echo "✓ UFW enabled"
else
    echo "UFW NOT enabled. To enable manually, run: sudo ufw enable"
fi

# Show status
echo ""
echo "========================================="
echo "  Firewall Configuration Complete"
echo "========================================="
echo ""
echo "Current firewall status:"
ufw status verbose
echo ""
echo "To add more rules:"
echo "  sudo ufw allow <port>/tcp"
echo "  sudo ufw allow from <ip> to any port <port>"
echo ""
echo "To view rules:"
echo "  sudo ufw status verbose"
echo "  sudo ufw status numbered"
echo ""
echo "To delete a rule:"
echo "  sudo ufw delete <rule-number>"
echo "  sudo ufw delete allow <port>/tcp"
echo ""
