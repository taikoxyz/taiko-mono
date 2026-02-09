use alloy_primitives::B256;
use alloy_provider::Provider;

use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, block_signing_hash, recover_signer,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
};

use super::{
    WhitelistPreconfirmationImporter,
    validation::{normalize_unsafe_payload_envelope, validate_execution_payload_for_preconf},
};

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Handle an incoming unsafe payload.
    pub(super) async fn handle_unsafe_payload(
        &mut self,
        payload: DecodedUnsafePayload,
    ) -> Result<()> {
        let prehash = block_signing_hash(self.chain_id, payload.payload_bytes.as_slice());
        let signer = recover_signer(prehash, &payload.wire_signature)?;
        self.ensure_signer_allowed(signer).await?;

        let envelope = normalize_unsafe_payload_envelope(payload.envelope, payload.wire_signature);
        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent(envelope);

        Ok(())
    }

    /// Handle an incoming unsafe response.
    pub(super) async fn handle_unsafe_response(
        &mut self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) -> Result<()> {
        let Some(signature) = envelope.signature else {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(
                "response payload is missing embedded signature".to_string(),
            ));
        };

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = recover_signer(prehash, &signature)?;
        self.ensure_signer_allowed(signer).await?;

        validate_execution_payload_for_preconf(
            &envelope.execution_payload,
            self.chain_id,
            self.anchor_address,
        )?;
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent(envelope);
        Ok(())
    }

    /// Handle a block-hash request from the request topic.
    pub(super) async fn handle_unsafe_request(
        &mut self,
        from: libp2p::PeerId,
        hash: B256,
    ) -> Result<()> {
        if let Some(envelope) = self.recent_cache.get_recent(&hash) {
            tracing::debug!(
                peer = %from,
                hash = %hash,
                "serving whitelist preconfirmation response from recent cache"
            );
            self.recent_cache.insert_recent(envelope.clone());
            self.publish_unsafe_response(envelope).await;
            return Ok(());
        }

        let Some(envelope) = self.build_response_envelope_from_l2(hash).await? else {
            tracing::debug!(
                peer = %from,
                hash = %hash,
                "requested whitelist preconfirmation hash not found in recent cache or local l2"
            );
            return Ok(());
        };

        tracing::debug!(
            peer = %from,
            hash = %hash,
            "serving whitelist preconfirmation response from local l2 block lookup"
        );
        self.recent_cache.insert_recent(envelope.clone());
        self.publish_unsafe_response(envelope).await;
        Ok(())
    }
}
