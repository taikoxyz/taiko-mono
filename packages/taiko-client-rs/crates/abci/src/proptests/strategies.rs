//! Generators of the values the properties encode and decode.
//!
//! Every field is arbitrary. Integers have a uniformly random bit length, so zero, single-byte,
//! short and full-width RLP integers all occur often; byte strings cross RLP's single-byte, short
//! (< 56 bytes) and long length forms.

use alloy_consensus::{Header, SignableTransaction, TxEip4844Variant, TxEnvelope};
use alloy_eips::{
    eip2930::{AccessList, AccessListItem},
    eip7702::{Authorization, SignedAuthorization},
};
use alloy_primitives::{Address, B64, B256, Bloom, Bytes, Signature, TxKind, U256};
use proptest::{collection::vec, option, prelude::*};

use crate::{
    envelope::{AnchorWitness, CommitteeWitness, EtnaEnvelope, ExecutionBlock},
    forced::{ForcedWitness, MAX_FORCED_TX_BYTES},
    l1::header::RawL1Header,
    types::{AccountWitness, CommitteeRecord, RegistryEntry, StorageProof},
};

/// A `u64` of uniformly random bit length (0 to 64).
pub(super) fn uint() -> impl Strategy<Value = u64> {
    (0u32..=64, any::<u64>()).prop_map(|(bits, x)| if bits == 0 { 0 } else { x >> (64 - bits) })
}

/// A `u128` of uniformly random bit length (0 to 128).
fn uint128() -> impl Strategy<Value = u128> {
    (0u32..=128, any::<u128>()).prop_map(|(bits, x)| if bits == 0 { 0 } else { x >> (128 - bits) })
}

/// A `U256` of uniformly random bit length (0 to 256).
pub(super) fn word() -> impl Strategy<Value = U256> {
    (0usize..=256, any::<[u8; 32]>()).prop_map(|(bits, bytes)| {
        if bits == 0 { U256::ZERO } else { U256::from_be_bytes(bytes) >> (256 - bits) }
    })
}

/// 32 arbitrary bytes.
pub(super) fn hash() -> impl Strategy<Value = B256> {
    any::<[u8; 32]>().prop_map(B256::from)
}

/// 20 arbitrary bytes.
pub(super) fn address() -> impl Strategy<Value = Address> {
    any::<[u8; 20]>().prop_map(Address::from)
}

/// Up to `max` arbitrary bytes.
pub(super) fn bytes(max: usize) -> impl Strategy<Value = Bytes> {
    vec(any::<u8>(), 0..=max).prop_map(Bytes::from)
}

/// `len` pseudo-random bytes (xorshift64 seeded with `seed`): long strings without generating
/// (and shrinking) every byte.
pub(super) fn noise(len: usize, seed: u64) -> Vec<u8> {
    let mut state = seed | 1;
    (0..len)
        .map(|_| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            (state >> 32) as u8
        })
        .collect()
}

/// A logs bloom: 256 bytes expanded from 32 arbitrary ones.
fn bloom() -> impl Strategy<Value = Bloom> {
    any::<[u8; 32]>()
        .prop_map(|seed| Bloom::new(std::array::from_fn(|i| seed[i % 32] ^ (i / 32) as u8)))
}

/// The RLP list of the already encoded `items`.
pub(super) fn rlp_list(items: &[Vec<u8>]) -> Vec<u8> {
    let payload = items.concat();
    let mut out = Vec::with_capacity(payload.len() + 9);
    alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut out);
    out.extend_from_slice(&payload);
    out
}

/// One canonically encoded RLP item: a byte string of up to 70 bytes, or a list of up to four
/// items nested at most `depth` deep.
pub(super) fn rlp_item(depth: u32) -> impl Strategy<Value = Vec<u8>> {
    bytes(70)
        .prop_map(|bytes| alloy_rlp::encode(&bytes))
        .prop_recursive(depth, 16, 4, |inner| vec(inner, 0..=4).prop_map(|items| rlp_list(&items)))
}

