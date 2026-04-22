//! Validation adapter for gossip and req/resp payloads.
//!
//! This indirection makes it straightforward to swap in an upstream validator (e.g., from
//! Kona/Lighthouse or a lookahead resolver) without changing the driver/service API. The default
//! implementation delegates to the existing local validators in `preconfirmation_types`.
//!
//! Upstream expectations: a replacement should implement `ValidationAdapter` for the three
//! req/resp protocols (commitments/raw txlist/head) plus the two gossip payloads. Validation is
//! expected to be deterministic, inexpensive, and side-effect free (no async). If an upstream
//! module is added later, wire it in by constructing the adapter in the driver instead of
//! `LocalValidationAdapter`; no public API changes are required.

use std::sync::Arc;

use alloy_primitives::Address;
use libp2p::PeerId;

use preconfirmation_types::{
    Bytes20, GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip,
    SignedCommitment, Uint256, validate_commitments_response, validate_preconfirmation_basic,
    validate_raw_txlist_gossip, validate_raw_txlist_response, verify_signed_commitment,
};

/// Resolver that can validate commitments against an external lookahead schedule.
pub trait LookaheadResolver: Send + Sync {
    /// Return the expected signer for a slot ending at `submission_window_end`.
    fn signer_for_timestamp(&self, submission_window_end: &Uint256) -> Result<Address, String>;
    /// Return the expected slot end timestamp for `submission_window_end` (used to enforce
    /// equality).
    fn expected_slot_end(&self, submission_window_end: &Uint256) -> Result<Uint256, String>;
}

/// Adapter trait for validating inbound gossip and request/response payloads.
pub trait ValidationAdapter: Send + Sync {
    /// Validate a signed commitment gossip message from `from`.
    fn validate_gossip_commitment(
        &self,
        from: &PeerId,
        msg: &SignedCommitment,
    ) -> Result<(), String>;

    /// Validate a raw txlist gossip message from `from`.
    fn validate_gossip_raw_txlist(
        &self,
        from: &PeerId,
        msg: &RawTxListGossip,
    ) -> Result<(), String>;

    /// Validate an inbound commitments response.
    fn validate_commitments_response(
        &self,
        from: &PeerId,
        resp: &GetCommitmentsByNumberResponse,
    ) -> Result<(), String>;

    /// Validate an inbound raw txlist response.
    fn validate_raw_txlist_response(
        &self,
        from: &PeerId,
        resp: &GetRawTxListResponse,
    ) -> Result<(), String>;

    /// Validate an inbound head response.
    fn validate_head_response(
        &self,
        from: &PeerId,
        resp: &preconfirmation_types::PreconfHead,
    ) -> Result<(), String>;
}

/// Default adapter that reuses the existing local validators.
pub struct LocalValidationAdapter {
    /// Optional slasher address to enforce on inbound commitments.
    expected_slasher: Option<Bytes20>,
}

impl LocalValidationAdapter {
    /// Construct a local validator that optionally enforces a specific slasher address.
    pub fn new(expected_slasher: Option<Bytes20>) -> Self {
        Self { expected_slasher }
    }

    /// Validate slasher address and basic preconfirmation invariants.
    fn validate_commitment_fields(&self, msg: &SignedCommitment) -> Result<(), String> {
        if self
            .expected_slasher
            .as_ref()
            .is_some_and(|expected| &msg.commitment.slasher_address != expected)
        {
            return Err("slasher_address mismatch".to_string());
        }
        validate_preconfirmation_basic(&msg.commitment.preconf).map_err(|e| e.to_string())
    }
}

impl ValidationAdapter for LocalValidationAdapter {
    /// Validate a signed commitment gossip message using local signature checks.
    fn validate_gossip_commitment(
        &self,
        _from: &PeerId,
        msg: &SignedCommitment,
    ) -> Result<(), String> {
        verify_signed_commitment(msg).map_err(|e| e.to_string())?;
        self.validate_commitment_fields(msg)
    }

    /// Validate a raw txlist gossip message using local SSZ/size rules.
    fn validate_gossip_raw_txlist(
        &self,
        _from: &PeerId,
        msg: &RawTxListGossip,
    ) -> Result<(), String> {
        validate_raw_txlist_gossip(msg).map_err(|e| e.to_string())
    }

    /// Validate an inbound commitments response (SSZ + size caps).
    fn validate_commitments_response(
        &self,
        from: &PeerId,
        resp: &GetCommitmentsByNumberResponse,
    ) -> Result<(), String> {
        validate_commitments_response(resp).map_err(|e| e.to_string())?;
        for commitment in resp.commitments.iter() {
            self.validate_gossip_commitment(from, commitment)?;
        }
        Ok(())
    }

