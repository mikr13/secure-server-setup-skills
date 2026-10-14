# Secure Server Setup Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Five [Agent Skills](https://agentskills.io/) for configuring Linux VPS security: automatic updates, SSH access, firewall rules, Fail2ban, and backups. Each skill combines instructions, shell helpers, and supporting references so an AI assistant or administrator can inspect and adapt the work to a specific server.

The setup helpers target Ubuntu and Debian systems using APT and systemd. Backup helpers require Linux with GNU utilities. Each skill declares its concrete requirements in `compatibility`; other distributions and custom service layouts need a separately reviewed procedure.

## Available skills

| Skill | Purpose |
| --- | --- |
| [auto-updates](secure-server-setup/auto-updates/SKILL.md) | Configure unattended upgrades and review update and reboot settings. |
| [ssh-hardening](secure-server-setup/ssh-hardening/SKILL.md) | Set up administrative access with SSH keys and restrict authentication. |
| [firewall-configuration](secure-server-setup/firewall-configuration/SKILL.md) | Configure UFW policies and rules for required services. |
| [fail2ban-setup](secure-server-setup/fail2ban-setup/SKILL.md) | Configure log monitoring and temporary IP bans for repeated authentication failures. |
| [backup-strategy](secure-server-setup/backup-strategy/SKILL.md) | Plan file and database backups, remote storage, retention, and restoration. |

## Install

