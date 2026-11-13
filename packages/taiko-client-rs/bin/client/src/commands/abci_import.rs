//! Offline checkpoint operations. No action reads or initializes signing credentials.
use crate::{error::Result, import};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

/// Output is one JSON line. A Safety error exits 2.
#[derive(Debug, Clone, Parser)]
pub struct Command {
    /// Selected offline action.
    #[command(subcommand)]
    action: Action,
}
/// Export a package, import one into a root, or inspect a root.
#[derive(Debug, Clone, Subcommand)]
enum Action {
    /// Authenticate a package against own finalized L1, install fresh app, stock Comet and EL
    /// stores in a private stage and publish them as ROOT/ready/{app,comet,el}. Rerun after any
    /// interruption.
    Import {
        /// Own deployment and L1.
        #[command(flatten)]
        own: import::Own,
        /// Local inputs.
        #[command(flatten)]
        inputs: import::Inputs,
        /// Import root, created if absent. It holds the lock, the stage and `ready`.
        #[arg(long)]
        root: PathBuf,
    },
    /// Collect and authenticate a portable app/consensus package at a landed checkpoint.
    Export {
        /// Own deployment and L1.
        #[command(flatten)]
        own: import::Own,
        /// Archive sources and the selected checkpoint.
        #[command(flatten)]
        request: import::export::Request,
    },
    /// Report a root's phase (absent, interrupted, ready or halted) without changing it.
    Status {
        /// Import root.
        #[arg(long)]
        root: PathBuf,
    },
}
impl Command {
    /// Drive the selected action on the one-shot runtime.
    pub async fn run(&self) -> Result<()> {
        let view = match &self.action {
            Action::Import { own, inputs, root } => import::import(own, inputs, root).await?,
            Action::Export { own, request } => import::export::run(own, request).await?,
            Action::Status { root } => import::status(root)?,
        };
        println!("{view}");
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The documented interface parses; every input of `import` is required.
    #[test]
    fn documented_flags_parse() {
        let own = ["--l1.http", "http://127.0.0.1:8545", "--l2.chain-id", "167001"];
        let import = [
            "--package",
            "/p",
            "--root",
            "/r",
            "--el-source",
            "/s",
            "--el-chain",
            "/c",
            "--el-helper",
            "/e",
            "--comet-helper",
            "/h",
            "--comet-config",
            "/t",
        ];
        let parse = |args: &[&str]| Command::try_parse_from(["abci-import"].iter().chain(args));
        let full = [&["import"][..], &own, &import].concat();
        assert!(matches!(parse(&full).unwrap().action, Action::Import { .. }));
        for skip in (0..import.len()).step_by(2) {
            let mut partial = [&["import"][..], &own].concat();
            partial
                .extend(import.iter().enumerate().filter(|(i, _)| i / 2 != skip / 2).map(|x| x.1));
            assert!(parse(&partial).is_err(), "{}", import[skip]);
        }
        let export = [
            "--comet.http",
            "http://127.0.0.1:26657",
            "--l2.http",
            "http://127.0.0.1:9545",
            "--comet-genesis",
            "/g",
            "--height",
            "600",
            "--out",
            "/o",
            "--validator-state",
            "/v",
            "--chain-config",
            "/cfg",
        ];
        let Action::Export { own, request } =
            parse(&[&["export"][..], &own, &export].concat()).unwrap().action
        else {
            panic!("export")
        };
        assert_eq!((own.l2_chain_id, request.height), (167001, 600));
        assert!(request.recovery_bootstrap.is_none() && own.chain_config.is_some());
        assert!(matches!(
            parse(&["status", "--root", "/r"]).unwrap().action,
            Action::Status { .. }
        ));
        for removed in ["prepare", "install"] {
            assert!(parse(&[removed]).is_err(), "{removed}");
        }
    }
}
