---
name: auto-updates
description: Audit or configure unattended upgrades on Ubuntu/Debian. Use for security-update scheduling, allowed origins and reboot policy.
license: MIT
compatibility: Ubuntu/Debian Linux with APT, systemd, Bash, and unattended-upgrades; root for configuration.
metadata:
  author: secure-server-skill
  version: "1.0"
  category: security
---

# Automatic updates

Use this skill to inspect or configure periodic upgrades. Keep the requested maintenance policy: enabling a schedule does not authorize an immediate full upgrade, automatic reboot, or removal of dependencies.

## Inspect first

- Identify the distribution/release and installed `unattended-upgrades` version. Inspect `apt-config dump`, `/etc/apt/apt.conf.d/`, held packages, timers, and recent upgrade logs.
- Confirm allowed origins against this distribution's installed configuration. Ubuntu security, Debian security, third-party repositories, and Ubuntu Pro/ESM have different origin requirements. Do not copy an Ubuntu origin list onto Debian.
- Record existing automatic reboot, package cleanup, notification and scheduling choices. If the request is an audit, report findings without changing them.

## Configure

For operational details and lock troubleshooting, read [references/apt-config.md](references/apt-config.md).

1. If missing, install `unattended-upgrades` using the target's package manager within the authorized setup scope. This helper does not install packages.
2. Preview [scripts/setup-auto-updates.sh](scripts/setup-auto-updates.sh):

   ```bash
   sudo bash scripts/setup-auto-updates.sh --dry-run
   ```

3. Review the proposed daily periodic settings and existing origin/reboot policy. Once configuration and timer activation are authorized:

   ```bash
   sudo bash scripts/setup-auto-updates.sh --apply --activate
   ```

The helper writes its own managed drop-in, preserves the exact previous version for rollback, validates effective APT settings, and runs an unattended-upgrade dry run. It changes no allowed origins, reboot settings, dependency cleanup, or existing notification configuration. Without `--activate`, timer states remain unchanged.

## Verify and recover

- Check `apt-config dump`, the dry-run output and allowed origins, both APT timers, their installed schedules, and recent logs. Timer presence or an active service alone is insufficient evidence of upgrades.
- Plan required kernel/service restarts within the maintenance policy. Do not unhold packages without understanding why they were held.
- On failed validation or timer activation, the helper restores its prior drop-in and timer states it changed. The printed rollback directory contains the saved managed file. Restore it, or remove the new managed file if none existed, when reverting later.
- For APT contention, identify the lock holder and wait or diagnose it. Never delete lock files to bypass an active package manager.

Report configured origins, scheduling evidence, reboot policy, changes, and checks still pending on the target.
