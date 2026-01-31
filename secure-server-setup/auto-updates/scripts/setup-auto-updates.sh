#!/bin/bash
#
# Auto-Updates Setup Script
# Configures automatic security updates on Ubuntu/Debian systems
#

set -e  # Exit on error

echo "========================================="
echo "  VPS Auto-Updates Setup Script"
echo "========================================="
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Update package lists
echo "[1/4] Updating package lists..."
apt update

# Upgrade existing packages
echo "[2/4] Upgrading installed packages..."
apt upgrade -y

# Install unattended-upgrades
echo "[3/4] Installing unattended-upgrades..."
apt install unattended-upgrades -y

# Configure unattended-upgrades
echo "[4/4] Configuring automatic updates..."

# Enable unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Configure unattended-upgrades settings (optional: enable auto-reboot)
cat > /etc/apt/apt.conf.d/51auto-upgrades-custom <<EOF
// Enable automatic reboot if required (at 2 AM)
// Uncomment the lines below to enable:
// Unattended-Upgrade::Automatic-Reboot "true";
// Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Send email notifications (configure email settings)
// Unattended-Upgrade::Mail "root";
// Unattended-Upgrade::MailReport "on-change";

// Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF

# Enable and start the service
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Automatic updates are now configured."
echo ""
echo "Configuration files:"
echo "  - /etc/apt/apt.conf.d/20auto-upgrades"
echo "  - /etc/apt/apt.conf.d/50unattended-upgrades"
echo "  - /etc/apt/apt.conf.d/51auto-upgrades-custom"
echo ""
echo "Logs location:"
echo "  - /var/log/unattended-upgrades/"
echo ""
echo "To enable automatic reboots, edit:"
echo "  /etc/apt/apt.conf.d/51auto-upgrades-custom"
echo ""
echo "Test with: sudo unattended-upgrade --dry-run --debug"
echo ""
