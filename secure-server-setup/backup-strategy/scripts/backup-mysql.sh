#!/usr/bin/env bash
# Logical transactional database backup; requires a schema-stable window.
set -Eeuo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=backup-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/backup-common.sh"
BACKUP_DIR=/backup/mysql
defaults_file=
databases=()
maintenance_confirmed=false
usage() {
    cat <<'HELP'
Usage: backup-mysql.sh --defaults-file /secure/client.cnf --database APP [OPTIONS]
Preview by default. Requires mysql/mysqldump, gzip, coreutils and flock on Linux.
  --database NAME         Repeat for selected application databases (letters/digits/_)
  --defaults-file PATH    Private client option file; credentials never enter argv
  --maintenance-confirmed Attest no concurrent schema changes during this backup
  --backup-dir PATH       Dedicated private directory (default: /backup/mysql)
  --gpg-recipient KEY     Optional GPG encryption using a provisioned public key
  --apply                 Dump, compress, verify and publish
  --prune                 Prune verified old artifacts only after success
  --retention-days N      Retention in full 24-hour days (default: 7)
  --dry-run               Preview only (default)
  --help                  Show usage
Only InnoDB application tables are accepted. System databases/nontransactional
engines need a separately reviewed backup procedure. Restoration must be tested.
Exit: 0 success/preview, 1 dump/verification failure, 2 invalid input/locked.
HELP
}
while (($#)); do
    case $1 in
        --database) (($# >= 2)) || backup_die '--database needs a value'; [[ $2 =~ ^[a-zA-Z0-9_]+$ ]] || backup_die 'Use an explicit alphanumeric/underscore database name.'; case $2 in mysql|sys|information_schema|performance_schema) backup_die 'System databases require a separate procedure.' ;; esac; databases+=("$2"); shift 2 ;;
        --defaults-file) (($# >= 2)) || backup_die '--defaults-file needs a value'; defaults_file=$2; shift 2 ;;
        --maintenance-confirmed) maintenance_confirmed=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) if parse_backup_option "$1" "${2:-}"; then shift "$OPTION_COUNT"; else backup_die "Unknown option: $1"; fi ;;
    esac
done
check_backup_options
((${#databases[@]})) || backup_die 'Supply at least one application --database.'
[[ $defaults_file == /* && -f $defaults_file && ! -L $defaults_file && -O $defaults_file ]] || backup_die 'Use an existing private --defaults-file owned by this user.'
mode=$(stat -c '%a' -- "$defaults_file")
(( (8#$mode & 077) == 0 )) || backup_die 'Client credentials must not be readable/writable by group or others.'
printf 'Databases: %s\nBackup directory: %s\n' "${databases[*]}" "$BACKUP_DIR"
if ! $APPLY; then prune_backups mysql; printf 'Preview only; no database contacted or dump created.\n'; exit 0; fi
$maintenance_confirmed || backup_die 'Arrange a schema-stable window; supply --maintenance-confirmed.'
command -v mysql >/dev/null || backup_die 'Install the mysql client first.'
command -v mysqldump >/dev/null || backup_die 'Install mysqldump first.'
# Names are constrained above, so this SQL list cannot contain quotes or SQL syntax.
sql_names=$(printf "'%s'," "${databases[@]}")
sql_names=${sql_names%,}
nontransactional=$(mysql --defaults-file="$defaults_file" --batch --skip-column-names --execute "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ($sql_names) AND ENGINE IS NOT NULL AND ENGINE <> 'InnoDB';")
[[ $nontransactional == 0 ]] || backup_die 'Selected databases contain non-InnoDB tables or the engine check failed; use a consistent snapshot/locking procedure.'
prepare_backup_directory
sql_pending=$(mktemp "$BACKUP_DIR/.mysql.pending.XXXXXXXX")
if ! mysqldump --defaults-file="$defaults_file" --single-transaction --quick --no-tablespaces --routines --triggers --events --databases "${databases[@]}" > "$sql_pending"; then
    printf 'Database dump failed; previous backups preserved. Partial output: %s\n' "$sql_pending" >&2; exit 1
fi
[[ -s $sql_pending ]] || { printf 'Database dump is empty.\n' >&2; exit 1; }
pending=$(mktemp "$BACKUP_DIR/.mysql-compressed.pending.XXXXXXXX")
gzip -c -- "$sql_pending" > "$pending"
gzip -t -- "$pending"
rm -- "$sql_pending"
publish_backup "$pending" mysql sql.gz
