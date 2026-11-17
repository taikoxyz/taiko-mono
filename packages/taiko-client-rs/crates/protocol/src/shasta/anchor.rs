//! Anchor transaction construction and validation for Taiko Shasta.

use std::borrow::Cow;

use alethia_reth_consensus::validation::{ANCHOR_V3_V4_GAS_LIMIT, ANCHOR_V4_SELECTOR};
use alethia_reth_primitives::addresses::TAIKO_GOLDEN_TOUCH_ADDRESS;
use alloy::{
    primitives::{Address, B256, Bytes, TxKind, U256},
    sol_types::private::primitives::aliases::U48,
};
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope,
    transaction::{SignableTransaction, SignerRecoverable, Transaction as _, TxHashable},
};
use alloy_eips::{BlockId, eip1898::RpcBlockHash, eip2930::AccessList};
use alloy_provider::Provider;
use bindings::anchor::{Anchor::AnchorInstance, ICheckpointStore::Checkpoint};
use thiserror::Error;
use tracing::{info, instrument};

use crate::signer::{FixedKSigner, FixedKSignerError};

/// Errors emitted by the anchor transaction constructor.
#[derive(Debug, Error)]
pub enum AnchorTxConstructorError {
    /// Invalid signer or fixed-k signing failure.
    #[error(transparent)]
    Signer(#[from] FixedKSignerError),
    /// Provider call failure while assembling anchor data.
    #[error("provider error: {0}")]
    Provider(String),
    /// Nonce did not fit into the transaction nonce type.
    #[error("nonce exceeds u64 range")]
    NonceOverflow,
    /// Base fee did not fit into EIP-1559 fee-cap type.
    #[error("fee cap exceeds u128 range")]
    FeeOverflow,
}

/// Parameters required to assemble an `anchorV4` transaction.
#[derive(Debug)]
pub struct AnchorV4Input {
    /// L1 anchor block number included in the checkpoint.
    pub anchor_block_number: u64,
    /// L1 anchor block hash included in the checkpoint.
    pub anchor_block_hash: B256,
    /// L1 anchor block state root included in the checkpoint.
    pub anchor_state_root: B256,
    /// Target L2 height used for logging and call context.
    pub l2_height: u64,
    /// Base fee used to derive EIP-1559 fee cap.
    pub base_fee: U256,
}

/// Builds Shasta anchor transactions for the golden touch account.
///
/// Generic over the L2 provider type to avoid cyclic dependencies.
pub struct AnchorTxConstructor<L2Provider>
where
    L2Provider: Provider + Clone,
{
    /// Provider used for nonce, chain-id, and RPC queries.
    l2_provider: L2Provider,
    /// Bound Anchor contract instance.
    anchor_instance: AnchorInstance<L2Provider>,
    /// L2 chain identifier used when signing transactions.
    chain_id: u64,
    /// Deterministic fixed-k signer for golden-touch transactions.
    signer: FixedKSigner,
    /// Golden-touch account address used as sender.
    golden_touch_address: Address,
}

impl<L2Provider> AnchorTxConstructor<L2Provider>
where
    L2Provider: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new constructor using the shared golden touch key.
    ///
    /// # Arguments
    /// * `l2_provider` - Provider for L2 chain access
    /// * `anchor_address` - Address of the anchor contract on L2
    pub async fn new(
        l2_provider: L2Provider,
        anchor_address: Address,
    ) -> Result<Self, AnchorTxConstructorError> {
        let signer = FixedKSigner::golden_touch()?;
        let golden_touch_address = Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS);

        let chain_id = l2_provider
            .get_chain_id()
            .await
            .map_err(|err| AnchorTxConstructorError::Provider(err.to_string()))?;

        let anchor_instance = AnchorInstance::new(anchor_address, l2_provider.clone());

