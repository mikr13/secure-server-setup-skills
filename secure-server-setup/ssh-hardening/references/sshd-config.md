# SSH Configuration Reference (sshd_config)

## Configuration File Locations

- Main config: `/etc/ssh/sshd_config`
- Drop-in configs: `/etc/ssh/sshd_config.d/*.conf` (Ubuntu 22.04+)
- User keys: `~/.ssh/authorized_keys`

## Essential Security Settings

### Authentication Settings

```
# Enable public key authentication
PubkeyAuthentication yes

# Disable password authentication
PasswordAuthentication no

# Disable challenge-response authentication
ChallengeResponseAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Disable root login
PermitRootLogin no

# Disable host-based authentication
HostbasedAuthentication no
```

### Access Control

```
# Allow only specific users
AllowUsers user1 user2 deployer

# Or allow users in specific groups
AllowGroups sshusers admins

# Deny specific users
DenyUsers baduser

# Deny specific groups
DenyGroups nonetwork
```

### Connection Settings

```
# Limit authentication attempts
MaxAuthTries 3

# Maximum concurrent unauthenticated connections
MaxStartups 10:30:60

# Login grace time (seconds)
LoginGraceTime 60

# Client alive interval (seconds)
ClientAliveInterval 300
ClientAliveCountMax 2

# TCP keep alive
TCPKeepAlive yes
```

### Port and Protocol

```
# Default port (change for obscurity, optional)
Port 22

# Listen on specific IPs only
ListenAddress 0.0.0.0
ListenAddress ::

# Use only protocol 2
Protocol 2
```

### Forwarding and Tunneling

```
# X11 forwarding (disable unless needed)
X11Forwarding no

# TCP forwarding (disable unless needed)
AllowTcpForwarding no

# Agent forwarding (disable unless needed)
AllowAgentForwarding no

# Tunnel devices (disable unless needed)
PermitTunnel no
```

### Logging

```
# Log level
LogLevel VERBOSE

# Facility
SyslogFacility AUTH

# Print last login time
PrintLastLog yes

# Print message of the day
PrintMotd yes
```

## Advanced Security Settings

### Key Types

```
# Allowed host key types
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-256-cert-v01@openssh.com

# Allowed public key types
PubkeyAcceptedAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-256-cert-v01@openssh.com
```

### Ciphers and MACs

```
# Strong ciphers only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Strong MACs only
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Strong key exchange algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
```

### PAM and Environment

```
# Use PAM
UsePAM yes

# Accept environment variables
AcceptEnv LANG LC_*

# Print environment
PermitUserEnvironment no
```

## Testing Configuration

### Syntax Check

```bash
# Test configuration
sudo sshd -t

# Test with specific config file
sudo sshd -t -f /etc/ssh/sshd_config

# Extended test
sudo sshd -T
```

### View Effective Configuration

```bash
# Show all effective settings
sudo sshd -T

# Show settings for specific user
sudo sshd -T -C user=deployer

# Show settings with connection info
sudo sshd -T -C user=deployer,host=example.com,addr=192.168.1.100
```

## Restart SSH Service

```bash
# Test first!
sudo sshd -t

# Restart (Ubuntu/Debian)
sudo systemctl restart sshd

# Restart (older systems)
sudo service ssh restart

# Check status
sudo systemctl status sshd
```

## Match Blocks

Apply different settings for specific users, groups, or hosts:

```
# Different settings for specific user
Match User backupuser
    PasswordAuthentication yes
    AllowTcpForwarding no

# Different settings for specific network
Match Address 192.168.1.0/24
    PasswordAuthentication yes

# Different settings for specific group
Match Group contractors
    X11Forwarding no
    AllowTcpForwarding no
    ForceCommand /usr/local/bin/restricted-shell
```

## Common Configurations

### Maximum Security (Keys Only)

```
Protocol 2
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers deployer admin
```

### Balanced (Some Flexibility)

```
Protocol 2
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
AllowTcpForwarding yes
MaxAuthTries 3
LoginGraceTime 120
AllowGroups sshusers
```

## Security Checklist

- [ ] Root login disabled
- [ ] Password authentication disabled
- [ ] SSH keys configured for all users
- [ ] AllowUsers or AllowGroups configured
- [ ] MaxAuthTries set to 3 or less
- [ ] X11Forwarding disabled (unless needed)
- [ ] TCP forwarding restricted
- [ ] Strong ciphers and MACs configured
- [ ] Fail2ban installed and configured
- [ ] Firewall limiting SSH access
- [ ] Regular monitoring of /var/log/auth.log

## Monitoring and Logs

### Log Files

```bash
# Authentication log (Ubuntu/Debian)
/var/log/auth.log

# Authentication log (RHEL/CentOS)
/var/log/secure

# SSH daemon log
sudo journalctl -u sshd
```

### Useful Commands

```bash
# Watch authentication attempts in real-time
sudo tail -f /var/log/auth.log

# Count failed login attempts
sudo grep "Failed password" /var/log/auth.log | wc -l

# Show failed login IPs
sudo grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# Show successful logins
sudo grep "Accepted publickey" /var/log/auth.log

# Show last login times
lastlog

# Show who is currently logged in
who
w
```

## References

- [OpenSSH sshd_config man page](https://man.openbsd.org/sshd_config)
- [Mozilla SSH Configuration Guidelines](https://infosec.mozilla.org/guidelines/openssh)
- [SSH Hardening Guides](https://www.ssh.com/academy/ssh/sshd_config)
