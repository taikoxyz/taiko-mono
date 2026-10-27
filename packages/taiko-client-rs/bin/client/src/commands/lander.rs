//! Thin CLI entry point for the permissionless Etna lander.

use std::{future::Future, sync::Arc, time::Duration};

use abci::Engine;
use alloy_provider::Provider;
use clap::Parser;
use lander::{
    DummyProofProvider, LanderError,
    batch::{BatchBuilder, BatchBuilderConfig},
    comet::HttpCometSource,
    l1::{LandingSource, RpcLandingSource},
    metrics::LanderMetrics,
    runner::{Runner, RunnerConfig},
    store::{JournalIdentity, Store},
    tx::{RpcTransactionTransport, TransactionTransport},
};
use rpc::client::connect_http_with_timeout;
use tracing::{info, warn};

use crate::{
    commands::{init_logs, init_metrics, load_chain_params},
    error::Result,
    flags::{common::ObservabilityArgs, lander::LanderArgs},
};

/// Independent lander with authenticated EL checking for forced transaction skips.
#[derive(Parser, Clone, Debug)]
#[command(about = "Runs the permissionless Etna lander with the dummy (0x00) proof provider")]
pub struct LanderSubCommand {
    /// Shared logging and exporter flags.
    #[command(flatten)]
    pub observability_flags: ObservabilityArgs,
    /// Public endpoints, transaction caps and durable state flags.
    #[command(flatten)]
    pub lander_flags: LanderArgs,
}

impl LanderSubCommand {
    /// Validate local options, authenticate Engine capabilities, then drive the durable runner.
    ///
    /// Startup endpoint outages are retried; safety/configuration errors stop. Reading the key
    /// obtains its public address but cannot submit anything. The journal lock and integrity
    /// checks precede the first invocation of the runner's signing or broadcasting boundary.
    pub async fn run(&self) -> Result<()> {
        let config = self.lander_flags.config()?;
        init_logs(&self.observability_flags)?;
        LanderMetrics::init();
        init_metrics(&self.observability_flags)?;
        let l1 = connect_http_with_timeout(config.l1_http.clone(), config.timeouts.rpc);
        let l2 = connect_http_with_timeout(config.l2_http.clone(), config.timeouts.rpc);
        let signer = RpcTransactionTransport::signer_from_file(&config.signing_key)?;
        let transactions =
            Arc::new(RpcTransactionTransport::new(l1.clone(), signer, config.fee_caps)?);
        let sender = transactions.sender();
        let retry_max_delay = config.poll_interval.max(Duration::from_secs(30));
        let chain_id = retry_bootstrap(config.poll_interval, retry_max_delay, || async {
            let id: alloy_primitives::U256 =
                l2.raw_request("eth_chainId".into(), ()).await.map_err(|_| {
                    LanderError::Temporary("public L2 endpoint chain id is unavailable".into())
                })?;
            id.try_into().map_err(|_| {
                LanderError::Configuration(
                    "L2 chain id exceeds the supported uint64 EVM chain range".into(),
                )
            })
        })
        .await?;
        let (mut params, expected_l1) =
            load_chain_params(chain_id, config.chain_config.as_deref())?;
        let actual_l1 = retry_bootstrap(config.poll_interval, retry_max_delay, || async {
            l1.raw_request("eth_chainId".into(), ()).await.map_err(|_| {
                LanderError::Temporary("public L1 endpoint uint256 chain id is unavailable".into())
            })
        })
        .await?;
        super::bind_l1_chain_id(&mut params, expected_l1, actual_l1)?;
        let engine = Arc::new(abci::RpcEngine::new(
            config.l2_http.clone(),
            config.l2_auth.clone(),
            &config.jwt_secret,
            config.timeouts.engine,
        )?);
        retry_bootstrap(config.poll_interval, retry_max_delay, || async {
            tokio::time::timeout(config.timeouts.engine, engine.check_capabilities())
                .await
                .map_err(|_| {
                    LanderError::Temporary(
                        "startup engine_exchangeCapabilities timed out; check --l2.auth and \
                         --jwt.secret"
                            .into(),
                    )
                })?
                .map_err(|error| {
                    let message = format!(
                        "startup engine_exchangeCapabilities on --l2.auth: {}; check the endpoint \
                         and --jwt.secret",
                        lander::error::engine_diagnostic(&error),
                    );
                    if error.is_retryable() {
                        LanderError::Temporary(message)
                    } else {
                        LanderError::Configuration(message)
                    }
                })
        })
        .await?;
        let landing = Arc::new(RpcLandingSource::new(l1, l2, params.clone()));
        let snapshot =
            retry_bootstrap(config.poll_interval, retry_max_delay, || landing.snapshot()).await?;
        let identity = JournalIdentity {
            l1_chain_id: snapshot.l1_chain_id,
            l2_chain_id: snapshot.l2_chain_id,
            inbox: snapshot.inbox,
            registry: snapshot.registry,
            sender: transactions.sender(),
        };
        let store = Store::open(&config.data_dir, identity)?;
        // The message bound is CometBFT's block size; its JSON carries base64 transaction bytes
        // and structural overhead. The body budget is derived with checked arithmetic,
        // independently of bounded protobuf decoding.
        let max_response_bytes = config
            .limits
            .max_message_bytes
            .checked_mul(4)
            .and_then(|bytes| bytes.checked_add(1024 * 1024))
            .ok_or_else(|| {
                LanderError::Configuration("Comet response capacity overflows usize".into())
            })?;
        let comet = Arc::new(HttpCometSource::new(
            config.comet_http,
            config.timeouts.rpc,
            max_response_bytes,
        )?);
        let batches = Arc::new(BatchBuilder::new(
            comet,
            landing.clone(),
            BatchBuilderConfig {
                params: params.clone(),
                limits: config.limits,
                mode: config.sidecar_mode,
                engine,
                engine_timeout: config.timeouts.engine,
            },
        )?);
        let mut runner = Runner::new(
            batches,
            landing,
            transactions,
            Arc::new(DummyProofProvider),
            store,
            RunnerConfig {
                batch_policy: config.batch_policy,
                poll_interval: config.poll_interval,
                proof_timeout: config.timeouts.proof,
                broadcast_timeout: config.timeouts.broadcast,
                receipt_timeout: config.timeouts.receipt,
                confirmations: config.confirmations,
                retry_max_delay,
            },
        )?;
        info!(
            chain_id,
            inbox = %snapshot.inbox,
            sender = %sender,
            data_dir = %config.data_dir.display(),
            proof_provider = "dummy",
            proof = "0x00",
            "running the permissionless Etna lander"
        );
        runner.run().await?;
        Ok(())
    }
}

