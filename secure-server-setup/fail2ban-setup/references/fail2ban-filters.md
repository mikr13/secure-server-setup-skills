# Fail2ban log sources, filters and enforcement

## Prefer installed filters

Inspect the target's `/etc/fail2ban/filter.d/` and packaged configuration. Use installed filter names and supported options instead of replacing upstream regex catalogs with copied expressions. Separate a custom filter's file from its jail and test it before activation.

For SSH, upstream supports filter parameters, subject to the installed version:

```ini
[sshd]
enabled = true
filter = sshd[mode=aggressive]
```

Aggressive mode is an explicit local choice; `sshd-aggressive` is not a guaranteed shipped filter. Normal mode is the helper's default. Confirm acceptable false-positive behavior before using stricter modes or thresholds.

## File logs versus journald

For file-based SSH logs, select an existing log and a file backend:

```ini
[sshd]
enabled = true
filter = sshd
backend = polling
logpath = /var/log/auth.log
```

For journal-only SSH, install the appropriate Python systemd support and use the packaged filter's `journalmatch`:

```ini
[sshd]
enabled = true
filter = sshd
backend = systemd
```

Do not set a file `logpath` for the journal backend. Inspect the actual unit/daemon fields (`ssh`, `sshd`, `sshd-session`, depending on release) and ensure the installed filter recognizes them. If inherited configuration contains a log path, the systemd backend uses its journal match rather than watching that file; verify the generated configuration and live events.

The helper detects existing auth/secure files, otherwise selects journald. A file existing does not prove that SSH events are still written to it: check real event freshness and choose a manual journal override when the file is stale.

## Preserve overrides and allowlists

Use a narrowly scoped file in `jail.d/` and avoid replacing `jail.local`. Later `.local` files can override helper values; inspect effective configuration after all files are loaded. Preserve other jails and `ignoreip` values. If changing the management allowlist, add the exact approved addresses to the existing list; do not automatically trust whole private networks.

Recidive needs real Fail2ban log events and an appropriate backend/log target. Do not enable it merely because the SSH jail exists. Preserve any intentionally configured ban action, notification setup, and log retention policy.

## Meaningful filter tests

```bash
sudo fail2ban-client -t
sudo fail2ban-client -d
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
fail2ban-regex systemd-journal /etc/fail2ban/filter.d/sshd.conf
```

For a custom filter, test an actual fixture/log file containing both known failures and legitimate events. Include supported IPv4/IPv6 formats, proxy/client attribution and adversarial user-controlled fields. Broad `.*` around `<HOST>` can misattribute injected data; take the client from a trusted log field and anchor to the expected format.

A WordPress login POST or `/xmlrpc.php` request alone is not proof of failed authentication. Generic access-path or HTTP-status expressions can ban ordinary users. Use application-generated authentication failure events and verify client attribution instead of presenting broad request patterns as proven security filters.

## Actual enforcement

Check the jail, its log source, and ban action, then test from a disposable secondary client:

```bash
sudo fail2ban-client status sshd
sudo fail2ban-client get sshd ignoreip
sudo fail2ban-client set sshd unbanip 203.0.113.100
```

Substitute the test client's actual address. Prove that a ban blocks the intended service/network path and that unbanning restores it. Do not ban the sole administrator connection. A regex match or an "active" service alone is not enforcement evidence.

## Sources

- [Upstream jail settings/backends](https://github.com/fail2ban/fail2ban/blob/master/config/jail.conf)
- [Upstream SSH filter/modes](https://github.com/fail2ban/fail2ban/blob/master/config/filter.d/sshd.conf)
- [Upstream configuration filters](https://github.com/fail2ban/fail2ban/tree/master/config/filter.d)
