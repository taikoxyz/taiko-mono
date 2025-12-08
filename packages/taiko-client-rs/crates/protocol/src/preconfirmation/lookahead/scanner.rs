use alloy::primitives::Address;
use alloy_provider::{RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers};
use event_scanner::ScannerMessage;
use tokio::task::JoinHandle;
use tokio_stream::StreamExt;

use super::{error::LookaheadError, resolver::LookaheadResolver};
use crate::subscription_source::SubscriptionSource;

use super::error::Result;

impl<P> LookaheadResolver<P>
where
    P: alloy_provider::Provider + Clone + Send + Sync + 'static,
{
    /// Construct a resolver and immediately start a background event-scanner from the latest
    /// events (sized by on-chain lookahead buffer). Returns the resolver and a join handle for the
    /// scanner task.
    pub async fn new_with_scanner(
        inbox_address: Address,
        source: SubscriptionSource,
    ) -> Result<(
        LookaheadResolver<FillProvider<JoinedRecommendedFillers, RootProvider>>,
        JoinHandle<()>,
    )> {
        let provider = source
            .to_provider()
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?;

        let resolver = LookaheadResolver::new(inbox_address, provider).await?;
        let handle = resolver.spawn_scanner_from_latest(&source).await?;

        Ok((resolver, handle))
    }

    /// Spawn a background event-scanner starting from the latest on-chain lookahead buffer depth
    /// and continue streaming, feeding `LookaheadPosted` into the resolver cache.
    pub async fn spawn_scanner_from_latest(
        &self,
        source: &SubscriptionSource,
    ) -> Result<JoinHandle<()>> {
        let mut scanner = source
            .to_event_scanner_sync_from_latest_scanning(self.lookahead_buffer_size())
            .await
            .map_err(|err| LookaheadError::EventScanner(err.to_string()))?;

        let filter = self.lookahead_filter();
        let mut stream = scanner.subscribe(filter);
        let resolver = self.clone();

        let handle = tokio::spawn(async move {
            let runner = tokio::spawn(async move {
                if let Err(err) = scanner.start().await {
                    tracing::error!(?err, "lookahead event scanner terminated");
                }
            });

            while let Some(message) = stream.next().await {
                match message {
                    Ok(ScannerMessage::Data(logs)) => {
                        if let Err(err) = resolver.ingest_logs(logs).await {
                            tracing::warn!(?err, "failed to ingest lookahead logs");
                        }
                    }
                    Ok(ScannerMessage::Notification(_)) => {}
                    Err(err) => tracing::warn!(?err, "error from lookahead event stream"),
                }
            }

            if let Err(err) = runner.await {
                tracing::warn!(?err, "lookahead scanner runner join error");
            }
        });

        Ok(handle)
    }
}
