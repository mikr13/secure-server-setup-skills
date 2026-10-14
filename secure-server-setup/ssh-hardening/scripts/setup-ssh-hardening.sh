#!/usr/bin/env bash
# Key-only policy for a conventional Ubuntu/Debian OpenSSH service.
set -Eeuo pipefail
umask 077
apply=false
explicit_dry_run=false
activate=false
confirmed=false
users=()
connection=${SSH_CONNECTION:-}
client_address=${connection%% *}
client_host=
usage() {
    cat <<'HELP'
Usage: setup-ssh-hardening.sh --user USER [--user USER] --client-address IP [OPTIONS]
Preview by default. Requires an existing non-root administrator with working keys.
  --client-host HOST       Connection hostname for Match rules (default: IP)
  --key-access-confirmed  Attest fresh key login and sudo access for every user
  --apply                Write and validate a managed drop-in; root required
  --activate             Reload the active SSH service after validation
  --dry-run              Preview only (default)
  --help                 Show usage
Keep the current connection and provider console available. After activation,
verify a fresh key login and sudo access. Do not use this helper to replace MFA.
Exit: 0 success/preview, 1 configuration/activation failure, 2 invalid input.
HELP
}
die() { printf '%s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --user) (($# >= 2)) || die '--user needs a value'; users+=("$2"); shift 2 ;;
        --client-address) (($# >= 2)) || die '--client-address needs a value'; client_address=$2; shift 2 ;;
        --client-host) (($# >= 2)) || die '--client-host needs a value'; client_host=$2; shift 2 ;;
        --key-access-confirmed) confirmed=true; shift ;;
        --apply) apply=true; shift ;;
        --activate) activate=true; shift ;;
        --dry-run) explicit_dry_run=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
if $apply && $explicit_dry_run; then die 'Choose --apply or --dry-run, not both.'; fi
((${#users[@]})) || die 'Supply at least one existing --user.'
python3 -c 'import ipaddress,sys; ipaddress.ip_address(sys.argv[1])' "$client_address" >/dev/null 2>&1 || die 'Supply a valid actual client IP with --client-address (Python 3 required).'
client_host=${client_host:-$client_address}
[[ $client_host =~ ^[a-zA-Z0-9_.:-]+$ ]] || die 'Invalid --client-host.'
for user in "${users[@]}"; do
    [[ $user =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "Invalid username: $user"
    uid=$(id -u "$user") || die "User does not exist: $user"
    [[ $uid != 0 ]] || die 'A root account cannot be the administrator for this policy.'
done
sshd_bin=$(command -v sshd || true)
sshd_bin=${sshd_bin:-/usr/sbin/sshd}
[[ -x $sshd_bin ]] || die 'Install OpenSSH server before using this helper.'
"$sshd_bin" -t
# Do not silently remove intentional multiple-factor authentication.
for user in "${users[@]}"; do
    effective=$("$sshd_bin" -T -C "user=$user,host=$client_host,addr=$client_address")
    methods=$(awk '$1=="authenticationmethods" {print $2}' <<< "$effective")
    [[ $methods == any || $methods == publickey ]] || die 'Existing MFA/custom authentication requires a reviewed manual policy.'
done
managed=/etc/ssh/sshd_config.d/00-secure-server-hardening.conf
[[ -d /etc/ssh/sshd_config.d && ! -L $managed ]] || die 'Inspect the SSH include directory and remove ambiguous symlink targets first.'
service=
if $activate; then
    $apply || die '--activate requires --apply.'
    for unit in ssh.service sshd.service; do
        if systemctl is-active --quiet "$unit"; then service=$unit; break; fi
    done
    [[ -n $service ]] || die 'No active conventional SSH service found; inspect service/socket activation manually.'
fi
printf 'Managed file: %s\nUsers to verify: %s\n' "$managed" "${users[*]}"
cat <<'POLICY'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
POLICY
if ! $apply; then
    printf 'Preview only. Existing AllowUsers/AllowGroups, ports and forwarding settings are preserved.\n'
    exit 0
fi
[[ $EUID == 0 ]] || die '--apply requires root.'
$confirmed || die 'Verify fresh key login and sudo first; supply --key-access-confirmed.'
backup_root=/var/backups/secure-server-setup/ssh
mkdir -p "$backup_root"
chmod 700 "$backup_root"
backup=$(mktemp -d "$backup_root/rollback.XXXXXXXX")
existed=false
touched=false
activation_attempted=false
if [[ -f $managed ]]; then cp -p -- "$managed" "$backup/previous.conf"; existed=true; fi
rollback() {
    rc=$?
    trap - EXIT
    if ((rc != 0)) && $touched; then
        if $existed; then cp -p -- "$backup/previous.conf" "$managed"; else rm -f -- "$managed"; fi
        if $activation_attempted; then
            systemctl reload "$service" || printf 'Recovery reload failed; use the console and backup %s\n' "$backup" >&2
        fi
        printf 'Restored the previous managed drop-in. Backup: %s\n' "$backup" >&2
    fi
    exit "$rc"
}
trap rollback EXIT
cat > "$backup/candidate.conf" <<'POLICY'
# Managed by secure-server-setup-skills. Other access rules remain unchanged.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
POLICY
touched=true
install -m 600 -- "$backup/candidate.conf" "$managed"
"$sshd_bin" -t
for user in "${users[@]}" root; do
    effective=$("$sshd_bin" -T -C "user=$user,host=$client_host,addr=$client_address")
    for setting in 'permitrootlogin no' 'passwordauthentication no' 'kbdinteractiveauthentication no' 'pubkeyauthentication yes' 'authenticationmethods publickey'; do
        if ! grep -qxF "$setting" <<< "$effective"; then
            printf 'Effective policy mismatch for %s: %s. Inspect Include order and Match rules.\n' "$user" "$setting" >&2
            exit 1
        fi
    done
done
if $activate; then
    activation_attempted=true
    systemctl reload "$service"
    systemctl is-active --quiet "$service"
    printf 'SSH reload succeeded. Verify a fresh key login and sudo; keep your original session open.\n'
else
    printf 'Policy staged and effective file settings validated; the running daemon has not been reloaded.\n'
fi
printf 'Rollback directory: %s\n' "$backup"
