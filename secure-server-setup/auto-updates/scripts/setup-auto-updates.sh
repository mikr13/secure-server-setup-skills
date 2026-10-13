#!/usr/bin/env bash
# Configure periodic upgrades without changing origins, cleanup or reboot policy.
set -Eeuo pipefail
umask 077
apply=false
explicit_dry_run=false
activate=false
usage() {
    cat <<'HELP'
Usage: setup-auto-updates.sh [--apply] [--activate]
Preview by default. Requires unattended-upgrades, APT and systemd on Ubuntu/Debian.
  --apply      Write a managed periodic-settings drop-in and run an upgrade dry run
  --activate   Also enable/start apt-daily.timer and apt-daily-upgrade.timer
  --dry-run    Preview only (default)
  --help       Show usage
Does not perform apt upgrade, change allowed origins, dependency cleanup, or
reboot policy. Inspect existing origins/reboot settings before approval.
Exit: 0 success/preview, 1 validation/activation failure, 2 invalid input.
HELP
}
die() { printf '%s\n' "$*" >&2; exit 2; }
while (($#)); do
    case $1 in
        --apply) apply=true; shift ;;
        --activate) activate=true; shift ;;
        --dry-run) explicit_dry_run=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done
if $apply && $explicit_dry_run; then die 'Choose --apply or --dry-run, not both.'; fi
command -v unattended-upgrade >/dev/null || die 'Install unattended-upgrades before using this helper.'
command -v apt-config >/dev/null || die 'APT is required.'
managed=/etc/apt/apt.conf.d/99-secure-server-auto-upgrades
[[ -d /etc/apt/apt.conf.d && ! -L $managed ]] || die 'Inspect the APT configuration directory and symlink targets first.'
settings=$(apt-config dump)
if ! grep -Eq '^Unattended-Upgrade::(Allowed-Origins|Origins-Pattern):: "' <<< "$settings"; then
    die 'No allowed update origins are configured; review distribution security origins first.'
fi
printf 'Existing update and reboot policy:\n'
grep -E '^(Unattended-Upgrade::(Allowed-Origins|Origins-Pattern|Automatic-Reboot|Remove-)|APT::Periodic::)' <<< "$settings" || true
printf 'Managed file: %s\n' "$managed"
render() { printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n'; }
render
if $activate; then $apply || die '--activate requires --apply.'; fi
if ! $apply; then printf 'Preview only. Package upgrades, origins, cleanup and reboot settings are unchanged.\n'; exit 0; fi
[[ $EUID == 0 ]] || die '--apply requires root.'
timers=(apt-daily.timer apt-daily-upgrade.timer)
previous_enabled=()
previous_active=()
if $activate; then
    for timer in "${timers[@]}"; do
        state=$(systemctl is-enabled "$timer" || true)
        [[ $state == enabled || $state == disabled ]] || die "Inspect unexpected timer enablement state for $timer: $state"
        previous_enabled+=("$state")
        if systemctl is-active --quiet "$timer"; then previous_active+=(active); else previous_active+=(inactive); fi
    done
fi
backup_root=/var/backups/secure-server-setup/apt
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
            for i in "${!timers[@]}"; do
                if [[ ${previous_active[i]} == inactive ]]; then systemctl stop "${timers[i]}" || true; fi
                if [[ ${previous_enabled[i]} == disabled ]]; then systemctl disable "${timers[i]}" || true; fi
            done
        fi
        printf 'Previous periodic settings and changed timer states restored. Backup: %s\n' "$backup" >&2
    fi
    exit "$rc"
}
trap rollback EXIT
render > "$backup/candidate.conf"
touched=true
install -m 600 -- "$backup/candidate.conf" "$managed"
settings=$(apt-config dump)
for setting in 'APT::Periodic::Update-Package-Lists "1";' 'APT::Periodic::Unattended-Upgrade "1";'; do
    if ! grep -qxF "$setting" <<< "$settings"; then printf 'Effective APT policy mismatch: %s\n' "$setting" >&2; exit 1; fi
done
unattended-upgrade --dry-run --debug
if $activate; then
    activation_attempted=true
    systemctl enable --now "${timers[@]}"
    for timer in "${timers[@]}"; do systemctl is-enabled --quiet "$timer"; systemctl is-active --quiet "$timer"; done
    systemctl list-timers "${timers[@]}" --no-pager
else
    printf 'Periodic settings validated; timer states are unchanged. Inspect apt-daily timers before claiming scheduled updates.\n'
fi
printf 'Rollback directory: %s\n' "$backup"