/// An execution header with arbitrary fields (`extra_data` up to 97 bytes) and the optional
/// fields of a random fork.
///
/// Alloy encodes the optional fields in order and decodes a prefix of them, so a header keeps
/// exactly the first `forks` of: base fee, withdrawals root, blob gas used, excess blob gas,
/// parent beacon block root, requests hash.
pub(super) fn el_header() -> impl Strategy<Value = Header> {
    let roots = (hash(), hash(), address(), hash(), hash(), hash(), bloom());
    let values = (word(), uint(), uint(), uint(), uint(), bytes(97), hash(), any::<[u8; 8]>());
    let forks = (0usize..=6, uint(), hash(), uint(), uint(), hash(), hash());
    (roots, values, forks).prop_map(
        |(
            (
                parent_hash,
                ommers_hash,
                beneficiary,
                state_root,
                transactions_root,
                receipts_root,
                logs_bloom,
            ),
            (difficulty, number, gas_limit, gas_used, timestamp, extra_data, mix_hash, nonce),
            (forks, base_fee, withdrawals_root, blob_gas_used, excess_blob_gas, beacon, requests),
        )| Header {
            block_access_list_hash: None,
            slot_number: None,
            parent_hash,
            ommers_hash,
            beneficiary,
            state_root,
            transactions_root,
            receipts_root,
            logs_bloom,
            difficulty,
            number,
            gas_limit,
            gas_used,
            timestamp,
            extra_data,
            mix_hash,
            nonce: B64::from(nonce),
            base_fee_per_gas: (forks >= 1).then_some(base_fee),
            withdrawals_root: (forks >= 2).then_some(withdrawals_root),
            blob_gas_used: (forks >= 3).then_some(blob_gas_used),
            excess_blob_gas: (forks >= 4).then_some(excess_blob_gas),
            parent_beacon_block_root: (forks >= 5).then_some(beacon),
            requests_hash: (forks >= 6).then_some(requests),
        },
    )
}

/// `header`'s RLP list with the already encoded `extra` items appended to its fields, as a node
/// of an L1 fork newer than alloy's header serves it.
pub(super) fn raw_with_fields(header: &Header, extra: &[Vec<u8>]) -> Vec<u8> {
    let encoded = alloy_rlp::encode(header);
    let fields = alloy_rlp::Header::decode_bytes(&mut encoded.as_slice(), true)
        .expect("an alloy header encodes as a list");
    rlp_list(&[[fields.to_vec()].as_slice(), extra].concat())
}

/// A raw L1 header: an arbitrary alloy header with up to three arbitrary RLP items appended.
fn raw_l1_header() -> impl Strategy<Value = RawL1Header> {
    (el_header(), vec(rlp_item(2), 0..=3)).prop_map(|(header, extra)| {
        RawL1Header::from_raw(raw_with_fields(&header, &extra).into())
            .expect("an alloy header with appended items is an L1 header")
    })
}

/// An EIP-1186 storage proof with an arbitrary slot, value and nodes.
fn storage_proof() -> impl Strategy<Value = StorageProof> {
    (hash(), word(), vec(bytes(300), 0..=2)).prop_map(|(slot, value, proof)| StorageProof {
        slot,
        value,
        proof,
    })
}

/// An account witness with arbitrary fields, nodes and storage proofs.
pub(super) fn account_witness() -> impl Strategy<Value = AccountWitness> {
    (address(), uint(), word(), hash(), hash(), vec(bytes(300), 0..=3), vec(storage_proof(), 0..=3))
        .prop_map(|(address, nonce, balance, storage_root, code_hash, account_proof, storage)| {
            AccountWitness {
                address,
                nonce,
                balance,
                storage_root,
                code_hash,
                account_proof,
                storage,
            }
        })
}

/// A committee record with arbitrary fields.
pub(super) fn committee_record() -> impl Strategy<Value = CommitteeRecord> {
    (uint(), uint(), uint(), hash(), uint()).prop_map(
        |(target_epoch, cutoff_l1_block, checkpoint_index, set_root, total_power)| {
            CommitteeRecord {
                target_epoch,
                cutoff_l1_block,
                checkpoint_index,
                set_root,
                total_power,
            }
        },
    )
}

