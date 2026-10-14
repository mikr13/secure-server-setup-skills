# Migrating from v1 to v2

Version 2 changes helper interfaces and operational behavior. Skill names and directory paths stay the same. Updating installed instructions or scripts does not update server configuration, scheduled jobs, credentials or previously copied helpers.

The `v1.0.0` Git tag preserves the original baseline. Version 2 remains unreleased until its release tag is published; see [CHANGELOG.md](CHANGELOG.md).

## Review existing deployments

1. Inventory copied scripts, cron entries, systemd units, wrappers and agent installations. Record their current arguments and execution user, and pause affected schedules while replacing a deployed helper set.
2. Read the current helper's `--help`. Install and review its required packages separately. Setup helpers no longer install packages or run a broad system upgrade.
3. Review effective server configuration and access before choosing new arguments. Existing rules, authentication requirements, update origins, reboot settings and unrelated jails may need a separate procedure.
4. Preview each replacement with explicit inputs and `--dry-run`. A successful preview is not a completed backup or an applied security change.
5. After reviewing the plan, add `--apply` and only the activation, encryption, upload or pruning choices required for the authorized operation. Do not add mutation flags mechanically to an old command.
6. Verify access or restore the resulting artifacts before resuming schedules. Record deployed versions and any target-specific checks still outstanding.

## Helper changes

Paths below are relative to `secure-server-setup/`. Run setup helpers on the intended Ubuntu/Debian server; generate client SSH keys on the local client.

| Helper | Changes required for v2 |
| --- | --- |
| `auto-updates/scripts/setup-auto-updates.sh` | Preview existing settings first. `--apply` writes periodic settings and runs an unattended-upgrade dry run; add `--activate` only to enable/start APT timers. Review origins, cleanup and reboot policy separately. |
| `ssh-hardening/scripts/generate-ssh-keys.sh` | Supply an absolute `--key-file` and a nonempty `--comment`. Generation requires `--apply` and either human-terminal `--interactive` or an explicitly chosen service-key `--no-passphrase`. Existing key paths are refused. |
| `ssh-hardening/scripts/setup-ssh-hardening.sh` | Supply existing non-root administrators with repeatable `--user` and the actual `--client-address`; use `--client-host` for hostname conditions. Prove fresh key login and sudo before adding `--key-access-confirmed --apply`. `--activate` reloads the active SSH service. Review MFA separately. |
| `firewall-configuration/scripts/setup-firewall.sh` | Specify approved `--ssh-source` CIDRs or explicitly choose `--public-ssh`; review actual listeners and repeat `--ssh-port` where needed. Public services require explicit `--allow-port N/tcp` or `N/udp`. `--apply` adds rules, which can affect an already-active firewall immediately. `--enable` activates an inactive UFW. |
| `fail2ban-setup/scripts/setup-fail2ban.sh` | Review actual SSH listeners and the log/journal source; specify repeatable `--ssh-port` when discovery is insufficient, including socket activation. `--apply` writes and validates an SSH-only override; `--activate` reloads or starts Fail2ban. |
| `backup-strategy/scripts/backup-full.sh` | Select directories with repeatable `--path` and a dedicated `--backup-dir`. `--apply` creates an archive; it is not a full machine image. Add `--gpg-recipient` for a provisioned public key and `--prune` only for approved local retention. |
| `backup-strategy/scripts/backup-mysql.sh` | Supply an owned, private `--defaults-file` and repeatable `--database` selections. Applying requires `--maintenance-confirmed` for a no-concurrent-DDL window. Non-InnoDB tables and system databases need another reviewed procedure. Encryption and pruning are explicit choices. |
| `backup-strategy/scripts/backup-to-s3.sh` | Supply an existing approved bucket/prefix with `--s3-uri` and repeat `--file` for every file/database artifact. Adjacent checksum files are required. `--apply` uploads and downloads to verify bytes; local artifacts remain. Bucket lifecycle and remote retention need separate configuration. |

Copy `backup-common.sh` together with all deployed backup helpers. Preserve the directory structure or keep the common helper beside each caller. Protect database option files and encryption keys independently of the scripts.

For example, from the repository root, preview a selected-directory backup on the target Linux host:

```bash
sudo bash secure-server-setup/backup-strategy/scripts/backup-full.sh \
  --path /etc \
  --path /var/www \
  --backup-dir /backup/files \
  --dry-run
```

Replace the paths with the reviewed data scope. After authorization, replace `--dry-run` with `--apply` for a manual trial. Add pruning only after checking the retention scope and recoverability of retained generations; configure a schedule only after an isolated restore succeeds.

## Verify and recover

For SSH or firewall changes, keep the original session and provider console available until a fresh connection and required sudo access succeed. Check effective SSH policy, active listeners and reachability from relevant IPv4/IPv6 networks. UFW status does not cover provider firewalls or container exposure.

For updates and Fail2ban, verify the merged configuration and actual scheduling or ban/unban behavior on the target. Container tests do not prove systemd boot integration or live ban enforcement.

For backups, restore selected files and databases in isolation, including a decrypt/restore test when encrypted. Check off-server artifacts and credential permissions. A preview, checksum or successful upload alone does not demonstrate application recovery.

If migration fails, pause affected jobs and use the recorded managed-configuration backup or the existing recovery procedure. Reinstalling v1 files does not undo already-applied server changes, uploads or deletions. Avoid automatically resuming the original helpers: they lack the v2 safety fixes.
