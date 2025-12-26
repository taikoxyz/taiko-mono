//! SDK-level validation rules for preconfirmation commitments.
//!
//! This module implements spec-required invariants (§4–§7) layered on top of
//! network-level validation from `preconfirmation-net`. It provides:
//!
//! - `ValidationOutcome`: structured result of validation with penalization decision
//! - `ValidationStatus`: Valid, Pending, or Invalid status
//! - Individual validation rules for EOP, parent linkage, block progression, signatures
//! - `CommitmentValidator`: aggregates all rules for incoming commitments

use alloy_primitives::{Address, B256};
use preconfirmation_types::{
    Preconfirmation, SignedCommitment, keccak256_bytes, preconfirmation_hash,
    verify_signed_commitment,
};

/// Status of a validation check.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValidationStatus {
    /// The commitment passed all validation checks.
    Valid,
    /// The commitment cannot be validated yet (e.g., awaiting parent).
    /// This is not a failure - the commitment should be buffered.
    Pending,
    /// The commitment failed validation.
    Invalid,
}

impl ValidationStatus {
    /// Returns true if the status is Valid.
    pub fn is_valid(&self) -> bool {
        matches!(self, Self::Valid)
    }

    /// Returns true if the status is Pending.
    pub fn is_pending(&self) -> bool {
        matches!(self, Self::Pending)
    }

    /// Returns true if the status is Invalid.
    pub fn is_invalid(&self) -> bool {
        matches!(self, Self::Invalid)
    }
}

/// Result of validating a commitment with penalization decision.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValidationOutcome {
    /// The validation status.
    pub status: ValidationStatus,
    /// Whether to apply a gossipsub penalty to the peer.
    /// Invalid commitments may be penalized, but pending ones should not be.
    pub penalize: bool,
    /// Human-readable explanation of the outcome.
    pub reason: Option<String>,
}

impl ValidationOutcome {
    /// Create a valid outcome (no penalty, no reason needed).
    pub fn valid() -> Self {
        Self { status: ValidationStatus::Valid, penalize: false, reason: None }
    }

    /// Create a pending outcome (no penalty, with explanation).
    pub fn pending(reason: impl Into<String>) -> Self {
        Self { status: ValidationStatus::Pending, penalize: false, reason: Some(reason.into()) }
    }

    /// Create an invalid outcome with penalty decision.
    pub fn invalid(reason: impl Into<String>, penalize: bool) -> Self {
        Self { status: ValidationStatus::Invalid, penalize, reason: Some(reason.into()) }
    }
}

// --- Validation Rules ---

/// Validate EOP (End-of-Proposal) invariant per spec §3.1.
///
/// The relaxed rule is:
/// - If `eop=false`, the `raw_tx_list_hash` MUST be non-zero
/// - If `eop=true`, the `raw_tx_list_hash` can be zero or non-zero
///
/// An EOP commitment marks the end of a proposal but may still reference a txlist.
/// The key constraint is that non-EOP commitments MUST have a txlist (non-zero hash).
///
/// Violations are penalized as they indicate malformed commitments.
pub fn validate_eop_rule(preconf: &Preconfirmation) -> ValidationOutcome {
    let is_zero_hash = preconf.raw_tx_list_hash.iter().all(|b| *b == 0);

    match (preconf.eop, is_zero_hash) {
        // EOP=true with zero hash: valid (end-of-proposal with no txlist)
        (true, true) => ValidationOutcome::valid(),
        // EOP=true with non-zero hash: valid (end-of-proposal with txlist)
        (true, false) => ValidationOutcome::valid(),
        // EOP=false with non-zero hash: valid (normal commitment with txlist)
        (false, false) => ValidationOutcome::valid(),
        // EOP=false with zero hash: invalid (must have txlist)
        (false, true) => ValidationOutcome::invalid(
            "non-EOP preconfirmation requires non-zero raw_tx_list_hash",
            true,
        ),
    }
}

