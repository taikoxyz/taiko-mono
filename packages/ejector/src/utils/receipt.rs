use std::time::{Duration, Instant};

use alloy::{primitives::B256, providers::Provider};
use tokio::time::sleep;
use tracing::warn;

pub async fn poll_receipt_until<P>(
    provider: P,
    tx_hash: B256,
    poll_every: Duration,
    timeout: Duration,
) -> eyre::Result<Option<alloy::rpc::types::TransactionReceipt>>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let start = Instant::now();
    loop {
        match provider.get_transaction_receipt(tx_hash).await {
            Ok(Some(rcpt)) => return Ok(Some(rcpt)),
            Ok(None) => {
                if start.elapsed() >= timeout {
                    return Ok(None);
                }
                sleep(poll_every).await;
            }
            Err(e) => {
                // Transient RPC error: log and keep trying until timeout
                warn!("get_transaction_receipt error: {e}. Retrying…");
                if start.elapsed() >= timeout {
                    return Ok(None);
                }
                sleep(poll_every).await;
            }
        }
    }
}
