---
name: backup-strategy
description: Design and verify Linux backups and recovery. Use for file/database jobs, encryption, retention, S3 transfer and restore tests.
license: MIT
compatibility: Linux with Bash, GNU tar/coreutils, gzip and flock; MySQL clients for database backups, GPG for encryption, AWS CLI for S3.
metadata:
  author: secure-server-skill
  version: "1.0"
  category: disaster-recovery
---

# Backup strategy

Define recoverable data and recovery objectives before scheduling jobs or deleting generations. A selected-directory archive is not a full machine image; a successful upload or gzip check is not an application restore test.

## Establish the plan

- Identify required files, application databases, secrets, ownership/ACLs, recovery point and recovery time objectives, retention, encryption key custody, and an independent destination.
- Arrange database consistency and a schema-stable window. Do not copy live database data files into a generic tar archive and call it consistent.
- Specify how both file and database artifacts reach remote storage. Use scoped credentials and retention/versioning/immutability appropriate to the incident model; remote storage can still be deleted through compromised credentials.
- Treat configuration, scheduling, uploads, remote policy changes and retention deletion as distinct authorized actions. Reuse authorization already given for the applicable action; an audit alone does not authorize them.

Read [references/backup-locations.md](references/backup-locations.md) for storage decisions, failure handling, schedules and safe restoration.

## Create file and database artifacts

The helpers preview by default, require explicit inputs, create private output and checksum files, serialize jobs in a backup directory, and publish only verified results. Optional GPG encryption uses an already-provisioned public key; failed encryption retains the verified compressed source as a protected pending file.

Preview [file backups](scripts/backup-full.sh):

```bash
bash scripts/backup-full.sh --path /etc --path /var/www --backup-dir /backup/files --dry-run
```

After the data scope and storage are authorized, use `--apply`. Add `--gpg-recipient` for the chosen encryption key. Missing/invalid inputs fail instead of silently excluding required data. GNU tar captures selected-directory metadata; review restore permissions, ACLs and extended attributes on the target.

Preview [MySQL backups](scripts/backup-mysql.sh):

```bash
bash scripts/backup-mysql.sh --defaults-file /secure/mysql-backup.cnf --database application --backup-dir /backup/mysql --dry-run
```

The option file must be private and owned by the executing user. No password is passed in argv. Repeat `--database` for every application database. The helper refuses non-InnoDB tables; system databases and other engines need a separately reviewed snapshot/locking procedure. `--apply --maintenance-confirmed` attests the no-concurrent-DDL window. Verify routine/event privileges and successful restoration for the installed database version.

## Transfer and retain

The [S3 helper](scripts/backup-to-s3.sh) takes explicit artifact paths, verifies their adjacent checksums, uploads to the approved prefix, downloads them to compare bytes, then uploads checksums. It retains local copies and changes no bucket lifecycle or credentials.

```bash
bash scripts/backup-to-s3.sh --s3-uri s3://approved-backups/server-a --file /backup/files/FILE_ARCHIVE --file /backup/mysql/DATABASE_ARCHIVE --dry-run
```

Substitute the actual generated artifact paths before use. `--apply` performs the upload/readback and incurs transfer/storage costs. Specify `--kms-key-id` only for an approved accessible key; default uploads use S3 AES256 encryption. Uploaded ciphertext still needs independent private-key recovery testing.

Local retention is disabled unless `--prune` is explicitly selected. Preview it with `--dry-run --prune --retention-days 30`; `--apply --prune` prunes only after a new successful archive is published. Only regular matching artifacts directly inside the dedicated backup directory, older than the selected age and having valid checksums, qualify. Prior legacy/unverified archives are preserved for manual review. Scope scheduled cleanup to the already-authorized retention policy, and retain enough independent verified generations to meet recovery needs.

The helpers share [scripts/backup-common.sh](scripts/backup-common.sh); keep it beside them when copying or installing scripts.

## Verify recovery

- Inspect archive contents and checksums, output permissions, job exit status, age, and remote copies. Monitor failures and missing/stale artifacts explicitly.
- Restore into an isolated directory/database first. Compare required files, metadata and representative application queries; test encrypted restoration using independently stored keys.
- Restore application data selectively during a reviewed recovery operation. Do not extract `/etc`, `/root`, users or old credentials directly over a running system as a routine test.
- Configure cron/systemd only after a successful end-to-end run and restore. Define alerting, expected duration, exclusion policy, capacity and required restart coordination.

Report archive validation, remote byte verification, and application recovery as separate outcomes. Avoid deleting useful generations after failed dumps, encryption, transfer, or restore checks.