/// Validate parent linkage: verify that `parent_preconfirmation_hash` matches
/// the computed hash of the parent preconfirmation.
///
/// - If parent is `None`, returns `Pending` (awaiting parent arrival)
/// - If parent is `Some` and hash matches, returns `Valid`
/// - If parent is `Some` and hash mismatches, returns `Invalid` with penalty
///
/// Per spec, commitments awaiting parents should be buffered, not penalized.
pub fn validate_parent_linkage(
    child: &Preconfirmation,
    parent: Option<&Preconfirmation>,
) -> ValidationOutcome {
    match parent {
        None => ValidationOutcome::pending("awaiting parent preconfirmation"),
        Some(parent_preconf) => {
            // Compute the expected parent hash
            let expected_hash = match preconfirmation_hash(parent_preconf) {
                Ok(hash) => hash,
                Err(_) => {
                    return ValidationOutcome::invalid("failed to hash parent preconfirmation", true)
                }
            };

            // Compare with child's declared parent hash
            if expected_hash.as_slice() == child.parent_preconfirmation_hash.as_ref() {
                ValidationOutcome::valid()
            } else {
                ValidationOutcome::invalid("parent_preconfirmation_hash mismatch", true)
            }
        }
    }
}

/// Validate block number monotonicity: child's block_number must be >= parent's.
///
/// This enforces strict progression in the commitment chain.
/// Violations are penalized as they indicate an invalid commitment ordering.
pub fn validate_block_progression(
    child: &Preconfirmation,
    parent: &Preconfirmation,
) -> ValidationOutcome {
    // Compare block numbers (Uint256 supports ordering)
    if child.block_number >= parent.block_number {
        ValidationOutcome::valid()
    } else {
        ValidationOutcome::invalid("child block_number must be >= parent block_number", true)
    }
}

/// Validate block parameter progression: timestamp and anchor_block_number.
///
/// This enforces that:
/// - `timestamp` must strictly increase (child.timestamp > parent.timestamp)
/// - `anchor_block_number` must be monotonically non-decreasing (child.anchor_block_number >=
///   parent.anchor_block_number)
///
/// Violations are penalized as they indicate an invalid commitment ordering.
pub fn validate_block_params_progression(
    child: &Preconfirmation,
    parent: &Preconfirmation,
) -> ValidationOutcome {
    // Timestamp must strictly increase
    if child.timestamp <= parent.timestamp {
        return ValidationOutcome::invalid("child timestamp must be > parent timestamp", true);
    }

    // Anchor block number must be monotonically non-decreasing
    if child.anchor_block_number < parent.anchor_block_number {
        return ValidationOutcome::invalid(
            "child anchor_block_number must be >= parent anchor_block_number",
            true,
        );
    }

    ValidationOutcome::valid()
}

/// Validate that a txlist's hash matches the advertised raw_tx_list_hash.
///
/// This verifies: `keccak256(txlist) == raw_tx_list_hash`.
/// Violations are penalized as they indicate tampered or incorrect data.
pub fn validate_txlist_hash(expected_hash: &B256, txlist: &[u8]) -> ValidationOutcome {
    let computed = keccak256_bytes(txlist);
    if computed == *expected_hash {
        ValidationOutcome::valid()
    } else {
        ValidationOutcome::invalid("txlist hash mismatch", true)
    }
}

/// Validate that a txlist's size does not exceed the configured maximum.
///
/// Per spec, txlists exceeding `max_txlist_bytes` should be rejected to prevent
/// DoS attacks and ensure network bandwidth is used efficiently.
/// Violations are penalized as they indicate malformed or malicious data.
pub fn validate_txlist_size(txlist: &[u8], max_size: usize) -> ValidationOutcome {
    if txlist.len() <= max_size {
        ValidationOutcome::valid()
    } else {
        ValidationOutcome::invalid(
            format!("txlist size {} exceeds maximum {}", txlist.len(), max_size),
            true,
        )
    }
}

/// Validate a signature on a signed commitment.
///
/// Attempts to recover the signer address from the signature. If recovery fails,
/// the signature is invalid and the peer should be penalized.
pub fn validate_signature(signed: &SignedCommitment) -> ValidationOutcome {
    match verify_signed_commitment(signed) {
        Ok(_) => ValidationOutcome::valid(),
        Err(_) => ValidationOutcome::invalid("signature recovery failed", true),
    }
}

