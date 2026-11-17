use std::cmp::Ordering;

use alloy::{
    consensus::BlockHeader,
    eips::{BlockId, BlockNumberOrTag},
    network::{BlockResponse, Network},
};
use tokio::{sync::mpsc, try_join};

use robust_provider::RobustProvider;

use crate::{
    Notification, ScannerError,
    block_range_scanner::{
        common::BlockScannerResult,
        range_iterator::RangeIterator,
        reorg_handler::{DefaultReorgHandler, ReorgHandler},
        ring_buffer::RingBufferCapacity,
    },
    types::{ChannelState, TryStream},
};

pub(crate) struct RewindHandler<N: Network> {
    provider: RobustProvider<N>,
    max_block_range: u64,
    start_id: BlockId,
    end_id: BlockId,
    sender: mpsc::Sender<BlockScannerResult>,
    reorg_handler: DefaultReorgHandler<N>,
}

impl<N: Network> RewindHandler<N> {
    pub fn new(
        provider: RobustProvider<N>,
        max_block_range: u64,
        start_id: BlockId,
        end_id: BlockId,
        past_blocks_storage_capacity: RingBufferCapacity,
        sender: mpsc::Sender<BlockScannerResult>,
    ) -> Self {
        let reorg_handler =
            DefaultReorgHandler::new(provider.clone(), past_blocks_storage_capacity);
        Self { provider, max_block_range, start_id, end_id, sender, reorg_handler }
    }

    pub async fn run(self) -> Result<(), ScannerError> {
        let RewindHandler {
            provider,
            max_block_range,
            start_id,
            end_id,
            sender,
            mut reorg_handler,
        } = self;

        let (start_block, end_block) =
            try_join!(provider.get_block(start_id), provider.get_block(end_id))?;

        // normalize block range: from (higher) -> to (lower)
        let (from, to) = match start_block.header().number().cmp(&end_block.header().number()) {
            Ordering::Greater => (start_block, end_block),
            _ => (end_block, start_block),
        };

        info!(
            from_block = from.header().number(),
            to_block = to.header().number(),
            total_blocks = from.header().number().saturating_sub(to.header().number()) + 1,
            "Starting rewind stream"
        );

        tokio::spawn(async move {
            Self::handle_stream_rewind(
                from,
                to,
                max_block_range,
                &sender,
                &provider,
                &mut reorg_handler,
            )
            .await;
            debug!("Rewind stream ended");
        });

        Ok(())
    }

    /// Streams blocks in reverse order from `from` to `to`.
    #[cfg_attr(
        feature = "tracing",
        tracing::instrument(level = "trace", skip(sender, provider, reorg_handler))
    )]
    async fn handle_stream_rewind<R: ReorgHandler<N>>(
        from: N::BlockResponse,
        to: N::BlockResponse,
        max_block_range: u64,
        sender: &mpsc::Sender<BlockScannerResult>,
        provider: &RobustProvider<N>,
        reorg_handler: &mut R,
    ) {
        // for checking whether reorg occurred
        let mut tip = from;

        let from = tip.header().number();
        let to = to.header().number();

        // NOTE: Edge case - If the chain is too young to expose finalized blocks (height <
        // finalized depth) just use zero.
        // Since we use the finalized block number only to determine whether to run reorg checks
        // or not, this is a "low-stakes" RPC call, for which, for simplicity, we can default to `0`
        // even on errors. Here `0` is used because it effectively just enables reorg
        // checks. If there was actually a provider problem, any subsequent provider call
        // will catch and properly log it and return the error to the caller.
        let finalized_block_num =
            provider.get_block_number_by_id(BlockNumberOrTag::Finalized.into()).await.unwrap_or(0);

        // only check reorg if our tip is after the finalized block
        let check_reorg = tip.header().number() > finalized_block_num;
        debug!(
            from = from,
            to = to,
            finalized = finalized_block_num,
            check_reorg = check_reorg,
            "Rewind stream configuration"
        );

        let mut iter = RangeIterator::reverse(from, to, max_block_range);
        for range in &mut iter {
            // stream the range regularly, i.e. from smaller block number to greater
            if sender.try_stream(range).await.is_closed() {
                break;
            }

            if check_reorg {
                let reorg = match reorg_handler.check(&tip).await {
                    Ok(opt) => opt,
                    Err(e) => {
                        error!("Failed to perform reorg check");
                        _ = sender.try_stream(e).await;
                        return;
                    }
                };

                if let Some(common_ancestor) = reorg {
                    info!(
                        common_ancestor = common_ancestor.header().number(),
                        tip = tip.header().number(),
                        "Reorg detected during rewind, rescanning affected blocks"
                    );
                    if Self::handle_reorg_rescan(
                        &mut tip,
                        common_ancestor,
                        max_block_range,
                        sender,
                        provider,
                    )
                    .await
                    .is_closed()
                    {
                        return;
                    }
                }
            }
        }
    }

    /// Handles re-scanning of reorged blocks.
    ///
    /// Returns `ChannelState::Closed` if stream closed or terminal error occurred,
    /// `ChannelState::Open` on success.
    async fn handle_reorg_rescan(
        tip: &mut N::BlockResponse,
        common_ancestor: N::BlockResponse,
        max_block_range: u64,
        sender: &mpsc::Sender<BlockScannerResult>,
        provider: &RobustProvider<N>,
    ) -> ChannelState {
        let tip_number = tip.header().number();
        let common_ancestor = common_ancestor.header().number();

        debug!(
            tip_number = tip_number,
            common_ancestor = common_ancestor,
            blocks_to_rescan = tip_number.saturating_sub(common_ancestor),
            "Rescanning reorged blocks"
        );

        if sender.try_stream(Notification::ReorgDetected { common_ancestor }).await.is_closed() {
            return ChannelState::Closed;
        }

        // Get the new tip block (same height as original tip, but new hash)
        *tip = match provider.get_block_by_number(tip_number.into()).await {
            Ok(block) => {
                trace!(
                    new_tip_number = block.header().number(),
                    "Fetched new tip block after reorg"
                );
                block
            }
            Err(e) => {
                if matches!(e, robust_provider::Error::BlockNotFound) {
                    error!(
                        tip_number = tip_number,
                        "Unexpected: chain height decreased after reorg"
                    );
                }
                _ = sender.try_stream(e).await;
                return ChannelState::Closed;
            }
        };

        // Re-scan only the affected range (from common_ancestor + 1 up to tip)
        let rescan_from = common_ancestor + 1;

        for batch in RangeIterator::forward(rescan_from, tip_number, max_block_range) {
            trace!(range_start = *batch.start(), range_end = *batch.end(), "Rescanning batch");
            if sender.try_stream(batch).await.is_closed() {
                return ChannelState::Closed;
            }
        }

        ChannelState::Open
    }
}
