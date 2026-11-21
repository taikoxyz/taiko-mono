use alloy::{
    consensus::BlockHeader,
    eips::BlockNumberOrTag,
    network::{BlockResponse, Network, primitives::HeaderResponse},
    primitives::BlockNumber,
};
use robust_provider::RobustProvider;
use tokio::sync::mpsc;

use crate::{
    Notification,
    block_range_scanner::{common::BlockScannerResult, range_iterator::RangeIterator},
    types::{ChannelState, TryStream},
};

pub(crate) struct HistoricalRangeHandler<N: Network> {
    provider: RobustProvider<N>,
    max_block_range: u64,
    start: BlockNumber,
    end: BlockNumber,
    sender: mpsc::Sender<BlockScannerResult>,
}

impl<N: Network> HistoricalRangeHandler<N> {
    pub fn new(
        provider: RobustProvider<N>,
        max_block_range: u64,
        start: BlockNumber,
        end: BlockNumber,
        sender: mpsc::Sender<BlockScannerResult>,
    ) -> Self {
        Self { provider, max_block_range, start, end, sender }
    }

    pub fn run(self) {
        tokio::spawn(async move {
            _ = self.handle_stream_historical_range().await;
            debug!("Historical range stream ended");
        });
    }

    /// Run the handler in the current task.
    ///
    /// Returns `ChannelState::Closed` if the channel is closed, `ChannelState::Open` otherwise.
    #[must_use]
    pub async fn run_sync(self) -> ChannelState {
        self.handle_stream_historical_range().await
    }

    #[cfg_attr(feature = "tracing", tracing::instrument(level = "trace", skip(self)))]
    async fn handle_stream_historical_range(self) -> ChannelState {
        // Phase 1: Stream all finalized blocks without any reorg checks
        let Some((non_finalized_start, finalized_block_num)) = self.stream_finalized_blocks().await
        else {
            return ChannelState::Closed;
        };

        // All blocks already finalized
        if non_finalized_start > self.end {
            return ChannelState::Open;
        }

        // Phase 2: Stream non-finalized blocks with reorg detection
        self.stream_non_finalized_blocks(non_finalized_start, finalized_block_num).await
    }

    /// Streams finalized blocks without reorg checks.
    ///
    /// Returns `(non_finalized_start, finalized_block_num)`, or `None` if the channel closed.
    async fn stream_finalized_blocks(&self) -> Option<(BlockNumber, BlockNumber)> {
        // NOTE: Edge case - If the chain is too young to expose finalized blocks (height <
        // finalized depth) just use zero. Since we use the finalized block number only to
        // determine whether to run reorg checks or not, this is a "low-stakes" RPC call.
        let finalized_block_num = self
            .provider
            .get_block_number_by_id(BlockNumberOrTag::Finalized.into())
            .await
            .unwrap_or(0);

        let finalized_batch_end = finalized_block_num.min(self.end);

        let iter = RangeIterator::forward(self.start, finalized_batch_end, self.max_block_range);

        for range in iter {
            trace!(
                range_start = *range.start(),
                range_end = *range.end(),
                "Streaming finalized range"
            );
            if self.sender.try_stream(range).await.is_closed() {
                return None;
            }
        }

        // If start > finalized_batch_end, the loop above was empty and we should
        // continue from start. Otherwise, continue from after finalized_batch_end.
        Some((self.start.max(finalized_batch_end + 1), finalized_block_num))
    }

    /// Streams non-finalized blocks with end-of-range reorg detection.
    ///
    /// The handler takes a snapshot of the requested end block before streaming the
    /// non-finalized portion of the range. After streaming that portion, it re-fetches the end
    /// block and compares hashes. If a reorg is detected, it emits a
    /// [`Notification::ReorgDetected`] with the common ancestor and re-streams the non-finalized
    /// portion starting from `min_common_ancestor + 1`. This process repeats until the end block
    /// remains stable.
    ///
    /// Returns `ChannelState::Closed` if the channel is closed, `ChannelState::Open` otherwise.
    async fn stream_non_finalized_blocks(
        &self,
        non_finalized_start: BlockNumber,
        finalized_block_num: BlockNumber,
    ) -> ChannelState {
        let min_common_ancestor = non_finalized_start.saturating_sub(1).max(finalized_block_num);

        let mut end_block = match self.provider.get_block_by_number(self.end.into()).await {
            Ok(block) => block,
            Err(e) => {
                error!("Failed to get end block");
                _ = self.sender.try_stream(e).await;
                return ChannelState::Closed;
            }
        };

        // the only way to break out of the loop is for no reorg to happen while streaming
        loop {
            let iter = RangeIterator::forward(non_finalized_start, self.end, self.max_block_range);

            for range in iter {
                trace!(
                    range_start = *range.start(),
                    range_end = *range.end(),
                    "Streaming non-finalized range"
                );
                if self.sender.try_stream(range).await.is_closed() {
                    return ChannelState::Closed;
                }
            }

            let reorged_end_block = self.get_reorged_end_block(&end_block).await;

            match reorged_end_block {
                None => {
                    break;
                }
                Some(new_end_block) => {
                    // notify the receiver and update the tracked end block

                    if self
                        .sender
                        .try_stream(Notification::ReorgDetected {
                            common_ancestor: min_common_ancestor,
                        })
                        .await
                        .is_closed()
                    {
                        return ChannelState::Closed;
                    }
                    end_block = new_end_block;
                }
            }
        }

        debug!(end_block_hash = %end_block.header().hash(), "Historical sync completed");
        ChannelState::Open
    }

    /// Checks if a reorg occurred by comparing block hashes.
    ///
    /// Returns `Some(new_hash)` if a reorg was detected, `None` otherwise.
    async fn get_reorged_end_block(
        &self,
        end_block: &N::BlockResponse,
    ) -> Option<N::BlockResponse> {
        let new_end_block =
            match self.provider.get_block_by_number(end_block.header().number().into()).await {
                Ok(block) => block,
                Err(e) => {
                    error!("Failed to fetch end block for reorg check");
                    _ = self.sender.try_stream(e).await;
                    return None;
                }
            };

        let new_block_hash = new_end_block.header().hash();
        if new_block_hash == end_block.header().hash() {
            return None;
        }

        warn!(
            end_block = end_block.header().number(),
            old_hash = %end_block.header().hash(),
            new_hash = %new_block_hash,
            "Reorg detected, re-streaming non-finalized blocks"
        );

        Some(new_end_block)
    }
}
