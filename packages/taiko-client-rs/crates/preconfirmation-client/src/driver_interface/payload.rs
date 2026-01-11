//! Helpers for constructing execution payloads from preconfirmation inputs.

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::{Header as RpcHeader, eth::Withdrawal};
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
use async_trait::async_trait;
use preconfirmation_types::uint256_to_u256;

use super::traits::PreconfirmationInput;
use crate::{Result, error::PreconfirmationClientError};
use protocol::shasta::{
    calculate_shasta_difficulty, compute_build_payload_args_id, encode_extra_data, encode_tx_list,
};

/// Maximum value for a `uint48`.
const MAX_U48: u64 = (1u64 << 48) - 1;

/// Resolve a block header for a block number.
#[async_trait]
pub trait BlockHeaderProvider: Send + Sync {
    /// Fetch the block header for the specified block number.
    async fn header_by_number(&self, block_number: u64) -> Result<RpcHeader>;
}

#[async_trait]
impl<P> BlockHeaderProvider for P
where
    P: Provider + Send + Sync,
{
    async fn header_by_number(&self, block_number: u64) -> Result<RpcHeader> {
        let block = self
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map_err(|err| PreconfirmationClientError::DriverClient(err.to_string()))?
            .ok_or_else(|| {
                PreconfirmationClientError::DriverClient(format!("missing block {block_number}"))
            })?;
        Ok(block.header)
    }
}

