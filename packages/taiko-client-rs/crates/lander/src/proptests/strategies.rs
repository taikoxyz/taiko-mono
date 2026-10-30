//! Generators for the lander's properties: envelopes with arbitrary contents and transaction
//! payloads deflate shrinks to almost nothing, not at all, or worse once shifted against its block
//! boundaries.

use std::sync::LazyLock;

use abci::{
    AccountWitness, AnchorWitness, CommitteeRecord, CommitteeWitness, EtnaEnvelope, ExecutionBlock,
    ForcedWitness, RawL1Header, RegistryEntry, StorageProof,
};
use alloy_consensus::Header;
use alloy_primitives::{Address, B64, B256, Bloom, Bytes, U256};
use proptest::{collection::vec, option, prelude::*};

/// A `u64` of uniformly random bit length (0 to 64).
pub(crate) fn uint() -> impl Strategy<Value = u64> {
    (0u32..=64, any::<u64>()).prop_map(|(bits, x)| if bits == 0 { 0 } else { x >> (64 - bits) })
}

/// A `U256` of uniformly random bit length (0 to 256).
fn word() -> impl Strategy<Value = U256> {
    (0usize..=256, any::<[u8; 32]>()).prop_map(|(bits, bytes)| {
        if bits == 0 { U256::ZERO } else { U256::from_be_bytes(bytes) >> (256 - bits) }
    })
}

/// 32 arbitrary bytes.
fn hash() -> impl Strategy<Value = B256> {
    any::<[u8; 32]>().prop_map(B256::from)
}

/// Up to `max` arbitrary bytes.
pub(crate) fn bytes(max: usize) -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..=max)
}

