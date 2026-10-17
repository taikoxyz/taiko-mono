//! Bounded RPC fixtures and owned real-client processes for Docker landing scenarios.

use std::{
    collections::BTreeMap,
    fs::File,
    path::{Path, PathBuf},
    process::{ExitStatus, Stdio},
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
    time::Duration,
};

use abci::CommitteeState;
use alloy_consensus::Header;
use anyhow::{Context, Result, bail, ensure};
use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::post,
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use lander::CertifiedBlock;
use serde_json::{Value, json};
use tokio::{
    process::{Child, Command},
    sync::RwLock,
    task::JoinHandle,
    time::{sleep, timeout},
};
use url::Url;

/// Decided source data; every block/certificate comes from the shared genuine fixture generator.
#[derive(Clone)]
pub struct RpcData {
    pub blocks: Vec<CertifiedBlock>,
    pub headers: Vec<Header>,
    pub committees: BTreeMap<u64, CommitteeState>,
}

/// One local fixture endpoint supports both public L2 and CometBFT read APIs.
pub struct FixtureRpc {
    pub url: Url,
    pub data: Arc<RwLock<RpcData>>,
    pub engine_reply: Arc<RwLock<(StatusCode, Value)>>,
    pub capability_calls: Arc<AtomicUsize>,
    task: JoinHandle<()>,
}

#[derive(Clone)]
struct RpcState {
    data: Arc<RwLock<RpcData>>,
    engine_reply: Arc<RwLock<(StatusCode, Value)>>,
    capability_calls: Arc<AtomicUsize>,
}

impl FixtureRpc {
    pub async fn start(data: RpcData) -> Result<Self> {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await?;
        let url = Url::parse(&format!("http://{}/", listener.local_addr()?))?;
        let data = Arc::new(RwLock::new(data));
        let engine_reply = Arc::new(RwLock::new((
            StatusCode::OK,
            json!({
                "jsonrpc": "2.0", "result": rpc::auth::REQUIRED_ENGINE_METHODS,
            }),
        )));
        let capability_calls = Arc::new(AtomicUsize::new(0));
        let router = Router::new().route("/", post(rpc)).with_state(RpcState {
            data: data.clone(),
            engine_reply: engine_reply.clone(),
            capability_calls: capability_calls.clone(),
        });
        let task = tokio::spawn(async move {
            let _ = axum::serve(listener, router).await;
        });
        Ok(Self { url, data, engine_reply, capability_calls, task })
    }

    pub async fn replace(&self, data: RpcData) {
        *self.data.write().await = data;
    }
}

impl Drop for FixtureRpc {
    fn drop(&mut self) {
        self.task.abort();
    }
}

async fn rpc(State(state): State<RpcState>, Json(request): Json<Value>) -> Response {
    if request["method"] == "engine_exchangeCapabilities" {
        state.capability_calls.fetch_add(1, Ordering::Relaxed);
        let (status, mut reply) = state.engine_reply.read().await.clone();
        reply["id"] = request["id"].clone();
        return (status, Json(reply)).into_response();
    }
    let data = state.data.read().await;
    let method = request["method"].as_str().unwrap_or_default();
    let params = &request["params"];
    let result = match method {
        "eth_chainId" => Some(json!(format!("0x{:x}", 167001))),
        "eth_getBlockByNumber" => {
            let value = params[0].as_str().unwrap_or_default();
            let height = if value == "latest" {
                data.headers.len().checked_sub(1)
            } else {
                value.strip_prefix("0x").and_then(|n| usize::from_str_radix(n, 16).ok())
            };
            Some(height.and_then(|height| data.headers.get(height)).map_or(Value::Null, |header| {
                let mut header_json = serde_json::to_value(header).expect("header serialization");
                header_json["hash"] = json!(header.hash_slow());
                header_json
            }))
        }
        "status" => Some(json!({"node_info":{"network":"taiko-etna-167001-g0"},
            "sync_info":{"latest_block_height":data.blocks.len().to_string()}})),
        "block" | "commit" => {
            let index = params["height"]
                .as_str()
                .and_then(|height| height.parse::<usize>().ok())
                .and_then(|height| height.checked_sub(1));
            index.and_then(|index| data.blocks.get(index)).map(|pair| {
                if method == "block" {
                    json!({"block_id":pair.commit.block_id,"block":pair.block_proto().expect("fixture canonical original block")})
                } else {
                    json!({"signed_header":{"header":pair.block.header,"commit":pair.commit},"canonical":true})
                }
            })
        }
        "abci_query" => {
            let epoch = params["path"]
                .as_str()
                .and_then(|path| path.strip_prefix("/committee/"))
                .and_then(|epoch| epoch.parse::<u64>().ok());
            epoch.and_then(|epoch| data.committees.get(&epoch)).map(|committee| {
                let bytes = serde_json::to_vec(committee).expect("committee serialization");
                json!({"response":{"code":0,"value":STANDARD.encode(bytes)}})
            })
        }
        _ => None,
    };
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    Json(match result {
        Some(result) => json!({"jsonrpc":"2.0","id":id,"result":result}),
        None => {
            json!({"jsonrpc":"2.0","id":id,"error":{"code":-32602,"message":"fixture method or history unavailable"}})
        }
    }).into_response()
}

