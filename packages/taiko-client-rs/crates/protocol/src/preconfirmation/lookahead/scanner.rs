use alloy::primitives::Address;
use alloy_rpc_types::BlockNumberOrTag;
use event_scanner::{Notification, ScannerMessage};

use tokio::{sync::oneshot, time::Duration};
use tokio_retry::{RetryIf, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{Instrument, error, info, info_span};

use super::{
    LookaheadError, LookaheadResolverWithDefaultProvider, Result,
    resolver::{LookaheadResolver, SECONDS_IN_EPOCH, SECONDS_IN_SLOT},
};
use crate::{
    preconfirmation::lookahead::resolver::scanner_handle::LookaheadScannerHandle,
    subscription_source::SubscriptionSource,
};

/// Initial backoff delay in milliseconds when ingesting lookahead logs fails.
const INGEST_BACKOFF_BASE_MS: u64 = 200;
/// Upper bound for the exponential backoff delay between ingest retries (milliseconds).
const INGEST_BACKOFF_MAX_MS: u64 = 5_000;
/// Number of epochs to backfill when starting the scanner.
const SCAN_EPOCH_LOOKBACK: u64 = 3;

/// Error wrapper used to classify ingest failures; all variants are retryable.
#[derive(Debug)]
enum IngestError {
    Retryable(LookaheadError),
}

impl LookaheadResolver {
    /// Construct a resolver and immediately start a background event-scanner from the latest
    /// events (sized by on-chain lookahead buffer). Returns the resolver and a join handle for the
    /// scanner task. Genesis is inferred for known chains (1 mainnet, 17_000 Holesky, 560_048
    /// Hoodi); for others use `new_with_genesis`.
    pub async fn new(
        inbox_address: Address,
        source: SubscriptionSource,
    ) -> Result<(LookaheadResolverWithDefaultProvider, LookaheadScannerHandle)> {
        let provider = source
            .to_provider()
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?;

        let resolver = LookaheadResolver::build(inbox_address, provider).await?;
        let handle = resolver.spawn_scanner_from_latest(&source).await?;

        Ok((resolver, handle))
    }

    /// Same as [`new`], but allows specifying the genesis timestamp explicitly for custom or
    /// unknown networks.
    pub async fn new_with_genesis(
        inbox_address: Address,
        source: SubscriptionSource,
        genesis_timestamp: u64,
    ) -> Result<(LookaheadResolverWithDefaultProvider, LookaheadScannerHandle)> {
        let provider = source
            .to_provider()
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?;

        let resolver =
            LookaheadResolver::build_with_genesis(inbox_address, provider, genesis_timestamp)
                .await?;
        let handle = resolver.spawn_scanner_from_latest(&source).await?;

        Ok((resolver, handle))
    }

    /// Spawn a background event-scanner starting from the latest limited history (aligned with the
    /// resolver's lookback), stream events forward, and keep feeding lookahead plus
    /// blacklist/unblacklist logs into the resolver cache.
    /// The returned handle drives the long-running scanner task; log ingestion retries with
    /// capped exponential backoff.
    pub async fn spawn_scanner_from_latest(
        &self,
        source: &SubscriptionSource,
    ) -> Result<LookaheadScannerHandle> {
        info!(
            buffer = self.lookahead_buffer_size(),
            source = ?source,
            "starting lookahead scanner from three-epoch backfill"
        );

        // Compute a starting block approximately three epochs behind the current head to capture
        // recent history without relying on an event-count heuristic.
        let latest = self
            .block_reader
            .latest_block()
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?
            .ok_or_else(|| LookaheadError::EventScanner("missing latest block".into()))?;

        let blocks_per_epoch = SECONDS_IN_EPOCH / SECONDS_IN_SLOT;
        let backfill_blocks = blocks_per_epoch.saturating_mul(SCAN_EPOCH_LOOKBACK);
        let start_block = latest.number().saturating_sub(backfill_blocks);

        // Initialize the event scanner from the computed block.
        let mut scanner = source
            .to_event_scanner_from_tag(BlockNumberOrTag::Number(start_block))
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?;

        let subscription = scanner.subscribe(self.lookahead_filter());
        let resolver = self.clone();

        // Signal when the scanner reports it has switched to live mode.
        let (live_tx, live_rx) = oneshot::channel();

        let span = info_span!("lookahead_scanner", start_block);
        let handle = tokio::spawn(async move {
            let mut live_tx = Some(live_tx);
            // Start the scanner driver and obtain the StartProof required to access the stream.
            let proof = match scanner.start().await {
                Ok(proof) => proof,
                Err(err) => {
                    error!(?err, "lookahead event scanner failed to start");
                    return;
                }
            };

            // Convert the subscription into a stream using the start proof.
            let mut stream = subscription.stream(&proof);

            // Consume scanner output and push lookahead logs into the resolver as they arrive.
            while let Some(message) = stream.next().await {
                match message {
                    Ok(ScannerMessage::Data(logs)) => {
                        // Retry ingest indefinitely with capped exponential backoff until success.
                        let backoff = ExponentialBackoff::from_millis(INGEST_BACKOFF_BASE_MS)
                            .max_delay(Duration::from_millis(INGEST_BACKOFF_MAX_MS));

                        let retry_result = RetryIf::spawn(
                            backoff,
                            || {
                                let resolver = resolver.clone();
                                let logs = logs.clone();
                                async move {
                                    resolver.ingest_logs(logs).await.map_err(IngestError::Retryable)
                                }
                            },
                            // Retry on every failure; we do not drop lookahead logs.
                            |_: &IngestError| true,
                        )
                        .await;

                        if let Err(IngestError::Retryable(err)) = retry_result {
                            error!(
                                ?err,
                                "unexpected failure in lookahead log ingestion retry mechanism"
                            );
                        }
                    }
                    Ok(ScannerMessage::Notification(note)) => {
                        info!(?note, "lookahead scanner notification");
                        if matches!(note, Notification::SwitchingToLive) &&
                            let Some(tx) = live_tx.take()
                        {
                            let _ = tx.send(());
                        }
                    }
                    Err(err) => error!(?err, "error from lookahead event stream"),
                }
            }
        }.instrument(span));

        // Wait until the scanner reports it is live before returning to callers.
        live_rx
            .await
            .map_err(|_| LookaheadError::EventScanner("scanner exited before live".into()))?;

        Ok(LookaheadScannerHandle::new(handle))
    }
}
