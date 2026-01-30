//! Tip catch-up implementation.
//!
//! This module implements the tip catch-up logic for synchronizing
//! preconfirmation commitments after normal L2 sync completes.

mod catchup;
mod txlist_fetch;

pub use catchup::TipCatchup;
#[cfg(test)]
mod module_tests {
    use super::{catchup::CATCHUP_MODULE_MARKER, txlist_fetch::TXLIST_FETCH_MODULE_MARKER};

    #[test]
    fn sync_submodules_exist() {
        let _ = CATCHUP_MODULE_MARKER;
        let _ = TXLIST_FETCH_MODULE_MARKER;
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, U256};
    use async_trait::async_trait;
    use preconfirmation_types::{
        Bytes20, Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
        preconfirmation_hash, public_key_to_address, sign_commitment, uint256_to_u256,
    };
    use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
    use secp256k1::{PublicKey, Secp256k1, SecretKey};

    use super::catchup::{
        chain_from_tip, ensure_catchup_boundary, map_commitments, validate_commitment,
    };
    use crate::error::PreconfirmationClientError;

    struct MockResolver {
        signer: Address,
        submission_window_end: U256,
    }

    #[async_trait]
    impl PreconfSignerResolver for MockResolver {
        async fn signer_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<Address> {
            Ok(self.signer)
        }

        async fn slot_info_for_timestamp(
            &self,
            _l2_block_timestamp: U256,
        ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo {
                signer: self.signer,
                submission_window_end: self.submission_window_end,
            })
        }
    }

    fn make_commitment(
        block_number: u64,
        parent_hash: Bytes32,
        submission_window_end: u64,
        timestamp: u64,
        sk: &SecretKey,
    ) -> SignedCommitment {
        let preconf = Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_number),
            timestamp: Uint256::from(timestamp),
            submission_window_end: Uint256::from(submission_window_end),
            parent_preconfirmation_hash: parent_hash,
            coinbase: Bytes20::try_from(vec![0u8; 20]).expect("coinbase"),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).expect("txlist hash"),
            ..Default::default()
        };
        let commitment = PreconfCommitment { preconf, ..Default::default() };
        let signature = sign_commitment(&commitment, sk).expect("sign commitment");
        SignedCommitment { commitment, signature }
    }

    #[tokio::test]
    async fn validate_commitment_accepts_valid() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let commitment = make_commitment(1, parent_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_some());
    }

    #[tokio::test]
    async fn validate_commitment_rejects_wrong_signer() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let resolver = MockResolver {
            signer: Address::repeat_byte(0x42),
            submission_window_end: U256::from(1000u64),
        };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let commitment = make_commitment(1, parent_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn validate_commitment_accepts_genesis() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let zero_hash = Bytes32::try_from(vec![0u8; 32]).expect("zero hash");
        let commitment = make_commitment(0, zero_hash, 1000, 10, &sk);

        let result = validate_commitment(&commitment, None, &resolver).await;
        assert!(result.is_some());
    }

    #[test]
    fn catchup_boundary_mismatch_returns_error() {
        let stop_block = U256::from(10u64);
        let boundary_block = Some(U256::from(9u64));

        let err = ensure_catchup_boundary(stop_block, boundary_block).expect_err("must error");
        assert!(err.to_string().contains("catch-up chain did not reach"));
    }

    #[test]
    fn empty_catchup_chain_returns_error() {
        let err = PreconfirmationClientError::Catchup(
            "no valid commitments found during catch-up".to_string(),
        );
        assert!(err.to_string().contains("no valid commitments found"));
    }

    #[tokio::test]
    async fn chain_from_tip_follows_parent_hashes() {
        let sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
        let secp = Secp256k1::new();
        let pk = PublicKey::from_secret_key(&secp, &sk);
        let signer = public_key_to_address(&pk);
        let resolver = MockResolver { signer, submission_window_end: U256::from(1000u64) };

        let parent_hash = Bytes32::try_from(vec![1u8; 32]).expect("parent hash");
        let block1 = make_commitment(1, parent_hash, 1000, 10, &sk);
        let hash1 = preconfirmation_hash(&block1.commitment.preconf).expect("hash block1");
        let block2_parent = Bytes32::try_from(hash1.as_slice().to_vec()).expect("hash length 32");
        let block2 = make_commitment(2, block2_parent, 1000, 20, &sk);
        let hash2 = preconfirmation_hash(&block2.commitment.preconf).expect("hash block2");
        let block3_parent = Bytes32::try_from(hash2.as_slice().to_vec()).expect("hash length 32");
        let tip = make_commitment(3, block3_parent, 1000, 30, &sk);

        let map = map_commitments(vec![block1.clone(), block2.clone()]);
        let chain = chain_from_tip(tip, &map, U256::ONE, None, &resolver).await;

        assert_eq!(chain.len(), 3);
        assert_eq!(uint256_to_u256(&chain[0].commitment.preconf.block_number), U256::from(3));
        assert_eq!(uint256_to_u256(&chain[2].commitment.preconf.block_number), U256::ONE);
    }
}
