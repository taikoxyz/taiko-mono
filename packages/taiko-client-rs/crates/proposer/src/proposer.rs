use std::sync::Arc;
use std::time::{Duration, Instant};

use alloy_provider::Provider;
use futures::StreamExt;
use tokio::select;
use tokio::sync::mpsc;
use tokio::time::{Interval, interval};
use tokio_util::sync::CancellationToken;
use tracing::{error, info};

use rpc::RpcClient;

/// Information about the latest L2 head update.
#[derive(Debug, Clone)]
pub struct L2HeadUpdateInfo {
    pub block_id: u64,
    pub updated_at: Instant,
}

/// The main proposer structure that handles block proposing.
pub struct Proposer {
    /// RPC client for interacting with L1 and L2.
    rpc: Arc<RpcClient>,

    /// Timer for proposing blocks at regular intervals.
    proposing_timer: Interval,

    /// Information about the latest L2 head.
    l2_head_update: Option<L2HeadUpdateInfo>,

    /// Total number of proposing epochs.
    total_epochs: u64,

    /// Cancellation token for graceful shutdown.
    cancellation_token: CancellationToken,
}

impl Proposer {
    /// Creates a new proposer instance.
    pub fn new(
        rpc: Arc<RpcClient>,
        proposing_interval: Duration,
        cancellation_token: CancellationToken,
    ) -> Self {
        Self {
            rpc,
            proposing_timer: interval(proposing_interval),
            l2_head_update: None,
            total_epochs: 0,
            cancellation_token,
        }
    }

    /// Starts the main event loop for the proposer.
    pub async fn event_loop(mut self) {
        // Create a channel for L2 head updates
        let (l2_head_tx, mut l2_head_rx) = mpsc::channel::<L2HeadUpdateInfo>(10);

        // Spawn a task to subscribe to L2 chain head updates
        let rpc_clone = self.rpc.clone();
        let cancellation_token = self.cancellation_token.clone();
        tokio::spawn(async move {
            Self::subscribe_l2_head(rpc_clone, l2_head_tx, cancellation_token).await;
        });

        loop {
            select! {
                // Handle graceful shutdown
                _ = self.cancellation_token.cancelled() => {
                    info!("Proposer event loop cancelled");
                    break;
                }

                // Proposing interval timer has been reached
                _ = self.proposing_timer.tick() => {
                    // Increment metrics (would be implemented with a metrics crate)
                    self.total_epochs += 1;
                    info!("Proposing epoch {}", self.total_epochs);

                    // Attempt a proposing operation
                    if let Err(e) = self.propose_op().await {
                        error!("Proposing operation error: {}", e);
                        continue;
                    }
                }

                // Handle L2 head updates
                Some(head_info) = l2_head_rx.recv() => {
                    self.l2_head_update = Some(head_info);
                }
            }
        }

        info!("Proposer event loop stopped");
    }

    /// Subscribes to L2 chain head updates and sends them through the channel.
    /// This requires WebSocket/IPC subscription support.
    async fn subscribe_l2_head(
        rpc: Arc<RpcClient>,
        tx: mpsc::Sender<L2HeadUpdateInfo>,
        cancellation_token: CancellationToken,
    ) {
        // Subscribe to new block headers via WebSocket/IPC
        let subscription = match rpc.l2_provider().subscribe_blocks().await {
            Ok(sub) => sub,
            Err(e) => {
                error!(
                    "Failed to subscribe to L2 blocks: {}. WebSocket/IPC connection required.",
                    e
                );
                return;
            }
        };

        let mut stream = subscription.into_stream();

        loop {
            select! {
                _ = cancellation_token.cancelled() => {
                    info!("L2 head subscription cancelled");
                    break;
                }

                Some(header) = stream.next() => {
                    let head_info = L2HeadUpdateInfo {
                        block_id: header.number,
                        updated_at: Instant::now(),
                    };

                    info!("New L2 block: #{}", header.number);

                    // Send the update (ignore if receiver is dropped)
                    if tx.send(head_info).await.is_err() {
                        info!("L2 head receiver dropped, stopping subscription");
                        break;
                    }
                }

                else => {
                    error!("L2 block subscription stream ended unexpectedly");
                    break;
                }
            }
        }
    }

    /// Performs a block proposing operation.
    async fn propose_op(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        info!("Performing propose operation");

        Ok(())
    }
}
