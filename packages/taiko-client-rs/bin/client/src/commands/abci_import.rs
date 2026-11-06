//! Offline checkpoint operations. No action reads or initializes signing credentials.
use crate::{error::Result, import};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Output is one JSON report. Offline reports can never open a trust session.
#[derive(Debug, Clone, Parser)]
pub struct Command {
    /// Selected offline action.
    #[command(subcommand)]
    action: Action,
}
/// Explicit phases with independent read-only status.
#[derive(Debug, Clone, Subcommand)]
enum Action {
    /// Serve a completed imported app with its bound native execution writer in the foreground.
    RunApp {
        /// Canonical completed operation root.
        #[arg(long)]
        root: PathBuf,
        /// Original private runtime profile.
        #[arg(long)]
        profile: PathBuf,
        /// Explicit proposed-block beneficiary.
        #[arg(long)]
        fee_recipient: alloy_primitives::Address,
        /// Optional loopback public EL HTTP reader port. App traffic uses private IPC.
        #[arg(long)]
        el_http_port: Option<u16>,
        /// EL devp2p port (TCP and UDP). User transactions arrive only over devp2p; without it
        /// the owned EL has no peers.
        #[arg(long)]
        el_p2p_port: Option<u16>,
        /// EL devp2p listen address.
        #[arg(long, default_value = "0.0.0.0", requires = "el_p2p_port")]
        el_p2p_addr: std::net::IpAddr,
        /// Comma-separated EL discovery bootnode enode URLs; defaults to the chainspec's.
        #[arg(long, value_delimiter = ',', value_parser = enode, requires = "el_p2p_port")]
        el_bootnodes: Vec<String>,
        /// Comma-separated enode URLs of EL peers to keep connected.
        #[arg(long, value_delimiter = ',', value_parser = enode, requires = "el_p2p_port")]
        el_trusted_peers: Vec<String>,
        /// EL NAT resolution (any|none|upnp|publicip|extip:<IP>).
        #[arg(long, value_parser = nat, requires = "el_p2p_port")]
        el_nat: Option<String>,
        /// Optional existing archive for post-import immutable grid preimages.
        #[arg(long)]
        checkpoint_archive_dir: Option<PathBuf>,
    },
    /// Check the actual app/Comet paths before starting either a signer or a full node.
    #[command(hide = true)]
    CheckRuntime {
        /// Require a response from the running, checked app and its owned EL.
        #[arg(long)]
        live: bool,
        /// Selected app data directory.
        #[arg(long)]
        app_dir: PathBuf,
        /// Selected Comet home.
        #[arg(long)]
        comet_home: PathBuf,
    },
    /// Collect and authenticate a portable app/consensus package at a fixed landed height.
    Export {
        /// Private JSON configuration of own L1 and archival source endpoints.
        #[arg(long)]
        profile: PathBuf,
        /// Explicit selected global grid height.
        #[arg(long)]
        height: u64,
        /// Fresh canonical output directory.
        #[arg(long)]
        out: PathBuf,
        /// Archived raw appendix-A preimage if the source app has already pruned it.
        #[arg(long)]
        validator_state: Option<PathBuf>,
    },
    /// Preserve exact package bytes, authenticate own finalized L1 and verify local inputs.
    Prepare {
        /// Private JSON import profile.
        #[arg(long)]
        profile: PathBuf,
        /// Strict package directory containing package.json and blocks.jsonl only.
        #[arg(long)]
        package: PathBuf,
        /// Fresh operation root, or an identical interrupted operation.
        #[arg(long)]
        root: PathBuf,
    },
    /// Reauthenticate, import into fresh stores, check the restarted EL, and publish.
    Install {
        /// Same private profile that selected this operation.
        #[arg(long)]
        profile: PathBuf,
        /// Private operation root.
        #[arg(long)]
        root: PathBuf,
    },
    /// Inspect durable local state only; always reports live_trust=false.
    Status {
        /// Private operation root.
        #[arg(long)]
        root: PathBuf,
    },
}
impl Command {
    /// Whether this invocation owns a serving process until orderly signal shutdown.
    pub(crate) fn is_server(&self) -> bool {
        matches!(self.action, Action::RunApp { .. })
    }
    /// Drive the selected action on the one-shot runtime.
    pub async fn run(&self) -> Result<()> {
        let view = match &self.action {
            Action::RunApp {
                root,
                profile,
                fee_recipient,
                el_http_port,
                el_p2p_port,
                el_p2p_addr,
                el_bootnodes,
                el_trusted_peers,
                el_nat,
                checkpoint_archive_dir,
            } => {
                let p2p = el_p2p_port.map(|port| import::runtime::ElP2p {
                    addr: *el_p2p_addr,
                    port,
                    bootnodes: el_bootnodes.clone(),
                    trusted_peers: el_trusted_peers.clone(),
                    nat: el_nat.clone(),
                });
                return import::runtime::run(
                    profile,
                    root,
                    *fee_recipient,
                    *el_http_port,
                    p2p,
                    checkpoint_archive_dir.clone(),
                )
                .await
            }
            Action::CheckRuntime { app_dir, comet_home, live } => {
                let info = import::boundary::check_pair(app_dir, comet_home).await?;
                if *live {
                    import::runtime::check_live(app_dir).await?;
                }
                info
            }
            Action::Export { profile, height, out, validator_state } => {
                import::export::run(profile, *height, out, validator_state.as_deref()).await?
            }
            Action::Prepare { profile, package, root } => {
                import::operate(profile, Some(package), root).await?
            }
            Action::Install { profile, root } => import::operate(profile, None, root).await?,
            Action::Status { root } => import::status(root)?,
        };
        println!("{view}");
        Ok(())
    }
}

