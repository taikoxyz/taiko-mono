//! Helpers for constructing execution payloads from preconfirmation inputs.

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Header as RpcHeader;
use alloy_rpc_types_engine::{ExecutionPayloadInputV2, ExecutionPayloadV1};
use async_trait::async_trait;
use preconfirmation_types::uint256_to_u256;

use super::traits::PreconfirmationInput;
use crate::{Result, error::PreconfirmationClientError};
use protocol::shasta::encode_extra_data;

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

/// Build an [`ExecutionPayloadInputV2`] from a [`PreconfirmationInput`].
///
/// This builder is intentionally conservative: it only derives fields available in the
/// preconfirmation commitment, txlist, and basefee sharing percentage provided by the caller.
pub async fn build_execution_payload_input_v2(
    input: &PreconfirmationInput,
    basefee_sharing_pctg: u8,
    l2_provider: &dyn BlockHeaderProvider,
) -> Result<ExecutionPayloadInputV2> {
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
    let parent_hash = parent_header.hash;
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
    let extra_data = encode_extra_data(basefee_sharing_pctg, proposal_id);

    let transactions = input
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
        .collect();

    let mut payload = ExecutionPayloadV1 {
        parent_hash,
        fee_recipient,
        state_root: B256::ZERO,
        receipts_root: B256::ZERO,
        logs_bloom: Bloom::default(),
        prev_randao: B256::ZERO,
        block_number,
        gas_limit,
        gas_used: 0,
        timestamp,
        extra_data,
        base_fee_per_gas: U256::from(base_fee_per_gas),
        block_hash: B256::ZERO,
        transactions,
    };

    let block = payload.clone().into_block_raw().map_err(|err| {
        PreconfirmationClientError::DriverClient(format!("failed to build execution block: {err}"))
    })?;
    payload.block_hash = block.header.hash_slow();

    Ok(ExecutionPayloadInputV2 { execution_payload: payload, withdrawals: None })
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
            base_fee_per_gas: Some(900_000_000),
            ..Default::default()
        };
        let parent_header = RpcHeader::new(parent_inner);
        let parent_hash = parent_header.hash;

        let grandparent_inner = Header { number: 3, timestamp: 6, ..Default::default() };
        let grandparent_header = RpcHeader::new(grandparent_inner);

        let mut headers = BTreeMap::new();
        headers.insert(4, parent_header.clone());
        headers.insert(3, grandparent_header);
        let provider = TestHeaderProvider { headers };
        let basefee_sharing_pctg = 5;
        let payload = build_execution_payload_input_v2(&input, basefee_sharing_pctg, &provider)
            .await
            .expect("payload");
        assert_eq!(payload.execution_payload.block_number, 5);
        assert_eq!(payload.execution_payload.timestamp, 10);
        assert_eq!(payload.execution_payload.gas_limit, 30_000_000);
        assert_eq!(payload.execution_payload.fee_recipient, Address::from([1u8; 20]));
        assert_eq!(payload.execution_payload.parent_hash, parent_hash);
        assert_eq!(payload.execution_payload.transactions.len(), 1);
        assert_eq!(payload.execution_payload.extra_data.len(), 7);
        assert_eq!(payload.execution_payload.extra_data[0], basefee_sharing_pctg);
        assert_eq!(payload.execution_payload.base_fee_per_gas, U256::from(900_000_000));
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
