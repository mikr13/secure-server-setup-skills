#!/bin/bash
#
# SSH Key Generation Script
# Generates SSH key pairs for secure authentication
# Run this on your LOCAL machine, not the server
#

echo "========================================="
echo "  SSH Key Generation Script"
echo "========================================="
echo ""
echo "This script will generate an SSH key pair."
echo "Run this on your LOCAL machine (not the server)."
echo ""

# Prompt for email
read -p "Enter your email address: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "Email cannot be empty"
    exit 1
fi

# Check if key already exists
KEY_FILE="$HOME/.ssh/id_ed25519"
if [ -f "$KEY_FILE" ]; then
    echo ""
    echo "SSH key already exists at: $KEY_FILE"
    read -p "Generate a new key anyway? This will NOT overwrite the existing one. (yes/no): " GENERATE
    
    if [ "$GENERATE" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    
    # Generate with custom name
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    KEY_FILE="$HOME/.ssh/id_ed25519_$TIMESTAMP"
fi

# Generate SSH key
echo ""
echo "Generating ED25519 SSH key pair..."
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "  Key Generation Complete!"
    echo "========================================="
    echo ""
    echo "Private key: $KEY_FILE"
    echo "Public key:  ${KEY_FILE}.pub"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Copy the public key to your server:"
    echo "   ssh-copy-id -i ${KEY_FILE}.pub user@your-server-ip"
    echo ""
    echo "2. Test SSH connection:"
    echo "   ssh -i $KEY_FILE user@your-server-ip"
    echo ""
    echo "3. Once verified, you can disable password authentication"
    echo ""
    echo "Your public key (copy this if needed):"
    echo "---"
    cat "${KEY_FILE}.pub"
    echo "---"
else
    echo "Key generation failed!"
    exit 1
fi
