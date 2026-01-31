#!/bin/bash
#
# MySQL/MariaDB Backup Script
# Creates dumps of all databases with compression
#

set -e  # Exit on error

# Configuration
BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y-%m-%d-%H%M)
HOSTNAME=$(hostname -s)
BACKUP_NAME="${HOSTNAME}-mysql-${DATE}.sql"
RETENTION_DAYS=7
LOG_FILE="/var/log/mysql-backup.log"

# MySQL credentials
# Option 1: Set these variables
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

# Option 2: Use .my.cnf file (more secure)
# Create ~/.my.cnf with:
# [client]
# user=root
# password=yourpassword

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting MySQL backup: $BACKUP_NAME"
log "========================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if MySQL is running
if ! systemctl is-active --quiet mysql && ! systemctl is-active --quiet mariadb; then
    log "ERROR: MySQL/MariaDB is not running"
    exit 1
fi

# Create database dump
log "Creating database dump..."

if [ -n "$DB_PASS" ]; then
    # With password
    mysqldump -u"$DB_USER" -p"$DB_PASS" \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        --events \
        > "$BACKUP_DIR/$BACKUP_NAME" 2>>"$LOG_FILE"
else
    # Without password (uses .my.cnf)
    mysqldump \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        --events \
        > "$BACKUP_DIR/$BACKUP_NAME" 2>>"$LOG_FILE"
fi

if [ $? -ne 0 ]; then
    log "✗ Database dump FAILED!"
    exit 1
fi

log "✓ Database dump created successfully"

# Compress the dump
log "Compressing backup..."
gzip "$BACKUP_DIR/$BACKUP_NAME"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.gz"

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✓ Backup compressed successfully"
    log "  File: $BACKUP_FILE"
    log "  Size: $BACKUP_SIZE"
else
    log "✗ Compression FAILED!"
    exit 1
fi

# Verify backup integrity
log "Verifying backup integrity..."
if gzip -t "$BACKUP_FILE" 2>>"$LOG_FILE"; then
    log "✓ Backup archive verified successfully"
else
    log "✗ Backup archive is CORRUPTED!"
    exit 1
fi

# Delete old backups
log "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
DELETED_COUNT=0
while IFS= read -r old_backup; do
    if [ -n "$old_backup" ]; then
        log "  Deleting: $(basename "$old_backup")"
        rm "$old_backup"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done < <(find "$BACKUP_DIR" -name "${HOSTNAME}-mysql-*.sql.gz" -mtime +$RETENTION_DAYS)

if [ $DELETED_COUNT -gt 0 ]; then
    log "✓ Deleted $DELETED_COUNT old backup(s)"
else
    log "  No old backups to delete"
fi

# Show current backups
log "Current MySQL backups:"
ls -lh "$BACKUP_DIR"/${HOSTNAME}-mysql-*.sql.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' | tee -a "$LOG_FILE"

log "========================================="
log "MySQL backup complete"
log "========================================="

exit 0
