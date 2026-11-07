//! Complete native recovery controller and roles inside one disposable Linux runtime.
use super::{Commands, package, process::Process, write_private};
use crate::contracts_support::ContractFixture;
use anyhow::{Context, Result, ensure};
use serde_json::{Value, json};
use std::{fs, path::Path, process::Command};
use test_harness::ContractConsensus;

pub struct LinuxRuntime {
    name: String,
}
impl LinuxRuntime {
    pub fn start(f: &ContractFixture, c: &ContractConsensus, commands: &Commands) -> Result<Self> {
        let image = std::env::var("ETNA_RECOVERY_IMAGE")
            .context("tests/entrypoint.sh must build ETNA_RECOVERY_IMAGE")?;
        let name =
            format!("recovery-{}", commands.dir.path().file_name().unwrap().to_string_lossy());
        let this = Self { name };
        let rpc = c.cmt.url().port().context("Comet port")?;
        let label =
            format!("taiko-client-rs.test-run={}", std::env::var("TAIKO_CLIENT_RS_TEST_RUN")?);
        this.docker(&[
            "run",
            "-d",
            "--name",
            &this.name,
            "--label",
            &label,
            "--network",
            f.anvil.docker_network(),
            "-p",
            &format!("127.0.0.1:{rpc}:{rpc}"),
            "--entrypoint",
            "python3",
            &image,
            "-c",
            "import time; time.sleep(86400)",
        ])?;
        this.docker(&["network", "connect", f.l2.docker_network(), &this.name])?;
        this.exec(&["mkdir", "-m", "700", "/fixture"])?;
        this.exec(&["mkdir", "-m", "755", "/comet-homes"])?;
        // These are stopped, unenrolled legacy inputs, copied unchanged before any enrollment.
        // This fixture transplant is not a production app or signing-state importer.
        let signer = f.signer_storage.path().join("0");
        ensure!(
            !signer.join("authority").exists() &&
                !signer.join("key.json.authority.json").exists() &&
                !signer.join("state.json.authority.json").exists(),
            "never transplant an enrolled authority"
        );
        for (source, target) in [
            (c.app_dir(0), "/fixture/original-app"),
            (c.comet_home(0), "/fixture/original-comet"),
            (signer, "/fixture/signer"),
            (commands.chain.clone(), "/fixture/chain.toml"),
            (commands.key.clone(), "/fixture/account.hex"),
            (package().join("tests/docker/jwt.hex"), "/fixture/jwt.hex"),
        ] {
            this.copy(&source, target)?;
        }
        // Only the original transport template changes, before prepare; no persisted app,
        // Comet store, signing state or contract slot is edited.
        this.exec(&["python3", "-c", "from pathlib import Path; p=Path('/fixture/original-comet/config/config.toml'); p.write_text(p.read_text().replace('tcp://127.0.0.1:', 'tcp://0.0.0.0:')); p=Path('/fixture/original-comet/config/node_key.json'); p.chmod(0o600)"])?;
        let mut profile: toml::Table = toml::from_str(&fs::read_to_string(&commands.profile)?)?;
        for (key, value) in [
            ("l1_http", format!("http://{}:8545", f.anvil.docker_container())),
            ("l2_http", format!("http://{}:8545", f.l2.docker_container())),
            ("l2_auth", format!("http://{}:8551", f.l2.docker_container())),
            ("chain_config", "/fixture/chain.toml".into()),
            ("jwt_secret", "/fixture/jwt.hex".into()),
            ("app_data_dir", "/fixture/original-app".into()),
            ("comet_home", "/fixture/original-comet".into()),
            ("installation_parent", "/comet-homes".into()),
        ] {
            profile.insert(key.into(), toml::Value::String(value));
        }
        let executable = |program: &str, argv: &[&str], env: Value| -> Result<toml::Value> {
            Ok(toml::Value::try_from(json!({"program": program, "argv":argv, "env":env}))?)
        };
        profile.insert("app".into(), executable("/app/taiko-client", &["abci"], json!({}))?);
        profile.insert(
            "comet".into(),
            executable(
                "/usr/bin/cometbft",
                &["start"],
                json!({"ETNA_COMET_UID":"10001", "ETNA_COMET_GID":"10001"}),
            )?,
        );
        profile.insert("inspector".into(), executable("/app/etna-comet-inspect", &[], json!({}))?);
        profile.insert("signer".into(), toml::Value::try_from(json!({
            "key":"/fixture/signer/key.json", "state":"/fixture/signer/state.json", "authority":"/fixture/signer/authority",
            "executable":{"program":"/app/etna-signer","argv":[],"env":{}},
            "supervisor":{"program":"/usr/bin/python3","argv":["/app/script/etna_validator.py"],"env":{}}
        }))?);
        profile.insert("lander".into(), toml::Value::try_from(json!({"data_dir":"/fixture/lander", "executable":{"program":"/app/taiko-client", "argv":Commands::lander_prefix(Path::new("/fixture/account.hex")), "env":{}}}))?);
        let input = commands.dir.path().join("linux-profile.toml");
        write_private(&input, toml::to_string(&profile)?)?;
        this.copy(&input, "/fixture/profile.toml")?;
        this.exec(&["mkdir", "-m", "700", "/fixture/lander"])?;
        Ok(this)
    }
    fn docker(&self, args: &[&str]) -> Result<String> {
        let out = Command::new("docker").args(args).output()?;
        ensure!(
            out.status.success(),
            "docker fixture command: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        Ok(String::from_utf8(out.stdout)?)
    }
    fn exec(&self, args: &[&str]) -> Result<String> {
        let mut command = vec!["exec", &self.name];
        command.extend_from_slice(args);
        self.docker(&command)
    }
    fn copy(&self, source: &Path, target: &str) -> Result<()> {
        self.docker(&["cp", &source.display().to_string(), &format!("{}:{target}", self.name)])
            .map(drop)
    }
    pub fn read(&self, path: &str) -> Result<Vec<u8>> {
        let encoded = self.exec(&[
            "python3",
            "-c",
            "import sys; print(open(sys.argv[1],'rb').read().hex())",
            path,
        ])?;
        Ok(alloy_primitives::hex::decode(encoded.trim())?)
    }
    pub async fn prepare(&self, commands: &Commands) -> Result<String> {
        let args = [
            "abci-recover",
            "prepare",
            "--profile",
            "/fixture/profile.toml",
            "--root",
            "/fixture/recovery",
            "--generation",
            "1",
            "--json",
        ]
        .map(String::from);
        let mut process = Process::in_container(
            &self.name,
            &args,
            commands.dir.path().join("linux-prepare.log"),
        )?;
        let output = process.completed().await?;
        let report: Value = output
            .lines()
            .rev()
            .find_map(|line| serde_json::from_str(line).ok())
            .context("Linux prepare report")?;
        Ok(report["plan_id"].as_str().context("Linux plan")?.into())
    }
    pub fn activate(&self, commands: &Commands, plan: &str) -> Result<Process> {
        Process::in_container(
            &self.name,
            &[
                "abci-recover",
                "activate",
                "--profile",
                "/fixture/profile.toml",
                "--root",
                "/fixture/recovery",
                "--plan",
                plan,
            ]
            .map(String::from),
            commands.dir.path().join("linux-activate.log"),
        )
    }
    pub fn assert_uid_boundary(&self) -> Result<()> {
        self.exec(&["python3", "-c", r#"import json,os
active=json.load(open('/fixture/recovery/active.json')); home=active['installation']['home']
assert active['installation']['uid']==10001
assert os.stat(home).st_uid==10001
# Check actual stock Comet process identity, including its supplementary groups.
found=[]
for pid in os.listdir('/proc'):
 if pid.isdigit():
  try:
   args=open('/proc/'+pid+'/cmdline','rb').read().split(b'\0')
   if args[0]==b'/usr/bin/cometbft' and b'start' in args: found.append(open('/proc/'+pid+'/status').read())
  except (FileNotFoundError,ProcessLookupError): pass
assert len(found)==1, found
assert 'Uid:\t10001\t10001\t10001\t10001' in found[0], found
os.setgroups([]); os.setgid(10001); os.setuid(10001)
json.load(open(home+'/config/node_key.json'))
for path in ['/fixture/signer/key.json','/fixture/signer/state.json','/fixture/recovery']:
 try: open(path,'rb').read(); raise AssertionError('Comet could read '+path)
 except PermissionError: pass
"#])?;
        Ok(())
    }

    pub fn crash_and_quiesce(&self, plan: &str) -> Result<()> {
        self.exec(&["python3", "-c", r#"import os,signal,select,subprocess,sys
parent=int(open('/fixture/linux-activate.pid').read())
assert b'abci-recover\0activate' in open('/proc/'+str(parent)+'/cmdline','rb').read()
records={}
for pid in os.listdir('/proc'):
 if pid.isdigit():
  try:
   stat=open('/proc/'+pid+'/stat').read(); ppid=int(stat.rsplit(')',1)[1].split()[1])
   records[int(pid)]=(ppid,open('/proc/'+pid+'/cmdline','rb').read())
  except (FileNotFoundError,ProcessLookupError): pass
owned={parent}
while True:
 children={pid for pid,(ppid,_) in records.items() if ppid in owned}
 if children<=owned: break
 owned|=children
# Retain kernel process handles before killing anything; never signal a reusable PID.
fds={pid:os.pidfd_open(pid) for pid in owned}
signal.pidfd_send_signal(fds[parent],signal.SIGKILL)
assert select.select([fds[parent]],[],[],10)[0]
busy=subprocess.run(['/app/taiko-client','abci-recover','activate','--profile','/fixture/profile.toml','--root','/fixture/recovery','--plan',sys.argv[1]],capture_output=True,timeout=20)
assert busy.returncode and b'busy' in busy.stderr, busy.stderr
def stop(pid):
 fd=fds[pid]
 if not select.select([fd],[],[],0)[0]: signal.pidfd_send_signal(fd,signal.SIGTERM)
 assert select.select([fd],[],[],20)[0], records[pid]
# Lander first, then supervisor's real ordered Comet/signer shutdown, app last.
for tag in [b'lander\0',b'etna_validator.py',b'abci\0']:
 for pid in owned-{parent}:
  if tag in records[pid][1]: stop(pid)
for pid in owned: assert select.select([fds[pid]],[],[],20)[0], records[pid]
for fd in fds.values(): os.close(fd)
"#, plan])?;
        Ok(())
    }

    pub fn signed_height(&self) -> Result<u64> {
        let manifest: Value =
            serde_json::from_slice(&self.read("/fixture/signer/authority/manifest.json")?)?;
        let path =
            manifest["domains"].as_array().unwrap().last().unwrap()["state"].as_str().unwrap();
        let state: Value = serde_json::from_slice(&self.read(path)?)?;
        Ok(state["height"].as_str().context("signed native HRS")?.parse()?)
    }
}
impl Drop for LinuxRuntime {
    fn drop(&mut self) {
        let _ = Command::new("docker").args(["rm", "-f", "-v", &self.name]).output();
    }
}
