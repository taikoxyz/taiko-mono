//! Conversion between Engine API execution payloads and [`ExecutionBlock`]s. No I/O.
//!
//! An `engine_getPayloadV5` payload omits the header fields alethia-reth #248 fixes for every
//! Etna block, and the two it sets per block travel beside it: the zk gas (as `blockValue`, sent
//! back to `engine_newPayloadV4` as `headerDifficulty`) and the parent beacon block root (the
//! anchor's L1 state root). [`block_from_payload`] rebuilds the full header exactly as #248's
//! block assembler and `newPayload` validator do (`crates/block/src/assembler.rs`,
//! `crates/rpc/src/engine/validator.rs`); [`payload_from_block`] is its inverse.

use alloy_consensus::{
    EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header, constants::MAXIMUM_EXTRA_DATA_SIZE,
    proofs::ordered_trie_root_encoded,
};
use alloy_eips::eip7685::EMPTY_REQUESTS_HASH;
use alloy_primitives::{B64, B256, Bytes, U256};
use alloy_rpc_types_engine::{ExecutionPayloadV1, ExecutionPayloadV2, ExecutionPayloadV3};

use super::EngineError;
use crate::envelope::ExecutionBlock;

/// Rebuilds the Etna block an `engine_getPayloadV5` payload describes.
///
/// `zk_gas` is the payload's `blockValue` (the header `difficulty` under #248) and
/// `parent_beacon_block_root` the root sent with the forkchoice update that started the build.
/// The header takes every payload field (`feeRecipient` → `beneficiary`, `prevRandao` →
/// `mix_hash`) plus the Etna constants: empty ommers, the ordered trie root of the transaction
/// bytes, the empty withdrawals root, zero blob gas, the empty requests hash and a zero nonce.
/// Transactions are kept as the opaque EIP-2718 bytes of the payload.
///
/// Fails when the payload carries withdrawals ([`EngineError::Withdrawals`]) or blob gas
/// ([`EngineError::BlobGas`]), when the base fee or `zk_gas` exceeds `u64`, when `extraData`
/// exceeds 32 bytes, and when the rebuilt header does not hash to the payload's `blockHash`
/// ([`EngineError::BlockHashMismatch`]).
pub fn block_from_payload(
    p: &ExecutionPayloadV3,
    zk_gas: U256,
    parent_beacon_block_root: B256,
) -> Result<ExecutionBlock, EngineError> {
    let ExecutionPayloadV3 {
        payload_inner: ExecutionPayloadV2 { payload_inner: v1, withdrawals },
        blob_gas_used,
        excess_blob_gas,
    } = p;
    if !withdrawals.is_empty() {
        return Err(EngineError::Withdrawals(withdrawals.len()));
    }
    if (*blob_gas_used, *excess_blob_gas) != (0, 0) {
        return Err(EngineError::BlobGas {
            blob_gas_used: *blob_gas_used,
            excess_blob_gas: *excess_blob_gas,
        });
    }
    let base_fee = u64::try_from(v1.base_fee_per_gas)
        .map_err(|_| EngineError::BaseFeeOverflow(v1.base_fee_per_gas))?;
    check_zk_gas(zk_gas)?;
    check_extra_data(&v1.extra_data)?;

    let header = Header {
        parent_hash: v1.parent_hash,
        ommers_hash: EMPTY_OMMER_ROOT_HASH,
        beneficiary: v1.fee_recipient,
        state_root: v1.state_root,
        transactions_root: ordered_trie_root_encoded(&v1.transactions),
        receipts_root: v1.receipts_root,
        logs_bloom: v1.logs_bloom,
        difficulty: zk_gas,
        number: v1.block_number,
        gas_limit: v1.gas_limit,
        gas_used: v1.gas_used,
        timestamp: v1.timestamp,
        extra_data: v1.extra_data.clone(),
        mix_hash: v1.prev_randao,
        nonce: B64::ZERO,
        base_fee_per_gas: Some(base_fee),
        withdrawals_root: Some(EMPTY_ROOT_HASH),
        blob_gas_used: Some(0),
        excess_blob_gas: Some(0),
        parent_beacon_block_root: Some(parent_beacon_block_root),
        requests_hash: Some(EMPTY_REQUESTS_HASH),
    };
    let computed = header.hash_slow();
    if computed != v1.block_hash {
        return Err(EngineError::BlockHashMismatch { expected: v1.block_hash, computed });
    }
    Ok(ExecutionBlock { header, transactions: v1.transactions.clone() })
}

