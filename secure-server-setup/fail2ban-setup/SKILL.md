---
name: fail2ban-setup
description: Audit or configure Fail2ban SSH jails on Ubuntu/Debian. Use for log backends, filter behavior and ban enforcement.
license: MIT
compatibility: Ubuntu/Debian Linux with Fail2ban, OpenSSH, iproute2, Bash, systemd, and python3-systemd for journal-only SSH.
metadata:
  author: secure-server-skill
  version: "2.0.0"
  category: security
---

# Fail2ban setup

Protect the selected logging service without replacing unrelated jails or trusted-address policy. A process that is running may still have an inactive or ineffective jail.

## Inspect

- Identify installed Fail2ban/filter versions, actual SSH listeners, active jails, local overrides and existing `ignoreip` values. Review administrator access before testing bans.
- Determine whether SSH events reach `/var/log/auth.log`, `/var/log/secure`, or only journald. For journal-only systems, confirm `python3-systemd` and the installed SSH filter's `journalmatch` support.
- Identify the firewall ban action and network path, including reverse proxies or containers if relevant. A jail must identify the actual offending client, not a shared proxy or administrator address.

Read [references/fail2ban-filters.md](references/fail2ban-filters.md) when choosing backends, filter modes, custom application filters, or a controlled test.

## Configure

Install Fail2ban and required backend packages within the authorized scope if absent. Preview [scripts/setup-fail2ban.sh](scripts/setup-fail2ban.sh):

```bash
sudo bash scripts/setup-fail2ban.sh --dry-run
```

Pass `--ssh-port` for every actual listener when socket activation/custom ports make discovery ambiguous. For an authorized SSH jail change and activation:

```bash
sudo bash scripts/setup-fail2ban.sh --apply --activate
```

The helper writes only `jail.d/99-secure-server-sshd.local`, selects file polling or the systemd backend, preserves existing `ignoreip` and other jails, and validates configuration before activation. It uses the installed `sshd` filter with five failures in ten minutes and a one-hour ban. These are adjustable local policy choices, not universal Fail2ban defaults. Without `--activate`, the running service is unchanged.

Do not enable recidive or application jails unless their actual log source, filter and ban action are verified. Aggressive SSH behavior is an installed `sshd` filter mode, not a presumed `sshd-aggressive.conf` file.

The helper validates merged ban-action ports and TCP coverage. Installed iptables/nftables all-port actions require explicit `--allow-allports` approval; custom actions that cannot be verified need a manual procedure. Active-service reload and recovery select only `sshd`. Starting an inactive service loads all enabled jails and must be reviewed accordingly.

## Verify and recover

- Run `sudo fail2ban-client -t` and check `sudo fail2ban-client status sshd` after activation.
- Confirm the selected log/journal contains real events and the jail's filter matches authentication failures while excluding representative legitimate traffic.
- From a controlled secondary client, prove a ban blocks the intended network path, then unban it. Do not intentionally ban the only management client.
- Verify all previously required jails and allowlists remain effective. Keep ban notifications and log retention consistent with existing policy.
- On failed validation/activation, the helper restores the prior managed jail and attempts to recover prior service state. For later rollback, use the printed directory to restore or remove that managed override, validate, and reload.

Report running-service, active-jail, filter-match and actual enforcement evidence separately.
