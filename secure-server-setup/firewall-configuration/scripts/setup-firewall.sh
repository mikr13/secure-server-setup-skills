#!/usr/bin/env bash
# Conservative additive UFW setup; existing active policies are preserved.
set -Eeuo pipefail
umask 077
apply=false
explicit_dry_run=false
enable=false
public_ssh=false
ssh_ports=()
ssh_sources=()
allow_ports=()
usage() {
    cat <<'HELP'
Usage: setup-firewall.sh [--ssh-port PORT] (--ssh-source CIDR | --public-ssh) [OPTIONS]
Preview by default; inspect provider/container firewalls separately.
  --ssh-port PORT    Repeat for actual management listeners; otherwise use sshd -T
  --ssh-source CIDR  Repeat for approved management IPv4/IPv6 sources
  --public-ssh       Explicitly permit SSH from any source
  --allow-port N/tcp or N/udp  Repeat for public services that need access
  --apply           Add rules; root required
  --enable          Activate an inactive UFW after adding rules (--apply required)
  --dry-run         Preview only (default)
  --help            Show usage
An active firewall keeps its current default policies and existing rules.
On an inactive firewall, deny incoming/allow outgoing defaults are staged.
Exit: 0 success/preview, 1 command failure, 2 invalid or ambiguous input.
HELP
}
die() { printf '%s\n' "$*" >&2; exit 2; }
valid_port() { [[ $1 =~ ^[0-9]{1,5}$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
while (($#)); do
    case $1 in
        --ssh-port) (($# >= 2)) || die '--ssh-port needs a value'; valid_port "$2" || die 'Port must be 1-65535.'; ssh_ports+=("$((10#$2))"); shift 2 ;;
        --ssh-source) (($# >= 2)) || die '--ssh-source needs a value'; ssh_sources+=("$2"); shift 2 ;;
        --allow-port) (($# >= 2)) || die '--allow-port needs a value'; [[ $2 =~ ^([0-9]{1,5})/(tcp|udp)$ ]] || die 'Use --allow-port N/tcp or N/udp.'; valid_port "${BASH_REMATCH[1]}" || die 'Port must be 1-65535.'; allow_ports+=("$2"); shift 2 ;;
        --public-ssh) public_ssh=true; shift ;;
        --apply) apply=true; shift ;;
        --enable) enable=true; shift ;;
        --dry-run) explicit_dry_run=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
if $apply && $explicit_dry_run; then die 'Choose --apply or --dry-run, not both.'; fi
if $public_ssh; then ((${#ssh_sources[@]} == 0)) || die 'Choose source restrictions or --public-ssh, not both.'
else ((${#ssh_sources[@]})) || die 'Specify --ssh-source CIDR or explicitly choose --public-ssh.'; fi
for source in "${ssh_sources[@]}"; do
    python3 -c 'import ipaddress,sys; ipaddress.ip_network(sys.argv[1],strict=False)' "$source" >/dev/null 2>&1 || die "Invalid source CIDR: $source"
done
command -v ufw >/dev/null || die 'Install UFW before using this helper.'
command -v ss >/dev/null || die 'Install iproute2 before using this helper.'
[[ -f /etc/default/ufw ]] || die 'UFW configuration is missing.'
grep -Eq '^IPV6=yes([[:space:]]|$)' /etc/default/ufw || die 'Review IPv6 policy and set IPV6=yes before using this helper.'
if ((${#ssh_ports[@]} == 0)); then
    if systemctl is-active --quiet ssh.socket; then die 'Socket activation detected; inventory listeners and specify every --ssh-port explicitly.'; fi
    effective=$(/usr/sbin/sshd -T)
    mapfile -t ssh_ports < <(awk '$1=="port" {print $2}' <<< "$effective")
    ((${#ssh_ports[@]})) || die 'Cannot determine SSH ports; specify --ssh-port.'
fi
listeners=$(ss -H -ltn)
listener_ports=$(awk '{n=split($4,a,":"); print a[n]}' <<< "$listeners")
for port in "${ssh_ports[@]}"; do
    valid_port "$port" || die "Invalid SSH port: $port"
    grep -qxF "$port" <<< "$listener_ports" || die "No TCP listener on SSH port $port; inspect actual management access."
done
if [[ -n ${SSH_CONNECTION:-} ]]; then
    read -r _ _ _ current_port <<< "$SSH_CONNECTION"
    found=false
    for port in "${ssh_ports[@]}"; do if [[ $port == "$current_port" ]]; then found=true; fi; done
    $found || die 'The active SSH connection port is missing from the proposed allow rules.'
fi
status=$(ufw status verbose)
was_active=false
if grep -q '^Status: active' <<< "$status"; then was_active=true; fi
printf '%s\nSSH listeners: %s\nPublic service ports: %s\n' "$status" "${ssh_ports[*]}" "${allow_ports[*]:-none}"
if $public_ssh; then printf 'SSH sources: any (explicitly requested)\n'; else printf 'SSH sources: %s\n' "${ssh_sources[*]}"; fi
if $was_active; then printf 'Existing defaults and rules will be preserved; audit broad allows separately.\n'
else printf 'Inactive UFW: stage deny incoming and allow outgoing defaults.\n'; fi
if $enable; then $apply || die '--enable requires --apply.'; fi
if ! $apply; then printf 'Preview only; no firewall changes.\n'; exit 0; fi
[[ $EUID == 0 ]] || die '--apply requires root.'
backup_root=/var/backups/secure-server-setup/ufw
mkdir -p "$backup_root"
chmod 700 "$backup_root"
backup=$(mktemp -d "$backup_root/rollback.XXXXXXXX")
cp -a -- /etc/ufw "$backup/ufw"
cp -p -- /etc/default/ufw "$backup/default-ufw"
touched=false
rollback() {
    rc=$?
    trap - EXIT
    if ((rc != 0)) && $touched; then
        ufw --force disable || true
        cp -a -- "$backup/ufw/." /etc/ufw/
        cp -p -- "$backup/default-ufw" /etc/default/ufw
        if $was_active; then ufw --force enable || printf 'Firewall recovery failed; use the console and backup %s\n' "$backup" >&2; fi
        printf 'Previous firewall configuration restored from %s\n' "$backup" >&2
    fi
    exit "$rc"
}
trap rollback EXIT
touched=true
# Add management access before changing defaults or enabling the firewall.
for port in "${ssh_ports[@]}"; do
    if $public_ssh; then ufw allow "$port/tcp"
    else
        for source in "${ssh_sources[@]}"; do ufw allow from "$source" to any port "$port" proto tcp; done
    fi
done
for port in "${allow_ports[@]}"; do ufw allow "$port"; done
if ! $was_active; then ufw default deny incoming; ufw default allow outgoing; fi
if $enable && ! $was_active; then ufw --force enable; fi
ufw status verbose
printf 'Rollback directory: %s\nVerify a fresh SSH connection and service reachability from allowed and denied networks.\n' "$backup"
