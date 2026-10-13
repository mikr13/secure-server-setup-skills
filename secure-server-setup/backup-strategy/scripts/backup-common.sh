#!/usr/bin/env bash
# Shared by the three backup helpers; not a standalone command.
set -Eeuo pipefail
umask 077
APPLY=false
EXPLICIT_DRY_RUN=false
PRUNE=false
BACKUP_DIR=/backup
RETENTION_DAYS=7
GPG_RECIPIENT=
# Set for the calling helper to consume common option arguments.
# shellcheck disable=SC2034
OPTION_COUNT=1
backup_die() { printf '%s\n' "$*" >&2; exit 2; }
# shellcheck disable=SC2034
parse_backup_option() {
    OPTION_COUNT=1
    case $1 in
        --apply) APPLY=true ;;
        --dry-run) EXPLICIT_DRY_RUN=true ;;
        --prune) PRUNE=true ;;
        --backup-dir) [[ -n $2 ]] || backup_die '--backup-dir needs a value'; BACKUP_DIR=$2; OPTION_COUNT=2 ;;
        --retention-days) if ! [[ $2 =~ ^[1-9][0-9]{0,4}$ ]] || (( $2 > 36500 )); then backup_die 'Retention must be 1-36500 days.'; fi; RETENTION_DAYS=$2; OPTION_COUNT=2 ;;
        --gpg-recipient) [[ -n $2 ]] || backup_die '--gpg-recipient needs a value'; GPG_RECIPIENT=$2; OPTION_COUNT=2 ;;
        *) return 1 ;;
    esac
}
check_backup_options() {
    if $APPLY && $EXPLICIT_DRY_RUN; then backup_die 'Choose --apply or --dry-run, not both.'; fi
    [[ $BACKUP_DIR == /* && ! -L $BACKUP_DIR ]] || backup_die 'Use an absolute dedicated backup directory, not a symlink.'
    BACKUP_DIR=$(realpath -m -- "$BACKUP_DIR")
    case $BACKUP_DIR in /|/etc|/usr|/usr/local|/home|/root|/var|/var/log|/tmp|/var/tmp|/opt|/srv) backup_die 'Choose a dedicated backup directory, not a system directory.' ;; esac
    SERVER_NAME=$(hostname -s)
    [[ $SERVER_NAME =~ ^[a-zA-Z0-9_-][a-zA-Z0-9_.-]*$ ]] || backup_die 'Hostname cannot be used safely in backup names.'
    if [[ -n $GPG_RECIPIENT ]]; then command -v gpg >/dev/null || backup_die 'Install GPG and provision the recipient public key first.'; fi
}
prepare_backup_directory() {
    mkdir -p -- "$BACKUP_DIR"
    [[ -O $BACKUP_DIR ]] || backup_die 'Backup directory must be owned by the current user.'
    mode=$(stat -c '%a' -- "$BACKUP_DIR")
    (( (8#$mode & 077) == 0 )) || backup_die 'Existing backup directory must be private (chmod 700 after reviewing its purpose).'
    [[ ! -L $BACKUP_DIR/.backup.lock ]] || backup_die 'Backup lock cannot be a symlink.'
    exec 9>"$BACKUP_DIR/.backup.lock"
    flock -n 9 || backup_die 'Another backup is running in this directory.'
}
verify_checksum() {
    local artifact=$1 expected actual
    [[ -f $artifact.sha256 && ! -L $artifact.sha256 ]] || return 1
    expected=$(awk 'NR==1 {print $1}' "$artifact.sha256")
    [[ $expected =~ ^[a-fA-F0-9]{64}$ ]] || return 1
    actual=$(sha256sum -- "$artifact")
    [[ ${actual%% *} == "$expected" ]]
}
# Delete only verified, regular artifacts directly within this dedicated directory.
prune_backups() {
    local kind=$1 list old
    $PRUNE || return 0
    [[ -d $BACKUP_DIR ]] || return 0
    list=$(mktemp)
    if ! find "$BACKUP_DIR" -maxdepth 1 -type f -name "$SERVER_NAME-$kind-*.gz*" -mmin "+$((RETENTION_DAYS * 1440))" -print0 > "$list"; then
        rm -f -- "$list"; return 1
    fi
    while IFS= read -r -d '' old; do
        case $old in *.tar.gz|*.tar.gz.gpg|*.sql.gz|*.sql.gz.gpg) ;; *) continue ;; esac
        if ! verify_checksum "$old"; then printf 'Skipping legacy/unverified retention candidate: %s\n' "$old" >&2; continue; fi
        printf 'Retention candidate: %s\n' "$old"
        if $APPLY; then rm -- "$old" "$old.sha256"; fi
    done < "$list"
    rm -f -- "$list"
}
# Input must already be a verified compressed archive. Failed encryption retains it.
publish_backup() {
    local input=$1 kind=$2 suffix=$3 output token checksum_pending
    output=$input
    if [[ -n $GPG_RECIPIENT ]]; then
        output=$(mktemp "$BACKUP_DIR/.encrypted.pending.XXXXXXXX")
        # GPG refuses to overwrite, so use a fresh name in this private directory.
        rm -- "$output"
        if ! gpg --batch --encrypt --recipient "$GPG_RECIPIENT" --output "$output" "$input" || [[ ! -s $output ]]; then
            printf 'Encryption failed; verified source retained at %s\n' "$input" >&2
            return 1
        fi
        suffix=$suffix.gpg
    fi
    token=${input##*.}
    FINAL_BACKUP="$BACKUP_DIR/$SERVER_NAME-$kind-$(date -u +%Y-%m-%d-%H%M%S)-$token.$suffix"
    checksum_pending=$(mktemp "$BACKUP_DIR/.checksum.pending.XXXXXXXX")
    digest=$(sha256sum -- "$output")
    printf '%s  %s\n' "${digest%% *}" "$(basename -- "$FINAL_BACKUP")" > "$checksum_pending"
    chmod 600 -- "$output" "$checksum_pending"
    # The random suffix and directory lock prevent collisions between our runs.
    [[ ! -e $FINAL_BACKUP && ! -e $FINAL_BACKUP.sha256 ]] || backup_die 'Backup destination already exists.'
    mv -- "$output" "$FINAL_BACKUP"
    mv -- "$checksum_pending" "$FINAL_BACKUP.sha256"
    if [[ $input != "$output" ]]; then rm -- "$input"; fi
    printf 'Verified archive: %s\nChecksum: %s.sha256\n' "$FINAL_BACKUP" "$FINAL_BACKUP"
    prune_backups "$kind"
}
