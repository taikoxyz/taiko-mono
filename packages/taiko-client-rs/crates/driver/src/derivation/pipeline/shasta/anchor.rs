use std::borrow::Cow;

use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alethia_reth_evm::alloy::TAIKO_GOLDEN_TOUCH_ADDRESS;
use alloy::{
    primitives::{Address, B256, Bytes, TxKind, U256},
    sol_types::private::primitives::aliases::U48,
};
use alloy_consensus::{
    EthereumTypedTransaction, TxEip1559, TxEnvelope,
    transaction::{SignableTransaction, TxHashable},
};
use alloy_eips::{BlockId, eip1898::RpcBlockHash, eip2930::AccessList};
use alloy_provider::Provider;
use bindings::anchor::{Anchor::ProposalParams, ICheckpointStore::Checkpoint};
use rpc::client::Client;
use thiserror::Error;
use tracing::{info, instrument};

use crate::signer::{FixedKSigner, FixedKSignerError};

/// Errors emitted by the anchor transaction constructor.
#[derive(Debug, Error)]
pub enum AnchorTxConstructorError {
    #[error(transparent)]
    Signer(#[from] FixedKSignerError),
    #[error("provider error: {0}")]
    Provider(String),
    #[error("nonce exceeds u64 range")]
    NonceOverflow,
    #[error("fee cap exceeds u128 range")]
    FeeOverflow,
}

/// Parameters required to assemble an `anchorV4` transaction.
#[derive(Debug)]
pub struct AnchorV4Input {
    pub proposal_id: u64,
    pub proposer: Address,
    pub prover_auth: Vec<u8>,
    pub anchor_block_number: u64,
    pub anchor_block_hash: B256,
    pub anchor_state_root: B256,
    pub l2_height: u64,
    pub base_fee: U256,
}

/// Builds Shasta anchor transactions for the golden touch account.
pub struct AnchorTxConstructor<P>
where
    P: Provider + Clone,
{
    rpc: Client<P>,
    chain_id: u64,
    signer: FixedKSigner,
    golden_touch_address: Address,
}

impl<P> AnchorTxConstructor<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new constructor using the shared golden touch key.
    pub async fn new(rpc: Client<P>) -> Result<Self, AnchorTxConstructorError> {
        let signer = FixedKSigner::golden_touch()?;
        let golden_touch_address = Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS);

        let chain_id = rpc
            .l2_provider
            .get_chain_id()
            .await
            .map_err(|err| AnchorTxConstructorError::Provider(err.to_string()))?;

        Ok(Self { rpc, chain_id, signer, golden_touch_address })
    }

    /// Assemble an `anchorV4` transaction for the given parent header and parameters.
    #[instrument(skip(self), fields(proposal_id = params.proposal_id, anchor_block_number = params.anchor_block_number))]
    pub async fn assemble_anchor_v4_tx(
        &self,
        parent_hash: B256,
        params: AnchorV4Input,
    ) -> Result<TxEnvelope, AnchorTxConstructorError> {
        let AnchorV4Input {
            proposal_id,
            proposer,
            prover_auth,
            anchor_block_number,
            anchor_block_hash,
            anchor_state_root,
            l2_height,
            base_fee,
        } = params;

        // Fetch golden touch nonce at the parent header via EIP-1898 hash reference.
        let nonce: U256 = self
            .rpc
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
            proposal_id,
            ?prover_auth,
            ?anchor_block_number,
            ?anchor_block_hash,
            ?anchor_state_root,
            ?nonce,
            ?base_fee,
            ?gas_fee_cap,
            "assembling shasta anchor anchorV4 transaction",
        );

        let proposal_params = ProposalParams {
            proposalId: U48::from(proposal_id),
            proposer,
            proverAuth: prover_auth.into(),
        };

        let checkpoint = Checkpoint {
            blockNumber: U48::from(anchor_block_number),
            blockHash: anchor_block_hash,
            stateRoot: anchor_state_root,
        };

        let call_builder = self.rpc.shasta.anchor.anchorV4(proposal_params, checkpoint);

        let call_builder = call_builder
            .from(self.golden_touch_address)
            .chain_id(self.chain_id)
            .nonce(nonce)
            .gas(ANCHOR_V3_V4_GAS_LIMIT)
            .max_fee_per_gas(gas_fee_cap)
            .max_priority_fee_per_gas(0);

        let calldata: Bytes = call_builder.calldata().clone();
        let anchor_address = *self.rpc.shasta.anchor.address();

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
