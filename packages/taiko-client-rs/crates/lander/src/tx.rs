//! Explicit signing and identical-byte blob transaction transport, without automatic replacement.

use std::{io::Read, path::Path};

use alloy::{
    signers::{Signer, local::PrivateKeySigner},
    sol_types::{SolCall, SolError},
};
use alloy_consensus::{
    SignableTransaction, Transaction, TxEip4844, TxEip4844Variant, TxEip4844WithSidecar,
    TxEnvelope, transaction::SignerRecoverable,
};
use alloy_eips::{
    BlockNumberOrTag,
    eip2718::{Decodable2718, Encodable2718},
};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types::TransactionRequest;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::{
    contracts::{IEtnaInbox::landCall, ZeroFeeRecipient},
    error::{LanderError, Result, sanitized_rpc_error},
    proof::ProofRequest,
};

/// Explicit operator fee ceilings, all denominated in wei per gas unit.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeeCaps {
    /// Execution base plus priority fee cap.
    pub max_fee_per_gas: u128,
    /// Priority fee cap; must not exceed the execution cap.
    pub max_priority_fee_per_gas: u128,
    /// Blob data gas fee cap.
    pub max_fee_per_blob_gas: u128,
}

impl FeeCaps {
    /// Validate before loading a key or signing a transaction.
    pub fn validate(&self) -> Result<()> {
        if self.max_fee_per_gas == 0 ||
            self.max_priority_fee_per_gas == 0 ||
            self.max_fee_per_blob_gas == 0 ||
            self.max_priority_fee_per_gas > self.max_fee_per_gas
        {
            return Err(LanderError::Configuration(
                "nonzero fee caps and priority <= execution cap are required".into(),
            ));
        }
        Ok(())
    }
}

/// Complete signed network bytes, including the sidecar, durable before any network mutation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SignedTransaction {
    /// Canonical network envelope, including EIP-4844 or EIP-7594 sidecar.
    pub network_bytes: Bytes,
    /// Transaction hash (the sidecar is outside the hash preimage).
    pub hash: B256,
    /// Recovered sender, checked against configured signer during journal resume.
    pub sender: Address,
    /// The single outstanding signing-account nonce.
    pub nonce: u64,
}

impl SignedTransaction {
    /// Decode and bind every signed input and sidecar to the journal's immutable job.
    pub fn validate(&self, request: &ProofRequest, proof: &Bytes) -> Result<()> {
        let mut remaining = self.network_bytes.as_ref();
        let envelope = TxEnvelope::decode_2718(&mut remaining)
            .map_err(|e| LanderError::Journal(format!("signed envelope: {e}")))?;
        if !remaining.is_empty() ||
            envelope.tx_hash() != &self.hash ||
            envelope
                .recover_signer()
                .map_err(|e| LanderError::Journal(format!("transaction signature: {e}")))? !=
                self.sender
        {
            return Err(LanderError::Journal(
                "signed transaction hash/sender/encoding mismatch".into(),
            ));
        }
        let TxEnvelope::Eip4844(signed) = envelope else {
            return Err(LanderError::Journal(
                "journal transaction is not a blob transaction".into(),
            ));
        };
        let variant = signed.tx();
        let batch = &request.batch;
        let chain_id = u64::try_from(batch.snapshot.l1_chain_id)
            .map_err(|_| LanderError::Configuration("L1 chain id exceeds signing format".into()))?;
        let call = landCall { _input: batch.input.clone(), _proof: proof.clone() }.abi_encode();
        if variant.chain_id() != Some(chain_id) ||
            variant.nonce() != self.nonce ||
            variant.to() != Some(batch.snapshot.inbox) ||
            variant.value() != U256::ZERO ||
            variant.input().as_ref() != call ||
            variant.blob_versioned_hashes() != Some(batch.blobs.versioned_hashes.as_slice()) ||
            variant.sidecar() != Some(&batch.blobs.sidecar)
        {
            return Err(LanderError::Journal(
                "signed transaction differs from immutable job".into(),
            ));
        }
        batch
            .blobs
            .sidecar
            .validate(
                &batch.blobs.versioned_hashes,
                alloy_eips::eip4844::env_settings::EnvKzgSettings::Default.get(),
            )
            .map_err(|e| LanderError::Journal(format!("signed sidecar: {e}")))?;
        Ok(())
    }
}

