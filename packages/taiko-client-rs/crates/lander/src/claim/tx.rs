//! Local signing of ordinary L2 transactions and identical-byte-only rebroadcast.
use super::{ClaimIdentity, ClaimProof, source::rpc_error};
use crate::{
    LanderError, Result,
    tx::{LandingReceipt, MAX_TX_GAS, NonceState},
};
use alloy::signers::{Signer, local::PrivateKeySigner};
use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope, transaction::SignerRecoverable};
use alloy_eips::{
    BlockId, BlockNumberOrTag,
    eip2718::{Decodable2718, Encodable2718},
};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types::TransactionRequest;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// Durable ordinary L2 envelope, never regenerated after signing.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SignedClaim {
    /// Canonical signed EIP-1559 envelope.
    pub bytes: Bytes,
    /// Locally computed transaction hash.
    pub hash: B256,
    /// Single outstanding account nonce.
    pub nonce: u64,
}
impl SignedClaim {
    /// Recover the payer and bind all execution inputs to the journal's immutable proof.
    pub fn validate(&self, identity: &ClaimIdentity, proof: &ClaimProof) -> Result<()> {
        identity.validate_receipt(&proof.receipt)?;
        let mut remaining = self.bytes.as_ref();
        let envelope = TxEnvelope::decode_2718(&mut remaining)
            .map_err(|_| LanderError::Journal("invalid signed claim envelope".into()))?;
        if !remaining.is_empty() ||
            envelope.tx_hash() != &self.hash ||
            envelope
                .recover_signer()
                .map_err(|_| LanderError::Journal("invalid claim signature".into()))? !=
                identity.payer
        {
            return Err(LanderError::Journal("claim signature/hash/encoding mismatch".into()));
        }
        let TxEnvelope::Eip1559(signed) = envelope else {
            return Err(LanderError::Journal(
                "claim must be an ordinary EIP-1559 transaction".into(),
            ));
        };
        let tx = signed.tx();
        if tx.chain_id != identity.l2_chain_id ||
            tx.nonce != self.nonce ||
            tx.to != identity.vault.into() ||
            tx.value != U256::ZERO ||
            tx.input != proof.calldata()? ||
            tx.gas_limit == 0 ||
            tx.gas_limit > MAX_TX_GAS
        {
            return Err(LanderError::Journal("signed claim differs from immutable job".into()));
        }
        Ok(())
    }
}

/// Separate signing and transport boundary, permitting durable intent before broadcast.
#[async_trait]
pub trait ClaimTransport: Send + Sync {
    /// Estimate and sign locally; never submit here.
    async fn sign(&self, identity: &ClaimIdentity, proof: &ClaimProof) -> Result<SignedClaim>;
    /// Execute the original signed inputs at an exact canonical snapshot without sending.
    async fn simulate(&self, tx: &SignedClaim, hash: B256) -> Result<()>;
    /// Send only the original persisted bytes.
    async fn broadcast(&self, tx: &SignedClaim) -> Result<()>;
    /// Return the exact transaction's mined receipt, if currently indexed.
    async fn receipt(&self, hash: B256) -> Result<Option<LandingReceipt>>;
    /// Whether this exact signed transaction is known to the endpoint.
    async fn known(&self, hash: B256) -> Result<bool>;
    /// Read confirmed and pending nonces before signing or rebroadcast.
    async fn nonce(&self) -> Result<NonceState>;
    /// Pin confirmed nonce to the canonical snapshot; pending remains advisory.
    async fn nonce_at(&self, hash: B256) -> Result<NonceState>;
}

