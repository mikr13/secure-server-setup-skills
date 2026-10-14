# Changelog

The five skills share one semantic version. Git tags identify published snapshots; entries marked unreleased describe work being prepared for release.

## 2.0.0 — 2026-10-14

### Breaking changes

- Helpers preview by default. Existing jobs must supply explicit inputs and `--apply`; service activation and backup pruning require separate flags.
- Setup packages must already be installed. Helpers no longer install packages or perform a broad system upgrade.
- SSH hardening requires an existing administrator and confirmed fresh key/sudo access before applying policy. Firewall rules require an explicit management-source choice.
- File backups require selected directories. MySQL backups require selected InnoDB application databases, a private client option file and a confirmed schema-stable window.
- Backup scripts require the adjacent `backup-common.sh`. S3 transfer takes explicit artifacts and retains local copies. Local retention requires `--prune`.

See [Migrating from v1 to v2](MIGRATING.md) before replacing existing jobs or deployed helpers.

### Safety and validation

- Validate effective SSH policy, management listeners and Fail2ban configuration; preserve unrelated active firewall policies, jails and update settings.
- Restore previous managed configuration on validation or activation failure. Preserve verified backup data when later encryption or transfer fails.
- Create private, checksummed file/database artifacts with locking, optional GPG encryption and S3 download/readback verification.
- Add disposable Ubuntu 24.04 and Debian 12 regression coverage. The final suite passes 42 tests on each distribution; systemd control, firewall state changes and AWS calls are simulated.
- Shorten skill entrypoints, refresh operational references and document platform requirements, migration steps and verification limits.

### Review fixes

- Refuse excluded SSH client source addresses before firewall changes; enabling with an unknown client requires explicit console-recovery confirmation.
- Check merged Fail2ban action ports and TCP coverage, require approval for packaged all-port actions, and scope active-service reload/recovery to the SSH jail.
- Reject collisions across all S3 artifact and checksum destination keys before upload.
- Restore ACLs and extended attributes explicitly; test file contents, permissions, named/default ACLs and user attributes.

### Versioning

- Declare bundle version `2.0.0` in `.claude-plugin/plugin.json`; move skill paths from the marketplace entry into that manifest.
- Align all five skill versions and the marketplace catalog with the bundle release.
- Document semantic versioning, tagged checkouts and the release procedure while preserving existing skill names and paths.

## 1.0.0 — Retrospective baseline

The `v1.0.0` tag identifies commit `912daaccd7dd3c060be0ac8f3efa6b9aa3ea8c3a`, immediately before the v2 hardening work. This label was assigned retrospectively; no original publication date is asserted.

- Five skills covering automatic updates, SSH, UFW, Fail2ban and backups, with their original instructions and helper interfaces.
- Preserved for comparison and migration. It does not include the v2 safety changes described above.