/// Minimal receipt context, always checked against the canonical block hash by the runner.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct LandingReceipt {
    /// The submitted transaction hash.
    pub transaction_hash: B256,
    /// Number of the block containing the receipt.
    pub block_number: u64,
    /// Hash of the block containing the receipt.
    pub block_hash: B256,
    /// Whether execution succeeded rather than reverted.
    pub success: bool,
}

/// Account nonce view; both values are read before deciding whether identical rebroadcast is safe.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct NonceState {
    /// Next nonce after canonical mined transactions.
    pub confirmed: u64,
    /// Next nonce after the provider's pending transactions.
    pub pending: u64,
}

impl NonceState {
    /// Reject a lagging pending view before it can authorize signing or identical rebroadcast.
    pub(crate) fn validate(&self) -> Result<()> {
        if self.pending < self.confirmed {
            return Err(LanderError::Temporary(format!(
                "pending account nonce {} is below confirmed nonce {}; retry coherent nonce reads",
                self.pending, self.confirmed
            )));
        }
        Ok(())
    }
}

/// Stateful transaction boundary whose sign method never broadcasts.
#[async_trait]
pub trait TransactionTransport: Send + Sync {
    /// Configured signing identity; private material is never exposed.
    fn sender(&self) -> Address;
    /// Estimate, reserve rounded-up 20% execution gas, and sign with the pending nonce without
    /// submitting.
    async fn sign(&self, request: &ProofRequest, proof: &Bytes) -> Result<SignedTransaction>;
    /// Submit the already-persisted network bytes; no filling, replacement, or signing occurs.
    async fn broadcast(&self, transaction: &SignedTransaction) -> Result<B256>;
    /// Lookup a mined receipt; absence is not proof that a transaction was never broadcast.
    async fn receipt(&self, hash: B256) -> Result<Option<LandingReceipt>>;
    /// Whether the endpoint currently knows this exact transaction.
    async fn known(&self, hash: B256) -> Result<bool>;
    /// Read latest and pending nonce state for the configured sender.
    async fn nonce_state(&self) -> Result<NonceState>;
}

/// Alloy RPC transport with a locally loaded key; there is no wallet transaction filler.
#[derive(Clone)]
pub struct RpcTransactionTransport {
    /// Public L1 provider with caller-configured HTTP deadline.
    provider: RootProvider,
    /// Secret signer; never part of a journal or debug output.
    signer: PrivateKeySigner,
    /// Explicit operator fee caps, used without guessing a fee policy.
    fees: FeeCaps,
}

impl RpcTransactionTransport {
    /// Construct a transport after validating the fee policy.
    pub fn new(provider: RootProvider, signer: PrivateKeySigner, fees: FeeCaps) -> Result<Self> {
        fees.validate()?;
        Ok(Self { provider, signer, fees })
    }

    /// Read a bounded hex key file; parser failures never render the key bytes.
    pub fn signer_from_file(path: &Path) -> Result<PrivateKeySigner> {
        let file = std::fs::File::open(path).map_err(|e| {
            LanderError::Configuration(format!("cannot read signing key file: {e}"))
        })?;
        let mut text = String::new();
        file.take(257).read_to_string(&mut text).map_err(|_| {
            LanderError::Configuration("signing key file must contain UTF-8 hex".into())
        })?;
        if text.len() > 256 {
            return Err(LanderError::Configuration("signing key file is too large".into()));
        }
        text.trim()
            .parse()
            .map_err(|_| LanderError::Configuration("invalid hex signing key file".into()))
    }
}

#[async_trait]
impl TransactionTransport for RpcTransactionTransport {
    fn sender(&self) -> Address {
        self.signer.address()
    }

