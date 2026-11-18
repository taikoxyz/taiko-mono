//! Immutable execution bodies written before their committed application state.

use alloy_rlp::Decodable;

use super::{FramedRecord, HeightFile, Record, Store, StoreError};
use crate::envelope::ExecutionBlock;

/// Exact RLP execution payloads, with the standard record checksum prefix.
const EXECUTION_FILE: HeightFile = HeightFile { prefix: "execution-block-", suffix: ".bin" };

/// Corrupt payloads set aside before a decided replay restores their exact bytes.
const EXECUTION_SET_ASIDE: HeightFile =
    HeightFile { prefix: "execution-block-", suffix: ".bin.corrupt" };

/// Atomic, immutable execution payload records.
const EXECUTION_RECORD: FramedRecord = FramedRecord {
    file: EXECUTION_FILE,
    set_aside: EXECUTION_SET_ASIDE,
    temporary: "execution-block.tmp",
    conflict: StoreError::ExecutionConflict,
};

impl Store {
    /// Reads one checksum-framed RLP block, rejecting trailing bytes and another height.
    /// Missing or corrupt auxiliary data is unavailable, never a new source of chain authority.
    pub(crate) fn load_execution_block(
        &self,
        height: u64,
    ) -> Result<Record<ExecutionBlock>, StoreError> {
        self.load_framed(EXECUTION_FILE, height, |mut body| {
            let block = ExecutionBlock::decode(&mut body)?;
            if !body.is_empty() {
                return Err(alloy_rlp::Error::UnexpectedLength);
            }
            Ok((block.header.number, block))
        })
    }

    /// Fsyncs the finalized block before its AppState can be published. Equal crash replays
    /// succeed; another valid body at that height is an integrity failure. A corrupt file is
    /// set aside using the same atomic record barrier as validator-state records.
    pub(crate) fn save_execution_block(&self, block: &ExecutionBlock) -> Result<(), StoreError> {
        let height = block.header.number;
        let found = self.load_execution_block(height)?;
        self.save_framed(EXECUTION_RECORD, height, found, block, || Ok(alloy_rlp::encode(block)))
    }
}