/// Splits an Etna block into its `engine_newPayloadV4` inputs: the payload, the
/// `headerDifficulty` (zk gas) and the `parentBeaconBlockRoot`.
///
/// The payload's `blockHash` is `b.header.hash_slow()`; withdrawals are empty and blob gas zero.
/// Rejects, as [`EngineError::NotEtnaShaped`], any header [`block_from_payload`] could not have
/// produced from the result: a missing parent beacon block root or base fee, a requests hash,
/// withdrawals root, ommers hash or nonce other than the Etna constant, nonzero or missing blob
/// gas, a transactions root that is not the ordered trie root of `b.transactions`, or more than
/// 32 bytes of `extraData`. A difficulty above `u64` fails with
/// [`EngineError::DifficultyOverflow`]. On success `block_from_payload` of the parts returns `b`.
pub fn payload_from_block(
    b: &ExecutionBlock,
) -> Result<(ExecutionPayloadV3, u64, B256), EngineError> {
    let h = &b.header;
    let root =
        h.parent_beacon_block_root.ok_or(EngineError::NotEtnaShaped("parent_beacon_block_root"))?;
    let base_fee = h.base_fee_per_gas.ok_or(EngineError::NotEtnaShaped("base_fee_per_gas"))?;
    etna_field("requests_hash", h.requests_hash == Some(EMPTY_REQUESTS_HASH))?;
    etna_field("blob_gas_used", h.blob_gas_used == Some(0))?;
    etna_field("excess_blob_gas", h.excess_blob_gas == Some(0))?;
    etna_field("withdrawals_root", h.withdrawals_root == Some(EMPTY_ROOT_HASH))?;
    etna_field("ommers_hash", h.ommers_hash == EMPTY_OMMER_ROOT_HASH)?;
    etna_field("nonce", h.nonce == B64::ZERO)?;
    etna_field(
        "transactions_root",
        h.transactions_root == ordered_trie_root_encoded(&b.transactions),
    )?;
    check_extra_data(&h.extra_data)?;
    let difficulty = check_zk_gas(h.difficulty)?;

    let payload = ExecutionPayloadV3 {
        payload_inner: ExecutionPayloadV2 {
            payload_inner: ExecutionPayloadV1 {
                parent_hash: h.parent_hash,
                fee_recipient: h.beneficiary,
                state_root: h.state_root,
                receipts_root: h.receipts_root,
                logs_bloom: h.logs_bloom,
                prev_randao: h.mix_hash,
                block_number: h.number,
                gas_limit: h.gas_limit,
                gas_used: h.gas_used,
                timestamp: h.timestamp,
                extra_data: h.extra_data.clone(),
                base_fee_per_gas: U256::from(base_fee),
                block_hash: h.hash_slow(),
                transactions: b.transactions.clone(),
            },
            withdrawals: Vec::new(),
        },
        blob_gas_used: 0,
        excess_blob_gas: 0,
    };
    Ok((payload, difficulty, root))
}

/// `Ok` iff `ok`, else [`EngineError::NotEtnaShaped`] naming `field`.
fn etna_field(field: &'static str, ok: bool) -> Result<(), EngineError> {
    if ok { Ok(()) } else { Err(EngineError::NotEtnaShaped(field)) }
}

/// Narrows a zk gas / header difficulty to the `u64` `engine_newPayloadV4` carries as
/// `headerDifficulty`, or fails with [`EngineError::DifficultyOverflow`].
fn check_zk_gas(zk_gas: U256) -> Result<u64, EngineError> {
    u64::try_from(zk_gas).map_err(|_| EngineError::DifficultyOverflow(zk_gas))
}