    async fn sign(&self, request: &ProofRequest, proof: &Bytes) -> Result<SignedTransaction> {
        let batch = &request.batch;
        let chain_id = self.provider.get_chain_id().await.map_err(rpc_error)?;
        if U256::from(chain_id) != batch.snapshot.l1_chain_id {
            return Err(LanderError::Configuration(
                "signing RPC chain id differs from prepared job".into(),
            ));
        }
        let nonce = self.nonce_state().await?;
        nonce.validate()?;
        let nonce = nonce.pending;
        let input: Bytes =
            landCall { _input: batch.input.clone(), _proof: proof.clone() }.abi_encode().into();
        let mut tx = TxEip4844 {
            chain_id,
            nonce,
            gas_limit: 0,
            max_fee_per_gas: self.fees.max_fee_per_gas,
            max_priority_fee_per_gas: self.fees.max_priority_fee_per_gas,
            to: batch.snapshot.inbox,
            value: U256::ZERO,
            access_list: Default::default(),
            blob_versioned_hashes: batch.blobs.versioned_hashes.clone(),
            max_fee_per_blob_gas: self.fees.max_fee_per_blob_gas,
            input,
        };
        let mut estimate = TransactionRequest::from_transaction(tx.clone()).from(self.sender());
        // Zero denotes the as-yet-unfilled signed limit, not a valid estimation ceiling.
        estimate.gas = None;
        let estimated = self.provider.estimate_gas(estimate).await.map_err(estimate_error)?;
        tx.gas_limit = gas_limit_with_headroom(estimated)?;
        let variant: TxEip4844Variant =
            TxEip4844WithSidecar::from_tx_and_sidecar(tx, batch.blobs.sidecar.clone()).into();
        let signature =
            self.signer.sign_hash(&variant.signature_hash()).await.map_err(|_| {
                LanderError::Configuration("local transaction signing failed".into())
            })?;
        let signed = variant.into_signed(signature);
        let hash = *signed.hash();
        let network_bytes = TxEnvelope::Eip4844(signed).encoded_2718().into();
        let transaction = SignedTransaction { network_bytes, hash, sender: self.sender(), nonce };
        transaction.validate(request, proof)?;
        Ok(transaction)
    }

    async fn broadcast(&self, transaction: &SignedTransaction) -> Result<B256> {
        match self.provider.send_raw_transaction(&transaction.network_bytes).await {
            Ok(pending) => {
                let hash = *pending.tx_hash();
                if hash != transaction.hash {
                    return Err(LanderError::Safety(
                        "RPC broadcast returned a different transaction hash".into(),
                    ));
                }
                Ok(hash)
            }
            Err(error) => {
                let duplicate = error
                    .as_error_resp()
                    .is_some_and(|payload| is_known_response(&payload.message));
                if duplicate && self.known(transaction.hash).await? {
                    Ok(transaction.hash)
                } else {
                    Err(rpc_error(error))
                }
            }
        }
    }

    async fn receipt(&self, hash: B256) -> Result<Option<LandingReceipt>> {
        self.provider
            .get_transaction_receipt(hash)
            .await
            .map_err(rpc_error)?
            .map(|receipt| {
                Ok(LandingReceipt {
                    transaction_hash: receipt.transaction_hash,
                    block_number: receipt.block_number.ok_or_else(|| {
                        LanderError::Safety("mined receipt lacks block number".into())
                    })?,
                    block_hash: receipt.block_hash.ok_or_else(|| {
                        LanderError::Safety("mined receipt lacks block hash".into())
                    })?,
                    success: receipt.status(),
                })
            })
            .transpose()
    }

    async fn known(&self, hash: B256) -> Result<bool> {
        let transaction = self.provider.get_transaction_by_hash(hash).await.map_err(rpc_error)?;
        if transaction.as_ref().is_some_and(|transaction| transaction.inner.tx_hash() != &hash) {
            return Err(LanderError::Safety("transaction lookup returned a different hash".into()));
        }
        Ok(transaction.is_some())
    }

    async fn nonce_state(&self) -> Result<NonceState> {
        let confirmed = self
            .provider
            .get_transaction_count(self.sender())
            .block_id(BlockNumberOrTag::Latest.into())
            .await
            .map_err(rpc_error)?;
        let pending = self
            .provider
            .get_transaction_count(self.sender())
            .pending()
            .await
            .map_err(rpc_error)?;
        Ok(NonceState { confirmed, pending })
    }
}

