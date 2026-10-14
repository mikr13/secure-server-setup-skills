---
name: firewall-configuration
description: Audit or configure UFW on Ubuntu/Debian. Use for source-restricted services and IPv4/IPv6 network exposure checks.
license: MIT
compatibility: Ubuntu/Debian Linux with UFW, OpenSSH, iproute2, Python 3, Bash, and systemd; root for configuration.
metadata:
  author: secure-server-skill
  version: "2.0.0"
  category: security
---

# Firewall configuration

Configure only the required network paths. Existing active policies and rules must be understood before changing defaults; an allowed SSH rule does not demonstrate that a fresh connection works.

## Inventory

- Inspect `ss -ltnup`, effective SSH ports, `ssh.socket` where present, `ufw status verbose`, `ufw show added`, provider security groups and any container-published ports.
- Identify actual management ports and approved source IPv4/IPv6 ranges. With socket activation or a custom daemon invocation, confirm the listener rather than relying on `sshd_config` alone.
- Check `/etc/default/ufw` IPv6 handling. Include relevant external IPv6 tests; IPv4 filtering cannot establish IPv6 isolation.
- Record a console recovery path and the current rules/policies. Do not reset UFW as routine troubleshooting.

Read [references/ufw-rules.md](references/ufw-rules.md) for source-restricted rules, routing, Docker and recovery.

## Configure

Install UFW/iproute2 first if the authorized setup requires them. Preview [scripts/setup-firewall.sh](scripts/setup-firewall.sh):

```bash
sudo bash scripts/setup-firewall.sh --ssh-source 203.0.113.10/32 --allow-port 443/tcp --dry-run
```

For socket/custom listeners, pass each actual port with `--ssh-port`. Repeat `--ssh-source` for authorized sources, including IPv6. `--public-ssh` explicitly chooses access from any source; do not infer that choice from missing information.

Once the rule set and activation are authorized:

```bash
sudo bash scripts/setup-firewall.sh --ssh-source 203.0.113.10/32 --allow-port 443/tcp --apply --enable
```

The helper validates ports/sources/listeners, adds management access first, and snapshots UFW configuration for rollback. It stages deny-incoming/allow-outgoing defaults only on inactive UFW. Existing active defaults and rules are preserved; review unwanted broad allows separately. Without `--enable`, an inactive firewall remains inactive. Public service flags deliberately allow any source; use manual source-restricted rules for internal databases/services.

## Verify and recover

- Verify effective rules and policies, then reconnect through the actual management path. Test approved services and blocked paths from the relevant allowed/denied networks, in both address families where applicable.
- Check container published ports and provider rules independently. Docker's forwarding/NAT path can bypass UFW's host input filtering.
- On command failure, the helper restores its saved files and previous enabled state. For later recovery, use the provider console and printed backup directory; account for service/rule changes made since that snapshot.
- Report configuration, activation and reachability evidence separately. A default-deny policy does not remove pre-existing allow rules, and a running UFW service is not an external exposure test.
