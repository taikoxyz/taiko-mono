use super::*;
use alloy_primitives::address;

pub(super) fn receipt() -> Receipt {
    Receipt {
        l1ChainId: U256::from(1),
        l2ChainId: 167001,
        inbox: Address::repeat_byte(1),
        generation: 2,
        parentHeight: 3,
        parentHash: B256::repeat_byte(4),
        lastHeight: 5,
        lastBlockHash: B256::repeat_byte(6),
        l2RewardRecipient: Address::repeat_byte(7),
        baseFeeAmount: U256::from(11),
    }
}
pub(super) fn identity() -> ClaimIdentity {
    ClaimIdentity {
        landing_tx: B256::repeat_byte(9),
        batch_id: rewards::batch_id(&receipt()),
        l1_chain_id: U256::from(1),
        l2_chain_id: 167001,
        inbox: Address::repeat_byte(1),
        vault: address!("1670010000000000000000000000000000010001"),
        payer: Address::repeat_byte(8),
    }
}

#[test]
fn third_party_payer_preserves_authenticated_recipient_and_rejects_invalid_identity() {
    let id = identity();
    assert_ne!(id.payer, receipt().l2RewardRecipient);
    id.validate_receipt(&receipt()).unwrap();
    for mutate in [0, 1, 2, 3, 4] {
        let mut r = receipt();
        match mutate {
            0 => r.l2ChainId = 1,
            1 => r.inbox = Address::ZERO,
            2 => r.l2RewardRecipient = Address::ZERO,
            3 => r.lastHeight = r.parentHeight,
            _ => r.generation += 1,
        }
        assert!(id.validate_receipt(&r).is_err());
    }
}

pub(super) fn proof() -> ClaimProof {
    ClaimProof {
        receipt: receipt(),
        anchor_timestamp: 123,
        account_proof: vec![Bytes::from_static(&[1])],
        storage_proof: vec![Bytes::from_static(&[2])],
    }
}

pub(super) fn signer() -> alloy::signers::local::PrivateKeySigner {
    "0000000000000000000000000000000000000000000000000000000000000001".parse().unwrap()
}

pub(super) async fn signed(id: &ClaimIdentity, proof: &ClaimProof) -> tx::SignedClaim {
    use alloy::signers::Signer;
    use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope};
    use alloy_eips::eip2718::Encodable2718;
    let tx = TxEip1559 {
        chain_id: id.l2_chain_id,
        nonce: 3,
        gas_limit: 100_000,
        to: id.vault.into(),
        input: proof.calldata().unwrap(),
        max_fee_per_gas: 100,
        max_priority_fee_per_gas: 1,
        ..Default::default()
    };
    let sig = signer().sign_hash(&tx.signature_hash()).await.unwrap();
    let tx = tx.into_signed(sig);
    tx::SignedClaim {
        hash: *tx.hash(),
        nonce: 3,
        bytes: TxEnvelope::Eip1559(tx).encoded_2718().into(),
    }
}

#[tokio::test]
async fn signed_journal_rejects_mutation_and_preserves_original_bytes_across_reopen() {
    use store::{ClaimJob, ClaimState, ClaimStore};
    let dir = tempfile::tempdir().unwrap();
    let mut id = identity();
    id.payer = signer().address();
    let p = proof();
    let tx = signed(&id, &p).await;
    let store = ClaimStore::open(dir.path(), id.clone()).unwrap();
    let job = ClaimJob {
        state: ClaimState::Signed,
        proof: p,
        transaction: Some(tx.clone()),
        inclusion: None,
    };
    store.save(&job).unwrap();
    for kind in 0..5 {
        let mut bad = job.clone();
        match kind {
            0 => bad.proof.receipt.l2RewardRecipient = Address::repeat_byte(10),
            1 => bad.proof.anchor_timestamp += 1,
            2 => bad.transaction.as_mut().unwrap().nonce += 1,
            3 => bad.transaction.as_mut().unwrap().hash = B256::ZERO,
            _ => {
                bad.state = ClaimState::Prepared;
                bad.transaction = None;
            }
        }
        assert!(store.save(&bad).is_err());
    }
    assert!(ClaimStore::open(dir.path(), id.clone()).is_err());
    drop(store);
    let store = ClaimStore::open(dir.path(), id).unwrap();
    assert_eq!(store.load().unwrap(), Some(job));
    let bytes = std::fs::read(dir.path().join("claim-state.json")).unwrap();
    let text = String::from_utf8(bytes).unwrap();
    assert!(!text.contains("0000000000000000000000000000000000000000000000000000000000000001\""));
    let mut bad = tx;
    bad.bytes = [bad.bytes.as_ref(), &[0]].concat().into();
    assert!(bad.validate(store.identity(), &proof()).is_err());
}

