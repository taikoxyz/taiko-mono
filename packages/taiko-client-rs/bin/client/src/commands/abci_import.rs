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
                checkpoint_archive_dir,
            } => {
                return import::runtime::run(
                    profile,
                    root,
                    *fee_recipient,
                    *el_http_port,
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