        Ok(Self { l2_provider, anchor_instance, chain_id, signer, golden_touch_address })
    }

    /// Assemble an `anchorV4` transaction for the given parent header and parameters.
    #[instrument(skip(self), fields(anchor_block_number = params.anchor_block_number))]
    pub async fn assemble_anchor_v4_tx(
        &self,
        parent_hash: B256,
        params: AnchorV4Input,
    ) -> Result<TxEnvelope, AnchorTxConstructorError> {
        let AnchorV4Input {
            anchor_block_number,
            anchor_block_hash,
            anchor_state_root,
            l2_height,
            base_fee,
        } = params;

        // Fetch golden touch nonce at the parent header via EIP-1898 hash reference.
        let nonce: U256 = self
            .l2_provider
            .raw_request(
                Cow::Borrowed("eth_getTransactionCount"),
                (
                    self.golden_touch_address,
                    BlockId::Hash(RpcBlockHash {
                        block_hash: parent_hash,
                        require_canonical: Some(true),
                    }),
                ),
            )
            .await
            .or_else(|err| {
                // If the nonce cannot be found, which means the account has never been used before,
                // return zero nonce.
                if err.to_string().contains("not found") {
                    Ok(U256::ZERO)
                } else {
                    Err(AnchorTxConstructorError::Provider(err.to_string()))
                }
            })?;

        let nonce: u64 =
            u64::try_from(&nonce).map_err(|_| AnchorTxConstructorError::NonceOverflow)?;
        let gas_fee_cap: u128 =
            u128::try_from(&base_fee).map_err(|_| AnchorTxConstructorError::FeeOverflow)?;

        info!(
            l2_height,
            ?anchor_block_number,
            ?anchor_block_hash,
            ?anchor_state_root,
            ?nonce,
            ?base_fee,
            ?gas_fee_cap,
            "assembling shasta anchor anchorV4 transaction",
        );

        let checkpoint = Checkpoint {
            blockNumber: U48::from(anchor_block_number),
            blockHash: anchor_block_hash,
            stateRoot: anchor_state_root,
        };

        let call_builder = self.anchor_instance.anchorV4(checkpoint);

        let call_builder = call_builder
            .from(self.golden_touch_address)
            .chain_id(self.chain_id)
            .nonce(nonce)
            .gas(ANCHOR_V3_V4_GAS_LIMIT)
            .max_fee_per_gas(gas_fee_cap)
            .max_priority_fee_per_gas(0);

        let calldata: Bytes = call_builder.calldata().clone();
        let anchor_address = *self.anchor_instance.address();

        let tx = TxEip1559 {
            chain_id: self.chain_id,
            nonce,
            gas_limit: ANCHOR_V3_V4_GAS_LIMIT,
            max_fee_per_gas: gas_fee_cap,
            max_priority_fee_per_gas: 0,
            to: TxKind::Call(anchor_address),
            value: U256::ZERO,
            access_list: AccessList::default(),
            input: calldata,
        };

        let sig_hash = tx.signature_hash();
        let mut hash_bytes = [0u8; 32];
        hash_bytes.copy_from_slice(sig_hash.as_slice());
        let signature = self.signer.sign_with_predefined_k(&hash_bytes)?;
        let tx_hash = tx.tx_hash(&signature.signature);

        Ok(TxEnvelope::new_unchecked(
            EthereumTypedTransaction::Eip1559(tx),
            signature.signature,
            tx_hash,
        ))
    }
}

/// Validation failures for a transaction that must be the Shasta anchor call.
#[derive(Debug, Error)]
pub enum AnchorTransactionValidationError {
    /// Anchor transaction omitted the recipient field.
    #[error("invalid anchor transaction recipient: <none> (expected {expected})")]
    MissingRecipient {
        /// Required anchor contract address.
        expected: Address,
    },
    /// Anchor transaction targeted the wrong contract.
    #[error("invalid anchor transaction recipient: {actual} (expected {expected})")]
    UnexpectedRecipient {
        /// Actual recipient address found in the transaction.
        actual: Address,
        /// Required anchor contract address.
        expected: Address,
    },
    /// Anchor transaction carried an unexpected chain id.
    #[error("failed to get anchor transaction sender: unexpected chain id {actual:?}")]
    UnexpectedChainId {
        /// Chain id observed on the transaction.
        actual: Option<u64>,
    },
    /// Sender recovery from signature failed.
    #[error("failed to get anchor transaction sender: {reason}")]
    SenderRecovery {
        /// Underlying recover-signature failure.
        reason: String,
    },
    /// Sender did not match the golden touch account.
    #[error("invalid anchor transaction sender: {sender}")]
    UnexpectedSender {
        /// Sender recovered from the transaction signature.
        sender: Address,
    },
    /// Anchor calldata is too short to include a 4-byte selector.
    #[error("failed to get anchor transaction method: missing selector")]
    MissingSelector,
    /// Anchor selector bytes did not match `ANCHOR_V4_SELECTOR`.
    #[error("invalid anchor transaction method: {selector:?}")]
    UnexpectedMethod {
        /// Four-byte function selector encoded in the anchor transaction calldata.
        selector: [u8; 4],
    },
}

/// Validate that `tx` is a genuine Shasta anchor transaction for untrusted-input admission:
/// the recipient is the anchor contract, the chain id matches, the recovered sender is the
/// golden-touch account, and the calldata invokes `anchorV4`.
pub fn validate_anchor_transaction(
    tx: &TxEnvelope,
    anchor_address: Address,
    chain_id: u64,
) -> Result<(), AnchorTransactionValidationError> {
    let to = tx
        .to()
        .ok_or(AnchorTransactionValidationError::MissingRecipient { expected: anchor_address })?;

    if to != anchor_address {
        return Err(AnchorTransactionValidationError::UnexpectedRecipient {
            actual: to,
            expected: anchor_address,
        });
    }

    let actual_chain_id = tx.chain_id();
    if actual_chain_id != Some(chain_id) {
        return Err(AnchorTransactionValidationError::UnexpectedChainId { actual: actual_chain_id });
    }

    let sender = tx.recover_signer().map_err(|err| {
        AnchorTransactionValidationError::SenderRecovery { reason: err.to_string() }
    })?;

    let golden_touch_address = Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS);
    if sender != golden_touch_address {
        return Err(AnchorTransactionValidationError::UnexpectedSender { sender });
    }

    let calldata = tx.input();
    if calldata.len() < ANCHOR_V4_SELECTOR.len() {
        return Err(AnchorTransactionValidationError::MissingSelector);
    }

    let mut selector = [0u8; 4];
    selector.copy_from_slice(&calldata[..4]);
    if selector != *ANCHOR_V4_SELECTOR {
        return Err(AnchorTransactionValidationError::UnexpectedMethod { selector });
    }

    Ok(())
}
