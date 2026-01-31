---
name: auto-updates
description: Configure automatic security updates on Ubuntu/Debian VPS servers to patch vulnerabilities and prevent exploitation of known security flaws.
license: MIT
compatibility: Ubuntu, Debian, and derivative Linux distributions
metadata:
  author: secure-server-skill
  version: "1.0"
  category: security
allowed-tools: Bash(apt:*, dpkg-reconfigure:*, systemctl:*)
---

# Auto Updates Skill

Enable automatic security updates on VPS servers to ensure systems are patched against known vulnerabilities.

## What This Skill Does

This skill helps AI agents configure automatic security updates on Ubuntu/Debian-based VPS servers. Every piece of software has vulnerabilities - patches fix them. If you're not patching, you're running known-vulnerable software that attackers have pre-built exploits for.

**Key capabilities:**

- Update package lists and upgrade installed packages
- Configure unattended-upgrades for automatic security patches
- Set up automatic reboot schedules when required
- Verify update configuration and status

## When to Use

Use this skill when you need to:

- Set up a new VPS server with automatic updates
- Harden an existing server against known vulnerabilities
- Ensure compliance with security patching requirements
- Reduce manual maintenance overhead
- Fix security audit findings related to outdated packages

**Critical understanding:** A server that's been up for 400 days isn't impressive - it's concerning. Regular updates and reboots are essential for security.

## Prerequisites

- Root or sudo access to the server
- Ubuntu or Debian-based Linux distribution
- Internet connectivity for package downloads
- SSH access to the server

## Installation & Configuration

### Step 1: Update System Packages

First, update the package list and upgrade all installed packages:

```bash
sudo apt update && sudo apt upgrade -y
```

**What this does:**

- `apt update` - Refreshes the package index from repositories
- `apt upgrade -y` - Installs available updates without prompting

### Step 2: Install Unattended Upgrades

Install the unattended-upgrades package:

```bash
sudo apt install unattended-upgrades -y
```

### Step 3: Configure Unattended Upgrades

Enable automatic updates using the configuration tool:

```bash
sudo dpkg-reconfigure unattended-upgrades
```

Select "Yes" when prompted to enable automatic updates.

**Alternative manual configuration:**

Edit `/etc/apt/apt.conf.d/50unattended-upgrades` to customize:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Key settings to review:

- `Unattended-Upgrade::Allowed-Origins` - Which updates to install
- `Unattended-Upgrade::Automatic-Reboot` - Auto-reboot if required (default: false)
- `Unattended-Upgrade::Automatic-Reboot-Time` - When to reboot (e.g., "02:00")
- `Unattended-Upgrade::Remove-Unused-Dependencies` - Clean up old packages

### Step 4: Verify Configuration

Check that unattended-upgrades is active:

```bash
sudo systemctl status unattended-upgrades
```

View the automatic upgrade log:

```bash
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log
```

## Configuration Options

### Automatic Reboot Settings

To enable automatic reboots when kernel updates require them, edit `/etc/apt/apt.conf.d/50unattended-upgrades`:

```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

### Update Frequency

The default update frequency is configured in `/etc/apt/apt.conf.d/20auto-upgrades`:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
```

## Testing

Perform a dry run to see what would be updated:

```bash
sudo unattended-upgrade --dry-run --debug
```

Manually trigger an update cycle:

```bash
sudo unattended-upgrade --debug
```

## Troubleshooting

### Updates Not Running

Check the systemd timer status:

```bash
sudo systemctl status apt-daily.timer
sudo systemctl status apt-daily-upgrade.timer
```

Enable timers if disabled:

```bash
sudo systemctl enable apt-daily.timer
sudo systemctl enable apt-daily-upgrade.timer
```

### Check Logs

View recent update activity:

```bash
sudo journalctl -u unattended-upgrades
```

### Held Packages

Some packages may be held back. List them:

```bash
apt-mark showhold
```

Unhold if safe:

```bash
sudo apt-mark unhold <package-name>
```

## Security Best Practices

1. **Enable automatic security updates** - Don't wait for manual intervention
2. **Monitor update logs** - Regularly review `/var/log/unattended-upgrades/`
3. **Plan for reboots** - Some updates require system restart
4. **Test in staging** - For production systems, test updates in a staging environment first
5. **Set up monitoring** - Alert on failed updates or long uptime without reboots

## Common Mistakes to Avoid

- ❌ Disabling updates because "they might break something"
- ❌ Not monitoring update logs for failures
- ❌ Ignoring reboot notifications for kernel updates
- ❌ Holding back security packages indefinitely

## Additional Resources

See [references/apt-config.md](references/apt-config.md) for detailed APT configuration options.

See [scripts/setup-auto-updates.sh](scripts/setup-auto-updates.sh) for automated setup script.

## Related Skills

- `ssh-hardening` - Secure SSH configuration
- `firewall-configuration` - Set up UFW firewall
- `fail2ban-setup` - Configure brute-force protection
