//! Actual governance recovery from a settled checkpoint with stock consensus and pinned EL.
#[path = "../../../crates/lander/tests/support/mod.rs"]
mod contracts_support;
mod support {
    pub mod recovery;
}
use alloy_eips::{BlockNumberOrTag, eip2718::Encodable2718};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use contracts_support::ContractFixture;
use std::fs;
use support::recovery::{
    Commands, recover_and_finalize, recover_with_lists, wait_checkpoint, wait_committed,
    write_private,
};
use test_harness::{ContractConsensus, mine_l1_blocks, set_interval_mining};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_command_produces_and_lands() -> Result<()> {
    checkpoint_roundtrip(8, false).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_l7_overlap_preserves_global_grid() -> Result<()> {
    checkpoint_roundtrip(7, false).await
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn governance_recovery_l6_blanks_fi_and_lands_epoch_boundary() -> Result<()> {
    checkpoint_roundtrip(6, true).await
}

async fn checkpoint_roundtrip(epoch_len: u64, clear_fi: bool) -> Result<()> {
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
    let commands = Commands::new(&f, &c)?;
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
            let mut activation = commands.activate_command(&plan, "first")?;
            wait_committed(&c.cmt, 7, &mut activation)
                .await
                .with_context(|| activation.output())?;
            activation.running()?;
            let private_trust = commands.private_trust(&plan).await?;
            assert_eq!(private_trust["schema_version"], 2);
            assert_eq!(private_trust["generation"], 1);
            assert_eq!(private_trust["trust_ready"], true);
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
                        activation.running()?;
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
            wait_checkpoint(&f, &mut activation, 12).await?;
            mine_l1_blocks(&f.anvil.provider, 3).await?;
            let source = lander::l1::RpcLandingSource::new(
                f.anvil.provider.clone(),
                f.l2.provider.clone(),
                f.params.clone(),
            );
            use lander::l1::LandingSource;
            let finalized_landing = source.snapshot().await?;
            assert_eq!(finalized_landing.generation, 1);
            assert!(finalized_landing.checkpoint_height > 6);
            let origin =
                finalized_landing.recovery.as_ref().context("authenticated recovery origin")?;
            assert_eq!(origin.committee.record.target_epoch, 6 / epoch_len);
            assert_eq!(origin.committee.record.cutoff_l1_block, origin.l1_number);
            assert_eq!(origin.committee.members, f.committee.members);
            assert_eq!(origin.forced_cursor, 0);
            if first_fi.is_some() {
                assert_eq!(
                    finalized_landing.forced_inclusion_head, 1,
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
            for height in 7..=finalized_landing.checkpoint_height {
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
            if epoch_len == 8 {
                support::recovery::full_node::join_after_landing(&f, &c, &old_blocks).await?;
            }
            activation.stop().await?;
            assert!(
                abci::ownership::acquire_activation(&commands.root, plan.parse()?).is_ok(),
                "foreground activation exits only after all owned descendants release their leases"
            );
            assert_eq!(fs::read(old_hrs_path)?, old_hrs);
            assert_eq!(fs::read(old_key_path)?, old_key);
            assert_eq!(fs::read(old_wal_path)?, old_wal);
            let active: serde_json::Value =
                serde_json::from_slice(&fs::read(commands.root.join("active.json"))?)?;
            let home = std::path::PathBuf::from(
                active["installation"]["home"].as_str().context("installed Comet home")?,
            );
            let dummy: serde_json::Value =
                serde_json::from_slice(&fs::read(home.join("data/priv_validator_state.json"))?)?;
            assert_eq!(dummy["height"], "0", "stock local dummy never signs");
            f.l2.restart().await?;
            let mut resumed = commands.activate_command(&plan, "restart")?;
            wait_committed(&c.cmt, 14, &mut resumed).await.with_context(|| resumed.output())?;
            let canonical_restarted_hash =
                f.l2.provider.get_block_by_number(7.into()).await?.unwrap().header.hash;
            assert_eq!(canonical_restarted_hash, recovered_committed_hash);
            resumed.stop().await?;
            ensure!(commands.plan_dir(&plan).join("app").is_dir(), "real recovered app store");
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
    let original_profile = fs::read_to_string(&commands.profile)?;
    let mut profile: toml::Table = toml::from_str(&original_profile)?;
    profile.remove("lander");
    write_private(&commands.profile, toml::to_string(&profile)?)?;
    let result: Result<()> = async {
        recover_and_finalize(&f, 0, 0).await?;
        let first_plan = commands.prepare_command(1).await?;
        let mut first = commands.activate_command(&first_plan, "generation-one-zero")?;
        wait_committed(&c.cmt, 1, &mut first).await?;
        first.stop().await?;
        assert_eq!(f.checkpoint().await?.0, 0, "no landing before second recovery");
        let first_domain = archived_domain_states(&f)?;
        assert!(!first_domain.is_empty());
        let first_wal = installed_wal(&commands)?;
        recover_and_finalize(&f, 1, 0).await?;
        write_private(&commands.profile, &original_profile)?;
        let second_plan = commands.prepare_command(2).await?;
        assert_ne!(first_plan, second_plan);
        let mut second = commands.activate_command(&second_plan, "generation-two-zero")?;
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
        assert_eq!(fs::read(first_wal.0)?, first_wal.1);
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

fn installed_wal(commands: &Commands) -> Result<(std::path::PathBuf, Vec<u8>)> {
    let active: serde_json::Value =
        serde_json::from_slice(&fs::read(commands.root.join("active.json"))?)?;
    let path =
        std::path::Path::new(active["installation"]["home"].as_str().context("installed home")?)
            .join("data/cs.wal/wal");
    Ok((path.clone(), fs::read(path)?))
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
    let commands = Commands::new(&f, &c)?;
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
        let plan = runtime.prepare(&commands).await?;
        let mut activation = runtime.activate(&commands, &plan)?;
        wait_committed(&c.cmt, 1, &mut activation).await?;
        runtime.assert_uid_boundary()?;
        wait_checkpoint(&f, &mut activation, 6).await?;
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
        activation.stop().await?;
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
        // D(1)=12 and S(1)=13 have derived the old pending set; H(1)=15 has not activated it.
        let old_pending = c.cmt.committee(1).await?.context("old pending epoch-one committee")?;
        assert_eq!(old_pending.members[0].pubkey, f.keys[active].pubkey());
        for index in 0..2 {
            c.stop_node(index).await?;
        }
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
        let mut activation = commands.activate_command(&plan, "standby")?;
        wait_committed(&peer, 7, &mut activation).await?;
        let validators = peer.validators(Some(7)).await?;
        assert_eq!(validators.len(), 1);
        assert_eq!(validators[0].pubkey, f.keys[standby].pubkey());
        assert!(
            peer.committee(1).await?.is_none(),
            "old pending committee must not survive InitChain"
        );
        wait_checkpoint(&f, &mut activation, 12).await?;
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
        activation.stop().await?;
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
async fn governance_recovery_sigkill_boundaries_replay_without_duplicate_owners() -> Result<()> {
    for boundary in ["init-chain", "signature", "commit", "broadcast"] {
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
        let commands = Commands::new(&f, &c)?;
        c.stop_node(0).await?;
        let old_hrs = fs::read(f.signer_storage.path().join("0/state.json"))?;
        let old_wal = fs::read(c.comet_home(0).join("data/cs.wal/wal"))?;
        let runtime = support::recovery::linux::LinuxRuntime::start(&f, &c, &commands)?;
        let result: Result<()> = async {
            recover_and_finalize(&f, 0, 0).await?;
            let plan = runtime.prepare(&commands).await?;
            if boundary == "broadcast" {
                set_interval_mining(&f.anvil.provider, 0).await?;
                test_harness::anvil_request::<serde_json::Value>(
                    &f.anvil.provider,
                    "evm_setAutomine",
                    serde_json::json!([false]),
                )
                .await?;
            }
            let mut activation = runtime.activate(&commands, &plan)?;
            tokio::time::timeout(std::time::Duration::from_secs(100), async {
                loop {
                    activation.running()?;
                    let ready = match boundary {
                        "init-chain" => activation.output().contains("chain initialized"),
                        "signature" => runtime.signed_height().is_ok_and(|height| height > 0),
                        "commit" => c.cmt.abci_status().await.is_ok_and(|status| status.head > 0),
                        "broadcast" => {
                            activation.output().contains("broadcast persisted blob transaction")
                        }
                        _ => unreachable!(),
                    };
                    if ready {
                        return Ok::<_, anyhow::Error>(());
                    }
                    tokio::time::sleep(std::time::Duration::from_millis(20)).await;
                }
            })
            .await
            .with_context(|| format!("{boundary}\n{}", activation.output()))??;
            let signed = if boundary == "broadcast" {
                let journal: serde_json::Value =
                    serde_json::from_slice(&runtime.read("/fixture/lander/lander-state.json")?)?;
                assert_eq!(journal["state"]["phase"], "pending");
                Some(journal["state"]["transaction"].clone())
            } else {
                None
            };
            runtime.crash_and_quiesce(&plan)?;
            activation.killed().await?;
            let mut resumed = runtime.activate(&commands, &plan)?;
            if let Some(signed) = signed {
                // With mining still disabled the immutable Pending envelope must remain exact.
                wait_committed(&c.cmt, 7, &mut resumed).await?;
                let journal: serde_json::Value =
                    serde_json::from_slice(&runtime.read("/fixture/lander/lander-state.json")?)?;
                assert_eq!(journal["state"]["transaction"], signed);
                test_harness::anvil_request::<serde_json::Value>(
                    &f.anvil.provider,
                    "evm_setAutomine",
                    serde_json::json!([true]),
                )
                .await?;
                set_interval_mining(&f.anvil.provider, 1).await?;
                mine_l1_blocks(&f.anvil.provider, 3).await?;
            }
            wait_committed(&c.cmt, 2, &mut resumed).await?;
            wait_checkpoint(&f, &mut resumed, 6).await?;
            resumed.stop().await?;
            assert_eq!(runtime.read("/fixture/signer/state.json")?, old_hrs);
            assert_eq!(runtime.read("/fixture/original-comet/data/cs.wal/wal")?, old_wal);
            assert_eq!(fs::read(f.signer_storage.path().join("0/state.json"))?, old_hrs);
            eprintln!("actual SIGKILL/restart boundary passed: {boundary}");
            Ok(())
        }
        .await;
        if result.is_err() {
            commands.diagnostics();
        }
        drop(runtime);
        c.stop().await?;
        result?;
    }
    Ok(())
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
        old_job.request.batch.validate_statement()?;
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
        let mut activation = commands.activate_command(&plan, "old-pending-reorg")?;
        tokio::time::timeout(std::time::Duration::from_secs(30), async {
            loop {
                activation.running()?;
                if activation
                    .output()
                    .contains("outstanding nonce unresolved after competing checkpoint")
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
        wait_checkpoint(&f, &mut activation, 6).await?;
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
        activation.stop().await?;
        Ok(())
    }
    .await;
    if result.is_err() {
        commands.diagnostics();
    }
    c.stop().await?;
    result
}