/// Arbitrary canonical field encodings; derivation separately validates curve membership.
fn registry_entry() -> impl Strategy<Value = RegistryEntry> {
    (any::<u8>(), hash(), word(), uint(), uint()).prop_map(
        |(ck_prefix, ck_x, eff_stake, active_from_l1, exit_effective_l1)| RegistryEntry {
            ck_prefix,
            ck_x,
            eff_stake,
            active_from_l1,
            exit_effective_l1,
        },
    )
}

/// A committee witness: an arbitrary record, registry account witness and up to six entries.
pub(super) fn committee_witness() -> impl Strategy<Value = CommitteeWitness> {
    (committee_record(), account_witness(), vec(registry_entry(), 0..=6))
        .prop_map(|(record, registry, entries)| CommitteeWitness { record, registry, entries })
}

/// The bytes of a forced transaction, at most `max` long: short arbitrary bytes, pseudo-random
/// bytes of any length, or exactly `max` of them.
pub(super) fn forced_tx(max: usize) -> impl Strategy<Value = Bytes> {
    prop_oneof![
        bytes(64),
        (0..=max, any::<u64>()).prop_map(|(len, seed)| noise(len, seed).into()),
        any::<u64>().prop_map(move |seed| noise(max, seed).into()),
    ]
}

/// A forced inclusion witness whose transaction is within the byte limit.
fn forced_witness() -> impl Strategy<Value = ForcedWitness> {
    (uint(), account_witness(), forced_tx(MAX_FORCED_TX_BYTES))
        .prop_map(|(index, entry, tx)| ForcedWitness { index, entry, tx })
}

/// An anchor witness: an arbitrary raw L1 header (possibly with fields alloy does not know) and
/// an arbitrary Inbox account witness.
fn anchor_witness() -> impl Strategy<Value = AnchorWitness> {
    (raw_l1_header(), account_witness())
        .prop_map(|(l1_header, inbox)| AnchorWitness { l1_header, inbox })
}

/// An execution block: an arbitrary header and up to four arbitrary opaque transactions.
fn execution_block() -> impl Strategy<Value = ExecutionBlock> {
    (el_header(), vec(bytes(200), 0..=4))
        .prop_map(|(header, transactions)| ExecutionBlock { header, transactions })
}

/// An envelope: an arbitrary execution block, and each witness absent or arbitrary.
pub(super) fn envelope() -> impl Strategy<Value = EtnaEnvelope> {
    (
        execution_block(),
        option::of(anchor_witness()),
        option::of(committee_witness()),
        option::of(forced_witness()),
    )
        .prop_map(|(block, anchor, committee, forced)| EtnaEnvelope {
            block,
            anchor,
            committee,
            forced,
        })
}

/// An envelope-shaped body under the right version byte that rarely decodes: a valid execution
/// block followed by three arbitrary items, each an empty list, a list of one or two arbitrary
/// items, or a single arbitrary item.
pub(super) fn envelope_shaped_bytes() -> impl Strategy<Value = Vec<u8>> {
    let optional = || {
        prop_oneof![
            Just(rlp_list(&[])),
            rlp_item(2).prop_map(|item| rlp_list(&[item])),
            (rlp_item(2), rlp_item(2)).prop_map(|(a, b)| rlp_list(&[a, b])),
            rlp_item(2),
        ]
    };
    (execution_block(), optional(), optional(), optional()).prop_map(|(block, a, b, c)| {
        let body = rlp_list(&[alloy_rlp::encode(&block), a, b, c]);
        [vec![crate::envelope::ENVELOPE_VERSION], body].concat()
    })
}

/// An access list of up to two entries with up to two storage keys each.
fn access_list() -> impl Strategy<Value = AccessList> {
    vec((address(), vec(hash(), 0..=2)), 0..=2).prop_map(|items| {
        AccessList(
            items
                .into_iter()
                .map(|(address, storage_keys)| AccessListItem { address, storage_keys })
                .collect(),
        )
    })
}

/// A call to an arbitrary address or a contract creation.
fn tx_kind() -> impl Strategy<Value = TxKind> {
    prop_oneof![Just(TxKind::Create), address().prop_map(TxKind::Call)]
}

