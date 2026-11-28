use alloy::network::Network;

use robust_provider::IntoRobustProvider;

use crate::{
    ScannerError,
    block_range_scanner::{
        DEFAULT_MAX_BLOCK_RANGE, DEFAULT_STREAM_BUFFER_CAPACITY, RingBufferCapacity,
        scanner::BlockRangeScanner,
    },
};

/// Builder/configuration for the block-range streaming service.
#[derive(Clone, Debug)]
pub struct BlockRangeScannerBuilder {
    /// Maximum number of blocks per streamed range.
    pub max_block_range: u64,
    /// How many past block hashes to keep in memory for reorg detection.
    ///
    /// If set to `RingBufferCapacity::Limited(0)`, reorg detection is disabled.
    pub past_blocks_storage_capacity: RingBufferCapacity,
    pub buffer_capacity: usize,
}

impl Default for BlockRangeScannerBuilder {
    fn default() -> Self {
        Self::new()
    }
}

impl BlockRangeScannerBuilder {
    /// Creates a scanner with default configuration.
    #[must_use]
    pub fn new() -> Self {
        Self {
            max_block_range: DEFAULT_MAX_BLOCK_RANGE,
            past_blocks_storage_capacity: RingBufferCapacity::Limited(10),
            buffer_capacity: DEFAULT_STREAM_BUFFER_CAPACITY,
        }
    }

    /// Sets the maximum number of blocks per streamed range.
    ///
    /// This controls batching for historical scans and for catch-up in live/sync scanners.
    ///
    /// Must be greater than 0.
    #[must_use]
    pub fn max_block_range(mut self, max_block_range: u64) -> Self {
        self.max_block_range = max_block_range;
        self
    }

    /// Sets how many past block hashes to keep in memory for reorg detection.
    ///
    /// If set to `RingBufferCapacity::Limited(0)`, reorg detection is disabled.
    #[must_use]
    pub fn past_blocks_storage_capacity(
        mut self,
        past_blocks_storage_capacity: RingBufferCapacity,
    ) -> Self {
        self.past_blocks_storage_capacity = past_blocks_storage_capacity;
        self
    }

    /// Sets the stream buffer capacity.
    ///
    /// Controls the maximum number of messages that can be buffered in the stream
    /// before backpressure is applied.
    ///
    /// # Arguments
    ///
    /// * `buffer_capacity` - Maximum number of messages to buffer (must be greater than 0)
    #[must_use]
    pub fn buffer_capacity(mut self, buffer_capacity: usize) -> Self {
        self.buffer_capacity = buffer_capacity;
        self
    }

    /// Connects to an existing provider
    ///
    /// # Errors
    ///
    /// Returns an error if the provider connection fails.
    pub async fn connect<N: Network>(
        self,
        provider: impl IntoRobustProvider<N>,
    ) -> Result<BlockRangeScanner<N>, ScannerError> {
        if self.max_block_range == 0 {
            return Err(ScannerError::InvalidMaxBlockRange);
        }
        if self.buffer_capacity == 0 {
            return Err(ScannerError::InvalidBufferCapacity);
        }
        let provider = provider.into_robust_provider().await?;
        Ok(BlockRangeScanner::new(
            provider,
            self.max_block_range,
            self.past_blocks_storage_capacity,
            self.buffer_capacity,
        ))
    }
}
