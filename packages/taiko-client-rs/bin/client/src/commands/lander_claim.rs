//! Thin entry point for independent L2 reward claims.
use crate::{error::Result, flags::lander_claim::LanderClaimArgs};
use clap::Parser;
use lander::{
    LanderError,
    claim::{
        runner::{self, ClaimOutcome},
        source::RpcClaimSource,
        store::{ClaimState, ClaimStore},
        tx::RpcClaimTransport,
    },
    tx::RpcTransactionTransport,
};
use rpc::client::connect_http_with_timeout;
use std::time::Duration;

/// Claim one landed reward using an independent L2 payer.
#[derive(Parser, Clone, Debug)]
pub struct LanderClaimSubCommand {
    /// Explicit claim identities, endpoints and payer key.
    #[command(flatten)]
    pub flags: LanderClaimArgs,
}
impl LanderClaimSubCommand {
    /// Run until provisional inclusion, finalized confirmation, or an actionable error.
    /// Restart the same command to recheck inclusion and finalized L1 checkpoint coverage.
    pub async fn run(&self) -> Result<()> {
        let flags = &self.flags;
        if flags.landing_tx.is_zero() || flags.batch_id.is_zero() {
            return Err(LanderError::Configuration(
                "landing transaction and batch id must be nonzero".into(),
            )
            .into());
        }
        let deadline = Duration::from_secs(flags.rpc_timeout);
        let l1 = connect_http_with_timeout(flags.l1_http.clone(), deadline);
        let l2 = connect_http_with_timeout(flags.l2_http.clone(), deadline);
        let signer = RpcTransactionTransport::signer_from_file(&flags.key_file)?;
        let transport = RpcClaimTransport::new(l2.clone(), signer);
        let source = RpcClaimSource::connect(
            l1,
            l2,
            flags.landing_tx,
            flags.batch_id,
            transport.payer(),
            deadline,
        )
        .await?;
        let store = ClaimStore::open(&flags.data_dir, source.identity().clone())?;
        loop {
            match runner::step(&store, &source, &transport, deadline).await? {
                ClaimOutcome::AlreadyClaimed => {
                    println!("Reward already claimed; no transaction submitted.");
                    return Ok(());
                }
                ClaimOutcome::State(ClaimState::Included) => {
                    println!(
                        "Claim included provisionally; finalized L1 checkpoint coverage is still pending. Signed bytes retained; rerun this command to verify finality."
                    );
                    return Ok(());
                }
                ClaimOutcome::State(ClaimState::Finalized) => {
                    println!(
                        "Claim finalized through authenticated L1 checkpoint and EL ancestry. Signed bytes retained."
                    );
                    return Ok(());
                }
                ClaimOutcome::State(_) => tokio::time::sleep(Duration::from_secs(2)).await,
            }
        }
    }
}