/// Rejects an `extraData` longer than the EL's 32-byte cap, which alethia-reth enforces when it
/// converts a payload ([`EngineError::NotEtnaShaped`] naming `extra_data`).
fn check_extra_data(extra_data: &Bytes) -> Result<(), EngineError> {
    etna_field("extra_data", extra_data.len() <= MAXIMUM_EXTRA_DATA_SIZE)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_eips::eip4895::Withdrawal;
    use alloy_primitives::{Address, Bloom, b256, bytes};
    use serde_json::Value;

    /// `engine_getPayloadV5` output of alethia-reth `sha-1e25b48` for devnet block 1 (see the
    /// fixture's `source` field), plus the `parentBeaconBlockRoot` sent with the build.
    const GOLDEN: &str = include_str!("testdata/etna_block_1.json");

    /// `transactionsRoot` alethia-reth reported for the golden block (`eth_getBlockByNumber`).
    const GOLDEN_TX_ROOT: B256 =
        b256!("61ce0f0641c7fa032b8ead151e403d15188812f0c28e44b0c223266452cd6ef9");

    struct Golden {
        payload: ExecutionPayloadV3,
        zk_gas: U256,
        root: B256,
    }

    fn golden() -> Golden {
        let v: Value = serde_json::from_str(GOLDEN).expect("fixture is JSON");
        Golden {
            payload: serde_json::from_value(v["executionPayload"].clone()).expect("payload"),
            zk_gas: serde_json::from_value(v["blockValue"].clone()).expect("blockValue"),
            root: serde_json::from_value(v["parentBeaconBlockRoot"].clone()).expect("root"),
        }
    }

    /// An Etna-shaped block with two opaque transactions and nonzero zk gas.
    fn etna_block() -> ExecutionBlock {
        let transactions = vec![bytes!("02f801aa"), Bytes::from(vec![0x7f; 300])];
        let header = Header {
            parent_hash: B256::repeat_byte(0x01),
            ommers_hash: EMPTY_OMMER_ROOT_HASH,
            beneficiary: Address::repeat_byte(0x03),
            state_root: B256::repeat_byte(0x04),
            transactions_root: ordered_trie_root_encoded(&transactions),
            receipts_root: B256::repeat_byte(0x05),
            logs_bloom: Bloom::repeat_byte(0x06),
            difficulty: U256::from(987_654u64),
            number: 42,
            gas_limit: 45_000_000,
            gas_used: 63_000,
            timestamp: 1_791_526_500,
            extra_data: bytes!("64000000000002000000000007"),
            mix_hash: B256::repeat_byte(0x07),
            nonce: B64::ZERO,
            base_fee_per_gas: Some(25_000_000),
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            parent_beacon_block_root: Some(B256::repeat_byte(0x5a)),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
        };
        ExecutionBlock { header, transactions }
    }

    fn withdrawal() -> Withdrawal {
        Withdrawal { index: 0, validator_index: 1, address: Address::repeat_byte(0x09), amount: 1 }
    }

    #[test]
    fn golden_alethia_reth_payload_reproduces_its_block_hash() {
        let g = golden();
        let block = block_from_payload(&g.payload, g.zk_gas, g.root).expect("golden converts");

        let h = &block.header;
        assert_eq!(h.hash_slow(), g.payload.payload_inner.payload_inner.block_hash);
        assert_eq!(h.difficulty, U256::from(0x3b538u64));
        assert_eq!(h.transactions_root, GOLDEN_TX_ROOT);
        assert_eq!(h.parent_beacon_block_root, Some(g.root));
        assert_eq!(h.requests_hash, Some(EMPTY_REQUESTS_HASH));
        assert_eq!(block.transactions, g.payload.payload_inner.payload_inner.transactions);
        assert_eq!(block.transactions.len(), 1);
    }

    #[test]
    fn golden_payload_round_trips_through_the_block() {
        let g = golden();
        let block = block_from_payload(&g.payload, g.zk_gas, g.root).expect("golden converts");
        let (payload, difficulty, root) = payload_from_block(&block).expect("block converts");
        assert_eq!(payload, g.payload);
        assert_eq!(U256::from(difficulty), g.zk_gas);
        assert_eq!(root, g.root);
    }

    #[test]
    fn block_round_trips_through_the_payload() {
        let block = etna_block();
        let (payload, difficulty, root) = payload_from_block(&block).expect("block converts");

        let inner = &payload.payload_inner.payload_inner;
        assert_eq!(inner.block_hash, block.header.hash_slow());
        assert_eq!(inner.transactions, block.transactions);
        assert!(payload.payload_inner.withdrawals.is_empty());
        assert_eq!((payload.blob_gas_used, payload.excess_blob_gas), (0, 0));
        assert_eq!(difficulty, 987_654);
        assert_eq!(root, B256::repeat_byte(0x5a));

        let rebuilt =
            block_from_payload(&payload, U256::from(difficulty), root).expect("payload converts");
        assert_eq!(rebuilt, block);
    }

    #[test]
    fn empty_block_round_trips() {
        let mut block = etna_block();
        block.transactions.clear();
        block.header.transactions_root = EMPTY_ROOT_HASH;
        block.header.difficulty = U256::ZERO;
        let (payload, difficulty, root) = payload_from_block(&block).expect("block converts");
        assert_eq!(block_from_payload(&payload, U256::from(difficulty), root), Ok(block));
    }

    #[test]
    fn wrong_block_hash_is_rejected() {
        let g = golden();
        let real = g.payload.payload_inner.payload_inner.block_hash;
        let mut payload = g.payload;
        payload.payload_inner.payload_inner.block_hash = B256::repeat_byte(0xee);
        assert_eq!(
            block_from_payload(&payload, g.zk_gas, g.root),
            Err(EngineError::BlockHashMismatch {
                expected: B256::repeat_byte(0xee),
                computed: real
            })
        );
    }

    #[test]
    fn zk_gas_and_root_are_bound_by_the_block_hash() {
        let g = golden();
        let wrong_gas = block_from_payload(&g.payload, g.zk_gas + U256::from(1), g.root);
        assert!(matches!(wrong_gas, Err(EngineError::BlockHashMismatch { .. })), "{wrong_gas:?}");
        let wrong_root = block_from_payload(&g.payload, g.zk_gas, B256::repeat_byte(0x5b));
        assert!(matches!(wrong_root, Err(EngineError::BlockHashMismatch { .. })), "{wrong_root:?}");
    }

    #[test]
    fn payload_with_withdrawals_is_rejected() {
        let g = golden();
        let mut payload = g.payload;
        payload.payload_inner.withdrawals = vec![withdrawal(), withdrawal()];
        assert_eq!(
            block_from_payload(&payload, g.zk_gas, g.root),
            Err(EngineError::Withdrawals(2))
        );
    }

    #[test]
    fn payload_with_blob_gas_is_rejected() {
        let g = golden();
        for (used, excess) in [(1, 0), (0, 1), (131_072, 393_216)] {
            let mut payload = g.payload.clone();
            payload.blob_gas_used = used;
            payload.excess_blob_gas = excess;
            assert_eq!(
                block_from_payload(&payload, g.zk_gas, g.root),
                Err(EngineError::BlobGas { blob_gas_used: used, excess_blob_gas: excess })
            );
        }
    }

    #[test]
    fn base_fee_over_u64_is_rejected() {
        let g = golden();
        let mut payload = g.payload;
        let fee = U256::from(u64::MAX) + U256::from(1);
        payload.payload_inner.payload_inner.base_fee_per_gas = fee;
        assert_eq!(
            block_from_payload(&payload, g.zk_gas, g.root),
            Err(EngineError::BaseFeeOverflow(fee))
        );
    }

    #[test]
    fn difficulty_over_u64_is_rejected() {
        let too_big = U256::from(u64::MAX) + U256::from(1);

        let mut block = etna_block();
        block.header.difficulty = too_big;
        assert_eq!(payload_from_block(&block), Err(EngineError::DifficultyOverflow(too_big)));

        let g = golden();
        assert_eq!(
            block_from_payload(&g.payload, too_big, g.root),
            Err(EngineError::DifficultyOverflow(too_big))
        );

        let mut max = etna_block();
        max.header.difficulty = U256::from(u64::MAX);
        assert_eq!(payload_from_block(&max).map(|(_, d, _)| d), Ok(u64::MAX));
    }

    #[test]
    fn non_etna_headers_are_rejected() {
        type Mutation = fn(&mut Header);
        let cases: [(&str, Mutation); 13] = [
            ("parent_beacon_block_root", |h| h.parent_beacon_block_root = None),
            ("requests_hash", |h| h.requests_hash = None),
            ("requests_hash", |h| h.requests_hash = Some(B256::repeat_byte(0x01))),
            ("blob_gas_used", |h| h.blob_gas_used = Some(1)),
            ("blob_gas_used", |h| h.blob_gas_used = None),
            ("excess_blob_gas", |h| h.excess_blob_gas = Some(1)),
            ("withdrawals_root", |h| h.withdrawals_root = Some(B256::repeat_byte(0x02))),
            ("withdrawals_root", |h| h.withdrawals_root = None),
            ("ommers_hash", |h| h.ommers_hash = B256::ZERO),
            ("nonce", |h| h.nonce = B64::with_last_byte(1)),
            ("transactions_root", |h| h.transactions_root = EMPTY_ROOT_HASH),
            ("base_fee_per_gas", |h| h.base_fee_per_gas = None),
            ("extra_data", |h| h.extra_data = Bytes::from(vec![0; 33])),
        ];
        for (field, mutate) in cases {
            let mut block = etna_block();
            mutate(&mut block.header);
            assert_eq!(
                payload_from_block(&block),
                Err(EngineError::NotEtnaShaped(field)),
                "mutating {field}"
            );
        }
    }
}
