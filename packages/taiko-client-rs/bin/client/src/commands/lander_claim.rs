//! Thin entry point for independent L2 reward claims and cancellable operational retries.
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
use rpc::client::connect_http_with_limits;
use std::time::Duration;

/// Claim one landed reward using an independent L2 payer.
#[derive(Parser, Clone, Debug)]
pub struct LanderClaimSubCommand {
    /// Explicit claim identities, endpoints and payer key.
    #[command(flatten)]
    pub flags: LanderClaimArgs,
}
impl LanderClaimSubCommand {
    /// Retry availability failures until inclusion or an actionable outcome.
    /// The existing one-shot signal handler drops this future, including RPCs and backoff sleeps.
    pub async fn run(&self) -> Result<()> {
        let flags = &self.flags;
        if flags.landing_tx.is_zero() || flags.batch_id.is_zero() {
            return Err(LanderError::Configuration(
                "landing transaction and batch id must be nonzero".into(),
            )
            .into());
        }
        let deadline = Duration::from_secs(flags.rpc_timeout);
        let l1 = connect_http_with_limits(flags.l1_http.clone(), deadline, 2 * 1024 * 1024);
        let l2 = connect_http_with_limits(flags.l2_http.clone(), deadline, 2 * 1024 * 1024);
        let signer = RpcTransactionTransport::signer_from_file(&flags.key_file)?;
        let transport = RpcClaimTransport::new(l2.clone(), signer);
        let mut retry = Retry::default();
        let source = loop {
            match RpcClaimSource::connect(
                l1.clone(),
                l2.clone(),
                flags.landing_tx,
                flags.batch_id,
                transport.payer(),
                deadline,
            )
            .await
            {
                Ok(source) => break source,
                Err(error) => retry.wait(error).await?,
            }
        };
        let store = ClaimStore::open(&flags.data_dir, source.identity().clone())?;
        let mut last_state = None;
        loop {
            let outcome = runner::step(&store, &source, &transport, deadline).await;
            if let Some(job) = store.load()? &&
                let Some(tx) = job.transaction &&
                last_state != Some(job.state)
            {
                println!(
                    "Claim {:?}: transaction={} nonce={}. Signed bytes remain durable on retry, timeout or interruption.",
                    job.state, tx.hash, tx.nonce
                );
                last_state = Some(job.state);
            }
            match outcome {
                Err(error) => retry.wait(error).await?,
                Ok(ClaimOutcome::AlreadyClaimed) => {
                    println!(
                        "Reward already claimed in canonical state; any original transaction is retained. No further broadcast."
                    );
                    return Ok(());
                }
                Ok(ClaimOutcome::State(ClaimState::Included)) => {
                    println!(
                        "Claim included in the canonical L2 chain, which is BFT-final. Signed bytes retained; after any recovery that rewinds L2, rerun this command to reconcile."
                    );
                    return Ok(());
                }
                Ok(ClaimOutcome::State(_)) => {
                    retry = Retry::default();
                    tokio::time::sleep(Duration::from_secs(2)).await;
                }
            }
        }
    }
}

/// Small bounded backoff; diagnostics contain only the source adapters' sanitized categories.
#[derive(Default)]
struct Retry {
    /// Last displayed sanitized reason, suppressing unchanged repetitive output.
    reason: Option<String>,
    /// Consecutive failure exponent, capped to an eight-second delay.
    exponent: u32,
}
impl Retry {
    /// Retry only explicit claim availability/transport failures; preserve signal cancellation.
    async fn wait(&mut self, error: LanderError) -> Result<()> {
        if !matches!(error, LanderError::Unavailable(_) | LanderError::Temporary(_)) {
            return Err(error.into());
        }
        let reason = error.to_string();
        let delay = Duration::from_secs(1 << self.exponent.min(3));
        if self.reason.as_ref() != Some(&reason) {
            eprintln!(
                "Claim waiting: {reason}; retrying with backoff capped at 8s. Existing signed bytes remain durable."
            );
            self.reason = Some(reason);
        }
        self.exponent = self.exponent.saturating_add(1);
        tokio::time::sleep(delay).await;
        Ok(())
    }
}