/// Build [`TaikoPayloadAttributes`] from a [`PreconfirmationInput`].
///
/// This builder is intentionally conservative: it only derives fields available in the
/// preconfirmation commitment, txlist, and basefee sharing percentage provided by the caller.
pub async fn build_taiko_payload_attributes(
    input: &PreconfirmationInput,
    basefee_sharing_pctg: u8,
    l2_provider: &dyn BlockHeaderProvider,
) -> Result<TaikoPayloadAttributes> {
    let preconf = &input.commitment.commitment.preconf;

    let block_number = uint256_to_u256(&preconf.block_number).to::<u64>();
    let timestamp = uint256_to_u256(&preconf.timestamp).to::<u64>();
    let gas_limit = uint256_to_u256(&preconf.gas_limit).to::<u64>();
    let proposal_id = uint256_to_u256(&preconf.proposal_id).to::<u64>();
    if proposal_id > MAX_U48 {
        return Err(PreconfirmationClientError::DriverClient(
            "proposal_id does not fit into uint48".to_string(),
        ));
    }

    let fee_recipient = Address::from_slice(preconf.coinbase.as_ref());
    let parent_block_number = block_number.saturating_sub(1);
    let parent_header = l2_provider.header_by_number(parent_block_number).await?;
    let mix_hash = calculate_shasta_difficulty(
        B256::from(parent_header.inner.difficulty.to_be_bytes::<32>()),
        block_number,
    );
    let withdrawals: Vec<Withdrawal> = Vec::new();
    let base_fee_per_gas = if parent_header.inner.number == 0 {
        SHASTA_INITIAL_BASE_FEE
    } else {
        if parent_header.inner.base_fee_per_gas.is_none() {
            return Err(PreconfirmationClientError::DriverClient(format!(
                "missing base fee for parent block {parent_block_number}"
            )));
        }
        let grandparent_header =
            l2_provider.header_by_number(parent_block_number.saturating_sub(1)).await?;

        calculate_next_block_eip4396_base_fee(
            &parent_header.inner,
            parent_header.inner.timestamp.saturating_sub(grandparent_header.inner.timestamp),
        )
    };
    let tx_list = encode_tx_list(
        &input
            .transactions
            .as_ref()
            .ok_or_else(|| {
                PreconfirmationClientError::DriverClient(
                    "missing transactions for execution payload".to_string(),
                )
            })?
            .iter()
            .cloned()
            .map(Bytes::from)
            .collect::<Vec<_>>(),
    );

    let l1_origin = RpcL1Origin {
        block_id: U256::from(block_number),
        l2_block_hash: B256::ZERO,
        l1_block_height: None,
        l1_block_hash: None,
        build_payload_args_id: compute_build_payload_args_id(
            parent_header.hash,
            timestamp,
            mix_hash,
            fee_recipient,
            &withdrawals,
            &tx_list,
        ),
        // Deprecated fields.
        is_forced_inclusion: false,
        signature: [0u8; 65],
    };

    let block_metadata = TaikoBlockMetadata {
        beneficiary: fee_recipient,
        gas_limit,
        timestamp: U256::from(timestamp),
        mix_hash,
        tx_list,
        extra_data: encode_extra_data(basefee_sharing_pctg, proposal_id),
    };

    let payload_attributes = EthPayloadAttributes {
        timestamp,
        prev_randao: mix_hash,
        suggested_fee_recipient: fee_recipient,
        withdrawals: Some(withdrawals),
        parent_beacon_block_root: None,
    };

    Ok(TaikoPayloadAttributes {
        payload_attributes,
        base_fee_per_gas: U256::from(base_fee_per_gas),
        block_metadata,
        l1_origin,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_consensus::Header;
    use preconfirmation_types::{
        Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
    };
    use std::collections::BTreeMap;

    /// Verifies that basic header fields are carried into the payload.
    #[tokio::test]
    async fn builds_payload_with_expected_header_fields() {
        let preconf = Preconfirmation {
            block_number: 5u64.into(),
            timestamp: 10u64.into(),
            gas_limit: 30_000_000u64.into(),
            coinbase: Bytes20::try_from(vec![1u8; 20]).expect("coinbase"),
            parent_preconfirmation_hash: Bytes32::try_from(vec![2u8; 32]).expect("parent"),
            proposal_id: 7u64.into(),
            ..Default::default()
        };

        let commitment = SignedCommitment {
            commitment: PreconfCommitment { preconf, ..Default::default() },
            signature: Bytes65::try_from(vec![0u8; 65]).expect("signature"),
        };

        let input = PreconfirmationInput::new(commitment, Some(vec![vec![0x01, 0x02]]), None);
        struct TestHeaderProvider {
            headers: BTreeMap<u64, RpcHeader>,
        }

        #[async_trait]
        impl BlockHeaderProvider for TestHeaderProvider {
            async fn header_by_number(&self, block_number: u64) -> Result<RpcHeader> {
                self.headers.get(&block_number).cloned().ok_or_else(|| {
                    PreconfirmationClientError::DriverClient(format!(
                        "missing block {block_number}"
                    ))
                })
            }
        }

        let parent_inner = Header {
            number: 4,
            timestamp: 8,
            gas_limit: 30_000_000,
            gas_used: 15_000_000,
            difficulty: U256::from(42),
            base_fee_per_gas: Some(900_000_000),
            ..Default::default()
        };
        let parent_header = RpcHeader::new(parent_inner);

        let grandparent_inner = Header { number: 3, timestamp: 6, ..Default::default() };
        let grandparent_header = RpcHeader::new(grandparent_inner);

        let mut headers = BTreeMap::new();
        headers.insert(4, parent_header.clone());
        headers.insert(3, grandparent_header);
        let provider = TestHeaderProvider { headers };
        let basefee_sharing_pctg = 5;
        let payload = build_taiko_payload_attributes(&input, basefee_sharing_pctg, &provider)
            .await
            .expect("payload");
        let parent_difficulty = B256::from(parent_header.inner.difficulty.to_be_bytes::<32>());
        let expected_mix_hash = calculate_shasta_difficulty(parent_difficulty, 5);
        let transactions = vec![Bytes::from(vec![0x01, 0x02])];
        let tx_list = encode_tx_list(&transactions);
        let expected_build_payload_args_id = compute_build_payload_args_id(
            parent_header.hash,
            10,
            expected_mix_hash,
            Address::from([1u8; 20]),
            &[],
            &tx_list,
        );
        assert_eq!(payload.payload_attributes.timestamp, 10);
        assert_eq!(payload.block_metadata.gas_limit, 30_000_000);
        assert_eq!(payload.block_metadata.beneficiary, Address::from([1u8; 20]));
        assert_eq!(payload.block_metadata.mix_hash, expected_mix_hash);
        assert_eq!(payload.payload_attributes.prev_randao, expected_mix_hash);
        assert_eq!(payload.block_metadata.extra_data.len(), 7);
        assert_eq!(payload.block_metadata.extra_data[0], basefee_sharing_pctg);
        assert_eq!(payload.base_fee_per_gas, U256::from(900_000_000));
        assert_eq!(payload.l1_origin.block_id, U256::from(5));
        assert_eq!(payload.l1_origin.build_payload_args_id, expected_build_payload_args_id);
        assert_eq!(payload.l1_origin.l1_block_height, None);
        assert_eq!(payload.l1_origin.l1_block_hash, None);
    }

    /// Verifies the proposal id layout in extra data.
    #[test]
    fn encodes_proposal_id_into_extra_data() {
        let basefee_sharing_pctg = 9;
        let extra = protocol::shasta::encode_extra_data(basefee_sharing_pctg, 0x0102_0304_0506);
        assert_eq!(extra.len(), 7);
        assert_eq!(extra[0], basefee_sharing_pctg);
        assert_eq!(&extra[1..7], &[0x01, 0x02, 0x03, 0x04, 0x05, 0x06]);
    }
}
