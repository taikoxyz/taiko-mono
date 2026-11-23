//! Fallback key lists by hash. An anchor's slot 278 and an origin record prove only a
//! `fallbackKeysHash`; the list itself comes from the node's own L1 ([`fetch_fallback_keys`]) and
//! is used only when it hashes to that value.
//!
//! The Inbox ABI around the list is etna-core's one declaration, re-exported here.

use alloy_primitives::{Address, B256};
use alloy_sol_types::SolCall;
pub use etna_core::fallback::{
    FALLBACK_KEYS_UPDATED, FallbackKey, FallbackKeys, FallbackKeysUpdated, MinTotalStakeUpdated,
    getFallbackKeysCall,
};

use crate::l1::{L1Error, L1Source};

/// The most L1 blocks one log query of [`fetch_fallback_keys`] spans, within the range limits
/// common L1 providers put on `eth_getLogs`.
pub const LOG_CHUNK_BLOCKS: u64 = 10_000;

/// Why [`fetch_fallback_keys`] obtained no list. Either way the fault is the node's own L1, not
/// the block or proposal that needs the list: a liveness-pause cause, after which the caller
/// waits and retries. It never halts the node and never makes `ProcessProposal` reject.
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum FallbackFetchError {
    /// Neither `getFallbackKeys()` at the anchor hash nor any log in the scanned blocks gave a
    /// list with the hash; the value says what was tried.
    #[error("fallback key list unavailable: {0}")]
    Unavailable(String),
    /// A log query failed.
    #[error("fallback key list log query failed: {0}")]
    L1(#[from] L1Error),
}

/// The fallback key list whose hash is `hash`, as the Inbox `inbox` stored it, for an anchor
/// whose verified L1 header has hash `at` and number `at_number`.
///
/// First `getFallbackKeys()` pinned to the block hash `at` (EIP-1898), accepted only when its
/// list hashes to `hash`. Otherwise (the Inbox has since stored another list, the data is no
/// valid list, or the call failed, as on pruned L1 state) the `FallbackKeysUpdated` logs whose
/// indexed topic is `hash`, scanned backward in queries of at most [`LOG_CHUNK_BLOCKS`] blocks
/// from `at_number` down to `from_block`: a log whose data is a valid list hashing to `hash` is
/// accepted, and any other log is skipped. All lists with one hash are the same list, so the
/// scan stops at the first chunk that holds one.
///
/// Callers pass `from_block = 0`. `L1_0` is no safe floor: on a switching network Inbox
/// initialization, which emits the first list, runs before the start write that sets `L1_0`.
/// The floor costs time only when no list exists, and a floor too high can cost liveness, never
/// safety.
///
/// When no log holds the list, [`FallbackFetchError::Unavailable`]; a failed log query is
/// [`FallbackFetchError::L1`].
pub async fn fetch_fallback_keys<L: L1Source + ?Sized>(
    l1: &L,
    inbox: Address,
    hash: B256,
    at: B256,
    at_number: u64,
    from_block: u64,
) -> Result<FallbackKeys, FallbackFetchError> {
    let call = match l1.call_at(inbox, getFallbackKeysCall {}.abi_encode().into(), at).await {
        Ok(data) => match FallbackKeys::from_abi(&data) {
            Ok(keys) if keys.hash() == hash => return Ok(keys),
            Ok(keys) => format!("it returned the list {}", keys.hash()),
            Err(error) => format!("it returned no list: {error}"),
        },
        Err(error) => format!("it failed: {error}"),
    };
    tracing::debug!(%inbox, %hash, %at, reason = %call, "getFallbackKeys() gave no matching list");

    let mut next = (from_block <= at_number).then_some(at_number);
    while let Some(to) = next {
        let from = to.saturating_sub(LOG_CHUNK_BLOCKS - 1).max(from_block);
        let logs = l1.inbox_logs(inbox, FALLBACK_KEYS_UPDATED, hash, from, to).await?;
        let found = logs
            .iter()
            .find_map(|data| FallbackKeys::from_abi(data).ok().filter(|keys| keys.hash() == hash));
        if let Some(keys) = found {
            return Ok(keys);
        }
        next = (from > from_block).then(|| from - 1);
    }
    Err(FallbackFetchError::Unavailable(format!(
        "no FallbackKeysUpdated log of {inbox} in L1 blocks {from_block}..={at_number} holds the \
         list {hash}, and getFallbackKeys() at {at}: {call}"
    )))
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Bytes, U256, keccak256};
    use alloy_sol_types::{SolCall, SolEvent, SolValue};

    use super::*;
    use crate::{
        key::ConsensusKey,
        test_utils::{L1Call, MockL1, test_key},
    };

    /// The Inbox the lists are read from.
    const INBOX: Address = Address::repeat_byte(0x1b);
    /// The anchor's L1 block hash, at which `getFallbackKeys()` is called.
    const AT: B256 = B256::repeat_byte(0xa7);
    /// The anchor's L1 block number, where the log scan starts.
    const AT_NUMBER: u64 = 35_000;

    /// The valid list of the keys of seeds `first..first + n`.
    fn list(first: u64, n: u64) -> FallbackKeys {
        let mut keys: Vec<_> = (first..first + n).map(test_key).collect();
        keys.sort();
        FallbackKeys::new(keys).unwrap()
    }

    /// The ABI entries of `keys`, in the given order.
    fn entries(keys: &[ConsensusKey]) -> Vec<FallbackKey> {
        keys.iter().map(|key| FallbackKey { ckPrefix: key.prefix(), ckX: key.x() }).collect()
    }

    /// The fallback keys hash formula over `keys`, whether or not they form a valid list.
    fn formula_hash(keys: &[FallbackKey]) -> B256 {
        let tag = B256::right_padding_from(b"ETNA_FALLBACK_KEYS_V1");
        keccak256((tag, keys.to_vec()).abi_encode_params())
    }

    /// Makes `l1`'s `getFallbackKeys()` return `keys`.
    fn answer_call(l1: &MockL1, keys: &[FallbackKey]) {
        l1.state().call_answers.insert(
            (INBOX, getFallbackKeysCall {}.abi_encode().into()),
            getFallbackKeysCall::abi_encode_returns(&keys.to_vec()).into(),
        );
    }

    /// An L1 whose `getFallbackKeys()` returns `keys`.
    fn serving(keys: &[FallbackKey]) -> MockL1 {
        let l1 = MockL1::new(AT_NUMBER);
        answer_call(&l1, keys);
        l1
    }

    /// An L1 that no longer holds the state at the anchor hash, as a pruned node.
    fn pruned() -> MockL1 {
        let l1 = MockL1::new(AT_NUMBER);
        l1.state().call_fail = Some(L1Error::Rpc("missing trie node".into()));
        l1
    }

    /// Serves an Inbox `FallbackKeysUpdated` log in L1 block `block` with `hash` as its indexed
    /// topic and `keys` as its data.
    fn emit(l1: &MockL1, block: u64, hash: B256, keys: &[FallbackKey]) {
        let event = FallbackKeysUpdated { fallbackKeysHash: hash, keys: keys.to_vec() };
        l1.insert_log(block, INBOX, [FALLBACK_KEYS_UPDATED, hash], event.encode_data().into());
    }

    /// The list `hash` names for the anchor at ([`AT`], [`AT_NUMBER`]), scanning down to block 0.
    async fn fetch(l1: &MockL1, hash: B256) -> Result<FallbackKeys, FallbackFetchError> {
        fetch_fallback_keys(l1, INBOX, hash, AT, AT_NUMBER, 0).await
    }

    #[tokio::test]
    async fn list_from_get_fallback_keys_at_the_anchor_hash() {
        let keys = list(0, 3);
        let l1 = serving(&entries(keys.keys()));
        assert_eq!(fetch(&l1, keys.hash()).await, Ok(keys));
        assert_eq!(
            l1.calls(),
            [L1Call::CallAt {
                address: INBOX,
                input: Bytes::copy_from_slice(&getFallbackKeysCall::SELECTOR),
                hash: AT,
            }],
            "one call pinned to the anchor hash and no log query"
        );
    }

    /// Inbox initialization emits the first list before the start write that sets `L1_0` (here
    /// block 100), so the scan reaches below `L1_0`.
    #[tokio::test]
    async fn list_emitted_at_initialization_is_found() {
        let keys = list(0, 2);
        let l1 = pruned();
        emit(&l1, 90, keys.hash(), &entries(keys.keys()));
        assert_eq!(fetch(&l1, keys.hash()).await, Ok(keys));
        assert_eq!(l1.log_ranges().last(), Some(&(0, 5_000)));
    }

    /// The anchor still proves list A after the Inbox replaced it with B: `getFallbackKeys()` at
    /// the anchor hash returns B, and A comes from its own log, found by its indexed hash.
    #[tokio::test]
    async fn replaced_list_is_found_by_its_indexed_hash() {
        let (a, b) = (list(0, 2), list(10, 3));
        let l1 = serving(&entries(b.keys()));
        emit(&l1, 100, a.hash(), &entries(a.keys()));
        emit(&l1, 20_000, b.hash(), &entries(b.keys()));

        assert_eq!(fetch(&l1, a.hash()).await, Ok(a.clone()));
        assert!(
            l1.calls().contains(&L1Call::InboxLogs {
                inbox: INBOX,
                topic0: FALLBACK_KEYS_UPDATED,
                topic1: a.hash(),
                from: 0,
                to: 5_000,
            }),
            "{:?}",
            l1.calls()
        );

        l1.state().calls.clear();
        assert_eq!(fetch(&l1, b.hash()).await, Ok(b));
        assert!(l1.log_ranges().is_empty(), "the stored list needs no log");
    }

    /// A log indexed under the hash whose data is another list is skipped, whether the scan
    /// meets it in an earlier chunk or next to the matching log in the same chunk.
    #[tokio::test]
    async fn event_with_data_that_hashes_elsewhere_is_skipped() {
        let (wanted, other) = (list(0, 2), list(10, 2));
        let l1 = pruned();
        for block in [30_000, 12_000, 12_002] {
            emit(&l1, block, wanted.hash(), &entries(other.keys()));
        }
        emit(&l1, 12_001, wanted.hash(), &entries(wanted.keys()));
        assert_eq!(fetch(&l1, wanted.hash()).await, Ok(wanted.clone()));
        assert_eq!(l1.log_ranges(), [(25_001, 35_000), (15_001, 25_000), (5_001, 15_000)]);

        let l1 = pruned();
        emit(&l1, 30_000, wanted.hash(), &entries(other.keys()));
        let result = fetch(&l1, wanted.hash()).await;
        assert!(matches!(result, Err(FallbackFetchError::Unavailable(_))), "{result:?}");
    }

    #[tokio::test]
    async fn logs_are_scanned_backward_in_bounded_chunks_from_the_anchor() {
        let keys = list(0, 1);
        let hash = keys.hash();
        let l1 = pruned();
        let result = fetch_fallback_keys(&l1, INBOX, hash, AT, AT_NUMBER, 1_234).await;
        assert!(matches!(result, Err(FallbackFetchError::Unavailable(_))), "{result:?}");
        assert_eq!(
            l1.log_ranges(),
            [(25_001, 35_000), (15_001, 25_000), (5_001, 15_000), (1_234, 5_000)]
        );
        for call in l1.calls().iter().skip(1) {
            assert!(
                matches!(call, L1Call::InboxLogs { inbox, topic0, topic1, .. }
                    if (*inbox, *topic0, *topic1) == (INBOX, FALLBACK_KEYS_UPDATED, hash)),
                "{call:?}"
            );
        }

        // Without a list, every range from the anchor down to the floor is queried once.
        let cases =
            [(35_000, 0), (29_999, 0), (30_000, 0), (30_000, 20_001), (7, 0), (7, 7), (0, 0)];
        for (at_number, from_block) in cases {
            let l1 = pruned();
            let result = fetch_fallback_keys(&l1, INBOX, hash, AT, at_number, from_block).await;
            assert!(matches!(result, Err(FallbackFetchError::Unavailable(_))), "{result:?}");
            let ranges = l1.log_ranges();
            assert_eq!(ranges.first().map(|range| range.1), Some(at_number), "{ranges:?}");
            assert_eq!(ranges.last().map(|range| range.0), Some(from_block), "{ranges:?}");
            for (index, (from, to)) in ranges.iter().enumerate() {
                assert!(from <= to && to - from < LOG_CHUNK_BLOCKS, "{ranges:?}");
                if index + 1 < ranges.len() {
                    assert_eq!(to - from + 1, LOG_CHUNK_BLOCKS, "only the last is short");
                    assert_eq!(ranges[index + 1].1 + 1, *from, "contiguous and descending");
                }
            }
        }

        // A floor above the anchor leaves nothing to scan.
        let l1 = pruned();
        let result = fetch_fallback_keys(&l1, INBOX, hash, AT, 10, 11).await;
        assert!(matches!(result, Err(FallbackFetchError::Unavailable(_))), "{result:?}");
        assert!(l1.log_ranges().is_empty());

        // The scan stops at the first chunk that holds a matching log.
        let l1 = pruned();
        emit(&l1, 12_000, hash, &entries(keys.keys()));
        emit(&l1, 100, hash, &entries(keys.keys()));
        assert_eq!(fetch(&l1, hash).await, Ok(keys));
        assert_eq!(l1.log_ranges(), [(25_001, 35_000), (15_001, 25_000), (5_001, 15_000)]);
    }

    #[tokio::test]
    async fn wrong_hash_call_without_a_log_is_unavailable() {
        let (wanted, stored) = (list(0, 2), list(10, 2));
        let l1 = serving(&entries(stored.keys()));
        let result = fetch(&l1, wanted.hash()).await;
        assert!(matches!(result, Err(FallbackFetchError::Unavailable(_))), "{result:?}");
        assert_eq!(l1.log_ranges().last(), Some(&(0, 5_000)), "the whole range was scanned");
    }

    /// Data that is no valid list is refused from both sources even under its own formula hash.
    #[tokio::test]
    async fn unsorted_duplicate_empty_and_129_key_data_are_unavailable() {
        let sorted = list(0, 2);
        assert_eq!(formula_hash(&entries(sorted.keys())), sorted.hash());
        let [low, high] = [sorted.keys()[0], sorted.keys()[1]];
        let mut too_many: Vec<_> = (0..129).map(test_key).collect();
        too_many.sort();
        for keys in [vec![high, low], vec![low, low], vec![], too_many] {
            let keys = entries(&keys);
            let hash = formula_hash(&keys);
            let l1 = serving(&keys);
            emit(&l1, 100, hash, &keys);
            let result = fetch(&l1, hash).await;
            assert!(
                matches!(result, Err(FallbackFetchError::Unavailable(_))),
                "{} keys: {result:?}",
                keys.len()
            );
        }
    }

    /// The declared ABI is the spec's, as the shared event and view vectors spell it: event
    /// signatures and topics, the call's selector, and an encoding of the list that is
    /// [`FallbackKeys::abi_encode`] in both the return data and the log.
    #[test]
    fn topic0_matches_the_event_signature() {
        use crate::test_utils::vectors;
        let event = "/governance_events/fallback_keys_updated";
        assert_eq!(FallbackKeysUpdated::SIGNATURE, vectors::str_at(&format!("{event}/signature")));
        assert_eq!(FallbackKeysUpdated::SIGNATURE_HASH, FALLBACK_KEYS_UPDATED);
        assert_eq!(FALLBACK_KEYS_UPDATED, vectors::b256_at(&format!("{event}/topic0")));
        let event = "/governance_events/min_total_stake_updated";
        assert_eq!(MinTotalStakeUpdated::SIGNATURE, vectors::str_at(&format!("{event}/signature")));
        assert_eq!(
            MinTotalStakeUpdated::SIGNATURE_HASH,
            vectors::b256_at(&format!("{event}/topic0"))
        );
        assert_eq!(getFallbackKeysCall::SELECTOR, keccak256("getFallbackKeys()")[..4]);
        assert_eq!(
            getFallbackKeysCall::SIGNATURE,
            vectors::str_at("/view_abi/get_fallback_keys/signature")
        );
        assert_eq!(
            format!("0x{}", alloy_primitives::hex::encode(getFallbackKeysCall::SELECTOR)),
            vectors::str_at("/view_abi/get_fallback_keys/selector")
        );

        let keys = list(0, 2);
        let log = FallbackKeysUpdated { fallbackKeysHash: keys.hash(), keys: entries(keys.keys()) }
            .encode_log_data();
        assert_eq!(log.topics(), [FALLBACK_KEYS_UPDATED, keys.hash()]);
        assert_eq!(log.data, keys.abi_encode());
        assert_eq!(
            getFallbackKeysCall::abi_encode_returns(&entries(keys.keys())),
            keys.abi_encode()
        );
        assert_eq!(
            MinTotalStakeUpdated { value: U256::MAX }.encode_data(),
            U256::MAX.to_be_bytes::<32>()
        );
    }

    /// A failed log query is the node's own L1 fault, returned as is for the caller to retry.
    #[tokio::test]
    async fn log_query_failure_is_a_node_local_fault() {
        for error in [
            L1Error::Rpc("query exceeds the block range limit".into()),
            L1Error::MalformedResponse("a log of another contract".into()),
        ] {
            let l1 = pruned();
            l1.state().log_fail = Some(error.clone());
            assert_eq!(fetch(&l1, list(0, 1).hash()).await, Err(FallbackFetchError::L1(error)));
        }
    }
}
