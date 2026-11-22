//! Immutable execution bodies written before their committed application state.

use alloy_rlp::Decodable;

use super::{Record, SegmentLog, Store, StoreError};
use crate::envelope::ExecutionBlock;

impl Store {
    /// The segment log of the finalized execution blocks, each its exact RLP:
    /// `execution-block-<f>.log`.
    pub(crate) fn execution_blocks(&self) -> SegmentLog {
        self.log("execution-block", StoreError::ExecutionConflict)
    }

    /// Reads one checksummed RLP block, rejecting trailing bytes and another height.
    /// Missing or corrupt auxiliary data is unavailable, never a new source of chain authority.
    pub(crate) fn load_execution_block(
        &self,
        height: u64,
    ) -> Result<Record<ExecutionBlock>, StoreError> {
        Ok(self.execution_blocks().read(height)?.decode(|mut body| {
            let block = ExecutionBlock::decode(&mut body).map_err(|error| error.to_string())?;
            if !body.is_empty() {
                return Err("bytes follow the block".to_string());
            }
            if block.header.number != height {
                return Err(format!("it holds height {}", block.header.number));
            }
            Ok(block)
        }))
    }

    /// Fsyncs the finalized block before its AppState can be published. Equal crash replays
    /// succeed; another valid body at that height is an integrity failure. A corrupt record is
    /// superseded.
    pub(crate) fn save_execution_block(&self, block: &ExecutionBlock) -> Result<(), StoreError> {
        self.execution_blocks().append(block.header.number, &alloy_rlp::encode(block))
    }

    /// Deletes the execution segments wholly below `floor`, the committed anchor's checkpoint,
    /// and returns how many files it removed. Re-feeding a lost suffix that reaches below it
    /// then finds its bodies missing: unavailable data, never a halt.
    pub(crate) fn prune_execution_blocks(&self, floor: u64) -> Result<usize, StoreError> {
        self.execution_blocks().prune_below(floor)
    }
}