/// Validate a signature and return the recovered address on success.
///
/// This is useful when you need both the validation outcome and the signer address
/// for further checks (e.g., verifying against expected slasher address).
pub fn validate_signature_with_address(
    signed: &SignedCommitment,
) -> (ValidationOutcome, Option<Address>) {
    match verify_signed_commitment(signed) {
        Ok(addr) => (ValidationOutcome::valid(), Some(addr)),
        Err(_) => (ValidationOutcome::invalid("signature recovery failed", true), None),
    }
}

// --- BlockParamsValidator Hook ---

/// Hook trait for chain-specific block parameter validation.
///
/// This trait allows consumers to inject custom validation logic for
/// block parameters like `gas_limit`, `coinbase`, `prover_auth`, and `proposal_id`.
/// The default implementation performs timestamp and anchor_block_number checks.
pub trait BlockParamsValidator: Send + Sync {
    /// Validate block parameters between child and parent preconfirmations.
    ///
    /// Returns `ValidationOutcome::valid()` if parameters are acceptable,
    /// or an invalid outcome with reason and penalty decision.
    fn validate_params(
        &self,
        child: &Preconfirmation,
        parent: &Preconfirmation,
    ) -> ValidationOutcome;
}

/// Default block params validator that checks timestamp and anchor_block_number progression.
#[derive(Debug, Clone, Default)]
pub struct DefaultBlockParamsValidator;

impl BlockParamsValidator for DefaultBlockParamsValidator {
    fn validate_params(
        &self,
        child: &Preconfirmation,
        parent: &Preconfirmation,
    ) -> ValidationOutcome {
        validate_block_params_progression(child, parent)
    }
}

// --- CommitmentValidator ---

/// Result of validating a signed commitment through all rules.
#[derive(Debug, Clone)]
pub struct ValidationResult {
    /// The overall validation outcome.
    pub outcome: ValidationOutcome,
    /// The recovered signer address (if signature is valid).
    pub signer: Option<Address>,
}

/// Aggregates all validation rules for incoming commitments.
///
/// This validator runs checks in a specific order for efficiency:
/// 1. Signature validation (quick fail, provides signer address)
/// 2. EOP rule (quick, stateless)
/// 3. Parent linkage (may return Pending)
/// 4. Block progression (requires parent)
/// 5. Block parameter progression via hook (requires parent)
///
/// The validator short-circuits on the first failure or pending result.
pub struct CommitmentValidator {
    /// Optional hook for custom block parameter validation.
    block_params_hook: Option<Box<dyn BlockParamsValidator>>,
    /// Whether to enforce parent linkage validation.
    require_parent: bool,
}

impl Default for CommitmentValidator {
    fn default() -> Self {
        Self {
            block_params_hook: Some(Box::new(DefaultBlockParamsValidator)),
            require_parent: true,
        }
    }
}

impl CommitmentValidator {
    /// Create a new validator with default settings (includes default block params validation).
    pub fn new() -> Self {
        Self::default()
    }

    /// Create a new validator with a custom block params validation hook.
    ///
    /// The hook will be called after standard validations (signature, EOP, parent linkage,
    /// block number progression) to perform chain-specific parameter checks.
    pub fn with_hook(hook: Box<dyn BlockParamsValidator>) -> Self {
        Self { block_params_hook: Some(hook), require_parent: true }
    }

    /// Create a new validator without any block params validation hook.
    ///
    /// This disables the default timestamp and anchor_block_number progression checks.
    pub fn without_hook() -> Self {
        Self { block_params_hook: None, require_parent: true }
    }

    /// Create a validator that skips parent linkage validation entirely.
    ///
    /// This is useful during early integration when parent lookup is not yet
    /// implemented. Signature and EOP checks still run.
    pub fn without_parent_validation() -> Self {
        Self {
            block_params_hook: Some(Box::new(DefaultBlockParamsValidator)),
            require_parent: false,
        }
    }