/// Paths and endpoints supplied to the actual compiled client executable.
pub struct CliInputs {
    pub l1: Url,
    pub rpc: Url,
    pub key: PathBuf,
    pub data: PathBuf,
    pub chain_config: PathBuf,
    pub max_blocks: u64,
}

impl CliInputs {
    pub fn args(&self, overrides: &[(&str, &str)]) -> Vec<String> {
        let mut args = vec![
            "lander".into(),
            "--l1.http".into(),
            self.l1.to_string(),
            "--l2.auth".into(),
            self.rpc.to_string(),
            "--jwt.secret".into(),
            self.key.with_file_name("jwt.hex").display().to_string(),
            "--l2.reward-recipient".into(),
            "0x7777777777777777777777777777777777777777".into(),
            "--l2.http".into(),
            self.rpc.to_string(),
            "--comet.http".into(),
            self.rpc.to_string(),
            "--signing-key".into(),
            self.key.display().to_string(),
            "--data-dir".into(),
            self.data.display().to_string(),
            "--chain-config".into(),
            self.chain_config.display().to_string(),
            "--max-blocks".into(),
            self.max_blocks.to_string(),
            "--max-blobs".into(),
            "6".into(),
            "--max-fee-per-gas".into(),
            "100000000000".into(),
            "--max-priority-fee-per-gas".into(),
            "1000000000".into(),
            "--max-fee-per-blob-gas".into(),
            "100000000000".into(),
            "--sidecar".into(),
            "eip7594".into(),
            "--poll.interval".into(),
            "50".into(),
            "--rpc.timeout".into(),
            "5".into(),
            "--proof.timeout".into(),
            "10".into(),
            "--broadcast.timeout".into(),
            "10".into(),
            "--receipt.timeout".into(),
            "5".into(),
            "--confirmations".into(),
            "1".into(),
        ];
        for (flag, value) in overrides {
            if let Some(index) = args.iter().position(|arg| arg == flag) {
                args[index + 1] = (*value).into();
            } else {
                args.extend([(*flag).into(), (*value).into()]);
            }
        }
        args
    }
}

/// A supervised CLI process; drop kills a remaining child before fixture teardown.
pub struct CliProcess {
    child: Child,
    log: PathBuf,
}

impl CliProcess {
    pub fn spawn(
        binary: &Path,
        inputs: &CliInputs,
        log: PathBuf,
        overrides: &[(&str, &str)],
    ) -> Result<Self> {
        let stdout = File::create(&log)?;
        let stderr = stdout.try_clone()?;
        let child = Command::new(binary)
            .args(inputs.args(overrides))
            .env_remove("L1_HTTP")
            .env_remove("L2_HTTP")
            .env_remove("L2_AUTH")
            .env_remove("JWT_SECRET")
            .env_remove("LANDER_MIN_BLOCKS")
            .env_remove("LANDER_MAX_BATCH_WAIT")
            .env_remove("METRICS_ENABLED")
            .env_remove("METRICS_ADDR")
            .env_remove("METRICS_PORT")
            .env("RUST_LOG", "info")
            .env("RUST_LOG_STYLE", "never")
            .stdout(Stdio::from(stdout))
            .stderr(Stdio::from(stderr))
            .kill_on_drop(true)
            .spawn()
            .context("start actual taiko-client lander")?;
        Ok(Self { child, log })
    }

    pub fn output(&self) -> String {
        std::fs::read_to_string(&self.log).unwrap_or_default()
    }

    pub fn assert_running(&mut self) -> Result<()> {
        if let Some(status) = self.child.try_wait()? {
            bail!("lander exited early with {status}\n{}", self.output());
        }
        Ok(())
    }

    pub async fn wait_exit(&mut self) -> Result<ExitStatus> {
        timeout(Duration::from_secs(20), self.child.wait())
            .await
            .context("lander child did not stop within 20 seconds")?
            .context("wait for lander child")
    }

    pub async fn signal(&mut self, signal: libc::c_int) -> Result<ExitStatus> {
        let id = self.child.id().context("lander child already exited")?;
        // SAFETY: kill takes no pointers; this PID is the owned child and the signal is supplied
        // by a test as SIGTERM or SIGKILL. We wait for that child immediately afterward.
        let result = unsafe { libc::kill(i32::try_from(id)?, signal) };
        ensure!(result == 0, "send child signal: {}", std::io::Error::last_os_error());
        self.wait_exit().await
    }

    pub async fn wait_phase(&mut self, directory: &Path, phase: &str) -> Result<Value> {
        timeout(Duration::from_secs(45), async {
            loop {
                self.assert_running()?;
                if let Ok(bytes) = std::fs::read(directory.join("lander-state.json")) &&
                    let Ok(journal) = serde_json::from_slice::<Value>(&bytes) &&
                    journal["state"]["phase"].as_str() == Some(phase)
                {
                    return Ok(journal);
                }
                sleep(Duration::from_millis(25)).await;
            }
        })
        .await
        .with_context(|| format!("lander did not persist phase {phase}\n{}", self.output()))?
    }
}

impl Drop for CliProcess {
    fn drop(&mut self) {
        let _ = self.child.start_kill();
    }
}