Use the [Skills CLI](https://github.com/vercel-labs/skills) to discover the available skills before choosing what to install:

```bash
npx skills add mikr13/secure-server-setup-skills --list
```

Install the collection interactively:

```bash
npx skills add mikr13/secure-server-setup-skills
```

Or select individual skills:

```bash
npx skills add mikr13/secure-server-setup-skills \
  --skill ssh-hardening \
  --skill firewall-configuration
```

Select the intended agent and installation scope when prompted. Installing skills makes their instructions available to the assistant; server configuration happens separately when you request and authorize it.

For local review and development:

```bash
git clone https://github.com/mikr13/secure-server-setup-skills.git
cd secure-server-setup-skills
```

The repository also includes a [Claude plugin marketplace](.claude-plugin/marketplace.json). Its [plugin manifest](.claude-plugin/plugin.json) declares the bundle version and the same five skill paths.

On Claude Code 2.1.275 or later, install the plugin directly:

```text
/plugin install secure-server-skills --marketplace mikr13/secure-server-setup-skills
```

## Versions and releases

The working tree declares **2.0.0**. See the [changelog](CHANGELOG.md) for release status and the [v1-to-v2 migration guide](MIGRATING.md) before updating existing automation. Install commands above follow the repository's default branch; they do not select a version from skill metadata.

All five skills ship together under one semantic version:

- **Major** (`2.0.0`): incompatible helper interfaces, requirements, or operational behavior.
- **Minor** (`2.1.0`): additions that preserve existing supported usage.
- **Patch** (`2.0.1`): compatible fixes and documentation corrections.

The plugin manifest is the authoritative bundle version. Each skill's `metadata.version` and the marketplace catalog version follow that release number. Skill names and directories stay stable across releases. Metadata labels the files; it does not pin an installation or define an upgrade policy.

Published Git tags identify release snapshots. The retrospective `v1.0.0` tag preserves the original baseline; it does not imply those helpers meet the v2 safety guarantees. To inspect that baseline separately:

```bash
git clone --branch v1.0.0 --depth 1 \
  https://github.com/mikr13/secure-server-setup-skills.git \
  secure-server-setup-skills-v1
```

This checks out the tagged files in a separate directory. For reproducible use, record the tag's commit SHA and install or copy skills from that checkout. Host-specific update behavior still applies to the resulting installation.

For a release, align the manifest, skill metadata and catalog versions, finalize the changelog date and migration notes, validate skill discovery and packaging, and merge the reviewed changes. Then create an annotated `vMAJOR.MINOR.PATCH` tag at the intended release commit and push that exact tag. Keep unreleased work in branches; create `v2.0.0` only when v2 is ready to publish.

## Use with an assistant

Start with a request that names the target, scope, and constraints:

```text
Audit my Ubuntu VPS before making changes. Inspect SSH access, listening ports,
firewall rules, update configuration, and backup coverage. Show the proposed
changes, verification steps, and rollback plan for approval.
```

For a focused task:

```text
Use ssh-hardening to review this server. Preserve the current SSH port and
existing administrative users. Verify key login and sudo access in a separate
session before proposing authentication changes.
```

```text
Use backup-strategy to design daily file and MySQL backups to an existing S3
bucket. Define recovery objectives, credential handling, retention, encryption,
and a restore test before configuring jobs or deleting backups.
```

These prompts make the requested boundaries explicit. Review the selected skill and its helper scripts before execution.

## Before changing a server

1. Identify the operating system, active SSH port, administrative users, running services, and existing security configuration.
2. Confirm provider console or another recovery path, and take an appropriate snapshot or backup.
3. Establish and test SSH key login and sudo access in a separate session. Keep the original connection open while changing SSH or firewall settings.
4. Review the exact configuration changes, required ports, maintenance window, and rollback procedure. Preserve existing rules, jails, and operational requirements unless their removal is intentional.
5. Apply one area at a time, then verify its effective configuration and behavior. Test access again after the change is loaded.
6. Record the outcome and any checks that could not be performed. Schedule updates, monitoring, and restore exercises appropriate to the service.

On an existing server, changing default policies or replacing configuration files can affect workloads immediately. Inspect the current state before using a setup helper.

## Script helpers

The helpers accept explicit command-line arguments, expose `--help`, and preview by default. Configuration or artifact creation requires `--apply`; activation, remote transfer, and backup pruning are explicit choices. Inspect the plan before authorizing its application. Server setup packages must already be installed; the helpers do not run package installation or a broad system upgrade.

| Script | Role |
| --- | --- |
| [setup-auto-updates.sh](secure-server-setup/auto-updates/scripts/setup-auto-updates.sh) | Preview/configure periodic upgrades while preserving origins, cleanup and reboot policy. |
| [generate-ssh-keys.sh](secure-server-setup/ssh-hardening/scripts/generate-ssh-keys.sh) | Preview/generate a local key pair without overwriting either key path. |
| [setup-ssh-hardening.sh](secure-server-setup/ssh-hardening/scripts/setup-ssh-hardening.sh) | Stage/validate an SSH policy and optionally reload the active service, with exact drop-in rollback. |
| [setup-firewall.sh](secure-server-setup/firewall-configuration/scripts/setup-firewall.sh) | Validate management listeners and selected rules; preserve active policies and optionally enable UFW. |
| [setup-fail2ban.sh](secure-server-setup/fail2ban-setup/scripts/setup-fail2ban.sh) | Validate an SSH-only jail override and optionally activate it, preserving other jails. |
| [backup-full.sh](secure-server-setup/backup-strategy/scripts/backup-full.sh) | Archive explicit directories privately, verify contents, and optionally encrypt/prune. |
| [backup-mysql.sh](secure-server-setup/backup-strategy/scripts/backup-mysql.sh) | Dump selected InnoDB databases using protected credentials; verify and optionally encrypt/prune. |
| [backup-to-s3.sh](secure-server-setup/backup-strategy/scripts/backup-to-s3.sh) | Upload explicit file/database artifacts and verify downloaded bytes while retaining local copies. |

### Updating existing jobs

Version 2 replaces the former interactive or no-argument runs. Update existing automation to supply the required inputs and `--apply`; otherwise a command either previews or rejects missing inputs. Follow the [migration guide](MIGRATING.md) for each helper, activation choices, backup dependencies, and rollout verification.

### Current limitations

Setup helpers preserve their own previous managed configuration and restore it on validation/activation failure. SSH effective-policy checks cover the supplied users and client context; inspect other `Match` conditions as well. Existing active UFW rules/defaults and unrelated Fail2ban jails remain in place, so review them separately. Package upgrades and already-uploaded remote objects are not undone by configuration rollback.

The file archive covers selected directories; despite the `backup-full.sh` name, it is not a complete machine image. Database consistency, off-server transfer, encryption key recovery, scheduling, and restoration need explicit configuration and verification. MySQL helpers accept selected InnoDB application databases during a schema-stable window. Other engines/system databases need a reviewed backup method. Local pruning is opt-in and happens only after successful artifact creation; it does not establish that remote recovery objectives are met.

UFW status alone does not prove network isolation. Provider firewalls, IPv6, forwarding, and container networking also affect reachability. [Docker documents how published container ports can bypass UFW filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/).

## Verify the outcome

| Area | Evidence to collect |
| --- | --- |
| Updates | Effective APT settings and allowed origins, active scheduling, a successful unattended-upgrade dry run, and recent update logs. |
| SSH | Valid configuration, effective settings for relevant users and connection conditions, successful key login and sudo access after activation, and denied authentication methods where configured. |
| Firewall | Active listeners and host/provider rules, successful access to required services, and denied access to restricted services from relevant IPv4 and IPv6 networks. |
| Fail2ban | Valid configuration, active jails, the correct log or journal source, and a controlled ban/unban test that preserves administrator access. |
| Backups | Successful job results, archive contents, protected storage permissions, a confirmed remote copy, and restoration in an isolated environment. |

Shell syntax checks and a running service are useful checks, but neither establishes that the desired security behavior is active. A valid archive also needs a restore test to demonstrate recovery.

## Repository layout

```text
.claude-plugin/
├── marketplace.json
└── plugin.json
CHANGELOG.md
MIGRATING.md
secure-server-setup/
├── auto-updates/
├── ssh-hardening/
├── firewall-configuration/
├── fail2ban-setup/
└── backup-strategy/
```

Each skill directory contains `SKILL.md`, `scripts/`, and `references/`. Read the entrypoint first, then follow its links to the relevant helpers and reference material. Copy `backup-common.sh` together with the backup helpers. Repository regression tests live in `tests/` and are not part of skill discovery.

## Validation

The regression suite exercises Ubuntu 24.04 and Debian 12 containers. It covers real SSH key login after policy activation, MariaDB dump/restore, GPG encrypt/decrypt/restore, failure preservation, configuration rollback, port discovery, and opt-in retention. AWS calls, firewall state changes and systemd control are simulated; UFW rule syntax and Fail2ban's merged configuration use the installed tools. It does not prove live provider networking, systemd activation, ban enforcement or AWS permissions.

Run only in a disposable container with the repository mounted read-only. The suite refuses a normal host invocation because its fixtures modify container `/etc`:

```bash
docker build -f tests/Dockerfile -t secure-skills-test:ubuntu24 tests
docker run --rm --network none \
  --mount "type=bind,src=$(pwd),dst=/repo,readonly" \
  --env SECURE_SKILLS_DISPOSABLE=1 \
  secure-skills-test:ubuntu24 python3 /repo/tests/test_helpers.py
```

For Debian, build the same Dockerfile with `--build-arg BASE=debian:12` and a separate tag. These images require a Docker runtime; package installation occurs only inside the test images.

## Authoring approach

Keep descriptions short and scoped to the actual task. Entry points hold the decision criteria and operational safeguards; detailed procedures live in existing references. Scripts provide deterministic handling where failure can lose access or data. Metadata does not pre-approve server mutations.

This follows current [Agent Skills authoring guidance](https://agentskills.io/skill-creation/best-practices), [script interface guidance](https://agentskills.io/skill-creation/using-scripts), and OpenAI's [September 2026 guidance on skill descriptions and progressive disclosure](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra). `agents/openai.yaml` is an optional host-specific UI extension; the shared skills do not require it.

## Contributing

Keep changes focused on a concrete operational problem. Include the affected distributions and versions, existing configuration assumptions, verification evidence, and recovery behavior. For scripts, cover failed commands, repeated execution, and preservation of existing configuration where applicable.

Use the [Agent Skills specification](https://agentskills.io/specification) for metadata and packaging. Validate shell syntax and lint changed scripts, then test consequential behavior in a disposable Linux environment before describing it as verified.

## References

- [Ubuntu OpenSSH server documentation](https://ubuntu.com/server/docs/how-to/security/openssh-server/)
- [Ubuntu automatic updates documentation](https://ubuntu.com/server/docs/how-to/software/automatic-updates/)
- [OpenSSH configuration manual](https://man.openbsd.org/sshd_config)
- [Fail2ban upstream configuration](https://github.com/fail2ban/fail2ban/tree/master/config)
- [MySQL backup documentation](https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html)

The original collection was inspired by [Branko Petrić's VPS security thread](https://x.com/brankopetric00/status/2017283246254436501). This repository does not claim CIS certification or a complete compliance assessment.

## License

[MIT](LICENSE).
