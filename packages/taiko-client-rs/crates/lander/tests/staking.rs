//! Authenticated registry snapshots across delayed principal changes and DAO recovery.
mod support;

use abci::{RpcL1Source, build_committee_record};
use alloy::sol_types::SolCall;
use alloy_primitives::{B256, U256, keccak256};
use anyhow::Result;
use support::{
    ContractFixture,
    contracts::{EtnaInbox, EtnaStakingRegistry, TestERC20, transact, view},
};
use test_harness::{dev_signer, mine_l1_blocks};

// Independently encode the new spec ABI so old pinned bytecode produces a behavioral RED.
alloy::sol! {
    interface StakingChanges {
        function topUp(uint256 bondId, uint256 amount) external;
        function activateTopUp(uint256 bondId) external;
        function forfeit(uint256 bondId, bytes32 entryKey, bytes32 incidentId, uint256 validUntil) external;
        struct Exclusion { uint256 bondId; bytes32 entryKey; }
        function recover(uint48 generation, uint256 c, uint256 nonce, uint256 validUntil, Exclusion[] exclusions, uint256[] fiToClear) external;
        function recoveryNonce() external view returns (uint256);
    }
}

#[tokio::test]
#[ignore = "docker"]
async fn delayed_top_up_and_forfeiture_change_only_later_authenticated_committees() -> Result<()> {
    let f = ContractFixture::deploy_validators(3).await?;
    let p = &f.anvil.provider;
    let owner = dev_signer().address();
    let source = RpcL1Source::new(p.clone());
    let report = |cutoff| build_committee_record(&source, &f.params, cutoff, None);
    let original = report(f.genesis.genesis_cutoff).await?;
    let token = view(p, f.registry, EtnaStakingRegistry::tokenCall {}, None).await?;
    let extra = f.entry.eff_stake;
    transact(p, owner, token, TestERC20::mintCall { to: owner, amount: extra }.abi_encode())
        .await?;
    transact(
        p,
        owner,
        token,
        TestERC20::approveCall { spender: f.registry, amount: extra }.abi_encode(),
    )
    .await?;
    let deposited = transact(
        p,
        owner,
        f.registry,
        StakingChanges::topUpCall { bondId: U256::ZERO, amount: extra }.abi_encode(),
    )
    .await?;
    let deposit_height = deposited.block_number.unwrap();
    mine_l1_blocks(p, 3).await?;
    let pending = report(deposit_height).await?;
    assert_eq!(pending.members, original.members);
    assert_eq!(pending.selected_eff_stake, original.selected_eff_stake);
    let activated = transact(
        p,
        f.admin,
        f.registry,
        StakingChanges::activateTopUpCall { bondId: U256::ZERO }.abi_encode(),
    )
    .await?;
    let active_height = activated.block_number.unwrap();
    mine_l1_blocks(p, 3).await?;
    let active = report(active_height).await?;
    assert_eq!(active.selected_eff_stake, original.selected_eff_stake + extra);
    assert_eq!(report(deposit_height).await?.members, original.members);
    assert_eq!(original.record.total_power * 4, active.record.total_power * 3);

    let key = f.keys[0].pubkey();
    let mut encoded = [0u8; 64];
    encoded[31] = key.as_bytes()[0];
    encoded[32..].copy_from_slice(&key.as_bytes()[1..]);
    let entry_key = keccak256(encoded);
    let forfeited = transact(
        p,
        owner,
        f.registry,
        StakingChanges::forfeitCall {
            bondId: U256::ZERO,
            entryKey: entry_key,
            incidentId: B256::repeat_byte(42),
            validUntil: U256::MAX,
        }
        .abi_encode(),
    )
    .await?;
    let exclusion_height = forfeited.block_number.unwrap();
    mine_l1_blocks(p, 3).await?;
    let remaining = report(exclusion_height).await?;
    assert_eq!(remaining.members.len(), 2);
    assert_eq!(remaining.selected_eff_stake, extra * U256::from(2));
    assert!(remaining.members.iter().all(|m| m.pubkey != key));
    assert_eq!(report(active_height).await?.members, active.members);

    let recovery = StakingChanges::recoverCall {
        generation: Default::default(),
        c: U256::ZERO,
        nonce: U256::ZERO,
        validUntil: U256::MAX,
        exclusions: vec![],
        fiToClear: vec![],
    }
    .abi_encode();
    transact(p, owner, f.inbox, recovery.clone()).await?;
    assert_eq!(view(p, f.inbox, StakingChanges::recoveryNonceCall {}, None).await?, U256::from(1));
    assert_eq!(view(p, f.inbox, EtnaInbox::recoveryGenerationCall {}, None).await?, 1);
    assert!(transact(p, owner, f.inbox, recovery).await.is_err());
    f.l2.stop().await?;
    f.anvil.stop().await
}
