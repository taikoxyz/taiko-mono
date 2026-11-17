use alloy::{
    consensus::BlockHeader,
    eips::BlockNumberOrTag,
    network::{BlockResponse, Ethereum, Network, primitives::HeaderResponse},
    primitives::{BlockHash, BlockNumber},
};
use robust_provider::RobustProvider;

use super::ring_buffer::RingBuffer;
use crate::{ScannerError, block_range_scanner::ring_buffer::RingBufferCapacity};

/// Trait for handling chain reorganizations.
#[allow(async_fn_in_trait)]
pub trait ReorgHandler<N: Network> {
    /// Checks if a block was reorged and returns the common ancestor if found.
    ///
    /// # Arguments
    ///
    /// * `block` - The block to check for reorg.
    ///
    /// # Returns
    ///
    /// * `Ok(Some(common_ancestor))` - If a reorg was detected, returns the common ancestor block.
    /// * `Ok(None)` - If no reorg was detected, returns `None`.
    /// * `Err(e)` - If an error occurred while checking for reorg.
    async fn check(
        &mut self,
        block: &N::BlockResponse,
    ) -> Result<Option<N::BlockResponse>, ScannerError>;
}

/// Default implementation of [`ReorgHandler`] that uses an RPC provider.
#[derive(Clone, Debug)]
pub(crate) struct DefaultReorgHandler<N: Network = Ethereum> {
    provider: RobustProvider<N>,
    buffer: RingBuffer<(BlockNumber, BlockHash)>,
}

impl<N: Network> ReorgHandler<N> for DefaultReorgHandler<N> {
    /// Checks if a block was reorged and returns the common ancestor if found.
    ///
    /// # Arguments
    ///
    /// * `block` - The block to check for reorg.
    ///
    /// # Returns
    ///
    /// * `Ok(Some(common_ancestor))` - If a reorg was detected, returns the common ancestor block.
    /// * `Ok(None)` - If no reorg was detected, returns `None`.
    /// * `Err(e)` - If an error occurred while checking for reorg.
    ///
    /// # Edge Cases
    ///
    /// * **Duplicate block detection** - If the incoming block hash matches the last buffered hash,
    ///   it won't be added again to prevent buffer pollution from duplicate checks.
    ///
    /// * **Empty buffer on reorg** - If a reorg is detected but the buffer is empty (e.g., first
    ///   block after initialization), the function falls back to the finalized block as the common
    ///   ancestor.
    ///
    /// * **Deep reorg beyond buffer capacity** - If all buffered blocks are reorged (buffer
    ///   exhausted), the finalized block is used as a safe fallback to prevent data loss.
    ///
    /// * **Common ancestor beyond finalized** - This can happen if not all sequental blocks are
    ///   checked and stored. If the found common ancestor has a lower block number than the
    ///   finalized block, the finalized block is used instead and the buffer is cleared.
    ///
    /// * **Network errors during lookup** - Non-`BlockNotFound` errors (e.g., RPC failures) are
    ///   propagated immediately rather than being treated as reorgs.
    ///
    /// * **Finalized block unavailable** - If the finalized block cannot be fetched when needed as
    ///   a fallback, the error is propagated to the caller.
    #[cfg_attr(
        feature = "tracing",
        tracing::instrument(level = "trace", fields(block.hash = %block.header().hash(), block.number = block.header().number()))
    )]
    async fn check(
        &mut self,
        block: &N::BlockResponse,
    ) -> Result<Option<N::BlockResponse>, ScannerError> {
        let block = block.header();

        if !self.reorg_detected(block).await? {
            let block_number = block.number();
            let block_hash = block.hash();
            // store the incoming block's hash for future reference
            if !matches!(self.buffer.back(), Some(&(_, hash)) if hash == block_hash) {
                self.buffer.push((block_number, block_hash));
                trace!(
                    block_number,
                    block_hash = %block_hash,
                    "Block hash added to reorg buffer"
                );
            }
            return Ok(None);
        }

        debug!(
            block_number = block.number(),
            block_hash = %block.hash(),
            "Reorg detected, searching for common ancestor"
        );

        while let Some(&(candidate_number, candidate_hash)) = self.buffer.back() {
            trace!(
                block_number = candidate_number,
                block_hash = %candidate_hash,
                "Checking if buffered block is canonical"
            );
            match self.provider.get_block_by_number(candidate_number.into()).await {
                Ok(canonical) if canonical.header().hash() == candidate_hash => {
                    debug!(
                        common_ancestor_hash = %candidate_hash,
                        common_ancestor_number = candidate_number,
                        "Found common ancestor"
                    );
                    return self.return_common_ancestor(canonical).await;
                }
                Ok(_) | Err(robust_provider::Error::BlockNotFound) => {
                    trace!(
                        block_number = candidate_number,
                        block_hash = %candidate_hash,
                        "Buffered block is no longer canonical, removing from buffer"
                    );
                    _ = self.buffer.pop_back();
                }
                Err(e) => return Err(e.into()),
            }
        }

        // return last finalized block as common ancestor

        // no need to store finalized block's hash in the buffer, as it is returned by default only
        // if not buffered hashes exist on-chain

        info!("No common ancestors found in buffer, falling back to finalized block");

        let finalized = self.provider.get_block_by_number(BlockNumberOrTag::Finalized).await?;

        Ok(Some(finalized))
    }
}

impl<N: Network> DefaultReorgHandler<N> {
    pub fn new(provider: RobustProvider<N>, capacity: RingBufferCapacity) -> Self {
        Self { provider, buffer: RingBuffer::new(capacity) }
    }

    async fn reorg_detected(&self, block: &N::HeaderResponse) -> Result<bool, ScannerError> {
        match self.provider.get_block_by_number(block.number().into()).await {
            Ok(canonical_block) => Ok(canonical_block.header().hash() != block.hash()),
            Err(robust_provider::Error::BlockNotFound) => Ok(true),
            Err(e) => Err(e.into()),
        }
    }

    async fn return_common_ancestor(
        &mut self,
        common_ancestor: <N as Network>::BlockResponse,
    ) -> Result<Option<N::BlockResponse>, ScannerError> {
        let common_ancestor_header = common_ancestor.header();

        let finalized = self.provider.get_block_by_number(BlockNumberOrTag::Finalized).await?;
        let finalized_header = finalized.header();

        let common_ancestor = if finalized_header.number() <= common_ancestor_header.number() {
            debug!(
                common_ancestor_number = common_ancestor_header.number(),
                common_ancestor_hash = %common_ancestor_header.hash(),
                "Returning common ancestor"
            );
            common_ancestor
        } else {
            warn!(
                common_ancestor_number = common_ancestor_header.number(),
                common_ancestor_hash = %common_ancestor_header.hash(),
                finalized_number = finalized_header.number(),
                finalized_hash = %finalized_header.hash(),
                "Found common ancestor predates finalized block, falling back to finalized"
            );
            // all buffered blocks are finalized, so no more need to track them
            self.buffer.clear();
            finalized
        };
        Ok(Some(common_ancestor))
    }
}
