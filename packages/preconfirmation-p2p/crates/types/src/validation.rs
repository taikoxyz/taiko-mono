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
    #[error("txlist too large: {0} bytes (max {1})")]
    TxListTooLarge(usize, usize),
    #[error("commitments per response exceeds cap: {0} > {1}")]
    TooManyCommitments(usize, usize),
    #[error("max_count exceeds cap: {0} > {1}")]
    MaxCountExceeded(u32, u32),
}

/// Errors raised during crypto/hash/sign operations.
#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("ssz serialization error: {0}")]
    Ssz(ssz_rs::SerializeError),
    #[error("signature format error: {0}")]
    SignatureFormat(secp256k1::Error),
    #[error("signature recovery error: {0}")]
    Recover(secp256k1::Error),
}

/// Ensure a txlist blob does not exceed the configured maximum size.
pub fn validate_txlist(txlist: &TxListBytes) -> Result<(), ValidationError> {
    let len = txlist.len();
    if len > MAX_TXLIST_BYTES {
        return Err(ValidationError::TxListTooLarge(len, MAX_TXLIST_BYTES));
    }
    Ok(())
}

/// Validate a raw-txlist gossip payload (currently only size-checked).
pub fn validate_raw_txlist_gossip(msg: &RawTxListGossip) -> Result<(), ValidationError> {
    validate_txlist(&msg.txlist)
}

/// Validate a commitments response against the per-message commitment cap.
pub fn validate_commitments_response(
    resp: &GetCommitmentsByNumberResponse,
) -> Result<(), ValidationError> {
    let len = resp.commitments.len();
    if len > MAX_COMMITMENTS_PER_RESPONSE {
        return Err(ValidationError::TooManyCommitments(len, MAX_COMMITMENTS_PER_RESPONSE));
    }
    Ok(())
}

/// Validate a commitments request against a caller-supplied `max_count` cap.
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