/// Reserve rounded-up 20% execution gas for state changes between estimation and inclusion.
///
/// In particular, aging a reference past the BLOCKHASH window makes the Inbox use EIP-2935.
/// Fee caps remain explicit and unchanged; once signed, these bytes are never replaced.
fn gas_limit_with_headroom(estimated: u64) -> Result<u64> {
    if estimated == 0 {
        return Err(LanderError::Safety("RPC gas estimate is zero".into()));
    }
    let headroom = estimated.div_ceil(5);
    estimated.checked_add(headroom).ok_or_else(|| {
        LanderError::Safety("RPC gas estimate plus 20% headroom overflows u64".into())
    })
}

/// Recognize idempotent duplicate submission without treating an unknown transaction as known.
fn is_known_response(message: &str) -> bool {
    let lower = message.trim().to_ascii_lowercase();
    ["already known", "known transaction", "transaction already imported"].iter().any(|prefix| {
        lower
            .strip_prefix(prefix)
            .is_some_and(|rest| rest.is_empty() || rest.starts_with(':') || rest.starts_with(' '))
    })
}

/// Distinguish an executed land revert from transient RPC failure before any signature exists.
///
/// The Inbox's `ZeroFeeRecipient` revert is a [`LanderError::Configuration`] error: the lander
/// built the input with a zero recipient, which no retry or refresh changes.
fn estimate_error(error: alloy::transports::TransportError) -> LanderError {
    if let Some(payload) = error.as_error_resp() {
        if payload
            .as_revert_data()
            .is_some_and(|data| data.starts_with(&ZeroFeeRecipient::SELECTOR))
        {
            return LanderError::Configuration(format!(
                "the Inbox rejected the landing's zero fee recipient (ZeroFeeRecipient; RPC code {})",
                payload.code
            ));
        }
        let lower = payload.message.to_ascii_lowercase();
        if payload.code == 3 ||
            lower.starts_with("execution reverted") ||
            payload.as_revert_data().is_some()
        {
            return LanderError::Reverted(format!(
                "gas estimation rejected land (RPC code {}); verify the proof and batch settings before restarting",
                payload.code
            ));
        }
        if matches!(payload.code, -32601 | -32602) {
            return LanderError::Configuration(format!(
                "gas estimation RPC is unsupported or rejected its parameters (RPC code {})",
                payload.code
            ));
        }
    }
    rpc_error(error)
}

