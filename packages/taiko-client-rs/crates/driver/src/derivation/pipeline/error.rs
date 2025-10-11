use alloy::{
    contract::Error as ContractError,
    sol_types::Error as SolTypeError,
    transports::{RpcError, TransportErrorKind},
};
use anyhow::Error as AnyhowError;
use rpc::RpcClientError;
use thiserror::Error;

use crate::{
    derivation::{
        manifest::ManifestFetcherError,
        pipeline::shasta::{anchor::AnchorTxConstructorError, validation::ValidationError},
    },
    sync::error::EngineSubmissionError,
};

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
    /// Missing metadata required to finalise the proposal.
    #[error("proposal metadata incomplete for id {0}")]
    IncompleteMetadata(u64),
    /// Failure decoding the L1 proposal event payload.
    #[error(transparent)]
    ProposalDecode(#[from] SolTypeError),
    /// The proposal contains no derivation sources, which is invalid.
    #[error("proposal contains no derivation sources")]
    EmptyDerivationSources(u64),
    /// Failure while materialising payloads via the execution engine.
    #[error(transparent)]
    Engine(#[from] EngineSubmissionError),
    /// Generic error bucket.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

impl From<ContractError> for DerivationError {
    fn from(err: ContractError) -> Self {
        DerivationError::Rpc(err.into())
    }
}

impl From<RpcError<TransportErrorKind>> for DerivationError {
    fn from(err: RpcError<TransportErrorKind>) -> Self {
        DerivationError::Rpc(err.into())
    }
}
