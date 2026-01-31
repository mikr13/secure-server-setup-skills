# Fail2ban Filters Reference

## Common Filters

Fail2ban includes many pre-built filters in `/etc/fail2ban/filter.d/`. Here are the most commonly used ones:

### SSH Filters

**sshd.conf** - Standard SSH daemon filter

```ini
[Definition]
failregex = ^%(__prefix_line)s(?:error: PAM: )?[aA]uthentication (?:failure|error|failed) for .* from <HOST>( via \S+)?\s*$
            ^%(__prefix_line)s(?:error: PAM: )?User not known to the underlying authentication module for .* from <HOST>\s*$
            ^%(__prefix_line)sFailed (?:password|publickey) for .* from <HOST>(?: port \d*)?(?: ssh\d*)?
            ^%(__prefix_line)sROOT LOGIN REFUSED.* FROM <HOST>
            ^%(__prefix_line)s[iI](?:llegal|nvalid) user .* from <HOST>
```

**sshd-ddos.conf** - Protects against SSH connection flooding

```ini
[Definition]
failregex = ^%(__prefix_line)sdid not receive identification string from <HOST>\s*$
            ^%(__prefix_line)sConnection (?:closed|reset) by <HOST>
```

### Web Server Filters

**nginx-http-auth.conf** - Nginx HTTP authentication failures

```ini
[Definition]
failregex = ^ \[error\] \d+#\d+: \*\d+ user "\S+":? (password mismatch|was not found in ".*"), client: <HOST>, server: \S+, request: "\S+ \S+ HTTP/\d+\.\d+", host: "\S+"(, referrer: "\S+")?$
```

**apache-auth.conf** - Apache authentication failures

```ini
[Definition]
failregex = ^%(_apache_error_client)s (AH01797: )?client denied by server configuration: (uri )?\S*(, referer: \S+)?\s*$
            ^%(_apache_error_client)s (AH01617: )?user .*: authentication failure for "\S+": password mismatch(, referer: \S+)?\s*$
```

**nginx-noscript.conf** - Block script kiddie attempts

```ini
[Definition]
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)
```

**nginx-badbots.conf** - Block malicious bots

```ini
[Definition]
badbotscustom = EmailCollector|WebEMailExtrac|TrackBack/1\.02|sogou music spider
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*"(?:%(badbots)s|%(badbotscustom)s)"$
```

**nginx-noproxy.conf** - Block proxy attempts

```ini
[Definition]
failregex = ^<HOST> -.*GET http.*
```

**apache-overflows.conf** - Detect overflow attempts

```ini
[Definition]
failregex = ^%(_apache_error_client)s (AH00126: )?Invalid URI in request .*$
            ^%(_apache_error_client)s (AH00127: )?request failed: URI too long \(longer than \d+\).*$
```

### Application Filters

**wordpress-auth.conf** - WordPress login attempts

```ini
[Definition]
failregex = ^<HOST> .* "POST /wp-login\.php
            ^<HOST> .* "POST /xmlrpc\.php
```

**drupal-auth.conf** - Drupal login failures

```ini
[Definition]
failregex = ^.*\|<HOST>\|.*\|Login attempt failed for .*\|\d+\|.*$
```

**phpmyadmin.conf** - phpMyAdmin access

```ini
[Definition]
failregex = ^<HOST> -.*"(GET|POST) /(?:pma|phpmyadmin|myadmin|mysql|sql)
```

### Mail Server Filters

**postfix.conf** - Postfix SMTP authentication

```ini
[Definition]
failregex = ^%(__prefix_line)s(?:SASL (PLAIN|LOGIN) authentication failed): .*\[<HOST>\]$
            ^%(__prefix_line)swarning: [-._\w]+\[<HOST>\]: SASL (PLAIN|LOGIN) authentication failed
```

**dovecot.conf** - Dovecot IMAP/POP3

```ini
[Definition]
failregex = (?: pop3-login|imap-login): .*(?:Authentication failure|Aborted login \(auth failed|Aborted login \(tried to use disabled|Disconnected \(auth failed|Aborted login \(\d+ authentication attempts).*rip=<HOST>
```

### FTP Filters

**proftpd.conf** - ProFTPD failures

```ini
[Definition]
failregex = ^\S+ \(\S+\[<HOST>\]\) - maximum login attempts \(\d+\) exceeded$
            ^\S+ \(\S+\[<HOST>\]\) - (?:SECURITY VIOLATION|no such user found)
```

**vsftpd.conf** - vsftpd failures

```ini
[Definition]
failregex = ^.* \[pid \d+\] \[.+\] FAIL LOGIN: Client "<HOST>"\s*$
```

## Creating Custom Filters

### Basic Filter Structure

```ini
[INCLUDES]
# Include common definitions
before = common.conf

[Definition]
# Define the date format
datepattern = {^LN-BEG}%%Y-%%m-%%d %%H:%%M:%%S

# Regular expressions to match failed attempts
failregex = ^.*Failed login from <HOST>.*$
            ^.*Authentication failed for user .* from <HOST>.*$

# Regular expressions to ignore (whitelist patterns)
ignoreregex =
```

