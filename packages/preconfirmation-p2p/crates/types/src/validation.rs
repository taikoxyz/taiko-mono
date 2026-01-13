//! Validation logic and error types for preconfirmation P2P data structures.
//!
//! This module defines:
//! - `ValidationError` for issues related to message size, count limits, and invalid parameters.
//! - `CryptoError` for cryptographic operation failures (e.g., SSZ serialization, signature
//!   recovery).
//! - Functions to validate various P2P messages and parameters against protocol-defined
//!   constraints.

use thiserror::Error;

use crate::{
    constants::{MAX_COMMITMENTS_PER_RESPONSE, MAX_TXLIST_BYTES},
    crypto::{keccak256_bytes, preconfirmation_hash},
    types::{
        Bytes32, GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse,
        GetRawTxListResponse, Preconfirmation, RawTxListGossip, TxListBytes,
    },
};

/// Validation failures for size/count limits derived from the preconfirmation spec.
#[derive(Debug, Error)]
pub enum ValidationError {
    /// Indicates that a transaction list is too large, exceeding `MAX_TXLIST_BYTES`.
    #[error("txlist too large: {0} bytes (max {1})")]
    TxListTooLarge(usize, usize),
    /// Indicates that the number of commitments in a response exceeds
    /// `MAX_COMMITMENTS_PER_RESPONSE`.
    #[error("commitments per response exceeds cap: {0} > {1}")]
    TooManyCommitments(usize, usize),
    /// Indicates that a requested `max_count` exceeds the allowed cap.
    #[error("max_count exceeds cap: {0} > {1}")]
    MaxCountExceeded(u32, u32),
    /// Indicates that a txlist hash does not match the advertised hash.
    #[error("txlist hash mismatch: expected {expected}, got {actual}")]
    TxListHashMismatch { expected: String, actual: String },
    /// Indicates an invalid combination of EOP flag and raw tx list hash.
    #[error("non-eop preconfirmation requires non-zero raw_tx_list_hash")]
    EopTxListMismatch,
    /// Indicates the supplied parent hash does not match the computed preconfirmation hash.
    #[error("parent_preconfirmation_hash mismatch")]
    ParentPreconfirmationHashMismatch,
}

/// Errors raised during crypto/hash/sign operations.
#[derive(Debug, Error)]
pub enum CryptoError {
    /// An error occurred during SSZ serialization.
    #[error("ssz serialization error: {0}")]
    Ssz(ssz_rs::SerializeError),
    /// An error related to signature formatting or parsing.
    #[error("signature format error: {0}")]
    SignatureFormat(secp256k1::Error),
    /// An error occurred during public key recovery from a signature.
    #[error("signature recovery error: {0}")]
    Recover(secp256k1::Error),
}

/// Ensures a transaction list blob does not exceed `MAX_TXLIST_BYTES`.
pub fn validate_txlist(txlist: &TxListBytes) -> Result<(), ValidationError> {
    if txlist.len() > MAX_TXLIST_BYTES {
        return Err(ValidationError::TxListTooLarge(txlist.len(), MAX_TXLIST_BYTES));
    }
    Ok(())
}

/// Validates a `RawTxListGossip` payload (size cap + hash match).
pub fn validate_raw_txlist_gossip(msg: &RawTxListGossip) -> Result<(), ValidationError> {
    validate_raw_txlist_parts(&msg.raw_tx_list_hash, &msg.txlist)
}

/// Validates a raw-txlist response (empty body treated as "not found").
pub fn validate_raw_txlist_response(msg: &GetRawTxListResponse) -> Result<(), ValidationError> {
    if msg.txlist.is_empty() {
        return Ok(());
    }
    validate_raw_txlist_parts(&msg.raw_tx_list_hash, &msg.txlist)
}

