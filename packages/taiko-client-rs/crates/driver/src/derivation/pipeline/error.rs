use alloy::{
    contract::Error as ContractError,
    sol_types::Error as SolTypeError,
    transports::{RpcError, TransportErrorKind},
};
use anyhow::Error as AnyhowError;
use rpc::RpcClientError;
use thiserror::Error;

use crate::{
    derivation::{manifest::ManifestFetcherError, pipeline::shasta::validation::ValidationError},
    sync::error::EngineSubmissionError,
};
use protocol::shasta::AnchorTxConstructorError;

/// Errors emitted by derivation stages.
#[derive(Debug, Error)]
pub enum DerivationError {
    /// RPC failure while talking to the execution engine.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Failure constructing anchor transactions.
    #[error(transparent)]
    Anchor(#[from] AnchorTxConstructorError),
    /// Manifest validation failure.
    #[error(transparent)]
    Validation(#[from] ValidationError),
    /// Manifest fetch or decode failure.
    #[error(transparent)]
    Manifest(#[from] ManifestFetcherError),
    /// The required L2 block has not been produced yet.
    #[error("l2 block {0} not yet available")]
    BlockUnavailable(u64),
    /// Failure decoding the L1 proposal event payload.
    #[error(transparent)]
    ProposalDecode(#[from] SolTypeError),
    /// The proposal contains no derivation sources, which is invalid.
    #[error("proposal contains no derivation sources")]
    EmptyDerivationSources(u64),
    /// Execution engine failed to report the last block for a batch.
    #[error("missing last execution block for proposal {proposal_id}")]
    MissingBatchLastBlock {
        /// Proposal id whose batch-to-last-block mapping was missing.
        proposal_id: u64,
    },
    /// Failure while materialising payloads via the execution engine.
    #[error(transparent)]
    Engine(#[from] EngineSubmissionError),
    /// Proposal log was missing the emitting L1 block hash.
    #[error("proposal log missing block hash")]
    MissingL1BlockHash,
    /// Proposal log was missing the emitting L1 block number.
    #[error("proposal log missing block number")]
    MissingL1BlockNumber,
    /// Failed to query the anchor block fields.
    #[error("failed to fetch anchor block {block_number}: {reason}")]
    AnchorBlockQuery {
        /// Anchor block number being queried.
        block_number: u64,
        /// RPC failure detail.
        reason: String,
    },
    /// Anchor block was not present on L1.
    #[error("anchor block {block_number} not found")]
    AnchorBlockMissing {
        /// Missing anchor block number.
        block_number: u64,
    },
    /// Execution engine returned an unexpected block number.
    #[error("engine returned block {actual} but derivation expected {expected}")]
    UnexpectedBlockNumber {
        /// Expected block number from derivation state.
        expected: u64,
        /// Actual block number returned by the engine.
        actual: u64,
    },
    /// Attempted to derive blocks before the Shasta fork is active.
    #[error(
        "shasta fork inactive: activation timestamp {activation_timestamp}, parent timestamp {parent_timestamp}"
    )]
    ShastaForkInactive {
        /// Shasta activation timestamp for the current chain.
        activation_timestamp: u64,
        /// Parent block timestamp observed during derivation.
        parent_timestamp: u64,
    },
    /// Parent header was missing base fee while computing the next EIP-4396 base fee.
    #[error("parent header {parent_block_number} missing base fee for EIP-4396 calculation")]
    MissingParentBaseFee {
        /// Parent block number whose header was missing `base_fee_per_gas`.
        parent_block_number: u64,
    },
    /// Generic error bucket.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

impl From<ContractError> for DerivationError {
    /// Convert contract-call errors into the shared RPC error variant.
    fn from(err: ContractError) -> Self {
        DerivationError::Rpc(err.into())
    }
}

impl From<RpcError<TransportErrorKind>> for DerivationError {
    /// Convert transport-backed RPC errors into the shared RPC error variant.
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        DerivationError::Rpc(err.into())
    }
}
