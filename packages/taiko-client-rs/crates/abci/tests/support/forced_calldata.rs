//! Direct ABCI requests against a frozen real execution parent.
use abci::{
    App, AppState, Engine, EngineError, ExecutionBlock, RpcEngine, RpcL1Source, Store,
    engine::{PayloadVerdict, PoolSelection},
    envelope::EtnaEnvelope,
    rules::ExpectedHeader,
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{
    consensus::{Header, TxEnvelope},
    signers::local::PrivateKeySigner,
};
use alloy_primitives::{B256, Bytes, U256, b256, keccak256};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tendermint::{
    Hash, Time,
    abci::types::CommitInfo,
    account,
    block::{Height, Round},
    v0_38::abci::{Request, Response, request, response},
};
use test_harness::{Devnet, dev_signer, send_transfer, wait_until};

pub const POOL_KEY: B256 =
    b256!("5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a");
pub fn pool_signer() -> PrivateKeySigner {
    PrivateKeySigner::from_bytes(&POOL_KEY).unwrap()
}
pub async fn freeze(devnet: &mut Devnet) -> Result<AppState> {
    devnet.lander_pause().await;
    devnet.node_stop(0).await?;
    Store::new(devnet.app_data_dir(0)).load()?.context("persisted parent")
}
pub async fn comet_exit_code(devnet: &Devnet) -> Result<i32> {
    let name = devnet.cmt_container(0);
    let output = tokio::process::Command::new("docker")
        .args(["inspect", "--format", "{{.State.ExitCode}}", &name])
        .output()
        .await?;
    ensure!(output.status.success(), "read Comet exit status");
    Ok(String::from_utf8(output.stdout)?.trim().parse()?)
}

pub async fn fund_pool(devnet: &Devnet) -> Result<()> {
    let l2 = devnet.l2_provider(0);
    let signer = dev_signer();
    let nonce = l2.get_transaction_count(signer.address()).await?;
    let tx = send_transfer(
        &l2,
        &signer,
        pool_signer().address(),
        U256::from(10u64).pow(U256::from(18)),
        nonce,
    )
    .await?;
    let receipt =
        wait_until("pool funding", Duration::from_secs(30), Duration::from_millis(100), || async {
            Ok(l2.get_transaction_receipt(tx).await?)
        })
        .await?;
    ensure!(receipt.status(), "pool funding reverted");
    let height = receipt.block_number.context("funding receipt has no block")?;
    // EL receipts become visible before ABCI Commit. Freezing in that interval would build
    // on an unfunded committed parent while signing with the later EL nonce and balance.
    wait_until(
        "pool funding committed by ABCI",
        Duration::from_secs(30),
        Duration::from_millis(100),
        || async {
            // Query publishes the committed state only after its atomic save. Store::load is
            // startup recovery and removes temporary files, so never poll it on a running app.
            Ok((devnet.abci_status(0).await?.head >= height).then_some(()))
        },
    )
    .await
}
pub async fn anchor_ready(devnet: &Devnet, block: u64, timestamp: u64) -> Result<()> {
    wait_until(
        "finalized admission anchor",
        Duration::from_secs(40),
        Duration::from_millis(100),
        || async {
            let n = test_harness::finalized_number(devnet.l1())
                .await?
                .saturating_sub(devnet.params().l1_finality_extra_depth);
            let header = devnet.l1().get_block_by_number(n.into()).await?.context("L1 header")?;
            Ok((n >= block && header.header.timestamp >= timestamp).then_some(()))
        },
    )
    .await
}
pub fn now() -> Time {
    Time::from_unix_timestamp(
        SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64,
        0,
    )
    .unwrap()
}
pub fn process_request(env: &EtnaEnvelope, time: Time) -> request::ProcessProposal {
    request::ProcessProposal {
        txs: vec![env.encode().0],
        proposed_last_commit: None,
        misbehavior: vec![],
        hash: Hash::Sha256(keccak256(env.encode()).0),
        height: Height::try_from(env.block.header.number).unwrap(),
        time,
        next_validators_hash: Hash::None,
        proposer_address: account::Id::new([2; 20]),
    }
}
pub fn finalize_request(env: &EtnaEnvelope, time: Time) -> Request {
    let p = process_request(env, time);
    Request::FinalizeBlock(request::FinalizeBlock {
        txs: p.txs,
        decided_last_commit: CommitInfo { round: Round::default(), votes: vec![] },
        misbehavior: vec![],
        hash: p.hash,
        height: p.height,
        time: p.time,
        next_validators_hash: p.next_validators_hash,
        proposer_address: p.proposer_address,
    })
}
pub async fn prepare<E: Engine>(app: &mut App<RpcL1Source, E>, time: Time) -> Result<EtnaEnvelope> {
    let height = app.state().context("parent")?.last_height + 1;
    let r = request::PrepareProposal {
        max_tx_bytes: 22_020_096,
        txs: vec![],
        local_last_commit: None,
        misbehavior: vec![],
        height: Height::try_from(height)?,
        time,
        next_validators_hash: Hash::None,
        proposer_address: account::Id::new([1; 20]),
    };
    let Response::PrepareProposal(r) = app.handle(Request::PrepareProposal(r)).await? else {
        anyhow::bail!("wrong response")
    };
    ensure!(r.txs.len() == 1, "no proposal: {:?}", app.status());
    Ok(EtnaEnvelope::decode(&r.txs[0])?)
}
pub async fn accept<E: Engine>(
    app: &mut App<RpcL1Source, E>,
    env: &EtnaEnvelope,
    time: Time,
) -> Result<()> {
    let Response::ProcessProposal(r) =
        app.handle(Request::ProcessProposal(process_request(env, time))).await?
    else {
        anyhow::bail!("wrong response")
    };
    ensure!(r == response::ProcessProposal::Accept, "rejected: {:?}", app.status());
    app.handle(finalize_request(env, time)).await?;
    app.handle(Request::Commit).await?;
    Ok(())
}
pub fn expected(env: &EtnaEnvelope) -> ExpectedHeader {
    let h = &env.block.header;
    ExpectedHeader {
        number: h.number,
        parent_hash: h.parent_hash,
        timestamp: h.timestamp,
        beneficiary: h.beneficiary,
        extra_data: h.extra_data.clone(),
        parent_beacon_block_root: h.parent_beacon_block_root.unwrap(),
        gas_limit: h.gas_limit,
        base_fee: h.base_fee_per_gas.unwrap(),
        mix_hash: h.mix_hash,
    }
}
pub fn saved_store(parent: &AppState) -> Result<(tempfile::TempDir, Store)> {
    let dir = tempfile::tempdir()?;
    let store = Store::new(dir.path().to_path_buf());
    store.save(parent)?;
    Ok((dir, store))
}
#[derive(Clone, Debug)]
pub struct Build {
    pub list: Option<Bytes>,
    pub count: usize,
}
/// Real Engine with observable calls and source-backed unavailable-history error emulation.
pub struct ObservedEngine {
    pub inner: RpcEngine,
    pub builds: Arc<Mutex<Vec<Build>>>,
    pub unavailable: Arc<AtomicBool>,
    pub attempts: Arc<std::sync::atomic::AtomicUsize>,
}
impl ObservedEngine {
    pub fn new(inner: RpcEngine) -> Self {
        Self {
            inner,
            builds: Default::default(),
            unavailable: Default::default(),
            attempts: Default::default(),
        }
    }
}
#[async_trait::async_trait]
impl Engine for ObservedEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        self.inner.check_capabilities().await
    }
    async fn pool_transactions(&self, s: PoolSelection) -> Result<Vec<TxEnvelope>, EngineError> {
        self.inner.pool_transactions(s).await
    }
    async fn build_block(
        &self,
        p: B256,
        a: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        self.attempts.fetch_add(1, Ordering::SeqCst);
        if self.unavailable.load(Ordering::SeqCst) {
            return Err(EngineError::ErrorReply {
                call: "engine_getPayloadV5".into(),
                code: -32603,
                message: "Internal error".into(),
            });
        }
        let list = a.block_metadata.tx_list.clone();
        let b = self.inner.build_block(p, a).await?;
        self.builds.lock().unwrap().push(Build { list, count: b.transactions.len() });
        Ok(b)
    }
    async fn new_payload(&self, b: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        self.inner.new_payload(b).await
    }
    async fn forkchoice(&self, h: B256, s: B256, f: B256) -> Result<PayloadVerdict, EngineError> {
        self.inner.forkchoice(h, s, f).await
    }
    async fn header_by_number(&self, n: u64) -> Result<Option<Header>, EngineError> {
        self.inner.header_by_number(n).await
    }
}

/// Thread-safe tracing sink for observing fail-closed replay diagnostics.
pub struct LogWriter {
    pub bytes: Arc<Mutex<Vec<u8>>>,
    pub retry_recorded: Arc<tokio::sync::Notify>,
}
impl std::io::Write for LogWriter {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        let mut captured = self.bytes.lock().unwrap();
        captured.extend_from_slice(bytes);
        if captured.ends_with(b"\n") &&
            String::from_utf8_lossy(&captured).contains("forced_rebuild_unavailable")
        {
            self.retry_recorded.notify_one();
        }
        Ok(bytes.len())
    }
    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}
