//! A planned stop on the real contracts ends consensus after the first late block.
mod support;

use abci::{RpcL1Source, l1::source::L1Source};
use alloy::sol_types::SolCall;
use alloy_provider::Provider;
use anyhow::{Context, Result};
use support::{
    ContractFixture,
    contracts::{EtnaInbox, transact},
};
use test_harness::{ContractConsensus, anvil_request, dev_signer, mine_l1_blocks};

#[tokio::test]
#[ignore = "docker"]
async fn authenticated_planned_stop_ends_real_consensus_after_the_first_late_block() -> Result<()> {
    let f = ContractFixture::deploy_config(1, 120, 6).await?;
    let p = &f.anvil.provider;
    let owner = dev_signer().address();
    let now = p
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .context("L1 head")?
        .header
        .timestamp;
    let stop_time = now + f.genesis.max_anchor_age + 10;
    transact(
        p,
        owner,
        f.inbox,
        EtnaInbox::scheduleStopCall {
            _expectedGeneration: Default::default(),
            _time: stop_time.try_into()?,
        }
        .abi_encode(),
    )
    .await?;
    anvil_request::<serde_json::Value>(
        p,
        "evm_setNextBlockTimestamp",
        serde_json::json!([stop_time]),
    )
    .await?;
    mine_l1_blocks(p, 4).await?;
    let source = RpcL1Source::new(p.clone());
    let number = source.finalized_number().await?;
    let anchor = abci::l1::verify_anchor_witness(
        &abci::AnchorWitness {
            l1_header: source.header(number).await?,
            inbox: source
                .account_witness(f.inbox, &abci::l1::layout::inbox::anchor_slots(), number)
                .await?,
        },
        f.inbox,
    )?;
    assert_eq!(abci::l1::layout::word_u48(anchor.inbox.rules_schedule, 144), stop_time);
    let dirs = vec![f.signer_storage.path().join("0")];
    let consensus =
        ContractConsensus::start(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs).await?;
    // Block 1's finalized anchor is mined at or after `stopTime`, so block 1's timestamp is too,
    // and its successor is refused at any height (START-10.1-14d).
    consensus.wait_for_height(1).await?;
    let first = f.l2.provider.get_block_by_number(1.into()).await?.context("L2 block 1")?;
    assert!(first.header.timestamp >= stop_time);
    // Three ordinary one-second commit intervals: a node ignoring the stop would pass height 1.
    tokio::time::sleep(std::time::Duration::from_secs(3)).await;
    assert_eq!(consensus.cmt.latest_height().await?, 1);
    consensus.stop().await?;
    Ok(())
}

// Independently encode the new spec ABI so old pinned bytecode produces a behavioral RED.
alloy::sol! {
    interface StakingChanges {
        function topUp(uint256 bondId, uint256 amount) external;
        function activateTopUp(uint256 bondId) external;
        function forfeit(uint256 bondId, bytes32 incidentId, uint256 validUntil) external;
        function recover(uint48 generation, uint256 c, uint256 nonce, uint256 validUntil, uint256[] exclusions, uint256[] fiToClear, uint48 rules) external;
        function recoveryNonce() external view returns (uint256);
    }
}
