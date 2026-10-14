#!/usr/bin/env bash
# Run on the local client. Personal keys should have a passphrase.
set -Eeuo pipefail
umask 077
apply=false
explicit_dry_run=false
interactive=false
no_passphrase=false
key_file=
comment=
usage() {
    cat <<'HELP'
Usage: generate-ssh-keys.sh --key-file ABSOLUTE_PATH --comment LABEL [OPTIONS]
Preview by default. Never overwrite an existing private or public key.
  --apply           Generate on this local client
  --interactive     Human terminal only; ssh-keygen asks for a passphrase
  --no-passphrase   Explicit unattended service-key choice; protect access carefully
  --dry-run         Preview only (default)
  --help            Show usage
Choose --interactive for personal keys. Agents cannot supply a passphrase via
this helper; ask the user to generate it locally or use a hardware-backed key.
Exit: 0 success/preview, 1 generation failure, 2 invalid input/key already exists.
HELP
}
die() { printf '%s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --key-file) (($# >= 2)) || die '--key-file needs a value'; key_file=$2; shift 2 ;;
        --comment) (($# >= 2)) || die '--comment needs a value'; comment=$2; shift 2 ;;
        --apply) apply=true; shift ;;
        --interactive) interactive=true; shift ;;
        --no-passphrase) no_passphrase=true; shift ;;
        --dry-run) explicit_dry_run=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
if $apply && $explicit_dry_run; then die 'Choose --apply or --dry-run, not both.'; fi
[[ $key_file == /* && -n $comment ]] || die 'Supply an absolute --key-file and a nonempty --comment.'
[[ ! -e $key_file && ! -L $key_file && ! -e $key_file.pub && ! -L $key_file.pub ]] || die 'An existing key or public-key path must not be replaced.'
if $interactive && $no_passphrase; then die 'Choose one passphrase mode.'; fi
printf 'New private key: %s\nNew public key: %s.pub\n' "$key_file" "$key_file"
if ! $apply; then printf 'Preview only; run this helper on the LOCAL client.\n'; exit 0; fi
if $interactive; then [[ -t 0 ]] || die '--interactive requires a human terminal.'
elif ! $no_passphrase; then die 'Choose --interactive or explicitly --no-passphrase.'; fi
parent=$(dirname -- "$key_file")
mkdir -p -- "$parent"
[[ -O $parent && ! -L $parent ]] || die 'The key directory must be owned by the current user and not a symlink.'
# Reject a directory another user can write; do not alter existing directory modes.
if [[ $(find "$parent" -prune \( -perm -020 -o -perm -002 \) -print) ]]; then die 'The key directory must not be writable by group/others.'; fi
work=$(mktemp -d "$parent/.key-generation.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
if $interactive; then ssh-keygen -t ed25519 -C "$comment" -f "$work/key"
else ssh-keygen -q -t ed25519 -N '' -C "$comment" -f "$work/key"; fi
# Hard links fail on an existing destination instead of overwriting it.
ln -- "$work/key" "$key_file"
if ! ln -- "$work/key.pub" "$key_file.pub"; then
    if [[ $key_file -ef $work/key ]]; then rm -f -- "$key_file"; fi
    exit 1
fi
printf 'Key pair created. Test with: ssh -o IdentitiesOnly=yes -i "%s" user@host\n' "$key_file"
