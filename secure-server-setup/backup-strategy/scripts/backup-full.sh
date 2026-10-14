#!/usr/bin/env bash
# Selected-directory archive, not a machine image or live database snapshot.
set -Eeuo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=backup-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/backup-common.sh"
paths=()
usage() {
    cat <<'HELP'
Usage: backup-full.sh --path /etc [--path /home] [OPTIONS]
Preview by default. Uses GNU tar, gzip, coreutils and flock on Linux.
  --path PATH         Repeat for explicitly selected existing directories
  --backup-dir PATH   Dedicated private directory (default: /backup)
  --gpg-recipient KEY Encrypt to an already-provisioned GPG public key
  --apply             Create and verify a new archive
  --prune             Also prune verified old artifacts after success
  --retention-days N  Retention age in full 24-hour days (default: 7)
  --dry-run           Preview archive inputs and retention only (default)
  --help              Show usage
Use database-specific backups for live databases. No uploads or scheduling.
Exit: 0 success/preview, 1 backup/verification failure, 2 invalid input/locked.
HELP
}
while (($#)); do
    case $1 in
        --path) (($# >= 2)) || backup_die '--path needs a value'; paths+=("$2"); shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) if parse_backup_option "$1" "${2:-}"; then shift "$OPTION_COUNT"; else backup_die "Unknown option: $1"; fi ;;
    esac
done
check_backup_options
((${#paths[@]})) || backup_die 'Choose what to archive with --path (repeatable).'
relative_paths=()
for path in "${paths[@]}"; do
    [[ $path == /* && -d $path ]] || backup_die "Not an existing absolute directory: $path"
    path=$(realpath -- "$path")
    case $path in /|/proc|/sys|/dev|/run|/tmp|/var/tmp) backup_die "Not an archive source: $path" ;; esac
    [[ $BACKUP_DIR != "$path" && $BACKUP_DIR != "$path/"* ]] || backup_die 'Backup directory cannot be inside an archive source.'
    relative_paths+=("${path#/}")
done
printf 'Archive inputs: %s\nBackup directory: %s\n' "${paths[*]}" "$BACKUP_DIR"
if ! $APPLY; then prune_backups backup; printf 'Preview only; no archive created.\n'; exit 0; fi
prepare_backup_directory
pending=$(mktemp "$BACKUP_DIR/.files.pending.XXXXXXXX")
if ! tar --acls --xattrs --numeric-owner -czf "$pending" -C / -- "${relative_paths[@]}"; then
    printf 'Archive creation failed; previous backups preserved. Partial output: %s\n' "$pending" >&2; exit 1
fi
gzip -t -- "$pending"
tar -tzf "$pending" >/dev/null
publish_backup "$pending" backup tar.gz
