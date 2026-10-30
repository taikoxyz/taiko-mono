//! Authenticated registry snapshots across delayed principal changes and DAO recovery.
mod support;

use abci::{
    RpcL1Source, Schedule, build_committee_record,
    committee::verify_committee_witness_at_cutoff,
    l1::{fetch::build_committee_witness_at_cutoff, source::L1Source},
};
use alloy::sol_types::SolCall;
use alloy_primitives::{B256, U256, keccak256};
use anyhow::Result;
use support::{
    ContractFixture,
    contracts::{EtnaInbox, EtnaStakingRegistry, TestERC20, transact, view},
};
use test_harness::{ContractConsensus, dev_signer, mine_l1_blocks};

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
    let f = ContractFixture::deploy_config(3, 120, 6).await?;
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
    let dirs = (0..3).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut consensus =
        ContractConsensus::start(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs).await?;
    let schedule = Schedule::from_genesis(&f.genesis);
    // Pause one third of the original power after S(1). HRS/WAL remain intact; the
    // already-derived epoch-1 set must survive activation while consensus is paused.
    consensus.wait_for_height(schedule.h_first(1) - 2).await?;
    consensus.stop_node(0).await?;
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
    consensus.restart_node(0).await?;
    consensus.wait_for_height(schedule.h_first(2)).await?;
    let member_powers = |members: &[abci::Member]| {
        members.iter().map(|m| (m.pubkey, m.power)).collect::<std::collections::BTreeMap<_, _>>()
    };
    for peer in &consensus.peers {
        let old = peer.validators(Some(schedule.h_first(1))).await?;
        let new = peer.validators(Some(schedule.h_first(2))).await?;
        assert_eq!(
            old.into_iter()
                .map(|m| (m.pubkey, m.power))
                .collect::<std::collections::BTreeMap<_, _>>(),
            member_powers(&original.members)
        );
        assert_eq!(
            new.into_iter()
                .map(|m| (m.pubkey, m.power))
                .collect::<std::collections::BTreeMap<_, _>>(),
            member_powers(&active.members)
        );
    }

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
    let removal_epoch = schedule.epoch_of(consensus.cmt.latest_height().await?) + 2;
    consensus.wait_for_height(schedule.h_first(removal_epoch)).await?;
    for peer in &consensus.peers {
        let selected = peer.validators(Some(schedule.h_first(removal_epoch))).await?;
        assert_eq!(
            selected
                .into_iter()
                .map(|m| (m.pubkey, m.power))
                .collect::<std::collections::BTreeMap<_, _>>(),
            member_powers(&remaining.members)
        );
    }
    consensus.stop().await?;

    let recovery = StakingChanges::recoverCall {
        generation: Default::default(),
        c: U256::ZERO,
        nonce: U256::ZERO,
        validUntil: U256::MAX,
        exclusions: vec![],
        fiToClear: vec![],
    }
    .abi_encode();
    let recovered = transact(p, owner, f.inbox, recovery.clone()).await?;
    assert_eq!(view(p, f.inbox, StakingChanges::recoveryNonceCall {}, None).await?, U256::from(1));
    assert_eq!(view(p, f.inbox, EtnaInbox::recoveryGenerationCall {}, None).await?, 1);
    assert!(transact(p, owner, f.inbox, recovery).await.is_err());
    let r = recovered.block_number.unwrap();
    mine_l1_blocks(p, 3).await?;
    assert!(source.finalized_number().await? >= r);
    let header = source.header(r).await?;
    let witness = build_committee_witness_at_cutoff(&source, &f.params, r, r, 0).await?;
    let (record, recovered_members) =
        verify_committee_witness_at_cutoff(header.state_root(), r, &f.params, &witness, 0)?;
    assert_eq!(record.cutoff_l1_block, r);
    assert_eq!(record.target_epoch, 0); // c = 0, hence floor(c / L) = 0.
    assert_eq!(member_powers(&recovered_members), member_powers(&remaining.members));
    assert!(recovered_members.iter().all(|m| m.pubkey != key));
    f.l2.stop().await?;
    f.anvil.stop().await
}
