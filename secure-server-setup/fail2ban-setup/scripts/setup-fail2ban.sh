#!/usr/bin/env bash
# Manage only the SSH jail; preserve unrelated jails and global settings.
set -Eeuo pipefail
umask 077
apply=false
explicit_dry_run=false
activate=false
ssh_ports=()
usage() {
    cat <<'HELP'
Usage: setup-fail2ban.sh [--ssh-port PORT] [--apply] [--activate]
Preview by default. Requires installed Fail2ban and conventional OpenSSH.
  --ssh-port PORT  Repeat for actual listeners; otherwise read sshd -T
  --apply         Write and validate an SSH-only jail override; root required
  --activate      Reload active Fail2ban or enable/start it if inactive
  --dry-run       Preview only (default)
  --help          Show usage
File logs use polling; journal-only SSH uses systemd (python3-systemd required).
Existing ignoreip settings and other jails are retained. Review your management
allowlist before activation; test bans only from a controlled secondary client.
Exit: 0 success/preview, 1 validation/activation failure, 2 invalid input.
HELP
}
die() { printf '%s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --ssh-port) (($# >= 2)) || die '--ssh-port needs a value'; if ! [[ $2 =~ ^[0-9]{1,5}$ ]] || ((10#$2 < 1 || 10#$2 > 65535)); then die 'Port must be 1-65535.'; fi; ssh_ports+=("$((10#$2))"); shift 2 ;;
        --apply) apply=true; shift ;;
        --activate) activate=true; shift ;;
        --dry-run) explicit_dry_run=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
if $apply && $explicit_dry_run; then die 'Choose --apply or --dry-run, not both.'; fi
command -v fail2ban-client >/dev/null || die 'Install Fail2ban before using this helper.'
if ((${#ssh_ports[@]} == 0)); then
    if systemctl is-active --quiet ssh.socket; then die 'Socket activation detected; inspect listeners and pass explicit --ssh-port values.'; fi
    effective=$(/usr/sbin/sshd -T)
    mapfile -t ssh_ports < <(awk '$1=="port" {print $2}' <<< "$effective")
    ((${#ssh_ports[@]})) || die 'No SSH ports discovered.'
fi
listeners=$(ss -H -ltn)
listener_ports=$(awk '{n=split($4,a,":"); print a[n]}' <<< "$listeners")
for port in "${ssh_ports[@]}"; do
    if ! [[ $port =~ ^[0-9]{1,5}$ ]] || ((10#$port < 1 || 10#$port > 65535)); then die 'Invalid discovered SSH port.'; fi
    grep -qxF "$port" <<< "$listener_ports" || die "No listener on SSH port $port."
done
backend=systemd
logpath=
if [[ -f /var/log/auth.log ]]; then backend=polling; logpath=/var/log/auth.log
elif [[ -f /var/log/secure ]]; then backend=polling; logpath=/var/log/secure
else python3 -c 'import systemd.journal' >/dev/null 2>&1 || die 'Journal backend needs python3-systemd; install it before using this helper.'; fi
managed=/etc/fail2ban/jail.d/99-secure-server-sshd.local
[[ -d /etc/fail2ban/jail.d && ! -L $managed ]] || die 'Inspect the Fail2ban jail directory and symlink targets first.'
port_list=$(IFS=,; printf '%s' "${ssh_ports[*]}")
render() {
    printf '[sshd]\nenabled = true\nport = %s\nfilter = sshd\nbackend = %s\nmaxretry = 5\nfindtime = 600\nbantime = 3600\n' "$port_list" "$backend"
    if [[ -n $logpath ]]; then printf 'logpath = %s\n' "$logpath"; fi
}
printf 'Managed file: %s\n' "$managed"
render
if $activate; then $apply || die '--activate requires --apply.'; fi
if ! $apply; then printf 'Preview only. Existing ignoreip and unrelated jails remain unchanged.\n'; exit 0; fi
[[ $EUID == 0 ]] || die '--apply requires root.'
was_active=false
was_enabled=false
if $activate; then
    if systemctl is-active --quiet fail2ban; then was_active=true; fi
    if ! $was_active; then
        enablement=$(systemctl is-enabled fail2ban || true)
        [[ $enablement == enabled || $enablement == disabled ]] || die "Inspect unexpected Fail2ban enablement state: $enablement"
        if [[ $enablement == enabled ]]; then was_enabled=true; fi
    fi
fi
backup_root=/var/backups/secure-server-setup/fail2ban
mkdir -p "$backup_root"
chmod 700 "$backup_root"
backup=$(mktemp -d "$backup_root/rollback.XXXXXXXX")
existed=false
touched=false
activation_attempted=false
if [[ -f $managed ]]; then cp -p -- "$managed" "$backup/previous.local"; existed=true; fi
rollback() {
    rc=$?
    trap - EXIT
    if ((rc != 0)) && $touched; then
        if $existed; then cp -p -- "$backup/previous.local" "$managed"; else rm -f -- "$managed"; fi
        if $activation_attempted; then
            if $was_active; then fail2ban-client reload || systemctl restart fail2ban || printf 'Recovery failed; use backup %s\n' "$backup" >&2
            else systemctl stop fail2ban || true; fi
            if ! $was_enabled && ! $was_active; then systemctl disable fail2ban || true; fi
        fi
        printf 'Previous managed jail restored. Backup: %s\n' "$backup" >&2
    fi
    exit "$rc"
}
trap rollback EXIT
render > "$backup/candidate.local"
touched=true
install -m 600 -- "$backup/candidate.local" "$managed"
fail2ban-client -t
# Validate merged settings; a later jail override can supersede a valid candidate.
configuration_dump=$(fail2ban-client -d)
python3 -c '
import ast, sys
commands = [ast.literal_eval(line) for line in sys.stdin if line.startswith("[")]
settings = {c[2]: str(c[3]) for c in commands if len(c) == 4 and c[:2] == ["set", "sshd"]}
expected = {"maxretry": "5", "findtime": "600", "bantime": "3600"}
if ["add", "sshd", sys.argv[1]] not in commands or any(settings.get(k) != v for k, v in expected.items()):
    sys.exit("Effective SSH jail differs from the proposed policy; inspect later overrides.")
' "$backend" <<< "$configuration_dump"
if $activate; then
    activation_attempted=true
    if $was_active; then fail2ban-client reload; else systemctl enable --now fail2ban; fi
    fail2ban-client status sshd
    printf 'SSH jail activated. Verify its log source, management allowlist, and controlled ban/unban behavior.\n'
else
    printf 'Configuration validated and staged; the running service has not been changed.\n'
fi
printf 'Rollback directory: %s\n' "$backup"
