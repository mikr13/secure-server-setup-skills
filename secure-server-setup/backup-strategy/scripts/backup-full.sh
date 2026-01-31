#!/bin/bash
#
# Full Server Backup Script
# Creates compressed tar archive of critical directories
#

set -e  # Exit on error

# Configuration
BACKUP_DIR="/backup"
DATE=$(date +%Y-%m-%d-%H%M)
HOSTNAME=$(hostname -s)
BACKUP_NAME="${HOSTNAME}-backup-${DATE}.tar.gz"
RETENTION_DAYS=7
LOG_FILE="/var/log/backup.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting backup: $BACKUP_NAME"
log "========================================="

# Check available disk space
AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 5000000 ]; then
    log "ERROR: Less than 5GB available space in $BACKUP_DIR"
    exit 1
fi

# Create compressed archive
log "Creating compressed archive..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --exclude='*.log' \
    --exclude='*.tmp' \
    --exclude='/backup' \
    --exclude='/proc' \
    --exclude='/sys' \
    --exclude='/dev' \
    --exclude='/run' \
    --exclude='/tmp' \
    --exclude='/var/tmp' \
    --exclude='/var/cache' \
    --exclude='/var/log' \
    --exclude='lost+found' \
    /home \
    /etc \
    /var/www \
    /root \
    /usr/local \
    /opt \
    2>>"$LOG_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    log "✓ Backup completed successfully"
    log "  File: $BACKUP_DIR/$BACKUP_NAME"
    log "  Size: $BACKUP_SIZE"
else
    log "✗ Backup FAILED! Check $LOG_FILE for details"
    exit 1
fi

# Verify backup integrity
log "Verifying backup integrity..."
if gzip -t "$BACKUP_DIR/$BACKUP_NAME" 2>>"$LOG_FILE"; then
    log "✓ Backup archive verified successfully"
else
    log "✗ Backup archive is CORRUPTED!"
    exit 1
fi

# Delete old backups (keep last N days)
log "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
DELETED_COUNT=0
while IFS= read -r old_backup; do
    if [ -n "$old_backup" ]; then
        log "  Deleting: $(basename "$old_backup")"
        rm "$old_backup"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done < <(find "$BACKUP_DIR" -name "${HOSTNAME}-backup-*.tar.gz" -mtime +$RETENTION_DAYS)

if [ $DELETED_COUNT -gt 0 ]; then
    log "✓ Deleted $DELETED_COUNT old backup(s)"
else
    log "  No old backups to delete"
fi

# Show current backups
log "Current backups:"
ls -lh "$BACKUP_DIR"/${HOSTNAME}-backup-*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' | tee -a "$LOG_FILE"

log "========================================="
log "Backup process complete"
log "========================================="

# Exit successfully
exit 0
