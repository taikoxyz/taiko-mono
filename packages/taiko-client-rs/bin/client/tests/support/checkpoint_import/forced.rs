//! Run plain `abci` on an imported store against real stock decisions, with an explicit
//! FinalizeBlock/Commit crash boundary. The test supplies only decisions made by the independent
//! source consensus.
use super::*;
use abci::{App, AppOptions, EngineError, RpcL1Source, Store};
use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEnvelope},
    signers::SignerSync,
};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Address, B256, TxKind};
use alloy_provider::Provider;
use prost::Message;
use tendermint_proto::v0_38::abci as pb;
use tokio::io::{AsyncReadExt, AsyncWriteExt};

/// Inject only the pinned EL's permanent missing-state reply. Permit real checkpoint header and
/// floor-state reads so the negative control must reach a singleton build against the recorded
/// parent.
struct MissingParent {
    headers: RpcEngine,
    parent: B256,
}
#[async_trait::async_trait]
impl Engine for MissingParent {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        self.headers.check_capabilities().await
    }
    async fn pool_transactions(
        &self,
        _: abci::engine::PoolSelection,
    ) -> Result<Vec<TxEnvelope>, EngineError> {
        panic!("cold replay queried the pool")
    }
    async fn build_block(
        &self,
        parent: B256,
        _: alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes,
    ) -> Result<abci::ExecutionBlock, EngineError> {
        assert_eq!(parent, self.parent);
        Err(EngineError::ErrorReply {
            call: "engine_getPayloadV5".into(),
            code: -38100,
            message: "historical state unavailable".into(),
        })
    }
    async fn new_payload(&self, _: &abci::ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        panic!("missing state reached execution")
    }
    async fn forkchoice(&self, _: B256, _: B256, _: B256) -> Result<PayloadVerdict, EngineError> {
        panic!("missing state changed forkchoice")
    }
    async fn header_by_number(
        &self,
        h: u64,
    ) -> Result<Option<alloy_consensus::Header>, EngineError> {
        self.headers.header_by_number(h).await
    }
    async fn finalized_header(&self) -> Result<Option<alloy_consensus::Header>, EngineError> {
        self.headers.finalized_header().await
    }
    async fn historical_state_available(&self, hash: B256) -> Result<bool, EngineError> {
        // The startup check reads the execution floor's state (DATA-5.4-6). The missing
        // parent's singleton reply is decisive, so its state is never probed.
        assert_ne!(hash, self.parent, "singleton reply is decisive");
        self.headers.historical_state_available(hash).await
    }
}

/// Submit two canonically signed, fee-eligible transactions with unavailable future nonces.
/// U=6 holds the source at 6 until landing. The subsequent proven anchor makes both entries due.
pub(super) async fn enqueue(f: &ContractFixture) -> Result<()> {
    for nonce in [100_000, 100_001] {
        let tx = TxEip1559 {
            chain_id: f.params.l2_chain_id,
            nonce,
            gas_limit: 21_000,
            max_fee_per_gas: 100_000_000_000,
            max_priority_fee_per_gas: 1,
            to: TxKind::Call(Address::repeat_byte(0x40)),
            ..Default::default()
        };
        let sig = test_harness::dev_signer().sign_hash_sync(&tx.signature_hash())?;
        let raw = TxEnvelope::Eip1559(tx.into_signed(sig)).encoded_2718();
        f.save_forced_inclusion(&raw).await?;
    }
    let _: Value = f.anvil.provider.raw_request("evm_increaseTime".into(), [4000]).await?;
    mine_l1_blocks(&f.anvil.provider, 4).await?;
    Ok(())
}

async fn decided(rpc: &CmtClient, h: u64) -> Result<pb::Request> {
    let r = rpc.call("block", &[("height", h.to_string())]).await?;
    let header: tendermint::block::Header = serde_json::from_value(r["block"]["header"].clone())?;
    let env = rpc.envelope(h).await?;
    let entry = env.forced.as_ref().context("source decided FI")?;
    ensure!(
        entry.index == h - 7 &&
            !env.block.transactions.contains(&entry.tx) &&
            abci::forced::decode_canonical(&entry.tx).is_some(),
        "source decision must be a canonical skip at {h}"
    );
    ensure!(header.hash().to_string() == r["block_id"]["hash"].as_str().unwrap());
    Ok(pb::Request {
        value: Some(pb::request::Value::FinalizeBlock(pb::RequestFinalizeBlock {
            txs: vec![env.encode().0],
            decided_last_commit: Some(Default::default()),
            hash: header.hash().as_bytes().to_vec().into(),
            height: h as i64,
            time: Some(header.time.into()),
            next_validators_hash: header.next_validators_hash.as_bytes().to_vec().into(),
            proposer_address: header.proposer_address.as_bytes().to_vec().into(),
            ..Default::default()
        })),
    })
}

