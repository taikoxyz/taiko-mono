//! Real native helper and Engine API at a sparse checkpoint, independent of consensus generation.
use super::*;
use abci::{AnchorState, ChainParams, HeaderInputs, InboxFacts, ParentInfo, rules};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, U256, keccak256};
use alloy_provider::Provider;
use std::os::unix::fs::PermissionsExt;

#[derive(serde::Serialize)]
struct Manifest<'a> {
    schema: u32,
    installation_id: B256,
    chain_id: u64,
    origin: u64,
    unsettled_limit: u64,
    finalized_height: u64,
    finalized_hash: B256,
    headers: &'a [Header],
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn native_long_fence_restarts_and_executes_with_body_pruned_parents() -> Result<()> {
    let tmp = tempfile::Builder::new().prefix("etna-fence-").tempdir_in("/tmp")?;
    let base = tmp.path().canonicalize()?;
    let genesis = test_harness::EtnaGenesis::build()?;
    let chain = base.join("genesis.json");
    fs::write(&chain, &genesis.json)?;
    let bin = binary("ETNA_EL_BIN", "alethia-reth")?;
    let source = base.join("source");
    let (mut donor, _, _, engine) = el(&bin, &source, &chain, &base, "source").await?;
    let zero = engine.header_by_number(0).await?.context("genesis header")?;
    ensure!(zero.hash_slow() == genesis.hash && zero.state_root == genesis.state_root);
    donor.stop().await?;
    let local = base.join("imported");
    fs::create_dir_all(local.join("db"))?;
    fs::set_permissions(&local, fs::Permissions::from_mode(0o700))?;
    for name in ["database.version", "mdbx.dat"] {
        fs::copy(source.join("db").join(name), local.join("db").join(name))?;
    }
    let params = ChainParams::builtin(167001)?;
    let mut headers: Vec<Header> = vec![];
    let q = 606;
    let s = 900;
    for h in 601..=s {
        let header = Header {
            number: h,
            timestamp: zero.timestamp + 2 * h,
            parent_hash: headers.last().map_or(B256::repeat_byte(0x71), Header::hash_slow),
            extra_data: rules::encode_extra_data(0, 10)?,
            base_fee_per_gas: Some(10_000_000),
            gas_used: 30_000_000,
            gas_limit: 45_000_000,
            ..zero.clone()
        };
        headers.push(header);
    }
    let finalized = headers[(q - 601) as usize].hash_slow();
    let terminal = headers.last().unwrap();
    let head = terminal.hash_slow();
    let id = B256::repeat_byte(0xc7);
    let manifest = Manifest {
        schema: 1,
        installation_id: id,
        chain_id: 167001,
        origin: 0,
        unsettled_limit: 300,
        finalized_height: q,
        finalized_hash: finalized,
        headers: &headers,
    };
    let bytes = serde_json::to_vec(&manifest)?;
    let path = base.join("manifest.json");
    fs::write(&path, &bytes)?;
    write_private(
        &local.join(".etna-el-import-staging.json"),
        serde_json::to_vec(
            &json!({"schema":1,"installation_id":id,"manifest_hash":keccak256(&bytes)}),
        )?,
    )?;
    let installed = std::process::Command::new(binary("ETNA_EL_IMPORT_BIN", "etna-el-import")?)
        .arg("install")
        .arg("--datadir")
        .arg(&local)
        .arg("--chain")
        .arg(&chain)
        .arg("--manifest")
        .arg(&path)
        .arg("--chain-id")
        .arg("167001")
        .arg("--trusted-el-hash")
        .arg(head.to_string())
        .arg("--trusted-state-root")
        .arg(genesis.state_root.to_string())
        .arg("--trusted-genesis-hash")
        .arg(genesis.hash.to_string())
        .output()?;
    ensure!(
        installed.status.success(),
        "native helper: {}",
        String::from_utf8_lossy(&installed.stderr)
    );
    let report: Value = serde_json::from_slice(&installed.stdout)?;
    ensure!(
        report["state_floor"] == s &&
            report["finalized_height"] == q &&
            report["finalized_hash"] == json!(finalized)
    );
    // Preserve a closed, installed floor independent of the immediate-build branch. Neither
    // database is live during this copy, and neither contains signer or consensus data.
    let cold = base.join("cold");
    let copied = std::process::Command::new("cp").arg("-R").arg(&local).arg(&cold).output()?;
    ensure!(
        copied.status.success(),
        "copy closed native floor: {}",
        String::from_utf8_lossy(&copied.stderr)
    );
    enum AtFloor {
        Build,
        Stop,
        AlreadyAdvanced,
    }
    let mut immediate = None;
    for (launch, data, at_floor) in [
        ("immediate", &local, AtFloor::Build),
        ("post-progress-restart", &local, AtFloor::AlreadyAdvanced),
        ("stop-at-floor", &cold, AtFloor::Stop),
        ("restart-at-floor", &cold, AtFloor::Build),
    ] {
        let (mut node, http, _, engine) = el(&bin, data, &chain, &base, launch).await?;
        let rpc = rpc::client::connect_http_with_timeout(http, Duration::from_secs(10));
        let active = if matches!(at_floor, AtFloor::AlreadyAdvanced) {
            ensure!(rpc.get_block_number().await? == s + 1);
            immediate.context("immediate successor")?
        } else {
            ensure!(rpc.get_block_number().await? == s);
            head
        };
        ensure!(engine.forkchoice(active, B256::ZERO, finalized).await? == PayloadVerdict::Valid);
        ensure!(engine.finalized_header().await?.context("finalized q")?.hash_slow() == finalized);
        for h in [s - 1, s] {
            let body: Result<Value, _> =
                rpc.raw_request("eth_getBlockByNumber".into(), (format!("{h:#x}"), false)).await;
            ensure!(body.is_err() || body?.is_null(), "invented historical body at {h}");
            ensure!(
                engine.header_by_number(h).await?.context("canonical raw header")? ==
                    headers[(h - 601) as usize]
            );
        }
        if matches!(at_floor, AtFloor::Stop) {
            // In this branch no build/newPayload has ever been submitted at 901.
            node.stop().await?;
            continue;
        }
        if matches!(at_floor, AtFloor::Build) {
            let parent = engine.header_by_number(s).await?.unwrap();
            let grandparent = engine.header_by_number(s - 1).await?.unwrap();
            let info = ParentInfo {
                number: s,
                hash: head,
                timestamp: parent.timestamp,
                gas_limit: parent.gas_limit,
                gas_used: parent.gas_used,
                base_fee: parent.base_fee_per_gas.unwrap(),
                difficulty: parent.difficulty,
                grandparent_timestamp: grandparent.timestamp,
            };
            let anchor = AnchorState {
                number: 10,
                timestamp: 1,
                hash: B256::repeat_byte(4),
                state_root: B256::repeat_byte(5),
                inbox: InboxFacts {
                    rules_schedule: U256::ZERO,
                    recovery_generation: 0,
                    last_checkpoint_height: q,
                    last_checkpoint_hash: finalized,
                    forced_inclusion_head: 0,
                    forced_inclusion_tail: 0,
                },
            };
            let expected = rules::expected_header(&HeaderInputs {
                height: s + 1,
                beneficiary: Address::repeat_byte(0x77),
                parent: &info,
                anchor: &anchor,
                bft_time_secs: parent.timestamp + 2,
                generation: 0,
                params: &params,
                min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(167001),
            })?;
            ensure!(expected.base_fee == 10_416_666);
            let attrs = rules::payload_attributes(
                &expected,
                anchor.hash,
                Some(protocol::shasta::encode_transactions(&[])),
            );
            let successor = engine.build_block(head, attrs).await?;
            rules::check_header(&successor.header, &expected)?;
            ensure!(engine.new_payload(&successor).await? == PayloadVerdict::Valid);
            let next = successor.header.hash_slow();
            if let Some(previous) = immediate {
                ensure!(
                    next == previous,
                    "first cold successor differs from independent immediate build"
                );
            } else {
                immediate = Some(next);
            }
            eprintln!(
                "native_long_fence branch={launch} parent={s} q={q} successor={} base_fee={} hash={next}",
                s + 1,
                expected.base_fee
            );

            ensure!(engine.forkchoice(next, B256::ZERO, finalized).await? == PayloadVerdict::Valid);
        }
        ensure!(rpc.get_block_number().await? == s + 1);
        // Execute BLOCKHASH in the actual EVM against persisted indexes, including its oldest
        // legal argument. The state override supplies only temporary bytecode for eth_call.
        let account = Address::repeat_byte(0x74);
        for h in [s, s - 1, s - 255, s - 256] {
            let code = format!("0x61{h:04x}4060005260206000f3");
            let got: B256 = rpc
                .raw_request(
                    "eth_call".into(),
                    json!([{"to":account},"latest",{(format!("{account:#x}")):{"code":code}}]),
                )
                .await?;
            let expected =
                if h == s - 256 { B256::ZERO } else { headers[(h - 601) as usize].hash_slow() };
            ensure!(got == expected, "BLOCKHASH({h}) after launch {launch}: {got} != {expected}");
        }
        node.stop().await?;
    }
    Ok(())
}