/// Accept one enode URL; reth checks the rest when it starts.
fn enode(value: &str) -> std::result::Result<String, String> {
    if value.starts_with("enode://") && !value.contains(char::is_whitespace) {
        Ok(value.to_owned())
    } else {
        Err("expected an enode://<id>@<host>:<port> URL".into())
    }
}

/// Accept one of reth's NAT resolution forms.
fn nat(value: &str) -> std::result::Result<String, String> {
    match value {
        "any" | "none" | "upnp" | "publicip" => Ok(value.to_owned()),
        _ if value
            .strip_prefix("extip:")
            .is_some_and(|ip| ip.parse::<std::net::IpAddr>().is_ok()) =>
        {
            Ok(value.to_owned())
        }
        _ => Err("expected any, none, upnp, publicip or extip:<IP>".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(extra: &[&str]) -> std::result::Result<Command, clap::Error> {
        let base = ["abci-import", "run-app", "--root", "/r", "--profile", "/p"];
        let fee = ["--fee-recipient", "0x0000000000000000000000000000000000000001"];
        Command::try_parse_from(base.iter().chain(&fee).chain(extra))
    }

    #[test]
    fn run_app_el_p2p_options() {
        let Action::RunApp { el_p2p_port, el_p2p_addr, el_bootnodes, el_nat, .. } = parse(&[
            "--el-p2p-port",
            "30303",
            "--el-bootnodes",
            "enode://a@10.0.0.1:30303,enode://b@10.0.0.2:30303",
            "--el-nat",
            "extip:203.0.113.7",
        ])
        .unwrap()
        .action
        else {
            panic!("run-app");
        };
        assert_eq!(el_p2p_port, Some(30303));
        assert_eq!(el_p2p_addr.to_string(), "0.0.0.0");
        assert_eq!(el_bootnodes.len(), 2);
        assert_eq!(el_nat.as_deref(), Some("extip:203.0.113.7"));
        assert!(parse(&[]).is_ok());
        for bad in [
            &["--el-bootnodes", "enode://a@10.0.0.1:30303"][..],
            &["--el-p2p-port", "30303", "--el-bootnodes", "10.0.0.1:30303"],
            &["--el-p2p-port", "30303", "--el-nat", "extip:nope"],
        ] {
            assert!(parse(bad).is_err(), "{bad:?}");
        }
    }
}
