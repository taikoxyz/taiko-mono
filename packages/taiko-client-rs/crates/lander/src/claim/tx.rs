//! Local signing of ordinary L2 transactions and identical-byte-only rebroadcast.
use super::{ClaimIdentity, ClaimProof, source::rpc_error};
use crate::{
    LanderError, Result,
    tx::{LandingReceipt, MAX_TX_GAS, NonceState},
};
use alloy::signers::{Signer, local::PrivateKeySigner};
use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope, transaction::SignerRecoverable};
use alloy_eips::{
    BlockNumberOrTag,
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
    /// Send only the original persisted bytes.
    async fn broadcast(&self, tx: &SignedClaim) -> Result<()>;
    /// Return the exact transaction's mined receipt, if currently indexed.
    async fn receipt(&self, hash: B256) -> Result<Option<LandingReceipt>>;
    /// Whether this exact signed transaction is known to the endpoint.
    async fn known(&self, hash: B256) -> Result<bool>;
    /// Read confirmed and pending nonces before signing or rebroadcast.
    async fn nonce(&self) -> Result<NonceState>;
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
        nonce.validate()?;
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
        let gas = self.provider.estimate_gas(request).await.map_err(rpc_error)?;
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
