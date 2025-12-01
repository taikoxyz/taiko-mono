//! Validation logic and error types for preconfirmation P2P data structures.
//!
//! This module defines:
//! - `ValidationError` for issues related to message size, count limits, and invalid parameters.
//! - `CryptoError` for cryptographic operation failures (e.g., SSZ serialization, signature recovery).
//! - Functions to validate various P2P messages and parameters against protocol-defined constraints.

use thiserror::Error;

use crate::{
    constants::{MAX_COMMITMENTS_PER_RESPONSE, MAX_TXLIST_BYTES},
    types::{
        GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, RawTxListGossip, TxListBytes,
    },
};

/// Validation failures for size/count limits derived from the preconfirmation spec.
#[derive(Debug, Error)]
pub enum ValidationError {
    /// Indicates that a transaction list is too large, exceeding `MAX_TXLIST_BYTES`.
    #[error("txlist too large: {0} bytes (max {1})")]
    TxListTooLarge(usize, usize),
    /// Indicates that the number of commitments in a response exceeds `MAX_COMMITMENTS_PER_RESPONSE`.
    #[error("commitments per response exceeds cap: {0} > {1}")]
    TooManyCommitments(usize, usize),
    /// Indicates that a requested `max_count` exceeds the allowed cap.
    #[error("max_count exceeds cap: {0} > {1}")]
    MaxCountExceeded(u32, u32),
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

/// Ensures a transaction list blob does not exceed the configured maximum size.
///
/// # Arguments
///
/// * `txlist` - A reference to the `TxListBytes` to validate.
///
/// # Returns
///
/// `Ok(())` if the txlist is within the size limit, otherwise `Err(ValidationError::TxListTooLarge)`.
pub fn validate_txlist(txlist: &TxListBytes) -> Result<(), ValidationError> {
    let len = txlist.len();
    if len > MAX_TXLIST_BYTES {
        return Err(ValidationError::TxListTooLarge(len, MAX_TXLIST_BYTES));
    }
    Ok(())
}

/// Validates a `RawTxListGossip` payload.
///
/// Currently, this only checks if the embedded transaction list (`txlist`) exceeds the
/// maximum allowed size.
///
/// # Arguments
///
/// * `msg` - A reference to the `RawTxListGossip` message to validate.
///
/// # Returns
///
/// `Ok(())` if the message is valid, otherwise `Err(ValidationError)`.
pub fn validate_raw_txlist_gossip(msg: &RawTxListGossip) -> Result<(), ValidationError> {
    validate_txlist(&msg.txlist)
}

/// Validates a `GetCommitmentsByNumberResponse` against the per-message commitment cap.
///
/// Ensures that the number of commitments returned does not exceed `MAX_COMMITMENTS_PER_RESPONSE`.
///
/// # Arguments
///
/// * `resp` - A reference to the `GetCommitmentsByNumberResponse` to validate.
///
/// # Returns
///
/// `Ok(())` if the response is valid, otherwise `Err(ValidationError::TooManyCommitments)`.
pub fn validate_commitments_response(
    resp: &GetCommitmentsByNumberResponse,
) -> Result<(), ValidationError> {
    let len = resp.commitments.len();
    if len > MAX_COMMITMENTS_PER_RESPONSE {
        return Err(ValidationError::TooManyCommitments(len, MAX_COMMITMENTS_PER_RESPONSE));
    }
    Ok(())
}

/// Validates a `GetCommitmentsByNumberRequest` against a caller-supplied `max_count` cap.
///
/// Ensures that the `max_count` requested does not exceed the provided `cap`.
///
/// # Arguments
///
/// * `req` - A reference to the `GetCommitmentsByNumberRequest` to validate.
/// * `cap` - The maximum allowed value for `req.max_count`.
///
/// # Returns
///
/// `Ok(())` if the request is valid, otherwise `Err(ValidationError::MaxCountExceeded)`.
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

    #[test]
    fn txlist_within_limit_ok() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES]).unwrap();
        assert!(validate_txlist(&txlist).is_ok());
    }

    #[test]
    fn txlist_over_limit_errs() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES + 1]);
        assert!(txlist.is_err());
    }

    #[test]
    fn commitments_response_cap() {
        let resp = GetCommitmentsByNumberResponse { commitments: Default::default() };
        assert!(validate_commitments_response(&resp).is_ok());
    }

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
