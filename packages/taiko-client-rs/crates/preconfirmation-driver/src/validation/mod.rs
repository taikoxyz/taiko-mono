//! Validation rules for preconfirmation commitments and txlists.
//!
//! This module defines the validation rules used by the client to verify
//! incoming commitments and transaction lists.

use alloy_primitives::Address;
use preconfirmation_types::{
    Bytes20, SignedCommitment, uint256_to_u256, validate_preconfirmation_basic,
    verify_signed_commitment,
};
use protocol::preconfirmation::PreconfSlotInfo;

use crate::error::{PreconfirmationClientError, Result};

/// Validate a signed commitment with basic checks and return the recovered signer.
pub fn validate_commitment_with_signer(
    commitment: &SignedCommitment,
    expected_slasher: Option<&Bytes20>,
) -> Result<Address> {
    let recovered = verify_signed_commitment(commitment)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
    validate_preconfirmation_basic(&commitment.commitment.preconf)
        .map_err(|err| PreconfirmationClientError::Validation(err.to_string()))?;
    if let Some(expected) = expected_slasher &&
        &commitment.commitment.slasher_address != expected
    {
        return Err(PreconfirmationClientError::Validation("slasher address mismatch".to_string()));
    }
    Ok(recovered)
}

/// Returns true if the commitment is EOP-only (eop=true and zero txlist hash).
pub fn is_eop_only(commitment: &SignedCommitment) -> bool {
    let preconf = &commitment.commitment.preconf;
    preconf.eop && preconf.raw_tx_list_hash.iter().all(|&byte| byte == 0)
}

/// Validate that the commitment's signer and submission_window_end match the expected slot info.
pub fn validate_lookahead(
    commitment: &SignedCommitment,
    recovered_signer: Address,
    expected_slot_info: &PreconfSlotInfo,
) -> Result<()> {
    if recovered_signer != expected_slot_info.signer {
        return Err(PreconfirmationClientError::Validation(
            "signer mismatch: recovered signer does not match expected slot signer".to_string(),
        ));
    }

    if uint256_to_u256(&commitment.commitment.preconf.submission_window_end) !=
        expected_slot_info.submission_window_end
    {
        return Err(PreconfirmationClientError::Validation(
            "submission_window_end mismatch: commitment window end does not match expected slot end"
                .to_string(),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{is_eop_only, validate_lookahead};
    use alloy_primitives::{Address, U256};
    use preconfirmation_types::{Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment};
    use protocol::preconfirmation::PreconfSlotInfo;

    #[test]
    fn eop_only_detection() {
        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let preconf =
            Preconfirmation { eop: true, raw_tx_list_hash: zero_hash, ..Default::default() };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        assert!(is_eop_only(&commitment));
    }

    #[test]
    fn validate_lookahead_rejects_wrong_signer() {
        let preconf = Preconfirmation {
            submission_window_end: preconfirmation_types::Uint256::from(1000u64),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        let expected_slot_info = PreconfSlotInfo {
            signer: Address::repeat_byte(0x42),
            submission_window_end: U256::from(1000),
        };
        let result = validate_lookahead(&commitment, Address::ZERO, &expected_slot_info);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("signer mismatch"));
    }

    #[test]
    fn validate_lookahead_rejects_window_end_mismatch() {
        let preconf = Preconfirmation {
            submission_window_end: preconfirmation_types::Uint256::from(1000u64),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        let expected_slot_info =
            PreconfSlotInfo { signer: Address::ZERO, submission_window_end: U256::from(2000) };
        let result = validate_lookahead(&commitment, Address::ZERO, &expected_slot_info);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("submission_window_end mismatch"));
    }

    #[test]
    fn validate_lookahead_accepts_matching() {
        let preconf = Preconfirmation {
            submission_window_end: preconfirmation_types::Uint256::from(1000u64),
            ..Default::default()
        };
        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            ..Default::default()
        };
        let signer = Address::repeat_byte(0x42);
        let expected_slot_info =
            PreconfSlotInfo { signer, submission_window_end: U256::from(1000) };
        let result = validate_lookahead(&commitment, signer, &expected_slot_info);
        assert!(result.is_ok());
    }
}