async fn send(proxy: u16, request: &pb::Request) -> Result<pb::response::Value> {
    let mut io = tokio::net::TcpStream::connect(("127.0.0.1", proxy)).await?;
    io.write_all(&request.encode_length_delimited_to_vec()).await?;
    let mut prefix = Vec::new();
    loop {
        let b = io.read_u8().await?;
        prefix.push(b);
        if b < 128 {
            break;
        }
        ensure!(prefix.len() < 10);
    }
    let n = prost::encoding::decode_varint(&mut prefix.as_slice())?;
    ensure!(n <= 22_020_096);
    let mut data = vec![0; n as usize];
    io.read_exact(&mut data).await?;
    pb::Response::decode(data.as_slice())?.value.context("ABCI response")
}

pub(super) async fn replay(
    f: &ContractFixture,
    c: &ContractConsensus,
    commands: &Commands,
    x: &Fixture,
    root: &Path,
    s: u64,
) -> Result<()> {
    c.wait_for_height(s + 3).await?;
    let first = decided(&c.cmt, s + 1).await?;
    let later = decided(&c.cmt, s + 2).await?;
    let commit = pb::Request { value: Some(pb::request::Value::Commit(pb::RequestCommit {})) };
    let store = root.join("ready/app");
    let journal = || -> Result<abci::store::AppState> {
        Ok(serde_json::from_slice(&fs::read(store.join(abci::store::STATE_FILE))?)?)
    };
    ensure!(journal()?.forced_cursor == 0 && journal()?.last_height == s);
    // One EL on the imported store for both app launches.
    let elbin = binary("ETNA_EL_BIN", "alethia-reth")?;
    let (mut execution, http, auth, _) =
        el(&elbin, &root.join("ready/el"), &x.el_chain, &x.base, "forced-el").await?;
    let reader = rpc::client::connect_http_with_timeout(http.clone(), Duration::from_secs(5));
    for launch in 0..2 {
        let log = x.base.join(format!("forced-app-{launch}.log"));
        let mut runtime = app(f, commands, &store, (&http, &auth), x.proxy, log).await?;
        if launch == 0 {
            ensure!(matches!(send(x.proxy, &first).await?, pb::response::Value::FinalizeBlock(_)));
            ensure!(matches!(send(x.proxy, &commit).await?, pb::response::Value::Commit(_)));
        }
        ensure!(journal()?.forced_cursor == 1 && journal()?.last_height == s + 1);
        ensure!(matches!(send(x.proxy, &later).await?, pb::response::Value::FinalizeBlock(_)));
        ensure!(reader.get_block_number().await? == s + 2);
        if launch == 0 {
            // Deliberately stop before ABCI Commit. EL already executed s+2, while the
            // independently stored app journal still selects the retained s+1 parent.
            runtime.stop().await?;
        } else {
            ensure!(matches!(send(x.proxy, &commit).await?, pb::response::Value::Commit(_)));
            ensure!(journal()?.forced_cursor == 2 && journal()?.last_height == s + 2);
            runtime.stop().await?;
        }
        if launch == 0 {
            let committed = journal()?;
            let negative = x.base.join("missing-parent-control");
            let copy = Store::new(negative.clone());
            copy.save(&committed)?;
            let parent = c.cmt.envelope(s + 1).await?.block.header;
            ensure!(parent.hash_slow() == committed.parent.hash);
            let build = || -> Result<MissingParent> {
                Ok(MissingParent { headers: f.l2.engine()?, parent: parent.hash_slow() })
            };
            let l1 = || {
                RpcL1Source::new(rpc::client::connect_http_with_timeout(
                    f.anvil.http.clone(),
                    Duration::from_secs(5),
                ))
            };
            let mut app =
                App::new(l1(), build()?, f.params.clone(), copy.clone(), AppOptions::default())?;
            let error = tokio::time::timeout(
                Duration::from_secs(10),
                app.handle(abci::wire::Request::decode(&later.encode_to_vec())?),
            )
            .await?
            .unwrap_err();
            ensure!(
                matches!(error, abci::AbciError::SafetyHalt(_)) &&
                    error.to_string().contains("-38100"),
                "missing post-s parent: {error}"
            );
            ensure!(copy.load()? == Some(committed));
            let fatal = fs::read_to_string(negative.join("fatal-evidence.txt"))?;
            ensure!(
                fatal.contains("-38100") &&
                    fatal.contains("restore historical parent state before replay") &&
                    fatal.contains(&parent.hash_slow().to_string())
            );
            ensure!(matches!(
                App::new(l1(), build()?, f.params.clone(), copy, AppOptions::default()),
                Err(abci::AbciError::SafetyHalt(_))
            ));
        }
    }
    execution.stop().await?;
    let hash: B256 = journal()?.parent.hash;
    ensure!(hash == c.cmt.envelope(s + 2).await?.block.header.hash_slow());
    Ok(())
}