    /// Validate an inbound raw txlist response (hash match + size caps).
    fn validate_raw_txlist_response(
        &self,
        _from: &PeerId,
        resp: &GetRawTxListResponse,
    ) -> Result<(), String> {
        validate_raw_txlist_response(resp).map_err(|e| e.to_string())
    }

    /// Validate an inbound head response (no validation currently required).
    fn validate_head_response(
        &self,
        _from: &PeerId,
        _resp: &preconfirmation_types::PreconfHead,
    ) -> Result<(), String> {
        Ok(())
    }
}

/// Validation adapter that calls into an external lookahead resolver after basic checks.
pub struct LookaheadValidationAdapter {
    /// Local validator used for basic SSZ/hash/signature checks.
    local: LocalValidationAdapter,
    /// External resolver providing expected signer/slot for commitments.
    resolver: Arc<dyn LookaheadResolver>,
}

impl LookaheadValidationAdapter {
    /// Construct a lookahead validator wrapping the local validator and an external resolver.
    pub fn new(expected_slasher: Option<Bytes20>, resolver: Arc<dyn LookaheadResolver>) -> Self {
        Self { local: LocalValidationAdapter::new(expected_slasher), resolver }
    }
}

impl ValidationAdapter for LookaheadValidationAdapter {
    /// Validate a signed commitment gossip message using local checks plus lookahead rules.
    fn validate_gossip_commitment(
        &self,
        _from: &PeerId,
        msg: &SignedCommitment,
    ) -> Result<(), String> {
        let recovered = verify_signed_commitment(msg).map_err(|e| e.to_string())?;
        self.local.validate_commitment_fields(msg)?;
        let slot_end = &msg.commitment.preconf.submission_window_end;
        let expected_signer = self.resolver.signer_for_timestamp(slot_end)?;
        if recovered != expected_signer {
            return Err("unexpected signer for slot".into());
        }
        let expected_end = self.resolver.expected_slot_end(slot_end)?;
        if &expected_end != slot_end {
            return Err("submissionWindowEnd mismatch".into());
        }

        Ok(())
    }

    /// Validate a raw txlist gossip message.
    fn validate_gossip_raw_txlist(
        &self,
        _from: &PeerId,
        msg: &RawTxListGossip,
    ) -> Result<(), String> {
        validate_raw_txlist_gossip(msg).map_err(|e| e.to_string())
    }

    /// Validate an inbound commitments response.
    fn validate_commitments_response(
        &self,
        from: &PeerId,
        resp: &GetCommitmentsByNumberResponse,
    ) -> Result<(), String> {
        validate_commitments_response(resp).map_err(|e| e.to_string())?;
        for commitment in resp.commitments.iter() {
            self.validate_gossip_commitment(from, commitment)?;
        }
        Ok(())
    }

    /// Validate an inbound raw txlist response.
    fn validate_raw_txlist_response(
        &self,
        _from: &PeerId,
        resp: &GetRawTxListResponse,
    ) -> Result<(), String> {
        validate_raw_txlist_response(resp).map_err(|e| e.to_string())
    }