/// An arbitrary (not necessarily recoverable) ECDSA signature: transaction decoding never recovers
/// the sender.
fn signature() -> impl Strategy<Value = Signature> {
    (word(), word(), any::<bool>()).prop_map(|(r, s, y_parity)| Signature::new(r, s, y_parity))
}

/// An arbitrary EIP-7702 authorization with an arbitrary signature.
fn authorization() -> impl Strategy<Value = SignedAuthorization> {
    (word(), address(), uint(), any::<u8>(), word(), word()).prop_map(
        |(chain_id, address, nonce, y_parity, r, s)| {
            SignedAuthorization::new_unchecked(
                Authorization { chain_id, address, nonce },
                y_parity,
                r,
                s,
            )
        },
    )
}

/// A signed transaction of every type a block's `TxEnvelope` holds: legacy (pre-EIP-155 or with
/// a chain id), EIP-2930, EIP-1559, EIP-4844 without a sidecar and EIP-7702, with arbitrary
/// fields and signature.
pub(super) fn signed_transaction() -> impl Strategy<Value = TxEnvelope> {
    // Fields every type has: nonce, gas limit, value, input and the signature.
    let common = || (uint(), uint(), word(), bytes(300), signature());
    // EIP-1559-style fees: chain id, max fee and max priority fee.
    let fees = || (uint(), uint128(), uint128());
    prop_oneof![
        (common(), option::of(uint()), uint128(), tx_kind()).prop_map(
            |((nonce, gas_limit, value, input, signature), chain_id, gas_price, to)| {
                let tx = alloy_consensus::TxLegacy {
                    chain_id,
                    nonce,
                    gas_price,
                    gas_limit,
                    to,
                    value,
                    input,
                };
                TxEnvelope::Legacy(tx.into_signed(signature))
            }
        ),
        (common(), uint(), uint128(), tx_kind(), access_list()).prop_map(
            |(
                (nonce, gas_limit, value, input, signature),
                chain_id,
                gas_price,
                to,
                access_list,
            )| {
                let tx = alloy_consensus::TxEip2930 {
                    chain_id,
                    nonce,
                    gas_price,
                    gas_limit,
                    to,
                    value,
                    access_list,
                    input,
                };
                TxEnvelope::Eip2930(tx.into_signed(signature))
            }
        ),
        (common(), fees(), tx_kind(), access_list()).prop_map(
            |((nonce, gas_limit, value, input, signature), (chain_id, max_fee, tip), to, list)| {
                let tx = alloy_consensus::TxEip1559 {
                    chain_id,
                    nonce,
                    gas_limit,
                    max_fee_per_gas: max_fee,
                    max_priority_fee_per_gas: tip,
                    to,
                    value,
                    access_list: list,
                    input,
                };
                TxEnvelope::Eip1559(tx.into_signed(signature))
            }
        ),
        (common(), fees(), address(), access_list(), vec(hash(), 0..=3), uint128()).prop_map(
            |(
                (nonce, gas_limit, value, input, signature),
                (chain_id, max_fee, tip),
                to,
                access_list,
                blob_versioned_hashes,
                max_fee_per_blob_gas,
            )| {
                let tx = alloy_consensus::TxEip4844 {
                    chain_id,
                    nonce,
                    gas_limit,
                    max_fee_per_gas: max_fee,
                    max_priority_fee_per_gas: tip,
                    to,
                    value,
                    access_list,
                    blob_versioned_hashes,
                    max_fee_per_blob_gas,
                    input,
                };
                TxEnvelope::Eip4844(TxEip4844Variant::TxEip4844(tx).into_signed(signature))
            }
        ),
        (common(), fees(), address(), access_list(), vec(authorization(), 0..=2)).prop_map(
            |(
                (nonce, gas_limit, value, input, signature),
                (chain_id, max_fee, tip),
                to,
                access_list,
                authorization_list,
            )| {
                let tx = alloy_consensus::TxEip7702 {
                    chain_id,
                    nonce,
                    gas_limit,
                    max_fee_per_gas: max_fee,
                    max_priority_fee_per_gas: tip,
                    to,
                    value,
                    access_list,
                    authorization_list,
                    input,
                };
                TxEnvelope::Eip7702(tx.into_signed(signature))
            }
        ),
    ]
}
