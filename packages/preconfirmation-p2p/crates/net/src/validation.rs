//! Validation adapter for gossip and req/resp payloads.
//!
//! This indirection makes it straightforward to swap in an upstream validator (e.g., from
//! Kona/Lighthouse) without changing the driver/service API. The default implementation delegates
//! to the existing local validators in `preconfirmation_types`.
//!
//! Upstream expectations: a replacement should implement `ValidationAdapter` for the three
//! req/resp protocols (commitments/raw txlist/head) plus the two gossip payloads. Validation is
//! expected to be deterministic, inexpensive, and side-effect free (no async). If an upstream
//! module is added later, wire it in by constructing the adapter in the driver instead of
//! `LocalValidationAdapter`; no public API changes are required.

use libp2p::PeerId;

use preconfirmation_types::{
    GetCommitmentsByNumberResponse, GetRawTxListResponse, RawTxListGossip, SignedCommitment,
    validate_commitments_response, validate_head_response, validate_raw_txlist_gossip,
    validate_raw_txlist_response, verify_signed_commitment,
};

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
pub struct LocalValidationAdapter;

impl ValidationAdapter for LocalValidationAdapter {
    fn validate_gossip_commitment(
        &self,
        _from: &PeerId,
        msg: &SignedCommitment,
    ) -> Result<(), String> {
        verify_signed_commitment(msg).map(|_| ()).map_err(|e| e.to_string())
    }

    fn validate_gossip_raw_txlist(
        &self,
        _from: &PeerId,
        msg: &RawTxListGossip,
    ) -> Result<(), String> {
        validate_raw_txlist_gossip(msg).map_err(|e| e.to_string())
    }

    fn validate_commitments_response(
        &self,
        _from: &PeerId,
        resp: &GetCommitmentsByNumberResponse,
    ) -> Result<(), String> {
        validate_commitments_response(resp).map_err(|e| e.to_string())
    }

    fn validate_raw_txlist_response(
        &self,
        _from: &PeerId,
        resp: &GetRawTxListResponse,
    ) -> Result<(), String> {
        validate_raw_txlist_response(resp).map_err(|e| e.to_string())
    }

    fn validate_head_response(
        &self,
        _from: &PeerId,
        resp: &preconfirmation_types::PreconfHead,
    ) -> Result<(), String> {
        validate_head_response(resp).map_err(|e| e.to_string())
    }
}
