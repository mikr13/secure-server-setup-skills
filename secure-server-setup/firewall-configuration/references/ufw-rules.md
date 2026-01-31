# UFW Rules Reference

## Basic UFW Commands

### Status and Information

```bash
# Check status
sudo ufw status

# Verbose status
sudo ufw status verbose

# Numbered rules (for deletion)
sudo ufw status numbered

# Show listening ports
sudo ufw show listening

# Show added rules
sudo ufw show added
```

### Enable/Disable

```bash
# Enable firewall
sudo ufw enable

# Disable firewall
sudo ufw disable

# Reload rules
sudo ufw reload

# Reset all rules (WARNING: removes everything)
sudo ufw reset
```

## Default Policies

```bash
# Deny all incoming
sudo ufw default deny incoming

# Allow all outgoing
sudo ufw default allow outgoing

# Deny forwarding (routing)
sudo ufw default deny routed
```

## Allow Rules

### By Port Number

```bash
# Allow specific port
sudo ufw allow 22

# Allow specific port and protocol
sudo ufw allow 22/tcp
sudo ufw allow 53/udp

# Allow port range
sudo ufw allow 6000:6007/tcp

# Allow from specific port
sudo ufw allow from any to any port 22
```

### By Service Name

```bash
# Allow by service name
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow smtp
```

### By IP Address

```bash
# Allow from specific IP
sudo ufw allow from 203.0.113.10

# Allow from specific IP to specific port
sudo ufw allow from 203.0.113.10 to any port 22

# Allow from subnet
sudo ufw allow from 192.168.1.0/24

# Allow from subnet to specific port
sudo ufw allow from 192.168.1.0/24 to any port 3306
```

### By Network Interface

```bash
# Allow on specific interface
sudo ufw allow in on eth0 to any port 80

# Allow from interface
sudo ufw allow in on eth1
```

## Deny Rules

```bash
# Deny specific port
sudo ufw deny 23/tcp

# Deny from specific IP
sudo ufw deny from 203.0.113.100

# Deny to specific IP
sudo ufw deny to 203.0.113.101

# Deny from IP to specific port
sudo ufw deny from 203.0.113.100 to any port 22
```

## Rate Limiting

Limit connection attempts (useful for SSH):

```bash
# Limit SSH connections
sudo ufw limit 22/tcp

# Limit with IP
sudo ufw limit from 203.0.113.0/24 to any port 22
```

**How it works:** Denies connections if an IP makes more than 6 connection attempts within 30 seconds.

## Delete Rules

```bash
# Delete by rule specification
sudo ufw delete allow 80/tcp
sudo ufw delete allow from 203.0.113.10

# Delete by rule number
sudo ufw status numbered
sudo ufw delete 3

# Delete with confirmation
sudo ufw --force delete 3
```

## Application Profiles

### List and View Profiles

```bash
# List all application profiles
sudo ufw app list

# Show profile information
sudo ufw app info 'Nginx Full'

# Update application profiles
sudo ufw app update all
```

### Use Application Profiles

```bash
# Allow application
sudo ufw allow 'Nginx Full'
sudo ufw allow 'OpenSSH'
sudo ufw allow 'Apache Full'

# Delete application rule
sudo ufw delete allow 'Nginx Full'
```

### Create Custom Application Profile

Create file `/etc/ufw/applications.d/myapp`:

```
[MyApp]
title=My Application
description=Custom application ports
ports=8080,8443/tcp

[MyAppHTTP]
title=My Application (HTTP only)
description=Custom app HTTP only
ports=8080/tcp
```

Update and use:

```bash
sudo ufw app update MyApp
sudo ufw allow 'MyApp'
```

## Advanced Rules

### Specific Protocol

```bash
# TCP only
sudo ufw allow 22/tcp

# UDP only
sudo ufw allow 53/udp

# Both TCP and UDP
sudo ufw allow 53
```

### Interface-Specific Rules

```bash
# Allow on specific interface
sudo ufw allow in on eth0 to any port 80

# Allow from interface to interface
sudo ufw allow in on eth1 out on eth0
```

### Bidirectional Rules

```bash
# Allow incoming on port 22
sudo ufw allow in 22/tcp

# Allow outgoing on port 22
sudo ufw allow out 22/tcp

# Allow both
sudo ufw allow 22/tcp
```

### Complex Rules