    /// Validate an inbound head response (no validation currently required).
    fn validate_head_response(
        &self,
        _from: &PeerId,
        _resp: &preconfirmation_types::PreconfHead,
    ) -> Result<(), String> {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use preconfirmation_types::{
        Bytes20, PreconfCommitment, Preconfirmation, Uint256, sign_commitment,
    };
    use secp256k1::SecretKey;
    use ssz_rs::Vector;

    /// Helper to create a deterministic signed commitment for testing.
    fn sample_signed_commitment(slasher: Bytes20) -> SignedCommitment {
        let preconf = Preconfirmation {
            eop: false,
            block_number: Uint256::from(1u64),
            timestamp: Uint256::from(1u64),
            gas_limit: Uint256::from(1u64),
            coinbase: Vector::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(1u64),
            raw_tx_list_hash: Vector::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Vector::try_from(vec![2u8; 32]).unwrap(),
            submission_window_end: Uint256::from(1u64),
            prover_auth: Vector::try_from(vec![3u8; 20]).unwrap(),
            proposal_id: Uint256::from(4u64),
        };
        let commitment = PreconfCommitment { preconf, slasher_address: slasher };
        let sk = SecretKey::from_slice(&[9u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();
        SignedCommitment { commitment, signature: sig }
    }

    /// Accepts commitments when the slasher address matches expectation.
    #[test]
    fn slasher_address_enforced_when_expected() {
        let expected = Vector::try_from(vec![7u8; 20]).unwrap();
        let adapter = LocalValidationAdapter::new(Some(expected.clone()));
        let msg = sample_signed_commitment(expected);
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_ok());
    }

    /// Rejects commitments when the slasher address mismatches expectation.
    #[test]
    fn slasher_mismatch_rejected() {
        let expected = Vector::try_from(vec![7u8; 20]).unwrap();
        let adapter = LocalValidationAdapter::new(Some(expected.clone()));
        let wrong = Vector::try_from(vec![8u8; 20]).unwrap();
        let msg = sample_signed_commitment(wrong);
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_err());
    }

    /// Resolver that always returns a configured signer and slot end.
    struct AcceptResolver {
        /// Signer to return for all timestamps.
        signer: Address,
        /// Slot end to return for all timestamps.
        slot_end: Uint256,
    }
    impl LookaheadResolver for AcceptResolver {
        fn signer_for_timestamp(
            &self,
            _submission_window_end: &Uint256,
        ) -> Result<Address, String> {
            Ok(self.signer)
        }
        fn expected_slot_end(&self, _submission_window_end: &Uint256) -> Result<Uint256, String> {
            Ok(self.slot_end.clone())
        }
    }

    /// Resolver that rejects all lookups.
    struct RejectResolver;
    impl LookaheadResolver for RejectResolver {
        fn signer_for_timestamp(
            &self,
            _submission_window_end: &Uint256,
        ) -> Result<Address, String> {
            Err("rejected".into())
        }
        fn expected_slot_end(&self, _submission_window_end: &Uint256) -> Result<Uint256, String> {
            Err("rejected".into())
        }
    }

    /// Lookahead adapter accepts when resolver agrees with signer and slot.
    #[test]
    fn lookahead_adapter_delegates_ok() {
        let slasher = Vector::try_from(vec![7u8; 20]).unwrap();
        let msg = sample_signed_commitment(slasher.clone());
        let adapter = LookaheadValidationAdapter::new(
            Some(slasher.clone()),
            Arc::new(AcceptResolver {
                signer: preconfirmation_types::public_key_to_address(
                    &secp256k1::PublicKey::from_secret_key(
                        &secp256k1::Secp256k1::new(),
                        &SecretKey::from_slice(&[9u8; 32]).unwrap(),
                    ),
                ),
                slot_end: msg.commitment.preconf.submission_window_end.clone(),
            }),
        );
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_ok());
    }

    /// Lookahead adapter propagates resolver errors.
    #[test]
    fn lookahead_adapter_propagates_error() {
        let slasher = Vector::try_from(vec![7u8; 20]).unwrap();
        let msg = sample_signed_commitment(slasher.clone());
        let adapter = LookaheadValidationAdapter::new(Some(slasher), Arc::new(RejectResolver {}));
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_err());
    }

    /// Lookahead adapter rejects commitments signed by an unexpected signer.
    #[test]
    fn lookahead_rejects_wrong_signer() {
        let slasher = Vector::try_from(vec![7u8; 20]).unwrap();
        let msg = sample_signed_commitment(slasher.clone());
        let wrong_signer = alloy_primitives::Address::ZERO;
        let adapter = LookaheadValidationAdapter::new(
            Some(slasher),
            Arc::new(AcceptResolver {
                signer: wrong_signer,
                slot_end: msg.commitment.preconf.submission_window_end.clone(),
            }),
        );
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_err());
    }

    /// Lookahead adapter rejects when slot end differs from resolver expectation.
    #[test]
    fn lookahead_rejects_slot_end_mismatch() {
        let slasher = Vector::try_from(vec![7u8; 20]).unwrap();
        let mut msg = sample_signed_commitment(slasher.clone());
        msg.commitment.preconf.submission_window_end = Uint256::from(10u64);
        let adapter = LookaheadValidationAdapter::new(
            Some(slasher),
            Arc::new(AcceptResolver {
                signer: preconfirmation_types::public_key_to_address(
                    &secp256k1::PublicKey::from_secret_key(
                        &secp256k1::Secp256k1::new(),
                        &SecretKey::from_slice(&[9u8; 32]).unwrap(),
                    ),
                ),
                slot_end: Uint256::from(11u64),
            }),
        );
        assert!(adapter.validate_gossip_commitment(&PeerId::random(), &msg).is_err());
    }
}
