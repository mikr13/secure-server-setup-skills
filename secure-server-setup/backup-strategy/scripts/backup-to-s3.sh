#!/bin/bash
#
# Backup to AWS S3
# Uploads local backup to S3 and cleans up local copy
#

set -e  # Exit on error

# Configuration
LOCAL_BACKUP_DIR="/backup"
S3_BUCKET="s3://your-backup-bucket"
S3_PREFIX="server-backups/$(hostname -s)"
HOSTNAME=$(hostname -s)
DATE=$(date +%Y-%m-%d)
LOG_FILE="/var/log/s3-backup.log"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "Starting S3 backup sync"
log "========================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log "ERROR: AWS CLI is not installed"
    log "Install with: sudo apt install awscli"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log "ERROR: AWS credentials not configured"
    log "Configure with: aws configure"
    exit 1
fi

# Find latest backup
LATEST_BACKUP=$(find "$LOCAL_BACKUP_DIR" -name "${HOSTNAME}-backup-*.tar.gz" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "$LATEST_BACKUP" ]; then
    log "ERROR: No backup files found in $LOCAL_BACKUP_DIR"
    exit 1
fi

log "Latest backup: $(basename "$LATEST_BACKUP")"
BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
log "Size: $BACKUP_SIZE"

# Upload to S3
log "Uploading to S3: $S3_BUCKET/$S3_PREFIX/"
aws s3 cp "$LATEST_BACKUP" "$S3_BUCKET/$S3_PREFIX/" \
    --storage-class STANDARD_IA \
    2>>"$LOG_FILE"

if [ $? -eq 0 ]; then
    log "✓ Upload to S3 successful"
    
    # Optionally remove local backup after successful upload
    # Uncomment the line below to enable
    # rm "$LATEST_BACKUP"
    # log "  Local backup removed"
else
    log "✗ S3 upload FAILED!"
    exit 1
fi

# Set S3 lifecycle policy (run once manually)
# aws s3api put-bucket-lifecycle-configuration \
#     --bucket your-backup-bucket \
#     --lifecycle-configuration file://lifecycle.json

log "========================================="
log "S3 backup sync complete"
log "========================================="

exit 0