```bash
# Allow from specific IP to specific port on specific interface
sudo ufw allow in on eth0 from 203.0.113.10 to any port 3306

# Allow from subnet to specific IP and port
sudo ufw allow from 192.168.1.0/24 to 192.168.1.100 port 5432
```

## Logging

### Configure Logging

```bash
# Enable logging
sudo ufw logging on

# Set log level
sudo ufw logging low      # Default
sudo ufw logging medium   # More detail
sudo ufw logging high     # Maximum detail
sudo ufw logging full     # Everything

# Disable logging
sudo ufw logging off
```

### View Logs

```bash
# UFW log file
sudo tail -f /var/log/ufw.log

# Filter for blocked packets
sudo grep "\[UFW BLOCK\]" /var/log/ufw.log

# Filter for allowed packets
sudo grep "\[UFW ALLOW\]" /var/log/ufw.log

# Filter by IP
sudo grep "203.0.113.100" /var/log/ufw.log
```

## Rule Order and Priority

UFW processes rules in order. First match wins.

### Insert Rule at Position

```bash
# Insert at position 1 (highest priority)
sudo ufw insert 1 allow from 203.0.113.10

# Insert at specific position
sudo ufw insert 3 deny from 203.0.113.100
```

## Common Port Numbers

| Service | Port | Protocol |
|---------|------|----------|
| SSH | 22 | TCP |
| HTTP | 80 | TCP |
| HTTPS | 443 | TCP |
| FTP | 21 | TCP |
| FTP Data | 20 | TCP |
| SMTP | 25 | TCP |
| POP3 | 110 | TCP |
| IMAP | 143 | TCP |
| MySQL | 3306 | TCP |
| PostgreSQL | 5432 | TCP |
| Redis | 6379 | TCP |
| MongoDB | 27017 | TCP |
| DNS | 53 | TCP/UDP |
| NTP | 123 | UDP |

## UFW Configuration Files

### Main Config

```
/etc/ufw/ufw.conf          # Main UFW configuration
/etc/ufw/before.rules      # Rules processed before UFW rules
/etc/ufw/after.rules       # Rules processed after UFW rules
/etc/ufw/before6.rules     # IPv6 before rules
/etc/ufw/after6.rules      # IPv6 after rules
/etc/default/ufw           # UFW defaults
/etc/ufw/applications.d/   # Application profiles
```

### Enable IPv6

Edit `/etc/default/ufw`:

```
IPV6=yes
```

Reload:

```bash
sudo ufw reload
```

## Useful Rule Combinations

### Web Server

```bash
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Database Server (Restricted)

```bash
sudo ufw allow ssh
sudo ufw allow from 192.168.1.0/24 to any port 3306
```

### Mail Server

```bash
sudo ufw allow ssh
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 993/tcp   # IMAPS
sudo ufw allow 995/tcp   # POP3S
```

### Development Server

```bash
sudo ufw allow ssh
sudo ufw allow 3000/tcp  # Node.js
sudo ufw allow 8080/tcp  # Alt HTTP
sudo ufw allow 5432/tcp  # PostgreSQL
```

## Troubleshooting

### Check if UFW is Active

```bash
sudo ufw status
sudo systemctl status ufw
```

### Test Configuration

```bash
# Dry run (test without applying)
sudo ufw --dry-run enable
```

### View iptables Rules

UFW uses iptables underneath:

```bash
# View current iptables rules
sudo iptables -L -n -v

# View NAT rules
sudo iptables -t nat -L -n -v
```

### Reset UFW

If things go wrong:

```bash
# Disable first
sudo ufw disable

# Reset all rules
sudo ufw reset

# Start fresh
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

## Security Best Practices

1. **Always allow SSH first** before enabling UFW
2. **Default deny** - Start with deny all, then allow specific
3. **Minimal exposure** - Only open necessary ports
4. **IP restrictions** - Limit admin ports to known IPs
5. **Rate limiting** - Use for SSH and other auth services
6. **Regular audits** - Review rules periodically
7. **Logging** - Enable and monitor logs
8. **Documentation** - Keep notes on why ports are open

## References

- [UFW Manual](https://manpages.ubuntu.com/manpages/jammy/man8/ufw.8.html)
- [Ubuntu UFW Guide](https://help.ubuntu.com/community/UFW)
- [DigitalOcean UFW Essentials](https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands)