/// Shared helper to enforce txlist size cap and hash match for gossip and req/resp bodies.
fn validate_raw_txlist_parts(hash: &Bytes32, txlist: &TxListBytes) -> Result<(), ValidationError> {
    validate_txlist(txlist)?;
    let actual = keccak256_bytes(txlist.as_ref());
    if actual.as_slice() != hash.as_ref() {
        return Err(ValidationError::TxListHashMismatch {
            expected: format!("{:02x?}", hash.as_ref()),
            actual: format!("{:02x?}", actual.as_slice()),
        });
    }
    Ok(())
}

/// Validates a `GetCommitmentsByNumberResponse` against the per-message cap.
pub fn validate_commitments_response(
    resp: &GetCommitmentsByNumberResponse,
) -> Result<(), ValidationError> {
    if resp.commitments.len() > MAX_COMMITMENTS_PER_RESPONSE {
        return Err(ValidationError::TooManyCommitments(
            resp.commitments.len(),
            MAX_COMMITMENTS_PER_RESPONSE,
        ));
    }
    Ok(())
}

/// Validate basic preconfirmation invariants that do not require chain context.
/// - Non-EOP preconfirmations must have a non-zero raw tx list hash (spec §3.1 notes).
pub fn validate_preconfirmation_basic(preconf: &Preconfirmation) -> Result<(), ValidationError> {
    let is_zero_hash = preconf.raw_tx_list_hash.iter().all(|b| *b == 0);
    if !preconf.eop && is_zero_hash {
        return Err(ValidationError::EopTxListMismatch);
    }
    Ok(())
}

/// Validate that a supplied parent hash matches the computed hash of the parent preconfirmation.
pub fn validate_parent_hash(
    parent_preconfirmation_hash: &Bytes32,
    parent: &Preconfirmation,
) -> Result<(), ValidationError> {
    let expected = preconfirmation_hash(parent)
        .map_err(|_| ValidationError::ParentPreconfirmationHashMismatch)?;
    if expected.as_slice() != parent_preconfirmation_hash.as_ref() {
        return Err(ValidationError::ParentPreconfirmationHashMismatch);
    }
    Ok(())
}

/// Validates a `GetCommitmentsByNumberRequest` against a caller-supplied `max_count` cap.
pub fn validate_commitments_request(
    req: &GetCommitmentsByNumberRequest,
    cap: u32,
) -> Result<(), ValidationError> {
    if req.max_count > cap {
        return Err(ValidationError::MaxCountExceeded(req.max_count, cap));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Uint256;

    /// Txlist exactly at the configured limit is accepted.
    #[test]
    fn txlist_within_limit_ok() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES]).unwrap();
        assert!(validate_txlist(&txlist).is_ok());
    }

    /// Oversized txlist is rejected.
    #[test]
    fn txlist_over_limit_errs() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES + 1]);
        assert!(txlist.is_err());
    }

    /// Valid raw-txlist response passes size and hash checks.
    #[test]
    fn raw_txlist_response_cap() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES]).unwrap();
        let hash = crate::crypto::keccak256_bytes(txlist.as_ref());
        let resp = GetRawTxListResponse {
            raw_tx_list_hash: crate::Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            txlist,
        };
        assert!(validate_raw_txlist_response(&resp).is_ok());
    }

    /// Empty txlist is treated as not-found and accepted.
    #[test]
    fn raw_txlist_empty_allows_not_found() {
        let resp = GetRawTxListResponse {
            raw_tx_list_hash: crate::Bytes32::try_from(vec![0u8; 32]).unwrap(),
            txlist: TxListBytes::default(),
        };
        assert!(validate_raw_txlist_response(&resp).is_ok());
    }

    /// Commitments response exceeding the per-message cap is rejected.
    #[test]
    fn commitments_response_cap() {
        let resp = GetCommitmentsByNumberResponse { commitments: Default::default() };
        assert!(validate_commitments_response(&resp).is_ok());
    }

    /// Commitments request exceeding caller cap is rejected.
    #[test]
    fn commitments_request_cap() {
        let req = GetCommitmentsByNumberRequest {
            start_block_number: Uint256::from(0u64),
            max_count: 300,
        };
        assert!(matches!(
            validate_commitments_request(&req, 256),
            Err(ValidationError::MaxCountExceeded(_, _))
        ));
    }
}
