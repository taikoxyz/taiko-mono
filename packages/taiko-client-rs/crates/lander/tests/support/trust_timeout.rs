//! Inject one private-check timeout while forwarding genuine app observations unchanged.
use anyhow::{Context, Result, ensure};
use std::{
    path::{Path, PathBuf},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    task::JoinHandle,
};

pub struct TrustTimeout {
    path: PathBuf,
    backend: PathBuf,
    task: JoinHandle<()>,
    pub fired: Arc<AtomicBool>,
    pub ready_when_delayed: Arc<AtomicBool>,
}

pub async fn observe(path: &Path) -> Result<serde_json::Value> {
    let mut peer = UnixStream::connect(path).await?;
    peer.write_all(b"{\"schema_version\":1,\"op\":\"observe\"}\n").await?;
    let mut line = String::new();
    BufReader::new(peer).read_line(&mut line).await?;
    Ok(serde_json::from_str(&line)?)
}

impl TrustTimeout {
    pub async fn install(store: &Path) -> Result<Self> {
        let path = store.join("checkpoint-trust.sock");
        let backend = store.join("trust-backend.sock");
        let before = observe(&path).await?;
        ensure!(before["trust_ready"] == true, "timeout begins on a ready app");
        std::fs::rename(&path, &backend)?;
        let listener = UnixListener::bind(&path)?;
        let fired = Arc::new(AtomicBool::new(false));
        let ready_when_delayed = Arc::new(AtomicBool::new(false));
        let target = backend.clone();
        let triggered = fired.clone();
        let observed = ready_when_delayed.clone();
        let task = tokio::spawn(async move {
            let mut children = tokio::task::JoinSet::new();
            loop {
                tokio::select! {
                    accepted = listener.accept() => {
                        let Ok((peer, _)) = accepted else { break };
                        let target = target.clone();
                        let triggered = triggered.clone();
                        let observed = observed.clone();
                        children.spawn(async move {
                            let result: Result<()> = async {
                                let mut peer = BufReader::new(peer);
                                let mut line = String::new();
                                peer.read_line(&mut line).await?;
                                let request: serde_json::Value = serde_json::from_str(&line)?;
                                if request["op"] == "check_session" && !triggered.swap(true, Ordering::SeqCst) {
                                    let status = observe(&target).await?;
                                    observed.store(status["trust_ready"] == true, Ordering::SeqCst);
                                    // Beyond the actual signer's one-second private-control deadline.
                                    tokio::time::sleep(Duration::from_millis(1500)).await;
                                }
                                let mut upstream = UnixStream::connect(target).await?;
                                upstream.write_all(line.as_bytes()).await?;
                                line.clear();
                                BufReader::new(upstream).read_line(&mut line).await?;
                                peer.get_mut().write_all(line.as_bytes()).await?;
                                Ok(())
                            }.await;
                            let _ = result; // The timed-out peer deliberately closes before its reply.
                        });
                    }
                    _ = children.join_next(), if !children.is_empty() => {}
                }
            }
        });
        Ok(Self { path, backend, task, fired, ready_when_delayed })
    }
    pub async fn wait_recovered(&self, old_session: &str) -> Result<String> {
        test_harness::wait_until(
            "automatic signer-timeout recovery",
            Duration::from_secs(40),
            Duration::from_millis(100),
            || async {
                let current = observe(&self.backend).await?;
                let session = current["session_id"].as_str().context("opaque private session")?;
                Ok((self.fired.load(Ordering::SeqCst) &&
                    current["trust_ready"] == true &&
                    session != old_session)
                    .then(|| session.to_owned()))
            },
        )
        .await
    }
}
impl Drop for TrustTimeout {
    fn drop(&mut self) {
        self.task.abort();
        let _ = std::fs::remove_file(&self.path);
        let _ = std::fs::rename(&self.backend, &self.path);
    }
}
