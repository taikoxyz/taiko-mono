mod builder;
mod common;
mod historical_range_handler;
mod range_iterator;
mod reorg_handler;
mod rewind_handler;
mod ring_buffer;
mod scanner;
mod sync_handler;

pub use builder::BlockRangeScannerBuilder;
pub use common::BlockScannerResult;
pub use reorg_handler::ReorgHandler;
pub use ring_buffer::RingBufferCapacity;
pub use scanner::BlockRangeScanner;

pub use common::{
    DEFAULT_BLOCK_CONFIRMATIONS, DEFAULT_MAX_BLOCK_RANGE, DEFAULT_STREAM_BUFFER_CAPACITY,
};
