use alloy::{eips::BlockId, network::Network, primitives::BlockNumber};
use robust_provider::RobustProvider;
use tokio::sync::mpsc;

use crate::{
    Notification, ScannerError,
    block_range_scanner::{
        common::{self, BlockScannerResult},
        historical_range_handler::HistoricalRangeHandler,
        reorg_handler::{DefaultReorgHandler, ReorgHandler},
        ring_buffer::RingBufferCapacity,
    },
    types::TryStream,
};

pub(crate) struct SyncHandler<N: Network> {
    provider: RobustProvider<N>,
    max_block_range: u64,
    start_id: BlockId,
    block_confirmations: u64,
    sender: mpsc::Sender<BlockScannerResult>,
    reorg_handler: DefaultReorgHandler<N>,
}

impl<N: Network> SyncHandler<N> {
    pub fn new(
        provider: RobustProvider<N>,
        max_block_range: u64,
        start_id: BlockId,
        block_confirmations: u64,
        past_blocks_storage_capacity: RingBufferCapacity,
        sender: mpsc::Sender<BlockScannerResult>,
    ) -> Self {
        let reorg_handler =
            DefaultReorgHandler::new(provider.clone(), past_blocks_storage_capacity);
        Self { provider, max_block_range, start_id, block_confirmations, sender, reorg_handler }
    }

    pub async fn run(mut self) -> Result<(), ScannerError> {
        let (start_block, latest_block) = tokio::try_join!(
            self.provider.get_block_number_by_id(self.start_id),
            self.provider.get_block_number()
        )?;

        let confirmed_tip = latest_block.saturating_sub(self.block_confirmations);

        if start_block > confirmed_tip {
            debug!(
                start_block = start_block,
                confirmed_tip = confirmed_tip,
                block_confirmations = self.block_confirmations,
                "Start block is beyond confirmed tip, waiting until starting block is confirmed before starting live stream"
            );
            self.spawn_live_only(start_block).await?;
        } else {
            debug!(
                start_block = start_block,
                confirmed_tip = confirmed_tip,
                blocks_behind = confirmed_tip.saturating_sub(start_block),
                "Start block is behind confirmed tip, catching up before live mode"
            );
            self.spawn_catchup_then_live(start_block, confirmed_tip);
        }

        Ok(())
    }

    /// Spawns a task that only streams live blocks (no historical catchup needed)
    async fn spawn_live_only(&mut self, start_block: BlockNumber) -> Result<(), ScannerError> {
        let max_block_range = self.max_block_range;
        let block_confirmations = self.block_confirmations;
        let provider = self.provider.clone();
        let sender = self.sender.clone();
        let mut reorg_handler = self.reorg_handler.clone();

        info!(start_block = start_block, "Starting live-only sync mode");
        let subscription = provider.subscribe_blocks().await?;

        tokio::spawn(async move {
            common::stream_live_blocks(
                start_block,
                subscription,
                &sender,
                &provider,
                block_confirmations,
                max_block_range,
                &mut reorg_handler,
                true,
            )
            .await;
            debug!("Live-only sync stream ended");
        });

        Ok(())
    }

    /// Spawns a task that catches up on historical blocks, then transitions to live streaming
    fn spawn_catchup_then_live(&self, start_block: BlockNumber, confirmed_tip: BlockNumber) {
        let max_block_range = self.max_block_range;
        let block_confirmations = self.block_confirmations;
        let provider = self.provider.clone();
        let mut reorg_handler = self.reorg_handler.clone();
        let sender = self.sender.clone();

        info!(
            start_block = start_block,
            confirmed_tip = confirmed_tip,
            "Starting catchup-then-live sync mode"
        );

        tokio::spawn(async move {
            // Phase 1: Catch up on any blocks that have been minted during the historical sync
            let start_block = match Self::catchup_historical_blocks(
                start_block,
                confirmed_tip,
                block_confirmations,
                max_block_range,
                &sender,
                &provider,
            )
            .await
            {
                Ok(Some(start_block)) => start_block,
                Ok(None) => {
                    debug!("Channel closed during historical catchup");
                    return; // channel closed
                }
                Err(e) => {
                    error!("Error during historical catchup");
                    _ = sender.try_stream(e).await;
                    return;
                }
            };

            // Phase 2: Transition to live streaming
            debug!(start_block = start_block, "Phase 2: Transitioning to live streaming");
            Self::transition_to_live(
                start_block,
                block_confirmations,
                max_block_range,
                &sender,
                &provider,
                &mut reorg_handler,
            )
            .await;

            debug!("Sync stream ended");
        });
    }

    /// Catches up on historical blocks until we reach the chain tip
    /// Returns the block number where live streaming should begin
    async fn catchup_historical_blocks(
        mut start_block: BlockNumber,
        mut confirmed_tip: BlockNumber,
        block_confirmations: u64,
        max_block_range: u64,
        sender: &mpsc::Sender<BlockScannerResult>,
        provider: &RobustProvider<N>,
    ) -> Result<Option<BlockNumber>, ScannerError> {
        while start_block < confirmed_tip {
            let handler = HistoricalRangeHandler::new(
                provider.clone(),
                max_block_range,
                start_block,
                confirmed_tip,
                sender.clone(),
            );

            if handler.run_sync().await.is_closed() {
                return Ok(None);
            }

            let latest = provider.get_block_number().await?;

            start_block = confirmed_tip + 1;
            confirmed_tip = latest.saturating_sub(block_confirmations);
        }

        Ok(Some(start_block))
    }

    /// Subscribes to live blocks and begins streaming
    async fn transition_to_live<R: ReorgHandler<N>>(
        start_block: BlockNumber,
        block_confirmations: u64,
        max_block_range: u64,
        sender: &mpsc::Sender<BlockScannerResult>,
        provider: &RobustProvider<N>,
        reorg_handler: &mut R,
    ) {
        let subscription = match provider.subscribe_blocks().await {
            Ok(sub) => sub,
            Err(e) => {
                error!("Failed to subscribe to live blocks");
                _ = sender.try_stream(e).await;
                return;
            }
        };

        if sender.try_stream(Notification::SwitchingToLive).await.is_closed() {
            debug!("Channel closed before live streaming could start");
            return;
        }

        common::stream_live_blocks(
            start_block,
            subscription,
            sender,
            provider,
            block_confirmations,
            max_block_range,
            reorg_handler,
            false, // (already notified above)
        )
        .await;
    }
}