### Example: Custom Application Filter

Create `/etc/fail2ban/filter.d/myapp.conf`:

```ini
[INCLUDES]
before = common.conf

[Definition]
# Match failed login attempts
failregex = ^\[error\] .*: Failed login attempt from <HOST>
            ^\[warning\] .*: Invalid credentials from <HOST>
            ^<HOST> - .* "POST /api/auth" 401

# Ignore successful authentications
ignoreregex = ^\[info\] .*: Successful login from <HOST>
```

### Testing Filters

Test a filter against a log file:

```bash
# Test filter
fail2ban-regex /var/log/myapp.log /etc/fail2ban/filter.d/myapp.conf

# Test with verbose output
fail2ban-regex -v /var/log/myapp.log /etc/fail2ban/filter.d/myapp.conf

# Test specific lines
echo 'Failed login attempt from 203.0.113.100' | fail2ban-regex systemd-journal /etc/fail2ban/filter.d/myapp.conf
```

## Filter Variables

### Common Prefixes

```ini
__prefix_line = ^(?:%(__date_prefix)s\s+)?%(_daemon)s\s*:?\s*
__date_prefix = (?:DAY )?MON Day 24hour:Minute:Second(?:\.Microseconds)?(?: Year)?
_daemon = [\w\._-]+
```

### HOST Variable

`<HOST>` is automatically replaced with IPv4/IPv6 regex:

- IPv4: `(?:::f{4,6}:)?(?P<host>\S+)`
- IPv6: Full IPv6 address matching

### Custom Variables

Define custom variables:

```ini
[Definition]
_daemon = myapp
__prefix_line = ^\[%(__date_prefix)s\] \[%(_daemon)s\]
failregex = %(__prefix_line)s Failed login from <HOST>
```

## Filter Examples by Use Case

### Detect SQL Injection Attempts

```ini
[Definition]
failregex = ^<HOST> .* "(GET|POST).*?(union.*select|select.*from|insert.*into|delete.*from).*"
```

### Detect Directory Traversal

```ini
[Definition]
failregex = ^<HOST> .* "(GET|POST).*?(\.\.\/|\.\.\|\%2e\%2e).*"
```

### Detect XSS Attempts

```ini
[Definition]
failregex = ^<HOST> .* "(GET|POST).*?(<script|javascript:|onerror=|onload=).*"
```

### Detect Brute Force on Custom API

```ini
[Definition]
failregex = ^<HOST> - .* "POST /api/login" (401|403)
            ^.*Authentication failed for IP: <HOST>
```

### Detect Port Scanning

```ini
[Definition]
failregex = ^.*portscan.*from <HOST>
            ^.*connect.*attempt to closed port.*from <HOST>
```

## Common Regex Patterns

### Match IP Address

```regex
<HOST>  # Matches both IPv4 and IPv6
```

### Match Username

```regex
["\']?\w+["\']?  # With optional quotes
\S+              # Any non-whitespace
```

### Match HTTP Status Codes

```regex
(401|403|404|500)  # Specific codes
[45]\d{2}          # All 4xx and 5xx
```

### Match HTTP Methods

```regex
(GET|POST|PUT|DELETE|HEAD|OPTIONS)
```

### Match Timestamps

```regex
\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}  # YYYY-MM-DD HH:MM:SS
\d{2}/[A-Za-z]{3}/\d{4}:\d{2}:\d{2}:\d{2}  # DD/Mon/YYYY:HH:MM:SS
```

## Filter Performance Tips

1. **Be specific** - Narrow regex patterns run faster
2. **Anchor regex** - Use `^` and `$` where appropriate
3. **Avoid greedy quantifiers** - Use `.*?` instead of `.*` when possible
4. **Test thoroughly** - Use fail2ban-regex before deployment
5. **Use common.conf** - Leverage pre-defined patterns
6. **Group alternatives** - Use `(pattern1|pattern2)` efficiently

## Debugging Filters

### Enable Debug Mode

```bash
# Start fail2ban in debug mode
sudo fail2ban-client set loglevel DEBUG

# View debug output
sudo tail -f /var/log/fail2ban.log
```

### Test Individual Regex

```bash
# Test regex directly
echo "Failed login from 203.0.113.100" | grep -P "Failed login from (?P<host>\S+)"
```

### Check Filter Syntax

```bash
# Test configuration
sudo fail2ban-client -t

# Test specific filter
fail2ban-regex /dev/null /etc/fail2ban/filter.d/myapp.conf
```

## Filter Maintenance

### Update Filters

```bash
# After modifying filter
sudo fail2ban-client reload myapp

# Reload all filters
sudo systemctl reload fail2ban
```

### List Available Filters

```bash
ls /etc/fail2ban/filter.d/
```

### View Filter Content

```bash
cat /etc/fail2ban/filter.d/sshd.conf
```

## References

- [Fail2ban Filter Documentation](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8#Filters)
- [Regular Expression Testing](https://regex101.com/)
- [Fail2ban Filters Database](https://github.com/fail2ban/fail2ban/tree/master/config/filter.d)