/// Own L2 provider and explicit gas payer; key material is neither Debug nor serialized.
pub struct RpcClaimTransport {
    /// Own L2 endpoint with configured HTTP deadline.
    provider: RootProvider,
    /// Explicit local gas payer, independent of reward recipient.
    signer: PrivateKeySigner,
}
impl RpcClaimTransport {
    /// Construct without reading proof or mutating chain state.
    pub fn new(provider: RootProvider, signer: PrivateKeySigner) -> Self {
        Self { provider, signer }
    }
    /// Public payer identity for binding the store.
    pub fn payer(&self) -> Address {
        self.signer.address()
    }
}
#[async_trait]
impl ClaimTransport for RpcClaimTransport {
    /// Use current fee estimates once; enforce no outstanding nonce and the EIP-7825 gas cap.
    async fn sign(&self, identity: &ClaimIdentity, proof: &ClaimProof) -> Result<SignedClaim> {
        identity.validate_receipt(&proof.receipt)?;
        if identity.payer != self.payer() ||
            self.provider.get_chain_id().await.map_err(rpc_error)? != identity.l2_chain_id
        {
            return Err(LanderError::Safety("claim signer or L2 chain mismatch".into()));
        }
        let nonce = self.nonce().await?;
        if nonce.pending < nonce.confirmed {
            return Err(LanderError::Unavailable("payer nonce view changed before signing".into()));
        }
        if nonce.pending != nonce.confirmed {
            return Err(LanderError::Unavailable(
                "payer has an outstanding transaction; refusing a new nonce".into(),
            ));
        }
        let fees = self.provider.estimate_eip1559_fees().await.map_err(rpc_error)?;
        let mut tx = TxEip1559 {
            chain_id: identity.l2_chain_id,
            nonce: nonce.confirmed,
            to: identity.vault.into(),
            value: U256::ZERO,
            input: proof.calldata()?,
            max_fee_per_gas: fees.max_fee_per_gas,
            max_priority_fee_per_gas: fees.max_priority_fee_per_gas,
            ..Default::default()
        };
        let mut request = TransactionRequest::from_transaction(tx.clone()).from(self.payer());
        request.gas = None;
        let gas = self.provider.estimate_gas(request).await.map_err(vault_error)?;
        if gas == 0 || gas > MAX_TX_GAS {
            return Err(LanderError::Configuration(
                "claim gas estimate outside EIP-7825 bounds".into(),
            ));
        }
        tx.gas_limit = gas.saturating_add(gas.div_ceil(5)).min(MAX_TX_GAS);
        let signature = self
            .signer
            .sign_hash(&tx.signature_hash())
            .await
            .map_err(|_| LanderError::Configuration("local claim signing failed".into()))?;
        let signed = tx.into_signed(signature);
        let result = SignedClaim {
            hash: *signed.hash(),
            nonce: nonce.confirmed,
            bytes: TxEnvelope::Eip1559(signed).encoded_2718().into(),
        };
        result.validate(identity, proof)?;
        Ok(result)
    }
    /// Preserve the signed sender, calldata, gas, nonce and fees in a hash-pinned eth_call.
    async fn simulate(&self, tx: &SignedClaim, hash: B256) -> Result<()> {
        let mut remaining = tx.bytes.as_ref();
        let envelope = TxEnvelope::decode_2718(&mut remaining)
            .map_err(|_| LanderError::Journal("invalid signed claim envelope".into()))?;
        if !remaining.is_empty() ||
            envelope.tx_hash() != &tx.hash ||
            envelope
                .recover_signer()
                .map_err(|_| LanderError::Journal("invalid claim signature".into()))? !=
                self.payer()
        {
            return Err(LanderError::Journal(
                "claim simulation signature/hash/encoding mismatch".into(),
            ));
        }
        let request = TransactionRequest::from_transaction(envelope).from(self.payer());
        let output = self
            .provider
            .call(request)
            .block(BlockId::hash_canonical(hash))
            .await
            .map_err(vault_error)?;
        if !output.is_empty() {
            return Err(LanderError::Safety("claim simulation returned unexpected data".into()));
        }
        Ok(())
    }
    /// An ambiguous send is reported without replacing the original nonce or bytes.
    async fn broadcast(&self, tx: &SignedClaim) -> Result<()> {
        let pending = self.provider.send_raw_transaction(&tx.bytes).await.map_err(rpc_error)?;
        if *pending.tx_hash() != tx.hash {
            return Err(LanderError::Safety("claim broadcast returned another hash".into()));
        }
        Ok(())
    }
    /// Require mined block context, while leaving canonicality to the source and runner.
    async fn receipt(&self, hash: B256) -> Result<Option<LandingReceipt>> {
        self.provider
            .get_transaction_receipt(hash)
            .await
            .map_err(rpc_error)?
            .map(|r| {
                if r.transaction_hash != hash {
                    return Err(LanderError::Safety("claim receipt hash mismatch".into()));
                }
                Ok(LandingReceipt {
                    transaction_hash: r.transaction_hash,
                    block_number: r.block_number.ok_or_else(|| {
                        LanderError::Safety("claim receipt missing height".into())
                    })?,
                    block_hash: r.block_hash.ok_or_else(|| {
                        LanderError::Safety("claim receipt missing block hash".into())
                    })?,
                    success: r.status(),
                    gas_used: r.gas_used,
                })
            })
            .transpose()
    }
    /// An RPC response about another transaction cannot authorize a wait or retransmission.
    async fn known(&self, hash: B256) -> Result<bool> {
        let tx = self.provider.get_transaction_by_hash(hash).await.map_err(rpc_error)?;
        if tx.as_ref().is_some_and(|tx| tx.inner.tx_hash() != &hash) {
            return Err(LanderError::Safety("claim lookup returned another transaction".into()));
        }
        Ok(tx.is_some())
    }
    /// Read confirmed nonce at the caller's exact canonical snapshot before pending state.
    async fn nonce_at(&self, hash: B256) -> Result<NonceState> {
        let confirmed = self
            .provider
            .get_transaction_count(self.payer())
            .block_id(BlockId::hash_canonical(hash))
            .await
            .map_err(rpc_error)?;
        let pending =
            self.provider.get_transaction_count(self.payer()).pending().await.map_err(rpc_error)?;
        Ok(NonceState { confirmed, pending })
    }
    /// Preserve confirmed/pending disagreement for the runner's conservative decisions.
    async fn nonce(&self) -> Result<NonceState> {
        let confirmed = self
            .provider
            .get_transaction_count(self.payer())
            .block_id(BlockNumberOrTag::Latest.into())
            .await
            .map_err(rpc_error)?;
        let pending =
            self.provider.get_transaction_count(self.payer()).pending().await.map_err(rpc_error)?;
        Ok(NonceState { confirmed, pending })
    }
}

