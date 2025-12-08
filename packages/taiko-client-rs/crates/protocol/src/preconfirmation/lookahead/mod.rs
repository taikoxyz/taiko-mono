use alloy_primitives::{Address, U256};

mod client;
mod error;
mod resolver;
mod scanner;

pub use bindings::lookahead_store::ILookaheadStore::{
    LookaheadData, LookaheadSlot, ProposerContext,
};
pub use client::LookaheadClient;
pub use error::{LookaheadError, Result};
pub use resolver::LookaheadResolver;

/// Resolves the expected signer for a preconfirmation commitment at a given L2 block timestamp.
///
/// P2P validation uses this to check that a received commitment was signed by the committer
/// scheduled for the L2 block containing `l2_block_timestamp`.
pub trait PreconfSignerResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address>;
}
