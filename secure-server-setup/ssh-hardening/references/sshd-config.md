# OpenSSH policy and activation

## Effective values and conditional rules

OpenSSH generally uses the first obtained value for each option, with documented exceptions for accumulating lists. Includes are processed where they occur. An early managed filename helps only when the main file actually includes it before competing settings. Existing `AllowUsers` and `AllowGroups` can accumulate, so adding a new list is not necessarily a replacement restriction.

```bash
sudo sshd -t
sudo sshd -T -C user=administrator,host=client.example.com,addr=203.0.113.10
sudo ss -ltnp
sudo systemctl status ssh.service sshd.service ssh.socket --no-pager
```

Inspect every relevant user/address/hostname combination affected by `Match`. Test root and required automation accounts as well. `sshd -T` describes the file configuration, not whether the running daemon has loaded it. Socket units or a custom daemon command line may own the actual listener; preserve their configured ports.

## Key-only policy and MFA

The conventional helper policy is:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
PermitEmptyPasswords no
```

Do not apply it over intentional MFA, certificates/SSO or special account requirements without reviewing their authentication flow. `PasswordAuthentication no` alone does not disable a PAM-backed keyboard-interactive password path. Use `KbdInteractiveAuthentication` for current OpenSSH; `ChallengeResponseAuthentication` is an older alias.

Remove obsolete `Protocol 2` settings. Prefer the supported distribution's maintained crypto defaults over copied fixed cipher/KEX lists; make policy-specific overrides only after checking clients, FIPS requirements and the installed OpenSSH version.

Keep existing ports and access/forwarding rules unless the requested scope changes them. `ClientAliveInterval` checks responsiveness; it is not a user-idle timeout. Restrict forwarding only when compatible with required tunnels/deployment workflows.

## Local keys and explicit login tests

Generate personal keys on the local client, not the server:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/server_admin -C server-administration
ssh-copy-id -i ~/.ssh/server_admin.pub administrator@server.example.com
ssh -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -i ~/.ssh/server_admin administrator@server.example.com
```

Use a passphrase or hardware-backed key where supported. Never overwrite an existing key to satisfy a setup recipe. The helper requires an explicit destination and protects both private/public paths; unattended no-passphrase generation is only an explicit service-key choice. Secure the private key and provision only the public key on the server.

Verify `sudo` from that fresh key session before disabling fallback access. Keep a provider console and the old session during the change.

## Validate, activate, reconnect

Validate syntax and effective policy after staging. Find the actual active unit; reload that unit after authorization rather than assuming every distribution uses `sshd.service`. The helper supports active `ssh.service` or `sshd.service`; custom service/socket arrangements require manual inspection.

After reload, open a new connection using the selected key, verify sudo and required automation workflows, and test that disabled authentication methods/root access are rejected. Keep the existing connection until these tests pass. A connection before reload tests the old policy only.

## Exact rollback

The helper saves the precise managed drop-in it overwrites, not just the main `sshd_config`. On validation or activation failure it restores that file or removes the newly created file when none existed, then attempts a recovery reload if activation was attempted. Its printed rollback directory is private.

For a later rollback, restore the saved managed file, or remove only the helper's new managed file, validate syntax and effective policy, then reload the actual unit using the console/preserved session. Do not delete unrelated drop-ins or replace the whole SSH configuration.

## Sources

- [OpenSSH sshd_config manual](https://man.openbsd.org/sshd_config)
- [OpenSSH sshd test modes](https://man.openbsd.org/sshd)
- [Ubuntu OpenSSH server](https://ubuntu.com/server/docs/how-to/security/openssh-server/)
