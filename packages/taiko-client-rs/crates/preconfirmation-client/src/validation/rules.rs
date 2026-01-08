//! Validation rules for preconfirmation commitments and txlists.
//!
//! This module defines the validation rules used by the client to verify
//! incoming commitments and transaction lists.

use alloy_primitives::Address;
use preconfirmation_types::{
    Bytes20, GetRawTxListResponse, Preconfirmation, RawTxListGossip, SignedCommitment,
    uint256_to_u256, validate_parent_hash, validate_preconfirmation_basic,
    validate_raw_txlist_gossip, validate_raw_txlist_response, verify_signed_commitment,
};
use protocol::preconfirmation::PreconfSlotInfo;

use crate::error::{PreconfirmationClientError, Result};

/// Validate a signed commitment with basic checks and return the recovered signer.
pub fn validate_commitment_basic_with_signer(
    commitment: &SignedCommitment,
    expected_slasher: Option<&Bytes20>,
) -> Result<Address> {
    // Verify the signature and recover signer.
    let recovered = verify_signed_commitment(commitment)
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
    Ok(recovered)
}

/// Validate parent linkage using the parent preconfirmation.
pub fn validate_parent_linkage(
    commitment: &SignedCommitment,
    parent_preconf: &Preconfirmation,
) -> Result<()> {
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

/// Validate that the commitment's signer and submission_window_end match the expected slot info.
///
/// This validates:
/// 1. The recovered signer matches the expected signer for the slot.
/// 2. The commitment's submission_window_end matches the canonical slot end.
///
/// # Arguments
/// * `commitment` - The signed commitment to validate.
/// * `recovered_signer` - The address recovered from the commitment signature.
/// * `expected_slot_info` - The expected slot info from the lookahead resolver.
///
/// # Errors
/// Returns an error if the signer or submission_window_end does not match.
pub fn validate_lookahead(
    commitment: &SignedCommitment,
    recovered_signer: Address,
    expected_slot_info: &PreconfSlotInfo,
) -> Result<()> {
    // Validate the recovered signer matches the expected signer.
    if recovered_signer != expected_slot_info.signer {
        return Err(PreconfirmationClientError::Validation(
            "signer mismatch: recovered signer does not match expected slot signer".to_string(),
        ));
    }

    // Convert commitment's submission_window_end to U256 for comparison.
    let commitment_window_end =
        uint256_to_u256(&commitment.commitment.preconf.submission_window_end);

    // Validate the submission_window_end matches the canonical slot end.
    if commitment_window_end != expected_slot_info.submission_window_end {
        return Err(PreconfirmationClientError::Validation(
            "submission_window_end mismatch: commitment window end does not match expected slot end"
                .to_string(),
        ));
    }

    Ok(())
}

#[cfg(test)]
/// Tests for validation helpers.
mod tests {
    use super::{is_eop_only, validate_lookahead};
    use alloy_primitives::{Address, U256};
    use preconfirmation_types::{Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment};
    use protocol::preconfirmation::PreconfSlotInfo;

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

    /// Validate lookahead rejects when signer does not match expected.
    #[test]
    fn validate_lookahead_rejects_wrong_signer() {
        // Build a commitment with a specific submission_window_end.
        let submission_window_end = preconfirmation_types::Uint256::from(1000u64);
        let preconf = Preconfirmation {
            submission_window_end: submission_window_end.clone(),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        // Build slot info with a different signer.
        let recovered_signer = Address::ZERO;
        let expected_slot_info = PreconfSlotInfo {
            signer: Address::repeat_byte(0x42),
            submission_window_end: U256::from(1000),
        };
        // Should reject due to signer mismatch.
        let result = validate_lookahead(&commitment, recovered_signer, &expected_slot_info);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("signer mismatch"));
    }

    /// Validate lookahead rejects when submission_window_end does not match.
    #[test]
    fn validate_lookahead_rejects_window_end_mismatch() {
        // Build a commitment with submission_window_end = 1000.
        let submission_window_end = preconfirmation_types::Uint256::from(1000u64);
        let preconf = Preconfirmation {
            submission_window_end: submission_window_end.clone(),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        // Build slot info with a different submission_window_end.
        let recovered_signer = Address::ZERO;
        let expected_slot_info =
            PreconfSlotInfo { signer: Address::ZERO, submission_window_end: U256::from(2000) };
        // Should reject due to window end mismatch.
        let result = validate_lookahead(&commitment, recovered_signer, &expected_slot_info);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("submission_window_end mismatch"));
    }

    /// Validate lookahead accepts when signer and submission_window_end match.
    #[test]
    fn validate_lookahead_accepts_matching() {
        // Build a commitment with submission_window_end = 1000.
        let submission_window_end = preconfirmation_types::Uint256::from(1000u64);
        let preconf = Preconfirmation {
            submission_window_end: submission_window_end.clone(),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        // Build matching slot info.
        let recovered_signer = Address::repeat_byte(0x42);
        let expected_slot_info = PreconfSlotInfo {
            signer: Address::repeat_byte(0x42),
            submission_window_end: U256::from(1000),
        };
        // Should accept.
        let result = validate_lookahead(&commitment, recovered_signer, &expected_slot_info);
        assert!(result.is_ok());
    }
}
