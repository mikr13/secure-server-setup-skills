---
name: ssh-hardening
description: Audit or harden OpenSSH on Ubuntu/Debian with verified key access. Use when changing authentication or administrative SSH access.
license: MIT
compatibility: Ubuntu/Debian Linux with OpenSSH, Python 3, Bash, coreutils, and systemd for activation; local SSH client for access tests.
metadata:
  author: secure-server-skill
  version: "1.0"
  category: security
---

# SSH hardening

Establish working administrative access before restricting authentication. Keep the current session and provider console available until a fresh post-change login succeeds.

## Inspect and establish access

1. Identify the active daemon/service/socket, actual listener ports, administrative and automation identities, `Include` order, and relevant `Match` rules. Record `sshd -T -C` results for the actual users, client addresses, and hostnames.
2. Use an existing non-root administrator. If account creation is needed, create it separately with the distribution's user/group conventions, install its public key, then prove key login and sudo in a separate session before any lockdown.
3. Generate personal keys on the local client with a passphrase or hardware-backed key. [scripts/generate-ssh-keys.sh](scripts/generate-ssh-keys.sh) provides preview/no-overwrite behavior; its `--interactive` mode is for a human terminal and `--no-passphrase` is an explicit service-key choice.
4. Test the specific key without password fallback:

   ```bash
   ssh -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -i ~/.ssh/server_admin administrator@server.example.com
   ```

   In that new session, verify the required sudo operation. Password fallback or an already-open session is not proof of usable key access.

## Configure the authorized policy

Read [references/sshd-config.md](references/sshd-config.md) before editing includes, conditional access or activation.

The [setup helper](scripts/setup-ssh-hardening.sh) supports a conventional key-only policy. It requires an existing non-root administrator; it does not create accounts, replace `AllowUsers`/`AllowGroups`, change ports, or remove forwarding functionality. Existing multiple-factor authentication requires a reviewed manual policy instead of this helper.

```bash
sudo bash scripts/setup-ssh-hardening.sh --user administrator --client-address 203.0.113.10 --dry-run
```

After proven key/sudo access and authorization to configure/activate:

```bash
sudo bash scripts/setup-ssh-hardening.sh --user administrator --client-address 203.0.113.10 --key-access-confirmed --apply --activate
```

Repeat `--user` for administrators that must be verified. Set `--client-host` when hostname-based `Match` rules apply. The helper validates the supplied client context; inspect other relevant networks/hostnames as well. It writes a managed early drop-in and refuses success if earlier values or conditional rules override the requested policy. An early filename alone is not proof of precedence.

## Verify and recover

- Syntax: `sudo sshd -t`. Effective file policy: `sudo sshd -T -C user=administrator,host=client.example.com,addr=203.0.113.10`.
- Verify root, password and keyboard-interactive restrictions for all relevant contexts; ensure required key login and any intended MFA remain possible.
- After activation, establish a fresh login with the specific key and check sudo. Test denied authentication methods from a controlled client. Preserve the original session until these pass.
- If the script fails during validation or activation, it restores the exact previous managed drop-in and attempts to reload the restored policy when needed. For later rollback, use the printed protected backup directory; restore its saved file or remove the new managed file if none existed. Then validate and reload the actual service from the preserved session/console.

Report file validation separately from activation and live access tests. Do not describe `ClientAliveInterval` as a user-idle timeout or hard-code obsolete protocol/crypto settings.