/// An uncertain transport outcome is retryable only after receipt/nonce reconciliation.
fn rpc_error(error: alloy::transports::TransportError) -> LanderError {
    sanitized_rpc_error("transaction RPC", error)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::runtime::{request, signed};
    #[tokio::test]
    async fn signed_network_envelope_binds_every_job_input_and_exact_dummy_byte() {
        let request = request();
        let proof = Bytes::from_static(&[0]);
        let transaction = signed(&request, &proof, 4).await;
        transaction.validate(&request, &proof).unwrap();
        assert!(transaction.validate(&request, &Bytes::new()).is_err());
        let mut other = request.clone();
        other.batch.snapshot.inbox = Address::repeat_byte(99);
        assert!(transaction.validate(&other, &proof).is_err());
        other = request.clone();
        other.batch.snapshot.l1_chain_id += U256::from(1);
        assert!(transaction.validate(&other, &proof).is_err());
        other = request.clone();
        other.batch.blobs.versioned_hashes[0] = B256::repeat_byte(1);
        assert!(transaction.validate(&other, &proof).is_err());
        let mut corrupted = transaction.clone();
        corrupted.nonce += 1;
        assert!(corrupted.validate(&request, &proof).is_err());
        corrupted = transaction.clone();
        corrupted.sender = Address::repeat_byte(1);
        assert!(corrupted.validate(&request, &proof).is_err());
        corrupted = transaction.clone();
        corrupted.hash = B256::ZERO;
        assert!(corrupted.validate(&request, &proof).is_err());
        corrupted = transaction.clone();
        let mut bytes = corrupted.network_bytes.to_vec();
        bytes.push(0);
        corrupted.network_bytes = bytes.into();
        assert!(corrupted.validate(&request, &proof).is_err());
    }
    #[tokio::test]
    async fn both_sidecar_modes_have_the_same_signed_transaction_hash_and_exact_network_binding() {
        let old = request();
        let proof = Bytes::from_static(&[0]);
        let mut new = old.clone();
        let limits = crate::test_utils::runtime::limits();
        let payload = crate::blob::decode(old.batch.blobs.sidecar.blobs(), &limits).unwrap();
        new.batch.blobs =
            crate::blob::build(&payload, &limits, crate::SidecarMode::Eip7594).unwrap();
        assert_eq!(old.batch.blobs.versioned_hashes, new.batch.blobs.versioned_hashes);
        let old_transaction = signed(&old, &proof, 4).await;
        let new_transaction = signed(&new, &proof, 4).await;
        old_transaction.validate(&old, &proof).unwrap();
        new_transaction.validate(&new, &proof).unwrap();
        assert_eq!(old_transaction.hash, new_transaction.hash);
        assert_ne!(old_transaction.network_bytes, new_transaction.network_bytes);
        assert!(new_transaction.validate(&old, &proof).is_err());
    }

    #[test]
    fn gas_headroom_rounds_up_at_minimum_and_rejects_zero_or_overflow() {
        for (estimated, reserved) in [(1, 2), (4, 5), (5, 6), (6, 8), (500_000, 600_000)] {
            assert_eq!(gas_limit_with_headroom(estimated).unwrap(), reserved);
        }
        assert!(matches!(gas_limit_with_headroom(0), Err(LanderError::Safety(_))));
        let maximal = u64::try_from(u128::from(u64::MAX) * 5 / 6).unwrap();
        assert_eq!(gas_limit_with_headroom(maximal).unwrap(), u64::MAX);
        assert!(matches!(gas_limit_with_headroom(maximal + 1), Err(LanderError::Safety(_))));
        assert!(matches!(gas_limit_with_headroom(u64::MAX), Err(LanderError::Safety(_))));
    }

    #[tokio::test]
    async fn rpc_signing_uses_pending_nonce_and_an_unbounded_gas_estimate_before_filling() {
        use serde_json::json;
        for (quote, expected) in
            [(500_000u64, Some(600_000u64)), (1, Some(2)), (0, None), (u64::MAX, None)]
        {
            let provider =
                crate::l1::tests::rpc(move |request| match request["method"].as_str().unwrap() {
                    "eth_chainId" => json!("0x1"),
                    "eth_getTransactionCount" => {
                        assert!(matches!(
                            request["params"][1].as_str(),
                            Some("latest" | "pending")
                        ));
                        json!("0x7")
                    }
                    "eth_estimateGas" => {
                        let gas = &request["params"][0]["gas"];
                        if gas == "0x0" {
                            json!({"__rpc_error":{"code":-32000,"message":"intrinsic gas too low"}})
                        } else {
                            assert!(gas.is_null());
                            json!(format!("0x{quote:x}"))
                        }
                    }
                    method => panic!("unexpected signing method {method}"),
                })
                .await;
            let fees = FeeCaps {
                max_fee_per_gas: 5,
                max_priority_fee_per_gas: 2,
                max_fee_per_blob_gas: 10,
            };
            let transport = RpcTransactionTransport::new(
                provider.provider.clone(),
                crate::test_utils::runtime::signer(),
                fees,
            )
            .unwrap();
            let request = request();
            let proof = Bytes::from_static(&[0]);
            let result = transport.sign(&request, &proof).await;
            let Some(expected) = expected else {
                assert!(matches!(result, Err(LanderError::Safety(_))));
                continue;
            };
            let transaction = result.unwrap();
            assert_eq!(transaction.nonce, 7);
            transaction.validate(&request, &proof).unwrap();
            let TxEnvelope::Eip4844(signed) =
                TxEnvelope::decode_2718(&mut transaction.network_bytes.as_ref()).unwrap()
            else {
                panic!("blob transaction required")
            };
            let inner = signed.tx().tx();
            assert_eq!(inner.gas_limit, expected);
            assert_eq!(inner.max_fee_per_gas, 5);
            assert_eq!(inner.max_priority_fee_per_gas, 2);
            assert_eq!(inner.max_fee_per_blob_gas, 10);
            assert_eq!(inner.value, U256::ZERO);
        }
    }

    #[tokio::test]
    async fn signing_retries_a_pending_nonce_below_the_confirmed_nonce_without_estimating() {
        use serde_json::json;
        let provider =
            crate::l1::tests::rpc(move |request| match request["method"].as_str().unwrap() {
                "eth_chainId" => json!("0x1"),
                "eth_getTransactionCount" => match request["params"][1].as_str().unwrap() {
                    "latest" => json!("0x4"),
                    "pending" => json!("0x3"),
                    tag => panic!("unexpected nonce tag {tag}"),
                },
                "eth_estimateGas" => json!("0x7a120"),
                method => panic!("unexpected signing method {method}"),
            })
            .await;
        let transport = RpcTransactionTransport::new(
            provider.provider.clone(),
            crate::test_utils::runtime::signer(),
            FeeCaps { max_fee_per_gas: 5, max_priority_fee_per_gas: 2, max_fee_per_blob_gas: 10 },
        )
        .unwrap();
        assert!(matches!(
            transport.sign(&request(), &Bytes::from_static(&[0])).await,
            Err(LanderError::Temporary(_))
        ));
        assert!(
            provider
                .requests
                .lock()
                .unwrap()
                .iter()
                .all(|request| { request["method"] != "eth_estimateGas" })
        );
    }

    #[test]
    fn transaction_rpc_errors_never_render_endpoint_credentials_or_response_bodies() {
        use alloy::transports::{RpcError, TransportErrorKind};
        let sensitive = "https://alice:password@example.invalid/private-key-path?api_key=secret";
        let decoding = serde_json::from_str::<serde_json::Value>("<html>").unwrap_err();
        for error in [
            TransportErrorKind::custom_str(sensitive),
            TransportErrorKind::http_error(503, sensitive.into()),
            RpcError::deser_err(decoding, sensitive),
        ] {
            let result = rpc_error(error);
            assert!(result.is_retryable());
            let message = result.to_string();
            for secret in ["alice", "password", "private-key-path", "api_key", "secret"] {
                assert!(!message.contains(secret), "RPC error exposed {secret}");
            }
        }
    }

    #[test]
    fn gas_estimation_rejections_never_render_untrusted_rpc_messages() {
        use alloy::transports::RpcError;
        let sensitive = "https://alice:password@example.invalid/private-key-path?api_key=secret";
        for code in [3, -32602] {
            let error = RpcError::ErrorResp(
                serde_json::from_value(serde_json::json!({"code":code,"message":sensitive}))
                    .unwrap(),
            );
            let result = estimate_error(error);
            assert!(!result.is_retryable());
            for secret in ["alice", "password", "private-key-path", "api_key", "secret"] {
                assert!(!result.to_string().contains(secret), "estimate error exposed {secret}");
            }
        }
    }

    #[tokio::test]
    async fn imported_duplicate_requires_the_exact_transaction_to_be_known_by_the_node() {
        use serde_json::json;
        let request = request();
        let proof = Bytes::from_static(&[0]);
        let transaction = signed(&request, &proof, 4).await;
        let envelope = TxEnvelope::decode_2718(&mut transaction.network_bytes.as_ref()).unwrap();
        let rpc_transaction = alloy_rpc_types::Transaction {
            inner: alloy_consensus::transaction::Recovered::new_unchecked(
                envelope,
                transaction.sender,
            ),
            block_hash: None,
            block_number: None,
            transaction_index: None,
            effective_gas_price: None,
        };
        let value = serde_json::to_value(rpc_transaction).unwrap();
        for present in [false, true] {
            let value = value.clone();
            let hash = transaction.hash;
            let provider=crate::l1::tests::rpc(move |request| match request["method"].as_str().unwrap() {
                "eth_sendRawTransaction"=>json!({"__rpc_error":{"code":-32003,"message":"transaction already imported"}}),
                "eth_getTransactionByHash"=>{assert_eq!(request["params"][0],json!(hash));if present {value.clone()}else{json!(null)}},
                method=>panic!("unexpected duplicate lookup {method}"),
            }).await;
            let transport = RpcTransactionTransport::new(
                provider.provider.clone(),
                crate::test_utils::runtime::signer(),
                FeeCaps {
                    max_fee_per_gas: 5,
                    max_priority_fee_per_gas: 2,
                    max_fee_per_blob_gas: 10,
                },
            )
            .unwrap();
            let result = transport.broadcast(&transaction).await;
            if present {
                assert_eq!(result.unwrap(), transaction.hash);
            } else {
                assert!(matches!(result, Err(LanderError::Temporary(_))));
            }
            assert!(
                provider
                    .requests
                    .lock()
                    .unwrap()
                    .iter()
                    .any(|request| request["method"] == "eth_getTransactionByHash")
            );
        }
    }

    #[tokio::test]
    async fn gas_estimation_execution_revert_is_fatal_and_rpc_outage_is_retryable() {
        use serde_json::json;
        for revert in [true, false] {
            let provider=crate::l1::tests::rpc(move |request| match request["method"].as_str().unwrap() {
                "eth_chainId"=>json!("0x1"),"eth_getTransactionCount"=>json!("0x0"),
                "eth_estimateGas"=>if revert {json!({"__rpc_error":{"code":-32003,"message":"execution reverted: dummy verifier rejected proof","data":"0x12345678"}})}else{json!({"__rpc_error":{"code":-32603,"message":"upstream unavailable"}})},
                method=>panic!("unexpected estimate method {method}"),
            }).await;
            let transport = RpcTransactionTransport::new(
                provider.provider.clone(),
                crate::test_utils::runtime::signer(),
                FeeCaps {
                    max_fee_per_gas: 5,
                    max_priority_fee_per_gas: 2,
                    max_fee_per_blob_gas: 10,
                },
            )
            .unwrap();
            let result = transport.sign(&request(), &Bytes::from_static(&[0])).await;
            if revert {
                assert!(matches!(result, Err(LanderError::Reverted(_))));
            } else {
                assert!(matches!(result, Err(LanderError::Temporary(_))));
            }
        }
    }

    /// The Inbox's `ZeroFeeRecipient` revert names an input the lander built wrongly, so it is a
    /// configuration error, never a retry; another revert stays [`LanderError::Reverted`].
    #[tokio::test]
    async fn gas_estimation_zero_fee_recipient_revert_is_a_configuration_error() {
        use serde_json::json;
        let selector = ZeroFeeRecipient::SELECTOR;
        assert_eq!(selector, [0xcf, 0xf9, 0xf1, 0x94]);
        let data = alloy_primitives::hex::encode_prefixed(selector);
        let provider =
            crate::l1::tests::rpc(move |request| match request["method"].as_str().unwrap() {
                "eth_chainId" => json!("0x1"),
                "eth_getTransactionCount" => json!("0x0"),
                "eth_estimateGas" => json!({"__rpc_error": {
                    "code": 3, "message": "execution reverted", "data": data
                }}),
                method => panic!("unexpected estimate method {method}"),
            })
            .await;
        let transport = RpcTransactionTransport::new(
            provider.provider.clone(),
            crate::test_utils::runtime::signer(),
            FeeCaps { max_fee_per_gas: 5, max_priority_fee_per_gas: 2, max_fee_per_blob_gas: 10 },
        )
        .unwrap();
        let result = transport.sign(&request(), &Bytes::from_static(&[0])).await;
        assert!(
            matches!(&result, Err(LanderError::Configuration(m)) if m.contains("ZeroFeeRecipient")),
            "{result:?}"
        );
    }

    #[test]
    fn unknown_transaction_errors_are_not_successful_duplicate_broadcasts() {
        assert!(is_known_response("already known"));
        assert!(is_known_response("Known transaction: 0x123"));
        assert!(is_known_response("transaction already imported"));
        assert!(!is_known_response("transaction not already imported"));
        assert!(!is_known_response("not already known"));
        assert!(!is_known_response("unknown transaction"));
        assert!(!is_known_response("could not find known transaction"));
    }

    #[test]
    fn signer_errors_never_render_secret_key_material() {
        let file = tempfile::NamedTempFile::new().unwrap();
        let invalid = "private-key-material-must-never-appear";
        std::fs::write(file.path(), invalid).unwrap();
        let error = RpcTransactionTransport::signer_from_file(file.path()).unwrap_err().to_string();
        assert!(!error.contains(invalid));
        std::fs::write(file.path(), "a".repeat(257)).unwrap();
        assert!(RpcTransactionTransport::signer_from_file(file.path()).is_err());
    }
}