/// Known zero-argument vault errors; only structured revert bytes can select these labels.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum VaultFailure {
    /// Another payer may have won; canonical claimed state is still required.
    #[error("vault AlreadyClaimed")]
    AlreadyClaimed,
    /// Unsigned preparation may acquire a current root.
    #[error("vault InvalidAnchorRoot")]
    InvalidAnchorRoot,
    /// Either insufficient balance or a rejecting immutable recipient needs operator review.
    #[error("vault RewardTransferFailed; inspect vault balance and immutable recipient acceptance")]
    RewardTransferFailed,
    /// Unknown or malformed execution revert, intentionally opaque.
    #[error("opaque vault execution revert")]
    Unknown,
}
impl VaultFailure {
    /// Decode only exact generated zero-argument selectors, never arbitrary message text.
    fn decode(bytes: &[u8]) -> Self {
        use alloy::sol_types::SolError;
        match bytes {
            b if b == super::Vault::AlreadyClaimed::SELECTOR => Self::AlreadyClaimed,
            b if b == super::Vault::InvalidAnchorRoot::SELECTOR => Self::InvalidAnchorRoot,
            b if b == super::Vault::RewardTransferFailed::SELECTOR => Self::RewardTransferFailed,
            _ => Self::Unknown,
        }
    }
    /// Recognize only our typed adapter label from estimation or simulation.
    pub(super) fn is_already_claimed(error: &LanderError) -> bool {
        matches!(error, LanderError::ClaimReverted(Self::AlreadyClaimed))
    }
    /// Provide safe actionable diagnostics without echoing untrusted payloads.
    fn error(self) -> LanderError {
        match self {
            Self::InvalidAnchorRoot => LanderError::Unavailable(
                "vault InvalidAnchorRoot; anchor root is unavailable or expired".into(),
            ),
            _ => LanderError::ClaimReverted(self),
        }
    }
}
/// Apply vault-specific classification only to estimate/simulation responses.
fn vault_error(error: alloy::transports::TransportError) -> LanderError {
    if let alloy::transports::RpcError::ErrorResp(payload) = &error &&
        payload.code == 3
    {
        let bytes =
            payload.data.as_ref().and_then(|raw| serde_json::from_str::<Bytes>(raw.get()).ok());
        return bytes.map_or(VaultFailure::Unknown, |b| VaultFailure::decode(&b)).error();
    }
    rpc_error(error)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::sol_types::SolError;
    use serde_json::json;

    fn error(data: serde_json::Value) -> alloy::transports::TransportError {
        alloy::transports::RpcError::ErrorResp(serde_json::from_value(json!({
            "code":3,"message":"https://secret-user:secret-password@rpc/secret-path?key=secret-token", "data":data
        })).unwrap())
    }

    #[test]
    fn vault_selectors_are_exact_typed_and_redacted() {
        for (selector, label, retryable) in [
            (super::super::Vault::AlreadyClaimed::SELECTOR, "AlreadyClaimed", false),
            (super::super::Vault::InvalidAnchorRoot::SELECTOR, "InvalidAnchorRoot", true),
            (super::super::Vault::RewardTransferFailed::SELECTOR, "RewardTransferFailed", false),
        ] {
            let result = vault_error(error(json!(Bytes::copy_from_slice(&selector))));
            assert!(result.to_string().contains(label));
            assert_eq!(result.is_retryable(), retryable);
            assert!(!format!("{result:?}").contains("secret-"));
            let mut malformed = selector.to_vec();
            malformed.push(0);
            assert!(
                vault_error(error(json!(Bytes::from(malformed)))).to_string().contains("opaque")
            );
        }
        for data in [
            json!("secret-password"),
            json!("0x12345678"),
            json!({"message":"AlreadyClaimed secret-token"}),
            json!(null),
        ] {
            let result = vault_error(error(data));
            assert!(!VaultFailure::is_already_claimed(&result));
            assert!(!result.is_retryable());
            assert!(result.to_string().contains("opaque"));
            assert!(!format!("{result:?}").contains("secret-"));
        }
    }

    #[test]
    fn generic_source_errors_do_not_decode_vault_selectors_and_capabilities_stop() {
        let result = rpc_error(error(json!(Bytes::copy_from_slice(
            &super::super::Vault::AlreadyClaimed::SELECTOR
        ))));
        assert!(!VaultFailure::is_already_claimed(&result));
        for code in [-32600, -32601, -32602] {
            let result = rpc_error(alloy::transports::RpcError::ErrorResp(
                serde_json::from_value(json!({"code":code,"message":"secret-token"})).unwrap(),
            ));
            assert!(matches!(result, LanderError::Configuration(_)));
            assert!(!result.to_string().contains("secret"));
        }
    }
}
