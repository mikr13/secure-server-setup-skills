#!/usr/bin/env python3
"""Destructive fixtures: run ONLY in a disposable Linux container, repository mounted read-only."""
import ast, fcntl, gzip, hashlib, os, pathlib, shutil, signal, subprocess, tempfile, time, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SKILLS = ROOT / 'secure-server-setup'
if os.environ.get('SECURE_SKILLS_DISPOSABLE') != '1' or not pathlib.Path('/.dockerenv').exists() or os.geteuid() != 0:
    raise SystemExit('Run this suite inside the disposable container described in README; it changes container /etc fixtures.')

def run(args, env=None, **kw):
    return subprocess.run([str(a) for a in args], text=True, capture_output=True, env={**os.environ, **(env or {})}, timeout=30, **kw)

def helper(skill, script, *args, env=None):
    return run(['bash', SKILLS/skill/'scripts'/script, *args], env=env)

class Helpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db = None
        pathlib.Path('/run/mysqld').mkdir(exist_ok=True)
        subprocess.run(['chown','mysql:mysql','/run/mysqld'],check=True)
        cls.db = subprocess.Popen(['mariadbd','--user=mysql','--skip-networking','--socket=/run/mysqld/mysqld.sock','--pid-file=/run/mysqld/test.pid'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            if run(['mysql','--protocol=socket','-uroot','-e','SELECT 1']).returncode == 0: break
            time.sleep(.1)
        else: raise RuntimeError('Disposable MariaDB failed to start')

    @classmethod
    def tearDownClass(cls):
        if cls.db:
            cls.db.terminate()
            cls.db.wait(timeout=15)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='secure-skills-')
        self.base = pathlib.Path(self.tmp.name)
        self.bin = self.base/'bin'; self.bin.mkdir()
        self.env = {'PATH':str(self.bin)+':'+os.environ['PATH']}
        self.sources = self.base/'source with spaces'; self.sources.mkdir()
        (self.sources/'important.txt').write_text('recoverable data\n')
        self.backups = self.base/'private backups'
        self.saved = {}
        for path in ['/etc/ssh/sshd_config','/etc/ssh/sshd_config.d','/etc/fail2ban/jail.local','/etc/fail2ban/jail.d','/etc/apt/apt.conf.d','/etc/default/ufw','/etc/ufw','/var/log/auth.log','/var/log/secure']:
            p=pathlib.Path(path)
            if p.exists():
                dest=self.base/('saved-'+str(len(self.saved)))
                if p.is_dir(): shutil.copytree(p,dest)
                else: shutil.copy2(p,dest)
                self.saved[path]=dest
            else: self.saved[path]=None
        # Deterministic systemctl fixture: no container init; real daemons tested separately.
        self.mock('systemctl', '''#!/bin/bash
case "$1" in
  is-active) exit 3 ;;
  is-enabled) echo disabled; exit 1 ;;
  *) exit 0 ;;
esac
''')
        self.credentials=self.base/'mysql.cnf'
        self.credentials.write_text('[client]\nuser=root\nprotocol=socket\nsocket=/run/mysqld/mysqld.sock\n')
        self.credentials.chmod(0o600)
        self.daemon=None

    def tearDown(self):
        if self.daemon:
            self.daemon.terminate()
            self.daemon.wait(timeout=10)
        for path,dest in self.saved.items():
            p=pathlib.Path(path)
            if p.exists() or p.is_symlink():
                if p.is_dir() and not p.is_symlink(): shutil.rmtree(p)
                else: p.unlink()
            if dest:
                if dest.is_dir(): shutil.copytree(dest,p)
                else: shutil.copy2(dest,p)
        self.tmp.cleanup()

    def mock(self,name,body):
        p=self.bin/name; p.write_text(body); p.chmod(0o755); return p

    def file_args(self,*extra):
        return ['--path',self.sources,'--backup-dir',self.backups,*extra]

    def seed(self,kind='backup',name='old success',verified=True,nested=False):
        directory=self.backups/'nested' if nested else self.backups
        directory.mkdir(parents=True,exist_ok=True,mode=0o700)
        suffix='sql.gz' if kind=='mysql' else 'tar.gz'
        hostname=subprocess.check_output(['hostname','-s'],text=True).strip()
        p=directory/f'{hostname}-{kind}-{name}.{suffix}'
        with gzip.open(p,'wb') as f:f.write(b'old verified content')
        p.chmod(0o600)
        if verified:
            pathlib.Path(str(p)+'.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n')
        ago=time.time()-40*86400; os.utime(p,(ago,ago)); return p

    def conventional_ssh(self,extra=''):
        pathlib.Path('/etc/ssh/sshd_config.d').mkdir(exist_ok=True)
        pathlib.Path('/etc/ssh/sshd_config').write_text('Include /etc/ssh/sshd_config.d/*.conf\nUsePAM yes\n'+extra)

    def ssh_args(self,*extra):
        return ['--user','auditor','--client-address','127.0.0.1','--key-access-confirmed',*extra]

    def test_help_and_conflicting_modes(self):
        for p in SKILLS.glob('*/scripts/*.sh'):
            if p.name=='backup-common.sh':continue
            r=run(['bash',p,'--help']); self.assertEqual(r.returncode,0,r.stderr)
            r=run(['bash',p,'--apply','--dry-run']); self.assertNotEqual(r.returncode,0,p)

    def test_file_restore_private_permissions_and_default_no_prune(self):
        old=self.seed()
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        current=[p for p in self.backups.glob('*.tar.gz') if p!=old][0]
        self.assertTrue(old.exists())
        self.assertEqual(current.stat().st_mode & 0o777,0o600)
        self.assertEqual(self.backups.stat().st_mode & 0o777,0o700)
        restored=self.base/'restore';restored.mkdir()
        r=run(['tar','-xzf',current,'-C',restored]);self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual((restored/str(self.sources).lstrip('/')/'important.txt').read_text(),'recoverable data\n')

    def test_missing_input_and_shared_directory_fail_without_mutation(self):
        r=helper('backup-strategy','backup-full.sh','--path','/missing-required-input','--backup-dir',self.backups,'--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertFalse(self.backups.exists())
        self.backups.mkdir(mode=0o755)
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(self.backups.stat().st_mode & 0o777,0o755)

    def test_failed_tar_preserves_old_and_skips_retention(self):
        old=self.seed();self.mock('tar','#!/bin/bash\nexit 42\n')
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply','--prune'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue(old.exists())

    def test_failed_gpg_retains_verified_source_and_prior_generation(self):
        old=self.seed();self.mock('gpg','#!/bin/bash\nexit 42\n')
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--gpg-recipient','test','--apply','--prune'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue(old.exists())
        pending=list(self.backups.glob('.files.pending.*'));self.assertEqual(len(pending),1)
        self.assertEqual(run(['gzip','-t',pending[0]]).returncode,0)
        self.assertFalse(list(self.backups.glob('*.gpg')))

    def test_retention_stays_within_root_and_preserves_unverified(self):
        old=self.seed();legacy=self.seed(name='legacy',verified=False);nested=self.seed(name='nested',nested=True)
        outside=self.base/'outside.tar.gz';outside.write_text('must survive')
        link=self.backups/(old.name.replace('old success','symlink'));link.symlink_to(outside)
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply','--prune','--retention-days','7'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr);self.assertFalse(old.exists())
        self.assertTrue(legacy.exists());self.assertTrue(nested.exists());self.assertTrue(outside.exists())

    def test_overlapping_backup_is_refused(self):
        self.backups.mkdir(mode=0o700)
        with (self.backups/'.backup.lock').open('w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertFalse(list(self.backups.glob('*.tar.gz')))

    def db_setup(self,engine='InnoDB'):
        r=run(['mysql','--defaults-file='+str(self.credentials),'-e',f'DROP DATABASE IF EXISTS fixture; CREATE DATABASE fixture; CREATE TABLE fixture.items (id INT PRIMARY KEY, value VARCHAR(50)) ENGINE={engine}; INSERT INTO fixture.items VALUES (1,"restored value");'])
        self.assertEqual(r.returncode,0,r.stderr)

    def db_args(self,*extra):
        return ['--defaults-file',self.credentials,'--database','fixture','--backup-dir',self.backups,'--maintenance-confirmed',*extra]

    def test_real_database_dump_and_restore(self):
        self.db_setup()
        r=helper('backup-strategy','backup-mysql.sh',*self.db_args('--apply'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        artifact=list(self.backups.glob('*.sql.gz'))[0]
        sql=gzip.decompress(artifact.read_bytes()).decode()
        run(['mysql','--defaults-file='+str(self.credentials),'-e','DROP DATABASE fixture'])
        r=run(['mysql','--defaults-file='+str(self.credentials)],input=sql);self.assertEqual(r.returncode,0,r.stderr)
        r=run(['mysql','--defaults-file='+str(self.credentials),'-N','-e','SELECT value FROM fixture.items'])
        self.assertEqual(r.stdout.strip(),'restored value')

    def test_nontransactional_database_refused(self):
        self.db_setup('MyISAM')
        r=helper('backup-strategy','backup-mysql.sh',*self.db_args('--apply'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertFalse(self.backups.exists())

    def test_failed_dump_and_compression_preserve_success(self):
        self.db_setup();old=self.seed(kind='mysql')
        self.mock('mysqldump','#!/bin/bash\nprintf partial\nexit 42\n')
        r=helper('backup-strategy','backup-mysql.sh',*self.db_args('--apply','--prune'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue(old.exists())
        (self.bin/'mysqldump').unlink();self.mock('gzip','#!/bin/bash\nexit 42\n')
        r=helper('backup-strategy','backup-mysql.sh',*self.db_args('--apply','--prune'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue(old.exists())

    def s3_mock(self):
        self.mock('aws', '''#!/usr/bin/env python3
import os,sys,pathlib,shutil
src,dst=sys.argv[3:5]
base=pathlib.Path(os.environ['S3_TEST_ROOT'])
def path(p):return base/p[5:] if p.startswith('s3://') else pathlib.Path(p)
target=path(dst);target.parent.mkdir(parents=True,exist_ok=True)
if src.startswith('s3://') and os.environ.get('CORRUPT_READBACK'):target.write_text('corrupt')
else:shutil.copyfile(path(src),target)
''')
        self.env['S3_TEST_ROOT']=str(self.base/'remote')

    def test_s3_file_and_database_readback_and_source_preservation(self):
        file=self.seed();database=self.seed(kind='mysql');self.s3_mock()
        r=helper('backup-strategy','backup-to-s3.sh','--file',file,'--file',database,'--s3-uri','s3://approved-backups/server-a','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertTrue(file.exists());self.assertTrue(database.exists())
        for p in [file,database]:self.assertEqual((self.base/'remote/approved-backups/server-a'/p.name).read_bytes(),p.read_bytes())
        self.env['CORRUPT_READBACK']='1'
        r=helper('backup-strategy','backup-to-s3.sh','--file',file,'--s3-uri','s3://approved-backups/server-b','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertTrue(file.exists())
        self.assertFalse((self.base/'remote/approved-backups/server-b'/(file.name+'.sha256')).exists())

    def test_s3_preview_has_no_remote_requests(self):
        file=self.seed();self.mock('aws','#!/bin/bash\nexit 99\n')
        r=helper('backup-strategy','backup-to-s3.sh','--file',file,'--s3-uri','s3://approved-backups/server-a','--dry-run',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)

    def test_key_generation_never_overwrites_either_key_path(self):
        parent=self.base/'keys';parent.mkdir(mode=0o700);key=parent/'admin'
        r=helper('ssh-hardening','generate-ssh-keys.sh','--key-file',key,'--comment','test-service','--apply','--no-passphrase',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr);before=key.read_bytes()
        r=helper('ssh-hardening','generate-ssh-keys.sh','--key-file',key,'--comment','test-service','--apply','--no-passphrase',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(key.read_bytes(),before)
        self.assertEqual(key.stat().st_mode&0o777,0o600)

    def test_ssh_include_precedence_and_root_rejection(self):
        self.conventional_ssh()
        cloud=pathlib.Path('/etc/ssh/sshd_config.d/50-cloud-init.conf');cloud.write_text('PasswordAuthentication yes\n')
        r=helper('ssh-hardening','setup-ssh-hardening.sh',*self.ssh_args('--apply'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        r=run(['/usr/sbin/sshd','-T','-C','user=auditor,host=127.0.0.1,addr=127.0.0.1'])
        self.assertIn('passwordauthentication no',r.stdout);self.assertEqual(cloud.read_text(),'PasswordAuthentication yes\n')
        managed=pathlib.Path('/etc/ssh/sshd_config.d/00-secure-server-hardening.conf');before=managed.read_bytes()
        r=helper('ssh-hardening','setup-ssh-hardening.sh','--user','root','--client-address','127.0.0.1','--apply','--key-access-confirmed',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_bytes(),before)

    def test_ssh_conditional_failure_restores_exact_previous_dropin(self):
        self.conventional_ssh('Match Address 127.0.0.1\n    PasswordAuthentication yes\n')
        managed=pathlib.Path('/etc/ssh/sshd_config.d/00-secure-server-hardening.conf');managed.write_text('# existing managed settings\nPermitRootLogin no\n');managed.chmod(0o640);before=managed.read_bytes()
        r=helper('ssh-hardening','setup-ssh-hardening.sh',*self.ssh_args('--apply'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_bytes(),before);self.assertEqual(managed.stat().st_mode&0o777,0o640)

    def test_ssh_live_login_after_activation(self):
        self.conventional_ssh('Port 2222\nListenAddress 127.0.0.1\n')
        run(['passwd','-d','auditor'])
        keys=pathlib.Path('/home/auditor/.ssh');keys.mkdir(exist_ok=True,mode=0o700)
        key=self.base/'clientkey';self.assertEqual(run(['ssh-keygen','-q','-t','ed25519','-N','','-f',key]).returncode,0)
        shutil.copy2(str(key)+'.pub',keys/'authorized_keys');(keys/'authorized_keys').chmod(0o600)
        run(['chown','-R','auditor:auditor',keys])
        self.daemon=subprocess.Popen(['/usr/sbin/sshd','-D','-f','/etc/ssh/sshd_config'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        ssh=['ssh','-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=/dev/null','-o','IdentitiesOnly=yes','-o','BatchMode=yes','-i',key,'-p','2222','auditor@127.0.0.1','id -un']
        for _ in range(30):
            r=run(ssh)
            if r.returncode==0:break
            time.sleep(.1)
        self.assertEqual(r.returncode,0,r.stderr)
        self.env['SSH_TEST_PID']=str(self.daemon.pid)
        self.mock('systemctl','''#!/bin/bash
case "$1" in
is-active) [[ ${*: -1} == ssh.service ]] ;;
reload) kill -HUP "$SSH_TEST_PID" ;;
*) exit 1 ;;
esac
''')
        r=helper('ssh-hardening','setup-ssh-hardening.sh',*self.ssh_args('--apply','--activate'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        for _ in range(30):
            r=run(ssh)
            if r.returncode==0:break
            time.sleep(.1)
        self.assertEqual(r.stdout.strip(),'auditor',r.stderr)
        denied=ssh.copy();denied[1:1]=['-o','PreferredAuthentications=password']
        self.assertNotEqual(run(denied).returncode,0)

    def listener_mock(self,port='2222'):
        self.mock('ss',f'#!/bin/bash\nprintf "LISTEN 0 128 127.0.0.1:{port} 0.0.0.0:*\\n"\n')

    def test_fail2ban_journal_configuration_preserves_other_jails(self):
        self.conventional_ssh();self.listener_mock()
        for name in ['/var/log/auth.log','/var/log/secure']:
            pathlib.Path(name).unlink(missing_ok=True)
        original='[DEFAULT]\nignoreip = 127.0.0.1/8 ::1 203.0.113.10\n[custom-disabled]\nenabled = false\n'
        pathlib.Path('/etc/fail2ban/jail.local').write_text(original)
        r=helper('fail2ban-setup','setup-fail2ban.sh','--ssh-port','2222','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(pathlib.Path('/etc/fail2ban/jail.local').read_text(),original)
        dump=run(['fail2ban-client','-d'])
        commands=[ast.literal_eval(line) for line in dump.stdout.splitlines() if line.startswith('[')]
        self.assertIn(['add','sshd','systemd'],commands)
        self.assertTrue(any(c[:3]==['set','sshd','addignoreip'] and '203.0.113.10' in c for c in commands))

    def test_fail2ban_invalid_candidate_restores_existing_override(self):
        self.conventional_ssh();self.listener_mock()
        managed=pathlib.Path('/etc/fail2ban/jail.d/99-secure-server-sshd.local');managed.write_text('# previous managed file\n')
        self.mock('fail2ban-client','#!/bin/bash\nexit 42\n')
        r=helper('fail2ban-setup','setup-fail2ban.sh','--ssh-port','2222','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'# previous managed file\n')

    def test_apt_preserves_origins_reboots_and_no_broad_upgrade(self):
        managed=pathlib.Path('/etc/apt/apt.conf.d/98-fixture');managed.write_text('Unattended-Upgrade::Automatic-Reboot "false";\nUnattended-Upgrade::Remove-Unused-Dependencies "false";\n')
        before=run(['apt-config','dump']).stdout
        self.mock('unattended-upgrade','#!/bin/bash\n[[ $* == "--dry-run --debug" ]]\n')
        self.mock('apt','#!/bin/bash\nexit 99\n')
        r=helper('auto-updates','setup-auto-updates.sh','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        after=run(['apt-config','dump']).stdout
        origin=lambda s:[line for line in s.splitlines() if line.startswith(('Unattended-Upgrade::Allowed-Origins','Unattended-Upgrade::Origins-Pattern'))]
        self.assertEqual(origin(before),origin(after));self.assertIn('Unattended-Upgrade::Automatic-Reboot "false";',after)
        self.assertEqual(managed.read_text(),'Unattended-Upgrade::Automatic-Reboot "false";\nUnattended-Upgrade::Remove-Unused-Dependencies "false";\n')

    def test_apt_dryrun_failure_restores_previous_managed_file(self):
        managed=pathlib.Path('/etc/apt/apt.conf.d/99-secure-server-auto-upgrades');managed.write_text('// prior custom settings\n')
        self.mock('unattended-upgrade','#!/bin/bash\nexit 42\n')
        r=helper('auto-updates','setup-auto-updates.sh','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'// prior custom settings\n')

    def test_firewall_rejects_wrong_management_port_before_changes(self):
        self.listener_mock();self.env['SSH_CONNECTION']='203.0.113.10 12345 192.0.2.1 2222'
        r=helper('firewall-configuration','setup-firewall.sh','--ssh-port','22','--public-ssh','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertIn('No TCP listener',r.stderr)
        r=helper('firewall-configuration','setup-firewall.sh','--ssh-port','99999','--public-ssh','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0)

    def test_documented_ufw_direction_and_routing_syntax(self):
        for args in [ ['allow','from','203.0.113.20/32','to','any','port','3306','proto','tcp'], ['allow','from','2001:db8:1234::/64','to','any','port','5432','proto','tcp'], ['route','allow','in','on','eth1','out','on','eth0','to','203.0.113.20','port','443','proto','tcp'] ]:
            r=run(['ufw','--dry-run',*args]);self.assertEqual(r.returncode,0,r.stderr)

    def test_actual_gpg_encrypt_decrypt_restore(self):
        keyring=self.base/'keyring';keyring.mkdir(mode=0o700)
        self.env['GNUPGHOME']=str(keyring)
        r=run(['gpg','--batch','--passphrase','','--quick-generate-key','backup-test@example.org','rsa2048','encr','0'],env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        r=helper('backup-strategy','backup-full.sh',*self.file_args('--apply','--gpg-recipient','backup-test@example.org'),env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        encrypted=list(self.backups.glob('*.tar.gz.gpg'))[0]
        decrypted=subprocess.run(['gpg','--batch','--decrypt',str(encrypted)],capture_output=True,env={**os.environ,**self.env})
        self.assertEqual(decrypted.returncode,0,decrypted.stderr)
        archive=self.base/'decrypted.tar.gz';archive.write_bytes(decrypted.stdout)
        restored=self.base/'encrypted-restore';restored.mkdir()
        self.assertEqual(run(['tar','-xzf',archive,'-C',restored]).returncode,0)
        self.assertEqual((restored/str(self.sources).lstrip('/')/'important.txt').read_text(),'recoverable data\n')

    def test_ssh_failed_activation_restores_file(self):
        self.conventional_ssh()
        managed=pathlib.Path('/etc/ssh/sshd_config.d/00-secure-server-hardening.conf');managed.write_text('# prior file\n')
        self.mock('systemctl', '#!/bin/bash\nif [[ $1 == is-active && ${*: -1} == ssh.service ]]; then exit 0; fi\nexit 42\n')
        r=helper('ssh-hardening','setup-ssh-hardening.sh',*self.ssh_args('--apply','--activate'),env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'# prior file\n')

    def test_fail2ban_later_override_is_detected_and_rolled_back(self):
        self.conventional_ssh();self.listener_mock()
        later=pathlib.Path('/etc/fail2ban/jail.d/zz-fixture.local');later.write_text('[sshd]\nmaxretry = 99\n')
        managed=pathlib.Path('/etc/fail2ban/jail.d/99-secure-server-sshd.local');managed.write_text('# previous managed file\n')
        r=helper('fail2ban-setup','setup-fail2ban.sh','--ssh-port','2222','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'# previous managed file\n')
        self.assertEqual(later.read_text(),'[sshd]\nmaxretry = 99\n')

    def test_apt_actual_dry_run(self):
        r=helper('auto-updates','setup-auto-updates.sh','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)

    def test_apt_activation_failure_restores_timer_states(self):
        managed=pathlib.Path('/etc/apt/apt.conf.d/99-secure-server-auto-upgrades');managed.write_text('// previous file\n')
        timer_state=self.base/'timer-states';timer_state.write_text('disabled')
        self.env['TIMER_TEST_STATE']=str(timer_state)
        self.mock('unattended-upgrade','#!/bin/bash\nexit 0\n')
        self.mock('systemctl', '#!/bin/bash\ncase "$1" in\nis-enabled) cat "$TIMER_TEST_STATE"; exit 1 ;;\nis-active) exit 3 ;;\nenable) echo enabled > "$TIMER_TEST_STATE"; exit 42 ;;\ndisable) echo disabled > "$TIMER_TEST_STATE" ;;\nstop) exit 0 ;;\n*) exit 0 ;;\nesac\n')
        r=helper('auto-updates','setup-auto-updates.sh','--apply','--activate',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'// previous file\n');self.assertEqual(timer_state.read_text().strip(),'disabled')

    def ufw_mock(self,active=True):
        pathlib.Path('/etc/ufw/ufw.conf').write_text('ENABLED='+('yes' if active else 'no')+'\n')
        pathlib.Path('/etc/ufw/user.rules').write_text('legacy broad allow\n')
        self.mock('ufw', "#!/usr/bin/env python3\nimport pathlib,sys,os\nargs=sys.argv[1:]; rules=pathlib.Path('/etc/ufw/user.rules');config=pathlib.Path('/etc/ufw/ufw.conf')\nif args[0]=='status': print('Status: '+('active' if 'yes' in config.read_text() else 'inactive'))\nelif args[:2]==['--force','disable']:config.write_text('ENABLED=no\\n')\nelif args[:2]==['--force','enable']:config.write_text('ENABLED=yes\\n')\nelse:\n    with rules.open('a') as f:f.write(' '.join(args)+'\\n')\n    if os.environ.get('FAIL_UFW') and args==['allow','80/tcp']:sys.exit(42)\n")

    def test_firewall_active_defaults_preserved_and_failed_rule_rolls_back(self):
        self.listener_mock();self.ufw_mock()
        before=pathlib.Path('/etc/default/ufw').read_bytes()
        r=helper('firewall-configuration','setup-firewall.sh','--ssh-port','2222','--ssh-source','203.0.113.10/32','--allow-port','443/tcp','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        rules=pathlib.Path('/etc/ufw/user.rules');current=rules.read_bytes()
        self.assertIn(b'legacy broad allow',current);self.assertNotIn(b'default deny',current);self.assertEqual(pathlib.Path('/etc/default/ufw').read_bytes(),before)
        self.env['FAIL_UFW']='1'
        r=helper('firewall-configuration','setup-firewall.sh','--ssh-port','2222','--public-ssh','--allow-port','80/tcp','--apply',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(rules.read_bytes(),current)
        self.assertIn('ENABLED=yes',pathlib.Path('/etc/ufw/ufw.conf').read_text())

    def test_firewall_discovers_multiple_included_ports(self):
        self.conventional_ssh()
        pathlib.Path('/etc/ssh/sshd_config.d/10-port-fixture.conf').write_text('Port 2222\nPort 2200\n')
        self.mock('ss','#!/bin/bash\nprintf "LISTEN 0 128 127.0.0.1:2222 0.0.0.0:*\\nLISTEN 0 128 127.0.0.1:2200 0.0.0.0:*\\n"\n')
        self.ufw_mock(active=False)
        r=helper('firewall-configuration','setup-firewall.sh','--public-ssh','--apply',env=self.env)
        self.assertEqual(r.returncode,0,r.stderr)
        rules=pathlib.Path('/etc/ufw/user.rules').read_text()
        self.assertIn('allow 2222/tcp',rules);self.assertIn('allow 2200/tcp',rules);self.assertIn('default deny incoming',rules)
        self.assertIn('ENABLED=no',pathlib.Path('/etc/ufw/ufw.conf').read_text())

    def test_socket_activation_requires_explicit_ports(self):
        self.conventional_ssh();self.listener_mock()
        self.mock('systemctl','#!/bin/bash\n[[ $1 == is-active && ${*: -1} == ssh.socket ]]\n')
        r=helper('firewall-configuration','setup-firewall.sh','--public-ssh','--dry-run',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertIn('Socket activation',r.stderr)
        r=helper('fail2ban-setup','setup-fail2ban.sh','--dry-run',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertIn('Socket activation',r.stderr)

    def test_fail2ban_failed_activation_restores_file_and_enablement(self):
        self.conventional_ssh();self.listener_mock()
        managed=pathlib.Path('/etc/fail2ban/jail.d/99-secure-server-sshd.local');managed.write_text('# prior override\n')
        state=self.base/'fail2ban-state';state.write_text('disabled')
        self.env['F2B_TEST_STATE']=str(state)
        self.mock('systemctl', '#!/bin/bash\ncase "$1" in\nis-enabled) cat "$F2B_TEST_STATE"; exit 1 ;;\nis-active) exit 3 ;;\nenable) echo enabled > "$F2B_TEST_STATE"; exit 42 ;;\ndisable) echo disabled > "$F2B_TEST_STATE" ;;\nstop) exit 0 ;;\n*) exit 0 ;;\nesac\n')
        r=helper('fail2ban-setup','setup-fail2ban.sh','--ssh-port','2222','--apply','--activate',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertEqual(managed.read_text(),'# prior override\n');self.assertEqual(state.read_text().strip(),'disabled')

    def test_fail2ban_masked_state_refused_before_writing(self):
        self.conventional_ssh();self.listener_mock()
        managed=pathlib.Path('/etc/fail2ban/jail.d/99-secure-server-sshd.local');managed.write_text('# prior override\n')
        self.mock('systemctl','#!/bin/bash\nif [[ $1 == is-enabled ]]; then echo masked; fi\nexit 1\n')
        r=helper('fail2ban-setup','setup-fail2ban.sh','--ssh-port','2222','--apply','--activate',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertIn('unexpected Fail2ban enablement',r.stderr);self.assertEqual(managed.read_text(),'# prior override\n')

    def test_invalid_ssh_client_address_is_refused(self):
        r=helper('ssh-hardening','setup-ssh-hardening.sh','--user','auditor','--client-address','999.999.999.999','--apply','--key-access-confirmed',env=self.env)
        self.assertNotEqual(r.returncode,0);self.assertIn('valid actual client IP',r.stderr)

if __name__=='__main__':unittest.main(verbosity=2)
