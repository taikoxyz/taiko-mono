//! The encoded-size bound of the execution headers a batch start or a checkpoint import retains.

use crate::error::{LanderError, Result};
use alloy_consensus::Header;

/// Conservative encoded size ceiling for a canonical execution header, including genesis.
const MAX_EXECUTION_HEADER_BYTES: u64 = 1024;

/// Reject noncanonical or oversized headers before retaining or encoding their variable data.
pub fn check_header_capacity(header: &Header) -> Result<()> {
    if header.extra_data.len() > 32 ||
        alloy_rlp::encode(header).len() as u64 > MAX_EXECUTION_HEADER_BYTES
    {
        return Err(LanderError::Capacity(
            "execution history header exceeds encoded size budget".into(),
        ));
    }
    Ok(())
}
