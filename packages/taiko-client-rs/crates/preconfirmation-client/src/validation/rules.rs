//! Validation rules for preconfirmation commitments and txlists.
//!
//! This module defines the validation rules used by the client to verify
//! incoming commitments and transaction lists.

use alloy_primitives::B256;
use preconfirmation_types::{
    Bytes20, GetRawTxListResponse, Preconfirmation, RawTxListGossip, SignedCommitment,
    validate_parent_hash, validate_preconfirmation_basic, validate_raw_txlist_gossip,
    validate_raw_txlist_response, verify_signed_commitment,
};

use crate::error::{PreconfirmationClientError, Result};

/// Validate a signed commitment with basic checks.
pub fn validate_commitment_basic(
    commitment: &SignedCommitment,
    expected_slasher: Option<&Bytes20>,
) -> Result<()> {
    // Verify the signature and recover signer.
    verify_signed_commitment(commitment)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
    // Validate preconfirmation invariants.
    validate_preconfirmation_basic(&commitment.commitment.preconf)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
    // Enforce expected slasher address if configured.
    if let Some(expected) = expected_slasher {
        // Compare the configured slasher address.
        if &commitment.commitment.slasher_address != expected {
            return Err(PreconfirmationClientError::Validation(
                "slasher address mismatch".to_string(),
            ));
        }
    }
    Ok(())
}

/// Validate parent linkage using the parent preconfirmation.
pub fn validate_parent_linkage(
    commitment: &SignedCommitment,
    parent_preconf: &Preconfirmation,
) -> Result<()> {
    // Validate the parent hash against the supplied parent preconfirmation.
    validate_parent_hash(
        &commitment.commitment.preconf.parent_preconfirmation_hash,
        parent_preconf,
    )
    .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
    Ok(())
}

/// Validate a raw txlist gossip payload.
pub fn validate_txlist_gossip(msg: &RawTxListGossip) -> Result<()> {
    validate_raw_txlist_gossip(msg)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))
}

/// Validate a raw txlist response payload.
pub fn validate_txlist_response(msg: &GetRawTxListResponse) -> Result<()> {
    validate_raw_txlist_response(msg)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))
}

/// Returns true if the commitment is EOP-only (eop=true and zero txlist hash).
pub fn is_eop_only(commitment: &SignedCommitment) -> bool {
    // Extract the preconfirmation fields.
    let preconf = &commitment.commitment.preconf;
    // Check if eop is set and the txlist hash is zero.
    preconf.eop && preconf.raw_tx_list_hash.iter().all(|byte| *byte == 0)
}

/// Compute the commitment's raw txlist hash as B256.
pub fn commitment_txlist_hash(commitment: &SignedCommitment) -> B256 {
    // Convert the raw txlist hash into B256.
    B256::from_slice(commitment.commitment.preconf.raw_tx_list_hash.as_ref())
}

#[cfg(test)]
/// Tests for validation helpers.
mod tests {
    use super::is_eop_only;
    use preconfirmation_types::{Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment};

    /// Ensure EOP-only detection uses the zero hash.
    #[test]
    fn eop_only_detection() {
        // Build a zero hash payload for the commitment.
        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        // Build a preconfirmation with eop set.
        let preconf =
            Preconfirmation { eop: true, raw_tx_list_hash: zero_hash, ..Default::default() };
        // Build the signed commitment wrapper.
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        assert!(is_eop_only(&commitment));
    }
}
