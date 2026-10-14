# APT automatic-update operations

## Inspect effective policy

```bash
sudo apt-config dump
sudo systemctl cat apt-daily.timer apt-daily-upgrade.timer
sudo systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager
apt-mark showhold
```

Read the distribution's installed `50unattended-upgrades` and all later drop-ins. Ubuntu `Allowed-Origins` and Debian `Origins-Pattern` configurations are not interchangeable. Confirm security origins, third-party repositories, Ubuntu Pro/ESM access where applicable, and the actual release's policy. Do not claim that every default origin is security-only.

The setup helper's managed file sets only:

```text
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

It preserves other files and creates a protected copy of its previous managed file. A later lexicographically loaded override can still win; effective-setting validation detects this instead of declaring success.

## Reboots, cleanup and immediate upgrades

Inspect `Unattended-Upgrade::Automatic-Reboot`, `Automatic-Reboot-WithUsers`, `Automatic-Reboot-Time`, dependency/kernel cleanup, and held packages. Preserve choices unless the authorized maintenance plan changes them. Times are interpreted in the target server's timezone; inspect installed timers and their randomized delays rather than assuming a fixed schedule.

A manual broad package upgrade is a separate maintenance operation. Preview affected packages and coordinate service restarts, backups and any required reboot. Enabling unattended upgrades does not by itself authorize immediate `apt upgrade -y` or removing package holds.

If intentionally changing reboot policy, use a separate reviewed managed override rather than editing vendor files. For example, an approved no-auto-reboot policy is:

```text
Unattended-Upgrade::Automatic-Reboot "false";
```

## Verification

```bash
sudo unattended-upgrade --dry-run --debug
sudo journalctl -u apt-daily-upgrade.service -n 50 --no-pager
sudo tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log
```

Dry-run output should show the expected allowed origins and candidate packages. Confirm periodic settings and functioning timers, then monitor real scheduled outcomes. Service status alone is not proof that updates are occurring.

## Package-manager locks

Never remove APT/dpkg lock files to bypass a lock. Identify the holder:

```bash
sudo fuser -v /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock
```

Wait for an active upgrade. If a process appears stalled, inspect its logs and state and coordinate controlled recovery; do not kill a running package operation solely because the lock exists. After exclusive access is available, recover interrupted package configuration with `sudo dpkg --configure -a`, then diagnose any remaining package errors. Lock files can exist without being held; deleting a file does not release the process's region lock.

## Rollback

The helper prints `/var/backups/secure-server-setup/apt/rollback.*`. Restore `previous.conf` to the managed path if it existed, otherwise remove only the newly managed drop-in. Inspect/restore timer states and effective policy. Reverting configuration does not undo already-installed packages.

## Sources

- [Ubuntu automatic updates](https://ubuntu.com/server/docs/how-to/software/automatic-updates/)
- [Debian unattended upgrades](https://wiki.debian.org/UnattendedUpgrades)
- [Debian dpkg lock FAQ](https://wiki.debian.org/Teams/Dpkg/FAQ)