    /// Validate a signed commitment with optional parent context.
    ///
    /// Returns the validation result including outcome and recovered signer.
    pub fn validate(
        &self,
        signed: &SignedCommitment,
        parent: Option<&Preconfirmation>,
    ) -> ValidationResult {
        let preconf = &signed.commitment.preconf;

        // 1. Validate signature and recover signer
        let (sig_outcome, signer) = validate_signature_with_address(signed);
        if !sig_outcome.status.is_valid() {
            return ValidationResult { outcome: sig_outcome, signer: None };
        }

        // 2. Validate EOP rule
        let eop_outcome = validate_eop_rule(preconf);
        if !eop_outcome.status.is_valid() {
            return ValidationResult { outcome: eop_outcome, signer };
        }

        // 3. Validate parent linkage (optional)
        if self.require_parent {
            let linkage_outcome = validate_parent_linkage(preconf, parent);
            if !linkage_outcome.status.is_valid() {
                return ValidationResult { outcome: linkage_outcome, signer };
            }

            // 4. Validate block progression (only if parent is present)
            if let Some(parent_preconf) = parent {
                let prog_outcome = validate_block_progression(preconf, parent_preconf);
                if !prog_outcome.status.is_valid() {
                    return ValidationResult { outcome: prog_outcome, signer };
                }

                // 5. Validate block parameters via hook (if configured)
                if let Some(hook) = &self.block_params_hook {
                    let params_outcome = hook.validate_params(preconf, parent_preconf);
                    if !params_outcome.status.is_valid() {
                        return ValidationResult { outcome: params_outcome, signer };
                    }
                }
            }
        }

        // All validations passed
        ValidationResult { outcome: ValidationOutcome::valid(), signer }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // --- ValidationOutcome and ValidationStatus tests ---

    #[test]
    fn validation_status_valid_is_success() {
        let status = ValidationStatus::Valid;
        assert!(status.is_valid());
        assert!(!status.is_pending());
        assert!(!status.is_invalid());
    }

    #[test]
    fn validation_status_pending_indicates_awaiting_parent() {
        let status = ValidationStatus::Pending;
        assert!(!status.is_valid());
        assert!(status.is_pending());
        assert!(!status.is_invalid());
    }

    #[test]
    fn validation_status_invalid_is_failure() {
        let status = ValidationStatus::Invalid;
        assert!(!status.is_valid());
        assert!(!status.is_pending());
        assert!(status.is_invalid());
    }

    #[test]
    fn validation_outcome_valid_does_not_penalize() {
        let outcome = ValidationOutcome::valid();
        assert!(outcome.status.is_valid());
        assert!(!outcome.penalize);
        assert!(outcome.reason.is_none());
    }

    #[test]
    fn validation_outcome_pending_does_not_penalize() {
        let outcome = ValidationOutcome::pending("awaiting parent");
        assert!(outcome.status.is_pending());
        assert!(!outcome.penalize);
        assert_eq!(outcome.reason, Some("awaiting parent".to_string()));
    }

    #[test]
    fn validation_outcome_invalid_with_penalty() {
        let outcome = ValidationOutcome::invalid("EOP rule violation", true);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
        assert_eq!(outcome.reason, Some("EOP rule violation".to_string()));
    }

    #[test]
    fn validation_outcome_invalid_without_penalty() {
        let outcome = ValidationOutcome::invalid("expired commitment", false);
        assert!(outcome.status.is_invalid());
        assert!(!outcome.penalize);
    }

    // --- EOP validation tests ---

    fn sample_preconfirmation(
        eop: bool,
        zero_hash: bool,
    ) -> preconfirmation_types::Preconfirmation {
        use preconfirmation_types::{Bytes20, Bytes32, Uint256};
        let hash = if zero_hash { [0u8; 32] } else { [1u8; 32] };
        preconfirmation_types::Preconfirmation {
            eop,
            block_number: Uint256::from(100u64),
            timestamp: Uint256::from(1000u64),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(99u64),
            raw_tx_list_hash: Bytes32::try_from(hash.to_vec()).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        }
    }

    #[test]
    fn eop_true_requires_zero_hash() {
        // EOP=true with zero hash is valid
        let preconf = sample_preconfirmation(true, true);
        let outcome = validate_eop_rule(&preconf);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn eop_true_with_nonzero_hash_is_valid() {
        // EOP=true with non-zero hash is valid per relaxed spec §3.1.
        // An EOP commitment can still reference a txlist.
        let preconf = sample_preconfirmation(true, false);
        let outcome = validate_eop_rule(&preconf);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn eop_false_requires_nonzero_hash() {
        // EOP=false with non-zero hash is valid
        let preconf = sample_preconfirmation(false, false);
        let outcome = validate_eop_rule(&preconf);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn eop_false_with_zero_hash_is_invalid() {
        // EOP=false with zero hash violates spec §3.1
        let preconf = sample_preconfirmation(false, true);
        let outcome = validate_eop_rule(&preconf);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    // --- Parent linkage validation tests ---

    fn sample_preconf_with_parent_hash(
        block_num: u64,
        parent_hash: [u8; 32],
    ) -> preconfirmation_types::Preconfirmation {
        use preconfirmation_types::{Bytes20, Bytes32, Uint256};
        preconfirmation_types::Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(1000u64),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        }
    }

    #[test]
    fn parent_linkage_valid_when_hash_matches() {
        use preconfirmation_types::preconfirmation_hash;

        // Create parent
        let parent = sample_preconf_with_parent_hash(99, [0u8; 32]);
        let parent_hash = preconfirmation_hash(&parent).unwrap();

        // Create child with correct parent hash
        let child = sample_preconf_with_parent_hash(100, parent_hash.0);

        let outcome = validate_parent_linkage(&child, Some(&parent));
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn parent_linkage_pending_when_parent_missing() {
        let child = sample_preconf_with_parent_hash(100, [0xAB; 32]);

        // Parent is missing - should be pending, not invalid
        let outcome = validate_parent_linkage(&child, None);
        assert!(outcome.status.is_pending());
        assert!(!outcome.penalize); // Don't penalize for missing parent
    }

    #[test]
    fn parent_linkage_invalid_when_hash_mismatch() {
        // Create parent
        let parent = sample_preconf_with_parent_hash(99, [0u8; 32]);

        // Create child with wrong parent hash
        let child = sample_preconf_with_parent_hash(100, [0xFF; 32]);

        let outcome = validate_parent_linkage(&child, Some(&parent));
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize); // Penalize for hash mismatch
    }

    // --- Block number monotonicity tests ---

    fn sample_preconf_with_block_number(block_num: u64) -> preconfirmation_types::Preconfirmation {
        use preconfirmation_types::{Bytes20, Bytes32, Uint256};
        preconfirmation_types::Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(1000u64),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        }
    }

    #[test]
    fn block_number_valid_when_child_greater_than_parent() {
        let parent = sample_preconf_with_block_number(99);
        let child = sample_preconf_with_block_number(100);

        let outcome = validate_block_progression(&child, &parent);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn block_number_valid_when_child_equals_parent() {
        // Same block number is allowed (multiple commitments in same block)
        let parent = sample_preconf_with_block_number(100);
        let child = sample_preconf_with_block_number(100);

        let outcome = validate_block_progression(&child, &parent);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn block_number_invalid_when_child_less_than_parent() {
        let parent = sample_preconf_with_block_number(100);
        let child = sample_preconf_with_block_number(99);

        let outcome = validate_block_progression(&child, &parent);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    // --- TxList hash verification tests ---

    #[test]
    fn txlist_hash_valid_when_matches() {
        use preconfirmation_types::keccak256_bytes;

        let txlist_data = b"some transaction data";
        let computed_hash = keccak256_bytes(txlist_data);

        let outcome = validate_txlist_hash(&computed_hash, txlist_data);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn txlist_hash_invalid_when_mismatch() {
        use alloy_primitives::B256;

        let txlist_data = b"some transaction data";
        let wrong_hash = B256::from([0xDE; 32]);

        let outcome = validate_txlist_hash(&wrong_hash, txlist_data);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    // --- Signature verification tests ---

    fn sample_signed_commitment() -> preconfirmation_types::SignedCommitment {
        use preconfirmation_types::{
            Bytes20, Bytes32, PreconfCommitment, SignedCommitment, Uint256, sign_commitment,
        };
        use secp256k1::SecretKey;

        let preconf = preconfirmation_types::Preconfirmation {
            eop: false,
            block_number: Uint256::from(100u64),
            timestamp: Uint256::from(1000u64),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(99u64),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        };

        let commitment = PreconfCommitment {
            preconf,
            slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
        };

        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();

        SignedCommitment { commitment, signature: sig }
    }

    #[test]
    fn signature_valid_when_recoverable() {
        let signed = sample_signed_commitment();
        let outcome = validate_signature(&signed);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn signature_invalid_when_corrupted() {
        use preconfirmation_types::Bytes65;

        let mut signed = sample_signed_commitment();
        // Corrupt the signature
        signed.signature = Bytes65::try_from(vec![0xFF; 65]).unwrap();

        let outcome = validate_signature(&signed);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    #[test]
    fn signature_returns_recovered_address() {
        use preconfirmation_types::public_key_to_address;
        use secp256k1::{PublicKey, Secp256k1, SecretKey};

        let signed = sample_signed_commitment();
        let (outcome, address) = validate_signature_with_address(&signed);

        assert!(outcome.status.is_valid());
        assert!(address.is_some());

        // Verify the address matches expected
        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let pk = PublicKey::from_secret_key(&Secp256k1::new(), &sk);
        let expected = public_key_to_address(&pk);
        assert_eq!(address.unwrap(), expected);
    }

    // --- CommitmentValidator tests ---

    fn make_signed_commitment_for_validation(
        block_num: u64,
        parent_hash: [u8; 32],
        eop: bool,
        zero_txlist_hash: bool,
    ) -> preconfirmation_types::SignedCommitment {
        use preconfirmation_types::{
            Bytes20, Bytes32, PreconfCommitment, SignedCommitment, Uint256, sign_commitment,
        };
        use secp256k1::SecretKey;

        let hash = if zero_txlist_hash { [0u8; 32] } else { [1u8; 32] };
        // Derive timestamp from block_num to ensure proper progression
        let timestamp = 1000u64 + block_num;
        let preconf = preconfirmation_types::Preconfirmation {
            eop,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(timestamp),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(hash.to_vec()).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        };

        let commitment = PreconfCommitment {
            preconf,
            slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
        };

        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();

        SignedCommitment { commitment, signature: sig }
    }

    #[test]
    fn commitment_validator_validates_all_rules() {
        use preconfirmation_types::preconfirmation_hash;

        // Create parent commitment
        let parent = make_signed_commitment_for_validation(99, [0u8; 32], false, false);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();

        // Create valid child commitment
        let child = make_signed_commitment_for_validation(100, parent_hash.0, false, false);

        // Validate with parent present
        let result = CommitmentValidator::new().validate(&child, Some(&parent.commitment.preconf));

        assert!(result.outcome.status.is_valid());
        assert!(result.signer.is_some());
    }

    #[test]
    fn commitment_validator_returns_pending_when_parent_missing() {
        // Child with unknown parent hash
        let child = make_signed_commitment_for_validation(100, [0xAB; 32], false, false);

        let result = CommitmentValidator::new().validate(&child, None);

        assert!(result.outcome.status.is_pending());
        assert!(!result.outcome.penalize);
    }

    #[test]
    fn commitment_validator_fails_on_eop_violation() {
        use preconfirmation_types::preconfirmation_hash;

        // Create parent
        let parent = make_signed_commitment_for_validation(99, [0u8; 32], false, false);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();

        // EOP=false but zero hash (violation)
        let child = make_signed_commitment_for_validation(100, parent_hash.0, false, true);

        let result = CommitmentValidator::new().validate(&child, Some(&parent.commitment.preconf));

        assert!(result.outcome.status.is_invalid());
        assert!(result.outcome.penalize);
    }

    #[test]
    fn commitment_validator_fails_on_block_regression() {
        use preconfirmation_types::preconfirmation_hash;

        // Parent at block 100
        let parent = make_signed_commitment_for_validation(100, [0u8; 32], false, false);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();

        // Child at block 99 (regression)
        let child = make_signed_commitment_for_validation(99, parent_hash.0, false, false);

        let result = CommitmentValidator::new().validate(&child, Some(&parent.commitment.preconf));

        assert!(result.outcome.status.is_invalid());
        assert!(result.outcome.penalize);
    }

    // --- Block parameter progression tests ---

    fn sample_preconf_with_params(
        block_num: u64,
        timestamp: u64,
        anchor_block_num: u64,
    ) -> preconfirmation_types::Preconfirmation {
        use preconfirmation_types::{Bytes20, Bytes32, Uint256};
        preconfirmation_types::Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(timestamp),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(anchor_block_num),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(2000u64),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        }
    }

    #[test]
    fn timestamp_valid_when_child_greater_than_parent() {
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 1001, 99);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn timestamp_invalid_when_child_equals_parent() {
        // Same timestamp is NOT allowed (must strictly increase)
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 1000, 99);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    #[test]
    fn timestamp_invalid_when_child_less_than_parent() {
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 999, 99);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    #[test]
    fn anchor_block_number_valid_when_child_greater_than_parent() {
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 1001, 99);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn anchor_block_number_valid_when_child_equals_parent() {
        // Same anchor is allowed (may reference same L1 block)
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 1001, 98);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_valid());
    }

    #[test]
    fn anchor_block_number_invalid_when_child_less_than_parent() {
        let parent = sample_preconf_with_params(99, 1000, 98);
        let child = sample_preconf_with_params(100, 1001, 97);

        let outcome = validate_block_params_progression(&child, &parent);
        assert!(outcome.status.is_invalid());
        assert!(outcome.penalize);
    }

    // --- BlockParamsValidator hook tests ---

    struct RejectAllValidator;

    impl BlockParamsValidator for RejectAllValidator {
        fn validate_params(
            &self,
            _child: &preconfirmation_types::Preconfirmation,
            _parent: &preconfirmation_types::Preconfirmation,
        ) -> ValidationOutcome {
            ValidationOutcome::invalid("rejected by custom validator", true)
        }
    }

    struct AcceptAllValidator;

    impl BlockParamsValidator for AcceptAllValidator {
        fn validate_params(
            &self,
            _child: &preconfirmation_types::Preconfirmation,
            _parent: &preconfirmation_types::Preconfirmation,
        ) -> ValidationOutcome {
            ValidationOutcome::valid()
        }
    }

    #[test]
    fn commitment_validator_uses_custom_hook() {
        use preconfirmation_types::preconfirmation_hash;

        // Create valid parent-child chain
        let parent = make_signed_commitment_for_validation(99, [0u8; 32], false, false);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();
        let child = make_signed_commitment_for_validation(100, parent_hash.0, false, false);

        // With RejectAllValidator, should fail
        let validator = CommitmentValidator::with_hook(Box::new(RejectAllValidator));
        let result = validator.validate(&child, Some(&parent.commitment.preconf));
        assert!(result.outcome.status.is_invalid());
        assert_eq!(result.outcome.reason, Some("rejected by custom validator".to_string()));

        // With AcceptAllValidator, should pass
        let validator = CommitmentValidator::with_hook(Box::new(AcceptAllValidator));
        let result = validator.validate(&child, Some(&parent.commitment.preconf));
        assert!(result.outcome.status.is_valid());
    }

    #[test]
    fn commitment_validator_with_block_params_validates_all() {
        use preconfirmation_types::preconfirmation_hash;

        // Create parent
        let parent = make_signed_commitment_for_validation(99, [0u8; 32], false, false);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();

        // Create child with valid params
        let child = make_signed_commitment_for_validation(100, parent_hash.0, false, false);

        // Default validator should run block params progression checks
        let result = CommitmentValidator::new().validate(&child, Some(&parent.commitment.preconf));

        assert!(result.outcome.status.is_valid());
    }
}
