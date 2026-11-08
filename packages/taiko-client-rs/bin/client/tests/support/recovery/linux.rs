//! The recovery commands and the restarted roles inside one disposable Linux runtime, with stock
//! Comet as the packaged Comet UID.
use super::{Commands, RecoveredNode, package, process::Process};
use crate::contracts_support::ContractFixture;
use anyhow::{Context, Result, ensure};
use serde_json::Value;
use std::{path::Path, process::Command};
use test_harness::ContractConsensus;

/// The new generation's stores inside the runtime.
const HOME: &str = "/comet-homes/g1";
const APP: &str = "/fixture/app-g1";
const PLAN: &str = "/fixture/plan-g1.json";

pub struct LinuxRuntime {
    name: String,
    l1: String,
    l2: String,
    l2_auth: String,
    rpc: u16,
}
impl LinuxRuntime {
    pub fn start(f: &ContractFixture, c: &ContractConsensus, commands: &Commands) -> Result<Self> {
        let image = std::env::var("ETNA_RECOVERY_IMAGE")
            .context("tests/entrypoint.sh must build ETNA_RECOVERY_IMAGE")?;
        let name =
            format!("recovery-{}", commands.dir.path().file_name().unwrap().to_string_lossy());
        let rpc = c.cmt.url().port().context("Comet port")?;
        let this = Self {
            name,
            l1: format!("http://{}:8545", f.anvil.docker_container()),
            l2: format!("http://{}:8545", f.l2.docker_container()),
            l2_auth: format!("http://{}:8551", f.l2.docker_container()),
            rpc,
        };
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
    /// The in-container node's own endpoint flags, spelled as for `abci`.
    fn endpoints(&self) -> Vec<String> {
        [
            "--l1.http",
            &self.l1,
            "--l2.http",
            &self.l2,
            "--l2.auth",
            &self.l2_auth,
            "--jwt.secret",
            "/fixture/jwt.hex",
            "--chain-config",
            "/fixture/chain.toml",
        ]
        .map(String::from)
        .to_vec()
    }
    /// One-shot `abci-recover` inside the runtime.
    async fn recover(&self, commands: &Commands, args: Vec<String>, log: &str) -> Result<String> {
        Process::in_container(
            &self.name,
            "/app/taiko-client",
            &args,
            &[],
            commands.dir.path().join(format!("{log}.log")),
        )?
        .completed()
        .await
    }
    /// `prepare` and `install` inside the runtime, then hand the home to the Comet UID as the
    /// packaged runbook does.
    pub async fn prepare_and_install(&self, commands: &Commands) -> Result<()> {
        let mut args = vec!["abci-recover".to_string(), "prepare".into()];
        args.extend(self.endpoints());
        args.extend(["--generation", "1", "--out", PLAN].map(String::from));
        self.recover(commands, args, "linux-prepare").await?;
        let args = [
            "abci-recover",
            "install",
            "--plan",
            PLAN,
            "--comet-config",
            "/fixture/original-comet/config/config.toml",
            "--node-key",
            "/fixture/original-comet/config/node_key.json",
            "--home",
            HOME,
            "--app-dir",
            APP,
        ];
        self.recover(commands, args.map(String::from).to_vec(), "linux-install").await?;
        let args = ["abci-recover", "status", "--plan", PLAN, "--home", HOME, "--json"];
        let output =
            self.recover(commands, args.map(String::from).to_vec(), "linux-status").await?;
        let report: Value = output
            .lines()
            .rev()
            .find_map(|line| serde_json::from_str(line).ok())
            .context("Linux status report")?;
        ensure!(
            report["installed"] == true && report["origin_height"] == commands.origin,
            "{report}"
        );
        self.exec(&["chown", "-R", "10001:10001", HOME])?;
        Ok(())
    }
    /// The operator's restart inside the runtime (START-10-6): app, supervisor, lander.
    pub async fn start_recovered(
        &self,
        f: &ContractFixture,
        commands: &Commands,
    ) -> Result<RecoveredNode> {
        let log = |role: &str| commands.dir.path().join(format!("linux-{role}.log"));
        let config: toml::Table =
            toml::from_str(&String::from_utf8(self.read(&format!("{HOME}/config/config.toml"))?)?)?;
        let proxy = config["proxy_app"].as_str().context("installed proxy_app")?.to_owned();
        let mut args = vec!["abci".to_string(), "--data-dir".into(), APP.into()];
        args.extend(self.endpoints());
        args.extend([
            "--abci.addr".into(),
            proxy.clone(),
            "--fee-recipient".into(),
            f.params.fee_recipient.to_string(),
        ]);
        let mut app =
            Process::in_container(&self.name, "/app/taiko-client", &args, &[], log("app"))?;
        let port = proxy.rsplit(':').next().context("proxy port")?.to_owned();
        tokio::time::timeout(std::time::Duration::from_secs(150), async {
            loop {
                app.running()?;
                let probe =
                    format!("import socket; socket.create_connection(('127.0.0.1', {port}), 1)");
                if self.exec(&["python3", "-c", &probe]).is_ok() {
                    return Ok::<_, anyhow::Error>(());
                }
                tokio::time::sleep(std::time::Duration::from_millis(200)).await;
            }
        })
        .await
        .context("recovered app never listened")??;
        let genesis: abci::GenesisDoc =
            serde_json::from_slice(&self.read(&format!("{HOME}/config/genesis.json"))?)?;
        // The supervisor's environment from the one harness definition; the image supplies
        // ETNA_SIGNER_BIN and the Comet UID.
        let env: Vec<(String, String)> = test_harness::supervisor_command(
            Path::new(HOME),
            Path::new(APP),
            Path::new("/fixture/signer"),
            &genesis.chain_id,
            Some((&f.params, 1)),
        )
        .get_envs()
        .filter_map(|(key, value)| Some((key.to_str()?.to_owned(), value?.to_str()?.to_owned())))
        .collect();
        let supervisor = Process::in_container(
            &self.name,
            "/usr/bin/python3",
            &["/app/script/etna_validator.py".into()],
            &env,
            log("supervisor"),
        )?;
        let mut args = Commands::lander_prefix(Path::new("/fixture/account.hex"));
        args.extend(self.endpoints());
        args.extend([
            "--comet.http".into(),
            format!("http://127.0.0.1:{}", self.rpc),
            "--data-dir".into(),
            "/fixture/lander".into(),
        ]);
        let lander =
            Process::in_container(&self.name, "/app/taiko-client", &args, &[], log("lander"))?;
        Ok(RecoveredNode::new(app, supervisor, Some(lander)))
    }
    pub fn assert_uid_boundary(&self) -> Result<()> {
        self.exec(&["python3", "-c", r#"import os
home='/comet-homes/g1'
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
import json
json.load(open(home+'/config/node_key.json'))
for path in ['/fixture/signer/key.json','/fixture/signer/state.json','/fixture/app-g1']:
 try: open(path,'rb').read(); raise AssertionError('Comet could read '+path)
 except PermissionError: pass
"#])?;
        Ok(())
    }
}
impl Drop for LinuxRuntime {
    fn drop(&mut self) {
        let _ = Command::new("docker").args(["rm", "-f", "-v", &self.name]).output();
    }
}