#[test]
fn claim_and_landing_directories_reject_both_opening_orders_and_aliases() {
    use crate::store::{JournalIdentity, Store};
    use store::ClaimStore;
    let land_id = JournalIdentity {
        l1_chain_id: U256::from(1),
        l2_chain_id: 167001,
        inbox: Address::repeat_byte(1),
        registry: Address::repeat_byte(2),
        sender: Address::repeat_byte(8),
    };
    for claim_first in [false, true] {
        let dir = tempfile::tempdir().unwrap();
        let real = dir.path().join("real");
        std::fs::create_dir(&real).unwrap();
        #[cfg(unix)]
        let alias = {
            let alias = dir.path().join("alias");
            std::os::unix::fs::symlink(&real, &alias).unwrap();
            alias
        };
        #[cfg(not(unix))]
        let alias = real.clone();
        if claim_first {
            let c = ClaimStore::open(&real, identity()).unwrap();
            assert!(Store::open(&alias, land_id.clone()).is_err());
            drop(c);
            assert!(Store::open(&alias, land_id.clone()).is_err());
        } else {
            let l = Store::open(&real, land_id.clone()).unwrap();
            assert!(ClaimStore::open(&alias, identity()).is_err());
            drop(l);
            assert!(ClaimStore::open(&alias, identity()).is_err());
        }
    }
}

#[test]
fn corrupt_and_wrong_schema_claim_journals_stop_without_rewriting() {
    use store::ClaimStore;
    for text in ["{", r#"{"version":255}"#] {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("claim-state.json"), text).unwrap();
        assert!(ClaimStore::open(dir.path(), identity()).is_err());
        assert_eq!(std::fs::read_to_string(dir.path().join("claim-state.json")).unwrap(), text);
    }
}

#[path = "runner_tests.rs"]
mod recovery;

#[test]
fn foreign_store_rejection_does_not_create_files_in_the_landing_directory() {
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("lander-state.json");
    std::fs::write(&file, b"existing signed L1 state must remain untouched").unwrap();
    assert!(store::ClaimStore::open(dir.path(), identity()).is_err());
    assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 1);
    assert_eq!(std::fs::read(file).unwrap(), b"existing signed L1 state must remain untouched");
}

#[test]
fn simultaneous_empty_directory_creation_allows_only_one_transaction_kind() {
    use super::store::ClaimStore;
    use crate::store::{JournalIdentity, Store};
    use std::sync::Barrier;
    // A winning store remains locked until both open attempts have completed.
    for _ in 0..32 {
        let dir = tempfile::tempdir().unwrap();
        let start = Barrier::new(2);
        let hold = Barrier::new(2);
        std::thread::scope(|scope| {
            let claim = scope.spawn(|| {
                start.wait();
                let store = ClaimStore::open(dir.path(), identity());
                hold.wait();
                store.is_ok()
            });
            let landing = scope.spawn(|| {
                start.wait();
                let store = Store::open(
                    dir.path(),
                    JournalIdentity {
                        l1_chain_id: U256::from(1),
                        l2_chain_id: 167001,
                        inbox: Address::repeat_byte(1),
                        registry: Address::repeat_byte(2),
                        sender: Address::repeat_byte(8),
                    },
                );
                hold.wait();
                store.is_ok()
            });
            assert_ne!(
                claim.join().unwrap(),
                landing.join().unwrap(),
                "exactly one store kind wins the empty directory"
            );
        });
    }
}
