# APT Auto-Update Configuration Reference

## Configuration Files

### /etc/apt/apt.conf.d/20auto-upgrades

Controls the frequency of automatic updates:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
```

- `Update-Package-Lists` - Update package lists daily (1 = daily, 0 = disabled)
- `Unattended-Upgrade` - Run unattended-upgrade daily
- `Download-Upgradeable-Packages` - Pre-download packages
- `AutocleanInterval` - Remove old packages every N days

### /etc/apt/apt.conf.d/50unattended-upgrades

Main configuration file for unattended-upgrades:

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
```

## Important Settings

### Automatic Reboots

```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
```

- `Automatic-Reboot` - Reboot automatically if required
- `Automatic-Reboot-WithUsers` - Reboot even if users are logged in
- `Automatic-Reboot-Time` - Time for automatic reboot (24-hour format)

### Email Notifications

```
Unattended-Upgrade::Mail "root@localhost";
Unattended-Upgrade::MailReport "on-change";
```

Options for `MailReport`:

- `always` - Send email after every run
- `only-on-error` - Only send on errors
- `on-change` - Send when packages are upgraded

### Cleanup Options

```
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
```

### Package Blacklist

Prevent specific packages from auto-updating:

```
Unattended-Upgrade::Package-Blacklist {
    "vim";
    "nginx";
};
```

## Monitoring Commands

### Check Service Status

```bash
systemctl status unattended-upgrades
```

### View Timer Status

```bash
systemctl list-timers apt-daily.timer
systemctl list-timers apt-daily-upgrade.timer
```

### Check Recent Logs

```bash
# View unattended-upgrades log
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log

# View with systemd journal
sudo journalctl -u unattended-upgrades

# View APT history
sudo cat /var/log/apt/history.log
```

### Dry Run Test

```bash
sudo unattended-upgrade --dry-run --debug
```

## Update Schedule

Default schedule (can be viewed with `systemctl cat apt-daily.timer`):

- `apt-daily.timer` - Runs around 6:00 AM + random delay
- `apt-daily-upgrade.timer` - Runs around 6:00 AM + random delay

Random delay prevents all systems from updating simultaneously.

## Security Considerations

1. **Security updates only**: Default configuration only installs security updates
2. **Test updates**: For production systems, test in staging first
3. **Monitor logs**: Regularly check for failed updates
4. **Backup before updates**: Ensure backups are current
5. **Reboot planning**: Plan for automatic reboots if enabled

## Troubleshooting

### Updates Not Running

1. Check timer status: `systemctl list-timers`
2. Check service status: `systemctl status unattended-upgrades`
3. Enable if disabled: `systemctl enable unattended-upgrades`
4. Check logs: `journalctl -u unattended-upgrades`

### Packages Held Back

```bash
# List held packages
apt-mark showhold

# Unhold a package
sudo apt-mark unhold package-name

# Hold a package
sudo apt-mark hold package-name
```

### Lock File Issues

If APT is locked:

```bash
# Check for running processes
sudo lsof /var/lib/dpkg/lock-frontend
sudo lsof /var/lib/apt/lists/lock

# Remove locks (use with caution)
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock-frontend
sudo dpkg --configure -a
```

## References

- [Ubuntu Automatic Updates](https://help.ubuntu.com/community/AutomaticSecurityUpdates)
- [Debian Unattended Upgrades](https://wiki.debian.org/UnattendedUpgrades)
- [APT Configuration Reference](https://manpages.ubuntu.com/manpages/jammy/man5/apt.conf.5.html)