/// Retry startup reads with the runner's operational classification and configured delay bounds.
///
/// Each call is awaited in this future, so the existing signal handler can cancel the complete
/// bootstrap by dropping it. A fatal configuration, safety or journal error is never retried.
async fn retry_bootstrap<T, F, Fut>(
    base_delay: Duration,
    max_delay: Duration,
    mut read: F,
) -> lander::Result<T>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = lander::Result<T>>,
{
    let mut retry_delay = base_delay;
    loop {
        match read().await {
            Ok(value) => return Ok(value),
            Err(error) if error.is_retryable() => {
                LanderMetrics::retry(&error);
                warn!(%error, retry_seconds=retry_delay.as_secs_f64(), "lander retrying startup RPC");
                tokio::time::sleep(retry_delay).await;
                retry_delay = retry_delay.saturating_mul(2).min(max_delay);
            }
            Err(error) => return Err(error),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{
        Mutex,
        atomic::{AtomicUsize, Ordering},
    };
    use tokio::time::{Instant, sleep};

    #[tokio::test(start_paused = true)]
    async fn startup_retries_increase_then_cap_despite_delayed_rpc_failures() {
        let base = Duration::from_millis(100);
        let maximum = Duration::from_millis(350);
        let started = Instant::now();
        let attempts = Arc::new(Mutex::new(Vec::new()));
        let observed = attempts.clone();
        let result = retry_bootstrap(base, maximum, move || {
            let observed = observed.clone();
            async move {
                let attempt = {
                    let mut trace = observed.lock().unwrap();
                    trace.push(Instant::now().duration_since(started));
                    trace.len()
                };
                // The endpoint consumes time of its own; the backoff applies after the error.
                sleep(Duration::from_millis(10)).await;
                if attempt < 5 {
                    Err(LanderError::Temporary("delayed test endpoint outage".into()))
                } else {
                    Ok(123u64)
                }
            }
        })
        .await
        .unwrap();
        assert_eq!(result, 123);
        assert_eq!(*attempts.lock().unwrap(), [0, 110, 320, 680, 1040].map(Duration::from_millis));
    }

    #[tokio::test(start_paused = true)]
    async fn startup_fatal_errors_return_without_another_read_or_backoff() {
        for error in [
            LanderError::Configuration("bad configuration".into()),
            LanderError::Safety("wrong authenticated chain".into()),
            LanderError::Journal("corrupt state".into()),
        ] {
            let calls = AtomicUsize::new(0);
            let expected = error.to_string();
            let mut error = Some(error);
            let started = Instant::now();
            let result = retry_bootstrap(Duration::from_secs(1), Duration::from_secs(30), || {
                calls.fetch_add(1, Ordering::Relaxed);
                let failure = error.take().expect("fatal error must be returned only once");
                async move {
                    sleep(Duration::from_millis(10)).await;
                    Err::<u64, _>(failure)
                }
            })
            .await
            .unwrap_err();
            assert_eq!(result.to_string(), expected);
            assert_eq!(calls.load(Ordering::Relaxed), 1);
            assert_eq!(started.elapsed(), Duration::from_millis(10));
        }
    }
}