/// `len` pseudo-random bytes (xorshift64 seeded with `seed`), which deflate cannot shrink.
pub(crate) fn noise(len: usize, seed: u64) -> Vec<u8> {
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

/// An execution header of a random fork (the first `forks` of base fee, withdrawals root, blob
/// gas used, excess blob gas, parent beacon block root and requests hash present) with arbitrary
/// values in every field. Its encoding holds almost no repeated strings, so deflate reads it as
/// about one symbol (a literal) per byte.
fn el_header() -> impl Strategy<Value = Header> {
    let roots =
        (hash(), hash(), any::<[u8; 20]>(), hash(), hash(), hash(), any::<[u8; 32]>(), hash());
    let values = (word(), uint(), uint(), uint(), uint(), bytes(40), any::<[u8; 8]>());
    let forks = (0usize..=6, uint(), hash(), uint(), uint(), hash(), hash());
    (roots, values, forks).prop_map(
        |(
            (parent_hash, ommers_hash, beneficiary, state_root, tx_root, receipts_root, bloom, mix),
            (difficulty, number, gas_limit, gas_used, timestamp, extra, nonce),
            (forks, base_fee, withdrawals_root, blob_gas_used, excess_blob_gas, beacon, requests),
        )| Header {
            parent_hash,
            ommers_hash,
            beneficiary: Address::from(beneficiary),
            state_root,
            transactions_root: tx_root,
            receipts_root,
            // 256 bytes expanded from 32 arbitrary ones, each 32-byte stretch differently.
            logs_bloom: Bloom::new(std::array::from_fn(|i| bloom[i % 32] ^ (i / 32 * 37) as u8)),
            difficulty,
            number,
            gas_limit,
            gas_used,
            timestamp,
            extra_data: extra.into(),
            mix_hash: mix,
            nonce: B64::from(nonce),
            base_fee_per_gas: (forks >= 1).then_some(base_fee),
            withdrawals_root: (forks >= 2).then_some(withdrawals_root),
            blob_gas_used: (forks >= 3).then_some(blob_gas_used),
            excess_blob_gas: (forks >= 4).then_some(excess_blob_gas),
            parent_beacon_block_root: (forks >= 5).then_some(beacon),
            requests_hash: (forks >= 6).then_some(requests),
            block_access_list_hash: None,
            slot_number: None,
        },
    )
}

/// An account witness with arbitrary fields, nodes and storage proofs.
fn account_witness() -> impl Strategy<Value = AccountWitness> {
    let storage = vec((hash(), word(), vec(bytes(120), 0..=2)), 0..=2);
    (any::<[u8; 20]>(), uint(), word(), hash(), hash(), vec(bytes(120), 0..=2), storage).prop_map(
        |(address, nonce, balance, storage_root, code_hash, account_proof, storage)| {
            AccountWitness {
                address: Address::from(address),
                nonce,
                balance,
                storage_root,
                code_hash,
                account_proof: account_proof.into_iter().map(Bytes::from).collect(),
                storage: storage
                    .into_iter()
                    .map(|(slot, value, proof)| StorageProof {
                        slot,
                        value,
                        proof: proof.into_iter().map(Bytes::from).collect(),
                    })
                    .collect(),
            }
        },
    )
}

/// An anchor witness over an arbitrary L1 header.
fn anchor_witness() -> impl Strategy<Value = AnchorWitness> {
    (el_header(), account_witness())
        .prop_map(|(header, inbox)| AnchorWitness { l1_header: RawL1Header::from(&header), inbox })
}

/// A committee witness with an arbitrary record, registry witness and up to three entries.
fn committee_witness() -> impl Strategy<Value = CommitteeWitness> {
    let record = (uint(), uint(), uint(), hash(), uint()).prop_map(
        |(target_epoch, cutoff, index, set_root, total_power)| CommitteeRecord {
            target_epoch,
            cutoff_l1_block: cutoff,
            checkpoint_index: index,
            set_root,
            total_power,
        },
    );
    let entry = (hash(), word(), uint(), uint()).prop_map(
        |(pubkey, eff_stake, active_from_l1, exit_effective_l1)| RegistryEntry {
            ck_prefix: 2,
            ck_x: pubkey,
            eff_stake,
            active_from_l1,
            exit_effective_l1,
        },
    );
    (record, account_witness(), vec(entry, 0..=3))
        .prop_map(|(record, registry, entries)| CommitteeWitness { record, registry, entries })
}

/// A forced inclusion witness whose transaction is short arbitrary bytes or pseudo-random bytes
/// of up to the 8192-byte limit.
fn forced_witness() -> impl Strategy<Value = ForcedWitness> {
    let tx = prop_oneof![
        bytes(64),
        (0..=abci::forced::MAX_FORCED_TX_BYTES, any::<u64>())
            .prop_map(|(len, seed)| noise(len, seed)),
    ];
    (uint(), account_witness(), tx).prop_map(|(index, entry, tx)| ForcedWitness {
        index,
        entry,
        tx: tx.into(),
    })
}

/// An envelope carrying `transactions`, with an arbitrary execution header and each witness
/// absent or arbitrary: the codec carries envelopes opaquely and only checks that they decode.
pub(crate) fn envelope_with(
    transactions: impl Strategy<Value = Vec<Vec<u8>>>,
) -> impl Strategy<Value = EtnaEnvelope> {
    (
        el_header(),
        transactions,
        option::of(anchor_witness()),
        option::of(committee_witness()),
        option::of(forced_witness()),
    )
        .prop_map(|(header, transactions, anchor, committee, forced)| EtnaEnvelope {
            block: ExecutionBlock {
                header,
                transactions: transactions.into_iter().map(Bytes::from).collect(),
            },
            anchor,
            committee,
            forced,
        })
}

/// The length of one deflate-boundary run: one deflate symbol buffer of literals.
const RUN: usize = 16_383;

/// Nine runs of [`boundary_runs`], from which [`Payload::Boundary`] takes slices.
static BOUNDARY_RUNS: LazyLock<Vec<u8>> = LazyLock::new(|| boundary_runs(9));

/// `runs` runs of [`RUN`] bytes, alternating between the even and the odd byte values, with no
/// three-byte string repeated within deflate's window, so deflate emits only literals: a block
/// costs about 7 bits a byte when it covers one run and 8 when it straddles two. Shifting the
/// runs against deflate's block boundaries, as the payload list's framing before an execution
/// block does, therefore changes the output by kilobytes.
fn boundary_runs(runs: usize) -> Vec<u8> {
    let mut state = 0x9e37_79b9_7f4a_7c15u64;
    let mut next = || {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        state
    };
    let mut out = Vec::with_capacity(runs * RUN);
    let mut seen = std::collections::HashMap::<[u8; 3], usize>::new();
    for run in 0..runs {
        for _ in 0..RUN {
            loop {
                let byte = ((next() % 128) as u8) * 2 + (run % 2) as u8;
                if let [.., a, b] = out[..] {
                    let at = out.len();
                    if seen.get(&[a, b, byte]).is_some_and(|p| at - p < 40_000) {
                        continue;
                    }
                    seen.insert([a, b, byte], at);
                }
                out.push(byte);
                break;
            }
        }
    }
    out
}

/// One transaction's bytes, described compactly so that cases generate and shrink cheaply.
#[derive(Clone, Debug)]
pub(crate) enum Payload {
    /// `len` pseudo-random bytes, which deflate cannot shrink.
    Noise {
        /// The length in bytes.
        len: usize,
        /// The pseudo-random seed.
        seed: u64,
    },
    /// Runs of one repeated byte (`(byte, length)`), which deflate shrinks to almost nothing.
    Runs(Vec<(u8, usize)>),
    /// `len` (at least 16) bytes of [`boundary_runs`] whose run boundaries fall `shift` bytes
    /// after deflate's block boundaries when the envelope carrying them is compressed on its own
    /// ([`Payload::fill`]). A small shift is the crafted case: the envelope alone deflates
    /// cheaply, while the payload list's framing before it moves the run boundaries into
    /// deflate's blocks.
    Boundary {
        /// The run boundaries' offset after deflate's block boundaries, in bytes.
        shift: usize,
        /// The length in bytes.
        len: usize,
    },
}

impl Payload {
    /// Makes this payload `envelope`'s first transaction.
    ///
    /// Deflate-boundary runs are aligned against the transaction's offset in the encoded
    /// envelope, counting each byte before it as one deflate symbol (a literal), as for the
    /// execution headers [`envelope_with`] generates.
    pub(crate) fn fill(&self, envelope: &mut EtnaEnvelope) {
        let bytes = match self {
            Self::Noise { len, seed } => noise(*len, *seed),
            Self::Runs(runs) => runs.iter().flat_map(|(byte, len)| vec![*byte; *len]).collect(),
            Self::Boundary { shift, len } => {
                envelope.block.transactions[0] = vec![0; *len].into();
                let offset = first_transaction_offset(envelope);
                let start = (offset % RUN + RUN - shift % RUN) % RUN;
                BOUNDARY_RUNS[start..start + len].to_vec()
            }
        };
        envelope.block.transactions[0] = bytes.into();
    }
}

/// The offset of the bytes of `envelope`'s first transaction (at least 16 bytes long) in its
/// encoding.
fn first_transaction_offset(envelope: &EtnaEnvelope) -> usize {
    const MARKER: &[u8; 16] = b"first tx  marker";
    let mut marked = envelope.clone();
    let mut tx = marked.block.transactions[0].to_vec();
    tx[..MARKER.len()].copy_from_slice(MARKER);
    marked.block.transactions[0] = tx.into();
    let encoded = marked.encode();
    encoded.windows(MARKER.len()).position(|window| window == MARKER).expect("the marker")
}

/// A transaction payload sized by `max`: up to `max` bytes of noise, up to twice that of
/// repeated-byte runs, or deflate-boundary runs (up to `max` bytes, but at least 32 and at most
/// eight runs) at any alignment or, most often, crafted: shifted by at most 600 bytes and at least
/// half as long as the most that fits.
pub(crate) fn payload(max: usize) -> impl Strategy<Value = Payload> {
    let boundary = max.clamp(32, 8 * RUN);
    prop_oneof![
        1 => (0..=max, any::<u64>()).prop_map(|(len, seed)| Payload::Noise { len, seed }),
        1 => vec((any::<u8>(), 1..=max / 4 + 1), 1..=8).prop_map(Payload::Runs),
        1 => (0..RUN, 16..=boundary).prop_map(|(shift, len)| Payload::Boundary { shift, len }),
        2 => (0..=600usize, boundary / 2..=boundary)
            .prop_map(|(shift, len)| Payload::Boundary { shift, len }),
    ]
}
