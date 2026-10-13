# Backup storage, failure handling and restoration

## Choose storage against recovery requirements

| Destination | Useful for | Decisions to verify |
| --- | --- | --- |
| Local private directory | Staging and quick file recovery | Capacity, permissions, retention; the server remains a common failure domain. |
| Object storage | Independent retained generations | Scoped IAM, versioning/deletion protection, encryption/key custody, lifecycle, readback and restore latency. |
| Independent SSH storage | File/snapshot transfer | Host-key trust, restricted credentials, remote snapshots, independent administrative access. |
| NAS | Local recovery and owned storage | Site disaster exposure, independent replication, access controls and tested recovery. |

Choose recovery objectives and total workload before selecting storage class or schedule. Account for storage, requests, egress, minimum retention, archive retrieval and restoration time. Use current vendor pricing rather than fixed per-GB cost claims. Vendor marketing durability is not evidence that this backup job or a specific organization's controls are sufficient.

Provider references: [AWS S3 pricing](https://aws.amazon.com/s3/pricing/), [Backblaze B2 pricing](https://www.backblaze.com/cloud-storage/pricing), [DigitalOcean Spaces](https://www.digitalocean.com/products/spaces), [Google Cloud Storage pricing](https://cloud.google.com/storage/pricing), [Azure Blob pricing](https://azure.microsoft.com/pricing/details/storage/blobs/).

## Artifacts and private staging

The file helper requires explicit directories and captures their metadata with GNU tar. It is not a machine image. Include actual application state, user uploads and relevant configuration; do not substitute a generic folder list for a workload inventory. Stop writes/use snapshots when a consistent file view is required. Use database-native backup procedures for live databases.

The MySQL helper requires selected application databases, a private client option file, only InnoDB tables, and an attested no-DDL window. A minimal protected option file can use `[client]` entries for `user`, `password`, `host` and required TLS settings; provision it without printing secrets and restrict it to its owner. Credentials are not passed as command arguments. Database grants must permit the selected tables, routines, triggers and events. Other engines, system databases, GTID/replication recovery and physical backups need a version-specific procedure.

Backup directories must be dedicated, owned by the executing user and private; files are created with a restrictive umask and mode 600. Existing shared directories are refused rather than silently changing their permissions. Helper jobs use a per-directory `flock` to prevent overlap and random filename suffixes to avoid same-time collisions.

Outputs are staged as hidden pending files, verified, then promoted into timestamped artifacts and `.sha256` manifests. Failed dumps/compression/encryption never trigger retention. A failed encrypted operation retains its verified compressed source privately; review/remove incomplete pending files only after inspecting the failure and the useful generations.

## Encryption and independent keys

Provision the recipient's public key before using `--gpg-recipient`; keep the private key and recovery information outside the server's failure domain. The helper does not bypass GPG trust checks. A successful encryption command and nonempty ciphertext are useful production checks; perform a separate decrypt/restore test with the independently held key before calling recovery verified.

S3-side encryption protects stored objects according to the provider policy. Client-side encryption can additionally keep plaintext from the storage account, but loss of private keys can make every retained generation unusable. Avoid unauthenticated ad-hoc encryption recipes and credentials embedded in backup scripts.

## Failure-safe incremental snapshots

If the workload benefits from rsync snapshots, use a reviewed snapshot script/tool:

1. Create a unique private staging directory and acquire a job lock.
2. Run rsync with an appropriate consistent source view and link-destination pointing to the previous successful snapshot.
3. Check rsync status and required contents/metadata. On failure, retain the prior successful pointer and generations.
4. Promote the completed snapshot, then atomically replace the `current` symlink.
5. Preview and apply retention only to completed snapshots within the dedicated root, preserving required recoverable generations.

Do not update `current` after failed rsync, or use an unquoted `ls | xargs rm -rf` deletion recipe. The bundled tar helpers do not claim to implement incremental snapshots.

## Transfer both files and databases

Supply every required artifact explicitly to the S3 helper with repeated `--file` flags. It verifies local checksums first, uploads the artifact using the requested encryption policy, downloads it for a hash comparison, then uploads its checksum. It never removes local copies or sets lifecycle policies. Restore by retrieving both the artifact and manifest and verifying the bytes before extraction/import.

An upload can succeed but readback/checksum verification can fail; report that generation as unverified and keep useful local and prior remote copies. Scope credentials to the approved prefix and operations. Use provider roles/scoped credentials where available. Configure versioning/retention/immutability and deletion permissions separately so a compromised server cannot remove every generation.

## Local retention and schedules

Retention is opt-in with `--prune`. Only checksum-verified, regular matching artifacts directly in the private directory are candidates. Age is measured in full 24-hour days; legacy artifacts without checksums are skipped. Preview the policy first and authorize it for the planned job/schedule. Ensure remote recovery requirements are met before retiring needed local generations. Off-server and local retention are different policies.

After creation, transfer and a restore test succeed, install a job with its exact approved arguments. For example, a daily file job may run:

```cron
0 2 * * * /usr/local/lib/server-backups/backup-full.sh --path /etc --path /var/www --backup-dir /backup/files --apply >> /var/log/server-backups.log 2>&1
```

Install `backup-common.sh` beside the helper. The example creates local artifacts only; schedule explicit database and remote transfer jobs as required. Do not glob uploads before validating what they include. Prefer orchestration that records which file/database artifacts belong to one successful recovery set. Set the target timezone intentionally, protect logs, and configure alerts for failures, stale/missing jobs, capacity problems, and unexpected size changes. The cron example does not configure alert delivery or retention.

## Restore into isolation

Inspect and verify a downloaded file archive before extracting it:

```bash
sha256sum --check FILE_ARCHIVE.sha256
mkdir -m 700 restore-staging
tar -tzf FILE_ARCHIVE.tar.gz
tar -xzf FILE_ARCHIVE.tar.gz -C restore-staging
```

Substitute actual generated filenames. For encrypted artifacts, verify the ciphertext checksum, decrypt using the separately held private key into protected staging, then inspect/extract. Treat archives as sensitive and trusted input; restore in a disposable environment as an unprivileged user where possible. Never use an unreviewed archive to overwrite `/` on a live server.

For database restore, validate decompression first and import into an isolated test instance with appropriate credentials. The dump includes selected database definitions, routines/triggers/events; review names and scheduled events before importing. Verify representative records, required schema, permissions, metadata and application operations, not just gzip integrity. Document the result and measured restore time.

During actual incident recovery, select trusted generations and deliberately re-provision credentials, users and services rather than blindly restoring compromised accounts/configuration. Compliance requirements such as GDPR, HIPAA or SOC 2 need organization-specific controls and assessment; these scripts are not a certification.

## Sources

- [MySQL logical backup and consistency constraints](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html)
- [GNU tar manual](https://www.gnu.org/software/tar/manual/)
- [AWS S3 versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [AWS S3 Object Lock](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html)
