//! Actual governance recovery from a settled checkpoint with stock consensus and pinned EL.
#[path = "../../../crates/lander/tests/support/mod.rs"]
mod contracts_support;
mod support {
    pub mod checkpoint_import;
    pub mod recovery;
}
use alloy_eips::{BlockNumberOrTag, eip2718::Encodable2718};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use contracts_support::ContractFixture;
use std::fs;
use support::recovery::{
    Commands, Liveness, recover_and_finalize, recover_with_lists, snapshot, wait_checkpoint,
    wait_committed,
};
use test_harness::{ContractConsensus, mine_l1_blocks, set_interval_mining};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_command_produces_and_lands() -> Result<()> {
    checkpoint_roundtrip(8, false, false).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_l7_overlap_preserves_global_grid() -> Result<()> {
    checkpoint_roundtrip(7, false, false).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_l6_blanks_fi_and_lands_epoch_boundary() -> Result<()> {
    checkpoint_roundtrip(6, true, false).await
}

/// Imports a delayed generation-one full node at the fixed recovery origin (s = 6: no app state,
/// InitChain builds it) and at a later landing (s = 12: an ordinary import), and runs each as an
/// ordinary node.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn checkpoint_import_recovered_fixed_and_landed_points_continue_stock() -> Result<()> {
    checkpoint_roundtrip(8, false, true).await
}

async fn checkpoint_roundtrip(epoch_len: u64, clear_fi: bool, with_import: bool) -> Result<()> {
    test_harness::init_tracing();
    let f = ContractFixture::deploy_config(1, 120, epoch_len).await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let mut c = ContractConsensus::start_native(
        f.anvil.http.clone(),
        &f.l2,
        f.params.clone(),
        vec![f.signer_storage.path().join("0")],
    )
    .await?;
    let mut commands = Commands::new(&f, &c)?;
    if with_import {
        support::checkpoint_import::enable_recovery_archive(&mut commands)?;
    }
    let result: Result<()> =
        async {
            c.wait_for_height(6).await?;
            let mut original_lander = commands.old_lander(&f, &c.cmt)?;
            wait_checkpoint(&f, &mut original_lander, 6).await?;
            original_lander.stop().await?;
            assert_eq!(f.checkpoint().await?.0, 6, "real original landing at c6");
            mine_l1_blocks(&f.anvil.provider, 3).await?;
            c.wait_for_height(9).await?;
            let mut old_blocks = vec![];
            if epoch_len == 8 {
                for height in 1..=6 {
                    old_blocks.push(c.cmt.envelope(height).await?.block);
                }
            }
            c.stop_node(0).await?;
            let old_head =
                f.l2.provider
                    .get_block_by_number(BlockNumberOrTag::Latest)
                    .await?
                    .context("old EL head")?
                    .header;
            assert!(old_head.number > 6);
            let old_seven =
                f.l2.provider
                    .get_block_by_number(7.into())
                    .await?
                    .context("old block7")?
                    .header
                    .hash;
            let old_hrs_path = f.signer_storage.path().join("0/state.json");
            let old_key_path = f.signer_storage.path().join("0/key.json");
            let old_wal_path = c.comet_home(0).join("data/cs.wal/wal");
            let old_hrs = fs::read(&old_hrs_path)?;
            let old_key = fs::read(&old_key_path)?;
            let old_wal = fs::read(&old_wal_path)?;
            if clear_fi {
                f.save_forced_inclusion(&[0xc0]).await?;
            }
            let first_fi = if !clear_fi {
                let raw = test_harness::sign_transfer(
                    &f.l2.provider,
                    &test_harness::dev_signer(),
                    alloy_primitives::Address::repeat_byte(0x92),
                    alloy_primitives::U256::from(456),
                    f.l2.provider
                        .get_transaction_count(test_harness::dev_signer().address())
                        .await?,
                )
                .await?
                .encoded_2718();
                f.save_forced_inclusion(&raw).await?;
                Some(raw)
            } else {
                None
            };
            recover_with_lists(
                &f,
                0,
                6,
                vec![],
                if clear_fi { vec![alloy_primitives::U256::ZERO] } else { vec![] },
            )
            .await?;
            let plan = commands.prepare_command(1).await?;
            assert_eq!(
                f.l2.provider
                    .get_block_by_number(BlockNumberOrTag::Latest)
                    .await?
                    .unwrap()
                    .header
                    .hash,
                old_head.hash,
                "prepare leaves old canonical suffix intact"
            );
            if epoch_len == 8 {
                build_unpromoted_origin_candidate(&f, old_head.hash).await?;
            }
            // The operator's restart on fresh stores: install, then app, supervisor and lander.
            let installed = commands.install_command(&plan, "first").await?;
            let mut node = commands.start_recovered(&installed, 1, "first").await?;
            wait_committed(&c.cmt, 7, &mut node).await?;
            node.running()?;
            let private_trust = commands.private_trust(&installed).await?;
            assert_eq!(private_trust["schema_version"], 1);
            assert_eq!(private_trust["generation"], 1);
            assert_eq!(private_trust["phase"], "ready");
            assert_eq!(private_trust["recovery_origin"]["height"], 6);
            let first = c.cmt.call("block", &[("height", "7".into())]).await?;
            let first_comet: tendermint::Block = serde_json::from_value(first["block"].clone())?;
            assert_eq!(first_comet.header.height.value(), 7);
            assert!(first_comet.header.last_block_id.is_none());
            assert!(first_comet.last_commit.is_none());
            let envelope = c.cmt.envelope(7).await?;
            if let Some(raw) = &first_fi {
                let transaction = alloy_primitives::keccak256(raw);
                let receipt = tokio::time::timeout(std::time::Duration::from_secs(90), async {
                    loop {
                        node.running()?;
                        if let Some(receipt) =
                            f.l2.provider.get_transaction_receipt(transaction).await?
                        {
                            return Ok::<_, anyhow::Error>(receipt);
                        }
                        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                    }
                })
                .await??;
                let height = receipt.block_number.context("first recovered FI trial height")?;
                assert!(receipt.status());
                assert!(height >= 7);
                let trial = c.cmt.envelope(height).await?;
                eprintln!(
                    "actual FI trial: L={epoch_len} height={height} anchor={}",
                    abci::rules::decode_extra_data(&trial.block.header.extra_data)?.2
                );
                assert_eq!(
                    trial.block.transactions.first().map(|tx| tx.as_ref()),
                    Some(raw.as_slice()),
                    "first recovered FI trial includes the authenticated transaction"
                );
            }
            let recovered_committed_hash = envelope.block.header.hash_slow();
            assert_ne!(recovered_committed_hash, old_seven);
            assert_eq!(
                f.l2.provider.get_block_by_number(7.into()).await?.unwrap().header.hash,
                recovered_committed_hash
            );
            wait_checkpoint(&f, &mut node, 12).await?;
            mine_l1_blocks(&f.anvil.provider, 3).await?;
            let source = lander::l1::RpcLandingSource::new(
                f.anvil.provider.clone(),
                f.l2.provider.clone(),
                f.params.clone(),
            );
            use lander::l1::LandingSource;
            let landed = source.snapshot().await?;
            assert_eq!(landed.generation, 1);
            assert!(landed.checkpoint_height > 6);
            let origin = landed.recovery.as_ref().context("authenticated recovery origin")?;
            assert_eq!(origin.committee.record.target_epoch, 6 / epoch_len);
            assert_eq!(origin.committee.record.cutoff_l1_block, origin.l1_number);
            assert_eq!(origin.committee.members, f.committee.members);
            assert_eq!(origin.forced_cursor, 0);
            if first_fi.is_some() {
                assert_eq!(
                    landed.forced_inclusion_head, 1,
                    "first recovered FI trial advances the landed cursor"
                );
            }
            eprintln!(
                "first recovered witness: L={epoch_len} height=7 R={} consumed={}",
                origin.l1_number,
                envelope.anchor.as_ref().unwrap().l1_header.number()
            );
            assert!(
                envelope
                    .anchor
                    .as_ref()
                    .context("first recovered anchor witness")?
                    .l1_header
                    .number() >=
                    origin.l1_number
            );
            for height in 7..=landed.checkpoint_height {
                if let Some(anchor) = c.cmt.envelope(height).await?.anchor {
                    assert!(
                        anchor.l1_header.number() >= origin.l1_number,
                        "every newly consumed root stays at or above R"
                    );
                }
            }
            if clear_fi {
                use contracts_support::contracts::{EtnaInbox, view};
                let entry = view(
                    &f.anvil.provider,
                    f.inbox,
                    EtnaInbox::getForcedInclusionCall { _index: 0u64.try_into()? },
                    None,
                )
                .await?;
                assert_eq!(entry.txHash, alloy_primitives::keccak256([]));
                assert_eq!(
                    f.forced_inclusion_state().await?,
                    (0, 1),
                    "blank entry stays pending until the unchanged FI delay elapses"
                );
            }
            if with_import {
                support::checkpoint_import::recovered(&f, &c, &commands, &installed, &old_blocks)
                    .await?;
                node.stop().await?;
                assert_eq!(fs::read(old_hrs_path)?, old_hrs);
                assert_eq!(fs::read(old_key_path)?, old_key);
                assert_eq!(fs::read(old_wal_path)?, old_wal);
                return Ok(());
            }
            if epoch_len == 8 {
                support::recovery::full_node::join_after_landing(&f, &c, &old_blocks).await?;
            }
            node.stop().await?;
            assert_eq!(fs::read(old_hrs_path)?, old_hrs);
            assert_eq!(fs::read(old_key_path)?, old_key);
            assert_eq!(fs::read(old_wal_path)?, old_wal);
            let dummy: serde_json::Value = serde_json::from_slice(&fs::read(
                installed.home.join("data/priv_validator_state.json"),
            )?)?;
            assert_eq!(dummy["height"], "0", "stock local dummy never signs");
            // An ordinary restart of the same stores, as after any operator stop.
            f.l2.restart().await?;
            let mut restarted = commands.start_recovered(&installed, 1, "restart").await?;
            wait_committed(&c.cmt, 14, &mut restarted).await?;
            let canonical_restarted_hash =
                f.l2.provider.get_block_by_number(7.into()).await?.unwrap().header.hash;
            assert_eq!(canonical_restarted_hash, recovered_committed_hash);
            restarted.stop().await?;
            ensure!(
                installed.app.join(abci::store::STATE_FILE).is_file(),
                "real recovered app store"
            );
            Ok(())
        }
        .await;
    if result.is_err() {
        commands.diagnostics();
        f.anvil.dump_logs();
    }
    c.stop().await?;
    result
}

async fn build_unpromoted_origin_candidate(
    f: &ContractFixture,
    old_head: alloy_primitives::B256,
) -> Result<()> {
    use abci::{
        Engine, L1Source,
        rules::{self, HeaderInputs},
    };
    use alloy_rlp::Decodable;
    use lander::l1::LandingSource;
    let snapshot = lander::l1::RpcLandingSource::new(
        f.anvil.provider.clone(),
        f.l2.provider.clone(),
        f.params.clone(),
    )
    .snapshot()
    .await?;
    let origin = snapshot.recovery.context("authenticated origin for actual EL probe")?;
    let bytes = snapshot.recovery_witness.context("authenticated recovery evidence")?;
    let witness = abci::RecoveryWitness::decode(&mut bytes.as_ref())?;
    let parent = abci::recovery::recovery_parent(&witness);
    let anchor_proof = abci::RpcL1Source::new(f.anvil.provider.clone())
        .account_witness(
            f.inbox,
            &abci::l1::layout::inbox::anchor_slots(),
            snapshot.l1_header.number(),
        )
        .await?;
    let anchor = abci::l1::verify_anchor_witness(
        &abci::AnchorWitness { l1_header: snapshot.l1_header, inbox: anchor_proof },
        f.inbox,
    )?;
    assert!(anchor.number >= origin.l1_number);
    let expected = rules::expected_header(&HeaderInputs {
        height: origin.height + 1,
        parent: &parent,
        anchor: &anchor,
        bft_time_secs: anchor.timestamp,
        generation: origin.generation,
        beneficiary: f.params.fee_recipient,
        params: &f.params,
        min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(f.params.l2_chain_id),
    })?;
    // All old writers are already stopped. This normal provided-list build creates a real
    // candidate on c without importing it or changing the pinned EL's unwind configuration.
    let candidate =
        f.l2.engine()?
            .build_block(
                origin.el_hash,
                rules::payload_attributes(
                    &expected,
                    anchor.hash,
                    Some(alloy_primitives::Bytes::from_static(&[0xc0])),
                ),
            )
            .await?;
    rules::check_header(&candidate.header, &expected)?;
    assert!(candidate.transactions.is_empty());
    assert_eq!(
        f.l2.provider.get_block_by_number(BlockNumberOrTag::Latest).await?.unwrap().header.hash,
        old_head,
        "building on c must leave the old canonical suffix above c intact until Commit"
    );
    eprintln!(
        "actual unpromoted candidate: parent={} old canonical head retained={old_head}",
        origin.height
    );
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_zero_origin_and_second_generation_preserve_archives() -> Result<()> {
    test_harness::init_tracing();
    let f = ContractFixture::deploy_config(1, 120, 8).await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let mut c = ContractConsensus::start_native(
        f.anvil.http.clone(),
        &f.l2,
        f.params.clone(),
        vec![f.signer_storage.path().join("0")],
    )
    .await?;
    let mut commands = Commands::new(&f, &c)?;
    commands.origin = 0;
    c.stop_node(0).await?;
    let old_state = f.signer_storage.path().join("0/state.json");
    let old_hrs = fs::read(&old_state)?;
    let old_wal = fs::read(c.comet_home(0).join("data/cs.wal/wal"))?;
    let result: Result<()> = async {
        recover_and_finalize(&f, 0, 0).await?;
        // Generation one runs without a lander, so nothing lands before the second recovery.
        commands.lander = false;
        let first_plan = commands.prepare_command(1).await?;
        let first_installed = commands.install_command(&first_plan, "g1").await?;
        let mut first =
            commands.start_recovered(&first_installed, 1, "generation-one-zero").await?;
        wait_committed(&c.cmt, 1, &mut first).await?;
        first.stop().await?;
        assert_eq!(f.checkpoint().await?.0, 0, "no landing before second recovery");
        let first_domain = archived_domain_states(&f)?;
        assert!(!first_domain.is_empty());
        let first_stores = snapshot(&[&first_installed.home, &first_installed.app])?;
        assert!(first_stores.iter().any(|(path, _)| path.ends_with("data/cs.wal/wal")));
        recover_and_finalize(&f, 1, 0).await?;
        commands.lander = true;
        let second_plan = commands.prepare_command(2).await?;
        assert_ne!(fs::read(&first_plan)?, fs::read(&second_plan)?);
        // A new generation always gets fresh stores; the old ones stay as archives (RECOV-8-14).
        let second_installed = commands.install_command(&second_plan, "g2").await?;
        let mut second =
            commands.start_recovered(&second_installed, 2, "generation-two-zero").await?;
        wait_committed(&c.cmt, 1, &mut second).await?;
        let block: tendermint::Block = serde_json::from_value(
            c.cmt.call("block", &[("height", "1".into())]).await?["block"].clone(),
        )?;
        assert!(block.header.last_block_id.is_none());
        assert!(block.last_commit.is_none());
        assert_eq!(c.cmt.abci_status().await?.generation, 2);
        wait_checkpoint(&f, &mut second, 6).await?;
        mine_l1_blocks(&f.anvil.provider, 3).await?;
        use lander::l1::LandingSource;
        let snapshot = lander::l1::RpcLandingSource::new(
            f.anvil.provider.clone(),
            f.l2.provider.clone(),
            f.params.clone(),
        )
        .snapshot()
        .await?;
        assert_eq!(snapshot.generation, 2);
        assert!(snapshot.checkpoint_height > 0);
        assert_eq!(snapshot.recovery.as_ref().unwrap().height, 0);
        second.stop().await?;
        assert_eq!(fs::read(&old_state)?, old_hrs);
        assert_eq!(fs::read(c.comet_home(0).join("data/cs.wal/wal"))?, old_wal);
        for (path, bytes) in first_domain {
            assert_eq!(fs::read(path)?, bytes);
        }
        assert_eq!(
            support::recovery::snapshot(&[&first_installed.home, &first_installed.app])?,
            first_stores,
            "the generation-one home and app directory are never reused"
        );
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    c.stop().await?;
    result
}

fn archived_domain_states(f: &ContractFixture) -> Result<Vec<(std::path::PathBuf, Vec<u8>)>> {
    let manifest: serde_json::Value = serde_json::from_slice(&fs::read(
        f.signer_storage.path().join("0/authority/manifest.json"),
    )?)?;
    manifest["domains"]
        .as_array()
        .context("signer authority domains")?
        .iter()
        .map(|domain| {
            let path =
                std::path::PathBuf::from(domain["state"].as_str().context("domain HRS path")?);
            Ok((path.clone(), fs::read(path)?))
        })
        .collect()
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_linux_comet_uid_reads_p2p_and_cannot_read_registered_key() -> Result<()>
{
    test_harness::init_tracing();
    let f = ContractFixture::deploy_config(1, 120, 8).await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let mut c = ContractConsensus::start_native(
        f.anvil.http.clone(),
        &f.l2,
        f.params.clone(),
        vec![f.signer_storage.path().join("0")],
    )
    .await?;
    let mut commands = Commands::new(&f, &c)?;
    commands.origin = 0;
    c.stop_node(0).await?;
    let archives = [
        f.signer_storage.path().join("0/key.json"),
        f.signer_storage.path().join("0/state.json"),
        c.comet_home(0).join("data/cs.wal/wal"),
        c.app_dir(0).join("abci-state.json"),
    ]
    .into_iter()
    .map(|path| Ok((path.clone(), fs::read(path)?)))
    .collect::<Result<Vec<_>>>()?;
    let runtime = support::recovery::linux::LinuxRuntime::start(&f, &c, &commands)?;
    for ((_, bytes), remote) in archives.iter().zip([
        "/fixture/signer/key.json",
        "/fixture/signer/state.json",
        "/fixture/original-comet/data/cs.wal/wal",
        "/fixture/original-app/abci-state.json",
    ]) {
        assert_eq!(runtime.read(remote)?, *bytes, "retained legacy input copied without rewriting");
    }
    let result: Result<()> = async {
        recover_and_finalize(&f, 0, 0).await?;
        // In the runtime: prepare, install, chown the home to the Comet UID, then restart.
        runtime.prepare_and_install(&commands).await?;
        let mut node = runtime.start_recovered(&f, &commands).await?;
        wait_committed(&c.cmt, 1, &mut node).await?;
        runtime.assert_uid_boundary()?;
        wait_checkpoint(&f, &mut node, 6).await?;
        mine_l1_blocks(&f.anvil.provider, 3).await?;
        use lander::l1::LandingSource;
        let snapshot = lander::l1::RpcLandingSource::new(
            f.anvil.provider.clone(),
            f.l2.provider.clone(),
            f.params.clone(),
        )
        .snapshot()
        .await?;
        assert_eq!(snapshot.generation, 1);
        assert!(snapshot.checkpoint_height > 0);
        node.stop().await?;
        assert_eq!(runtime.read("/fixture/signer/state.json")?, archives[1].1);
        assert_eq!(runtime.read("/fixture/original-comet/data/cs.wal/wal")?, archives[2].1);
        for (path, bytes) in &archives {
            assert_eq!(fs::read(path)?, *bytes);
        }
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    drop(runtime);
    c.stop().await?;
    result
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_exclusion_activates_standby_and_cancels_old_pending_committee()
-> Result<()> {
    standby_recovery(false).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_combined_lists_activate_standby() -> Result<()> {
    standby_recovery(true).await
}

async fn standby_recovery(clear_fi: bool) -> Result<()> {
    test_harness::init_tracing();
    let f = ContractFixture::deploy_committee_config(2, 120, 14, 1).await?;
    let active = f
        .keys
        .iter()
        .position(|key| key.pubkey() == f.committee.members[0].pubkey)
        .context("original active key")?;
    let standby = 1 - active;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let dirs = (0..2).map(|i| f.signer_storage.path().join(i.to_string())).collect();
    let mut c =
        ContractConsensus::start_native(f.anvil.http.clone(), &f.l2, f.params.clone(), dirs)
            .await?;
    let commands = Commands::for_node(&f, &c, standby)?;
    let peer = c.peers[standby].clone();
    let (http, _) = c.execution_endpoints(standby, &f.l2);
    let provider = rpc::client::connect_http_with_timeout(http, std::time::Duration::from_secs(30));
    let result: Result<()> = async {
        c.wait_for_height(6).await?;
        let mut lander = commands.old_lander(&f, &c.cmt)?;
        wait_checkpoint(&f, &mut lander, 6).await?;
        lander.stop().await?;
        c.wait_for_height(13).await?;
        // Blockstore publication precedes ABCI Commit; the pending set is queryable only
        // after the app has durably committed S(1)=13, not merely published that block.
        let committed = test_harness::wait_until(
            "old app committed switch height 13",
            std::time::Duration::from_secs(120),
            std::time::Duration::from_millis(100),
            || async {
                let status = c.cmt.abci_status().await?;
                Ok((status.head >= 13).then_some(status.head))
            },
        )
        .await?;
        ensure!(committed < 15, "old committee activated before fixture isolation");
        // D(1)=12 and S(1)=13 have derived the old pending set; H(1)=15 has not activated it.
        let old_pending = c.cmt.committee(1).await?.context("old pending epoch-one committee")?;
        assert_eq!(old_pending.record.target_epoch, 1);
        assert_eq!(old_pending.members[0].pubkey, f.keys[active].pubkey());
        eprintln!("old pending committee observed: committed={committed}, target_epoch=1");
        for index in 0..2 {
            c.stop_node(index).await?;
        }
        let retained: abci::store::AppState =
            serde_json::from_slice(&fs::read(c.app_dir(0).join(abci::store::STATE_FILE))?)?;
        ensure!((13..15).contains(&retained.last_height), "old pending fixture height changed");
        assert_eq!(retained.committees.get(&1), Some(&old_pending));
        let archives = (0..2)
            .map(|i| {
                let path = f.signer_storage.path().join(format!("{i}/state.json"));
                Ok((path.clone(), fs::read(path)?))
            })
            .collect::<Result<Vec<_>>>()?;
        if clear_fi {
            f.save_forced_inclusion(&[0xc0]).await?;
        }
        let key = f.keys[active].pubkey();
        let mut encoded = [0u8; 64];
        encoded[31] = key.as_bytes()[0];
        encoded[32..].copy_from_slice(&key.as_bytes()[1..]);
        recover_with_lists(
            &f,
            0,
            6,
            vec![contracts_support::contracts::IEtnaInbox::Exclusion {
                bondId: alloy_primitives::U256::from(active),
                entryKey: alloy_primitives::keccak256(encoded),
            }],
            if clear_fi { vec![alloy_primitives::U256::ZERO] } else { vec![] },
        )
        .await?;
        let plan = commands.prepare_command(1).await?;
        let installed = commands.install_command(&plan, "standby").await?;
        let mut node = commands.start_recovered(&installed, 1, "standby").await?;
        wait_committed(&peer, 7, &mut node).await?;
        let validators = peer.validators(Some(7)).await?;
        assert_eq!(validators.len(), 1);
        assert_eq!(validators[0].pubkey, f.keys[standby].pubkey());
        assert!(
            peer.committee(1).await?.is_none(),
            "old pending committee must not survive InitChain"
        );
        wait_checkpoint(&f, &mut node, 12).await?;
        mine_l1_blocks(&f.anvil.provider, 3).await?;
        use lander::l1::LandingSource;
        let snapshot = lander::l1::RpcLandingSource::new(
            f.anvil.provider.clone(),
            provider.clone(),
            f.params.clone(),
        )
        .snapshot()
        .await?;
        let origin = snapshot.recovery.context("recovered R committee")?;
        assert_eq!(origin.committee.members.len(), 1);
        assert_eq!(origin.committee.members[0].pubkey, f.keys[standby].pubkey());
        assert_eq!(origin.committee.record.cutoff_l1_block, origin.l1_number);
        assert!(snapshot.checkpoint_height > 6);
        node.stop().await?;
        for (path, bytes) in archives {
            assert_eq!(fs::read(path)?, bytes);
        }
        assert!(
            !f.signer_storage.path().join(format!("{active}/authority")).exists(),
            "excluded key never enrolls or signs in the recovered domain"
        );
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    c.stop().await?;
    result
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_reconciles_old_pending_nonce_after_receipt_reorg() -> Result<()> {
    use alloy::sol_types::SolCall;
    use contracts_support::contracts::{EtnaInbox, transact};
    use serde_json::{Value, json};
    test_harness::init_tracing();
    let f = ContractFixture::deploy_config(1, 120, 8).await?;
    set_interval_mining(&f.anvil.provider, 1).await?;
    let mut c = ContractConsensus::start_native(
        f.anvil.http.clone(),
        &f.l2,
        f.params.clone(),
        vec![f.signer_storage.path().join("0")],
    )
    .await?;
    let mut commands = Commands::new(&f, &c)?;
    commands.origin = 0;
    let p = &f.anvil.provider;
    let result: Result<()> = async {
        c.wait_for_height(6).await?;
        // Governance and the permissionless lander use independent normal accounts, so an old
        // immutable landing nonce cannot block the governance transaction's account nonce.
        transact(
            p,
            test_harness::dev_signer().address(),
            f.inbox,
            EtnaInbox::transferOwnershipCall { newOwner: f.admin }.abi_encode(),
        )
        .await?;
        transact(p, f.admin, f.inbox, EtnaInbox::acceptOwnershipCall {}.abi_encode()).await?;
        mine_l1_blocks(p, 3).await?;
        set_interval_mining(p, 0).await?;
        test_harness::anvil_request::<Value>(p, "evm_setAutomine", json!([false])).await?;
        let snapshot: Value = test_harness::anvil_request(p, "evm_snapshot", json!([])).await?;
        let mut old = commands.old_lander(&f, &c.cmt)?;
        let pending: Value = tokio::time::timeout(std::time::Duration::from_secs(90), async {
            loop {
                old.running()?;
                if let Ok(bytes) = fs::read(commands.journal.join("lander-state.json")) {
                    let journal: Value = serde_json::from_slice(&bytes)?;
                    if journal["state"]["phase"] == "pending" &&
                        old.output().contains("broadcast persisted blob transaction")
                    {
                        return Ok::<_, anyhow::Error>(journal["state"]["transaction"].clone());
                    }
                }
                tokio::time::sleep(std::time::Duration::from_millis(20)).await;
            }
        })
        .await??;
        old.kill().await?;
        let old_journal: Value =
            serde_json::from_slice(&fs::read(commands.journal.join("lander-state.json"))?)?;
        let old_job: lander::store::ProvedJob =
            serde_json::from_value(old_journal["state"]["job"].clone())?;
        old_job.request.batch.verify_restored()?;
        assert_eq!(old_job.request.batch.snapshot.generation, 0);
        c.stop_node(0).await?;
        let old_hash: alloy_primitives::B256 =
            pending["hash"].as_str().context("pending transaction hash")?.parse()?;
        // Exercise a real canonical successful receipt, then an actual L1 snapshot reorg. The
        // CLI journal stays Pending with its exact original signed bytes throughout.
        mine_l1_blocks(p, 1).await?;
        let receipt = contracts_support::contracts::receipt(p, old_hash).await?;
        assert!(receipt.status());
        assert_eq!(f.checkpoint().await?.0, 6);
        assert_eq!(
            test_harness::anvil_request::<Value>(p, "evm_revert", json!([snapshot])).await?,
            json!(true)
        );
        assert_eq!(f.checkpoint().await?.0, 0);
        assert!(p.get_transaction_receipt(old_hash).await?.is_none());
        let _: Value =
            test_harness::anvil_request(p, "anvil_dropTransaction", json!([old_hash])).await?;
        test_harness::anvil_request::<Value>(p, "evm_setAutomine", json!([true])).await?;
        set_interval_mining(p, 1).await?;
        // The disposable verifier otherwise accepts every 0x00 proof, including a generation-
        // zero proof against a freshly computed generation-one statement. Bind this attempt to
        // the independently revalidated original statement through the verifier's real setter.
        f.expect_statement(old_job.request.batch.statement_hash).await?;
        recover_and_finalize(&f, 0, 0).await?;
        assert_eq!(
            contracts_support::contracts::view(
                p,
                f.inbox,
                EtnaInbox::recoveryGenerationCall {},
                None
            )
            .await?,
            1
        );
        let before: Value =
            serde_json::from_slice(&fs::read(commands.journal.join("lander-state.json"))?)?;
        assert_eq!(before["state"]["transaction"], pending);
        let plan = commands.prepare_command(1).await?;
        let installed = commands.install_command(&plan, "old-pending-reorg").await?;
        let mut node = commands.start_recovered(&installed, 1, "old-pending-reorg").await?;
        tokio::time::timeout(std::time::Duration::from_secs(30), async {
            loop {
                node.running()?;
                if node.output().contains("outstanding nonce unresolved after competing checkpoint")
                {
                    return Ok::<_, anyhow::Error>(());
                }
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        })
        .await??;
        let waiting: Value =
            serde_json::from_slice(&fs::read(commands.journal.join("lander-state.json"))?)?;
        assert_eq!(waiting["state"]["transaction"], pending);
        assert_eq!(
            p.get_transaction_count(test_harness::dev_signer().address()).await?,
            pending["nonce"].as_u64().unwrap()
        );
        // Recovery deliberately does not rebroadcast an obsolete generation automatically.
        // Explicit operator reconciliation sends the exact already-signed envelope, without
        // replacing fees, signing again, allocating another nonce, or editing its journal.
        let immutable: lander::tx::SignedTransaction = serde_json::from_value(pending.clone())?;
        assert_eq!(*p.send_raw_transaction(&immutable.network_bytes).await?.tx_hash(), old_hash);
        let reconciled = contracts_support::contracts::receipt(p, old_hash).await?;
        assert!(
            !reconciled.status(),
            "same old-generation signed bytes now revert canonically under g1"
        );
        assert_eq!(reconciled.transaction_hash, old_hash);
        assert_ne!(
            reconciled.block_hash, receipt.block_hash,
            "the earlier successful receipt is orphaned"
        );
        assert_eq!(
            p.get_block_by_number(reconciled.block_number.unwrap().into())
                .await?
                .unwrap()
                .header
                .hash,
            reconciled.block_hash.unwrap()
        );
        assert_eq!(f.checkpoint().await?.0, 0);
        // Resume the explicit dummy profile for the new, normal generation-one CLI proof.
        f.expect_statement(alloy_primitives::B256::ZERO).await?;
        wait_checkpoint(&f, &mut node, 6).await?;
        mine_l1_blocks(p, 3).await?;
        use lander::l1::LandingSource;
        let landed =
            lander::l1::RpcLandingSource::new(p.clone(), f.l2.provider.clone(), f.params.clone())
                .snapshot()
                .await?;
        assert_eq!(landed.generation, 1);
        assert!(landed.checkpoint_height >= 6);
        assert_eq!(
            landed.checkpoint_hash,
            c.cmt.envelope(landed.checkpoint_height).await?.block.header.hash_slow()
        );
        let nonce = pending["nonce"].as_u64().context("old nonce")?;
        assert!(p.get_transaction_count(test_harness::dev_signer().address()).await? >= nonce + 2);
        assert_eq!(c.cmt.abci_status().await?.generation, 1);
        node.stop().await?;
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    c.stop().await?;
    result
}
