# Backup Storage Locations Comparison

## Local vs Remote Storage

| Feature | Local Backup | Remote Backup |
|---------|--------------|---------------|
| Speed | Very fast | Depends on bandwidth |
| Cost | Server storage only | Storage + transfer fees |
| Protection | Same server risk | Protected from server failure |
| Compliance | May not meet requirements | Often required for compliance |
| Recommended | As temporary only | Yes, always |

**Best practice:** Use local backups as temporary staging, then transfer to remote storage.

## Remote Storage Options

### AWS S3

**Pros:**

- Highly durable (99.999999999% durability)
- Scalable storage
- Lifecycle policies for automatic retention
- Glacier for long-term archival
- Integrated with AWS services

**Cons:**

- Ongoing storage costs
- Data transfer fees
- Requires AWS account and credentials

**Cost:** ~$0.023/GB/month (Standard), ~$0.00099/GB/month (Glacier Deep Archive)

**Setup:**

```bash
# Install AWS CLI
sudo apt install awscli

# Configure credentials
aws configure

# Upload backup
aws s3 cp /backup/backup-2024-01-31.tar.gz s3://my-backups/
```

**Lifecycle policy example:**

```json
{
  "Rules": [
    {
      "Id": "Archive old backups",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 90,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

### DigitalOcean Spaces

**Pros:**

- S3-compatible API
- Simple pricing
- No egress fees within same region
- Built-in CDN

**Cons:**

- Less feature-rich than AWS
- Fewer global regions

**Cost:** $5/month for 250GB storage + 1TB transfer

**Setup:**

```bash
# Use s3cmd with Spaces
s3cmd --configure

# Upload backup
s3cmd put /backup/backup-2024-01-31.tar.gz s3://my-space/backups/
```

### Backblaze B2

**Pros:**

- Very low cost
- S3-compatible API
- First 10GB free
- Free egress via Cloudflare

**Cons:**

- Smaller company (reliability concerns)
- Limited global presence

**Cost:** $0.005/GB/month storage, $0.01/GB download

**Setup:**

```bash
# Install B2 CLI
sudo pip3 install b2

# Authorize
b2 authorize-account

# Upload backup
b2 upload-file my-bucket /backup/backup-2024-01-31.tar.gz backups/backup-2024-01-31.tar.gz
```

### Remote Server (VPS/Dedicated)

**Pros:**

- Full control
- Predictable costs
- No vendor lock-in
- Can run custom backup software

**Cons:**

- Must manage server yourself
- Single point of failure if not replicated
- Requires network bandwidth

**Cost:** $5-20/month for basic VPS

**Setup:**

```bash
# Upload via SCP
scp /backup/backup-2024-01-31.tar.gz user@backup-server.com:/backups/

# Or use rsync for incremental
rsync -avz /backup/ user@backup-server.com:/backups/
```

### Rsync.net

**Pros:**

- Designed for backups
- Simple rsync/SSH access
- Snapshots included
- Very reliable

**Cons:**

- Higher cost than object storage
- Less flexible than cloud providers

**Cost:** ~$0.01/GB/month (with commitment)

### NAS (Network Attached Storage)

**Pros:**

- One-time hardware cost
- On-premises (data locality)
- Fast local network speeds
- Full control

**Cons:**

- Physical security required
- Not protected from site disaster
- Requires network setup
- Hardware maintenance

**Cost:** $300-1000+ one-time + electricity

### Google Cloud Storage

**Pros:**

- Integration with Google Cloud Platform
- Multiple storage classes
- Global infrastructure
- Competitive pricing

**Cons:**

- Complex pricing
- Requires Google Cloud account

**Cost:** ~$0.020/GB/month (Standard), ~$0.0012/GB/month (Archive)

### Microsoft Azure Blob Storage

**Pros:**

- Integration with Azure services
- Enterprise features
- Multiple redundancy options
- Global presence

**Cons:**

- Complex pricing
- Requires Azure account
- Interface complexity

**Cost:** ~$0.018/GB/month (Hot), ~$0.00099/GB/month (Archive)

## Recommended Strategies by Use Case

### Small Website/Blog

**Storage:** Backblaze B2 or DigitalOcean Spaces

**Schedule:** Daily backups, 30-day retention

**Cost:** $1-5/month

### Business Application

**Storage:** AWS S3 with Glacier transitions

**Schedule:** Daily backups, 90-day retention, yearly archives

**Cost:** $10-50/month

### E-commerce Site

**Storage:** AWS S3 + Remote server (redundancy)

**Schedule:** Hourly database backups, daily full backups

**Cost:** $50-200/month

### Personal Server

**Storage:** Remote VPS or Backblaze B2

**Schedule:** Weekly backups, 30-day retention

**Cost:** $5-10/month

## Backup Frequency Recommendations

| Data Type | Frequency | Retention |
|-----------|-----------|-----------|
| Critical databases | Hourly | 7 days + weekly for 4 weeks |
| Application files | Daily | 30 days |
| Configuration | Daily | 90 days |
| User uploads | Daily | 30 days |
| Logs | Weekly | 30 days |
| System state | Weekly | 4 weeks |

## Storage Class Decision Matrix

| Priority | Storage Type | Use Case |
|----------|--------------|----------|
| Speed | Local/NAS | Quick restores, staging |
| Cost | Glacier/Archive | Long-term retention |
| Durability | S3/Cloud | Production backups |
| Simplicity | Remote VPS | Small deployments |
| Control | Self-hosted NAS | Data sensitivity |

## Encryption Recommendations

### Client-Side Encryption

Encrypt before upload - most secure:

```bash
# GPG encryption
gpg --encrypt --recipient admin@example.com backup.tar.gz

# OpenSSL encryption
openssl enc -aes-256-cbc -salt -in backup.tar.gz -out backup.tar.gz.enc
```

### Server-Side Encryption

Let storage provider encrypt:

```bash
# S3 server-side encryption
aws s3 cp backup.tar.gz s3://bucket/ --sse AES256

# Or use AWS KMS
aws s3 cp backup.tar.gz s3://bucket/ --sse aws:kms
```

## Testing and Verification

### Regular Test Restores

**Monthly:** Restore random file from backup

**Quarterly:** Full system restore test

**Annually:** Complete disaster recovery drill

### Backup Monitoring

- Alert if backup job fails
- Alert if backup age > 26 hours
- Monitor backup size trends (sudden changes indicate issues)
- Verify backups are reaching remote storage

## Compliance Considerations

### GDPR

- Encrypt personal data
- Document retention periods
- Ability to delete data on request

### HIPAA

- Encrypt at rest and in transit
- Access logging
- Business Associate Agreement with storage provider

### SOC 2

- Documented backup/restore procedures
- Regular testing
- Access controls
- Audit logging

## References

- [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [Backblaze B2 Pricing](https://www.backblaze.com/b2/cloud-storage-pricing.html)
- [DigitalOcean Spaces](https://www.digitalocean.com/products/spaces)
- [The 3-2-1 Backup Rule](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
