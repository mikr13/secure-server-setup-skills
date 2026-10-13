# UFW rules and exposure verification

## Read the current state

```bash
sudo ufw status verbose
sudo ufw status numbered
sudo ufw show added
sudo ss -ltnup
sudo systemctl status ssh.socket --no-pager
```

Preserve console access and record current rules, defaults, IPv6 policy, management listeners, provider rules and published container ports. On an active firewall, a new default-deny policy can affect workloads immediately. Existing allow rules remain in effect after changing defaults.

## Source-restricted services

Replace the example addresses with approved actual sources. Use explicit protocols:

```bash
sudo ufw --dry-run allow from 203.0.113.10/32 to any port 2222 proto tcp
sudo ufw --dry-run allow from 203.0.113.20/32 to any port 3306 proto tcp
sudo ufw --dry-run allow from 2001:db8:1234::/64 to any port 5432 proto tcp
```

The documentation ranges above are examples, not working production source addresses. Keep databases bound to the intended private/loopback interfaces where possible. Do not expose a database to any source merely because remote access is needed.

Use `--dry-run` to inspect a proposed rule; apply the same rule without that flag only in the authorized change scope. A dry run does not prove runtime reachability.

## Direction, interfaces and routing

`ufw allow 22/tcp` defaults to incoming; it is not a combined incoming/outgoing rule. Incoming and outgoing host rules are separate:

```bash
sudo ufw --dry-run allow in 22/tcp
sudo ufw --dry-run allow out 22/tcp
sudo ufw --dry-run allow in on eth0 to any port 443 proto tcp
```

Packets forwarded between interfaces need a routed rule and separately reviewed IP forwarding/routed-default settings:

```bash
sudo ufw --dry-run route allow in on eth1 out on eth0 to 203.0.113.20 port 443 proto tcp
```

Interface names and destinations must match the target. Allowing a route does not configure forwarding or provider routing by itself.

## Activation and IPv6

On a new/inactive firewall, add all required management/service rules before enabling default-deny protection. The setup helper checks that configured SSH ports are actual listeners and include the current SSH connection's server port when available. Socket activation requires explicit listener inventory and port flags.

Inspect `/etc/default/ufw` and require intentional IPv6 handling. The helper requires `IPV6=yes`; review the complete IPv6 rules before changing that setting on an existing machine. Test relevant address families from appropriate external clients after activation. A new connection is required; a surviving established SSH session is insufficient.

On an already active firewall, the helper adds requested rules while preserving defaults and existing rules. Remove an obsolete broad allow only after identifying it and proving that narrower approved access works. Do not assume an added narrow rule restricts an earlier broad allow.

## Containers and provider controls

Docker publishes ports using forwarding/NAT rules that can bypass UFW host input filtering. Inspect mappings, bind addresses and the daemon's configured firewall backend. Use the relevant supported Docker filtering path or bind services to the intended interface; do not disable Docker's firewall management as a blanket fix.

Provider security groups, NAT/forwarding, reverse proxies and IPv6 addresses are separate parts of the exposure boundary. Validate allowed and denied paths from outside the host. `ufw status` alone cannot establish public/LAN isolation.

## Recovery

Use the provider console when remote connectivity fails. The helper snapshots `/etc/ufw` and `/etc/default/ufw` and restores its prior state on command failure. Its printed backup is for the captured state only; review subsequent rule changes before manually reverting.

`ufw reset` deletes all rules. Reserve it for an explicitly reviewed recovery plan with saved configuration and replacement management/service rules; do not prescribe it as routine troubleshooting.

## Sources

- [UFW manual](https://manpages.ubuntu.com/manpages/jammy/man8/ufw.8.html)
- [Ubuntu firewall guidance](https://ubuntu.com/server/docs/how-to/security/firewalls/)
- [Docker packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
