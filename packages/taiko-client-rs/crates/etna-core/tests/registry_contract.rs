use alloy_primitives::{Address, B256, U256};
use etna_core::committee::{CommitteeError, RegistryProof, verify_snapshot};

struct Proof(usize);
impl RegistryProof for Proof {
    type Error = core::convert::Infallible;
    fn address(&self) -> Address {
        Address::ZERO
    }
    fn storage_proof_count(&self) -> usize {
        3
    }
    fn authenticate_storage(&self, _: B256, _: &[B256]) -> Result<Vec<U256>, Self::Error> {
        Ok(vec![U256::ZERO; self.0])
    }
}
#[test]
fn authenticated_word_count_is_checked_before_indexing() {
    for got in [0, 2, 4] {
        assert!(matches!(verify_snapshot(B256::ZERO, Address::ZERO, 0, &[], &Proof(got), 0),
            Err(CommitteeError::AuthenticatedWordCountMismatch { expected: 3, got: n }) if n == got));
    }
}

struct PanicsOnAuthentication;
impl RegistryProof for PanicsOnAuthentication {
    type Error = core::convert::Infallible;
    fn address(&self) -> Address {
        Address::repeat_byte(1)
    }
    fn storage_proof_count(&self) -> usize {
        panic!("wrong contract must be rejected first")
    }
    fn authenticate_storage(&self, _: B256, _: &[B256]) -> Result<Vec<U256>, Self::Error> {
        panic!("wrong contract must be rejected before authentication")
    }
}
#[test]
fn wrong_contract_is_rejected_before_proof_metadata_or_authentication() {
    assert!(matches!(
        verify_snapshot(B256::ZERO, Address::ZERO, 0, &[], &PanicsOnAuthentication, 0),
        Err(CommitteeError::WrongContract { .. })
    ));
}

struct AuthenticatedWords {
    words: Vec<U256>,
    root: B256,
    index: u64,
    has_next: bool,
}
impl RegistryProof for AuthenticatedWords {
    type Error = &'static str;
    fn address(&self) -> Address {
        Address::ZERO
    }
    fn storage_proof_count(&self) -> usize {
        if self.has_next { 4 } else { 3 }
    }
    fn authenticate_storage(&self, root: B256, slots: &[B256]) -> Result<Vec<U256>, Self::Error> {
        assert_eq!(root, self.root, "the proving root must reach the authentication backend");
        assert_eq!(slots, etna_core::committee::snapshot_slots(self.index, self.has_next));
        Ok(self.words.clone())
    }
}
#[test]
fn cutoff_selection_is_checked_after_backend_authentication() {
    // Empty historical checkpoint 0 at block 10; its successor is at block 20.
    let proof = AuthenticatedWords {
        words: vec![U256::from(2), U256::from(10), U256::ZERO, U256::from(20)],
        root: B256::repeat_byte(9),
        index: 0,
        has_next: true,
    };
    let snapshot = verify_snapshot(proof.root, Address::ZERO, 0, &[], &proof, 19).unwrap();
    assert_eq!(snapshot.l1_block, 10);
    assert!(matches!(
        verify_snapshot(proof.root, Address::ZERO, 0, &[], &proof, 9),
        Err(CommitteeError::CheckpointAfterCutoff { .. })
    ));
    assert!(matches!(
        verify_snapshot(proof.root, Address::ZERO, 0, &[], &proof, 20),
        Err(CommitteeError::NextCheckpointNotAfterCutoff { .. })
    ));
    let no_successor =
        AuthenticatedWords { words: proof.words[..3].to_vec(), has_next: false, ..proof };
    assert!(matches!(
        verify_snapshot(no_successor.root, Address::ZERO, 0, &[], &no_successor, 19),
        Err(CommitteeError::NextCheckpointMismatch { .. })
    ));
}

#[test]
fn oversized_uint48_entry_counts_are_rejected_without_pointer_width_truncation() {
    use etna_core::{committee::entries_root, types::RegistryEntry};
    let entry = RegistryEntry {
        ck_prefix: 2,
        ck_x: alloy_primitives::b256!(
            "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        ),
        eff_stake: U256::from(1_000_000_000_000_000_000u64),
        active_from_l1: 0,
        exit_effective_l1: (1 << 48) - 1,
    };
    for count in [1u64 << 32, (1u64 << 32) + 1, (1u64 << 48) - 1] {
        for entries in [vec![], vec![entry.clone()]] {
            let proof = AuthenticatedWords {
                words: vec![
                    U256::from(1),
                    (U256::from(count) << 48) | U256::from(10),
                    U256::from_be_bytes(entries_root(&entries).0),
                ],
                root: B256::repeat_byte(9),
                index: 0,
                has_next: false,
            };
            assert_eq!(
                verify_snapshot(proof.root, Address::ZERO, 0, &entries, &proof, 10),
                Err(CommitteeError::EntryCountMismatch { expected: count, got: entries.len() }),
                "count={count}, actual entries={}",
                entries.len(),
            );
        }
    }
}
