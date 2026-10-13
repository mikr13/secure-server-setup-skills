#!/usr/bin/env bash
# Explicit artifacts only. Upload, read back and verify; never delete local copies.
set -Eeuo pipefail
# shellcheck source-path=SCRIPTDIR
# shellcheck source=backup-common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/backup-common.sh"
files=()
s3_uri=
kms_key=
usage() {
    cat <<'HELP'
Usage: backup-to-s3.sh --s3-uri s3://BUCKET/PREFIX --file ARCHIVE [--file DUMP] [OPTIONS]
Preview by default. Requires AWS CLI, GNU coreutils and adjacent .sha256 files.
  --file PATH       Repeat to include file and database artifacts explicitly
  --s3-uri URI      An existing approved bucket with a nonempty prefix
  --kms-key-id KEY  Use an approved KMS key instead of S3 AES256 encryption
  --apply           Upload artifacts/checksums and download artifacts to verify bytes
  --dry-run         Preview only (default); does not contact AWS
  --help            Show usage
Local copies are retained. Readback incurs transfer/storage costs; configure
least-privilege credentials and remote versioning/retention separately.
Exit: 0 success/preview, 1 transfer/verification failure, 2 invalid input.
HELP
}
while (($#)); do
    case $1 in
        --file) (($# >= 2)) || backup_die '--file needs a value'; files+=("$2"); shift 2 ;;
        --s3-uri) (($# >= 2)) || backup_die '--s3-uri needs a value'; s3_uri=$2; shift 2 ;;
        --kms-key-id) (($# >= 2)) || backup_die '--kms-key-id needs a value'; kms_key=$2; shift 2 ;;
        --apply) APPLY=true; shift ;;
        --dry-run) EXPLICIT_DRY_RUN=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) backup_die "Unknown option: $1" ;;
    esac
done
if $APPLY && $EXPLICIT_DRY_RUN; then backup_die 'Choose --apply or --dry-run, not both.'; fi
((${#files[@]})) || backup_die 'Supply explicit --file paths for every required file/database artifact.'
[[ $s3_uri =~ ^s3://[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]/[^[:space:]]+$ ]] || backup_die 'Use an approved s3://bucket/nonempty-prefix destination.'
s3_uri=${s3_uri%/}
for file in "${files[@]}"; do
    [[ -f $file && ! -L $file && $file != *$'\n'* && $file != *$'\r'* ]] || backup_die "Not a regular artifact: $file"
    verify_checksum "$file" || backup_die "Missing/invalid checksum for $file; verify the artifact first."
    printf 'Upload and byte-verify: %s -> %s/%s\n' "$file" "$s3_uri" "$(basename -- "$file")"
done
if ! $APPLY; then printf 'Preview only; no AWS requests.\n'; exit 0; fi
command -v aws >/dev/null || backup_die 'Install AWS CLI and provision scoped credentials first.'
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
sse=(--sse AES256)
if [[ -n $kms_key ]]; then sse=(--sse aws:kms --sse-kms-key-id "$kms_key"); fi
# Validate all input artifacts above before the first remote mutation.
for file in "${files[@]}"; do
    destination="$s3_uri/$(basename -- "$file")"
    expected=$(awk 'NR==1 {print $1}' "$file.sha256")
    aws s3 cp "$file" "$destination" "${sse[@]}" --only-show-errors
    aws s3 cp "$destination" "$work/readback" --only-show-errors
    actual=$(sha256sum -- "$work/readback")
    [[ ${actual%% *} == "$expected" ]] || { printf 'Remote checksum mismatch for %s; local source retained.\n' "$destination" >&2; exit 1; }
    aws s3 cp "$file.sha256" "$destination.sha256" "${sse[@]}" --only-show-errors
    printf 'Remote bytes verified: %s (local copy retained)\n' "$destination"
done
