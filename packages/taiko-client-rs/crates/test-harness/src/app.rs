//! In-process `abci` apps, each on a dedicated OS thread with its own tokio runtime.
//!
//! Stopping an app shuts its runtime down, which drops the listener and every tower-abci
//! connection task with it: CometBFT sees exactly what it sees when the app process dies. Starting
//! it again builds a fresh app over the same store directory and port, as an operator restarting
//! the process would.

use std::{
    fs,
    path::PathBuf,
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};

use abci::{App, AppOptions, ChainParams, Engine, RpcEngine, RpcL1Source, Store, serve_with};
use anyhow::{Context, Result, anyhow, ensure};
use rpc::client::connect_http_with_timeout;
use tokio::{net::TcpStream, sync::oneshot};
use url::Url;

use crate::{
    boot::{POLL, RPC_TIMEOUT, RethNode},
    wait::wait_until,
};

/// How long a stopping app's runtime may take to finish its blocking tasks.
const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(5);

/// Deadline for a started app to listen on its port.
const LISTEN_TIMEOUT: Duration = Duration::from_secs(10);

/// Everything needed to (re)start app `index`.
#[derive(Clone, Debug)]
pub(crate) struct AppConfig {
    /// The validator index (logs, thread names).
    pub index: usize,
    /// The alethia-reth node it drives.
    pub reth: RethNode,
    /// anvil's JSON-RPC URL on the host (its own L1 view).
    pub l1_http: Url,
    /// The chain parameters.
    pub params: ChainParams,
    /// The Engine API JWT secret file.
    pub jwt: PathBuf,
    /// Its store directory (`abci-state.json`), kept across restarts.
    pub store_dir: PathBuf,
    /// The host port it listens on (all interfaces), kept across restarts.
    pub port: u16,
}

/// One app: its config, its recorded safety halt and, while it runs, its thread.
#[derive(Debug)]
pub(crate) struct AppNode {
    /// What it (re)starts with.
    config: AppConfig,
    /// The reason of a safety halt, once one happened (kept across restarts).
    halt: Arc<Mutex<Option<String>>>,
    /// The running app, if any.
    running: Option<AppThread>,
}

impl AppNode {
    /// Starts app `config.index` on `config.port` and returns once it listens.
    pub(crate) async fn start(config: AppConfig) -> Result<Self> {
        let mut node = Self { config, halt: Arc::new(Mutex::new(None)), running: None };
        node.launch().await?;
        Ok(node)
    }

    /// The host port it listens on.
    pub(crate) fn port(&self) -> u16 {
        self.config.port
    }

    /// The reason of its safety halt, if it halted.
    pub(crate) fn halt(&self) -> Option<String> {
        self.halt.lock().ok().and_then(|h| h.clone())
    }

    /// Whether its thread is running.
    pub(crate) fn is_running(&self) -> bool {
        self.running.as_ref().is_some_and(|t| !t.is_finished())
    }

    /// Starts a stopped app again over the same store and port; returns once it listens.
    pub(crate) async fn launch(&mut self) -> Result<()> {
        ensure!(self.running.is_none(), "app {} is already running", self.config.index);
        let i = self.config.index;
        let (ready_tx, ready_rx) = oneshot::channel();
        let (stop_tx, stop_rx) = oneshot::channel();
        let config = self.config.clone();
        let halt = self.halt.clone();
        let thread = thread::Builder::new()
            .name(format!("abci-app-{i}"))
            .spawn(move || run(config, halt, ready_tx, stop_rx))
            .context("spawning the app thread")?;
        self.running = Some(AppThread { stop: Some(stop_tx), thread: Some(thread) });

        let ready = tokio::time::timeout(RPC_TIMEOUT + LISTEN_TIMEOUT, ready_rx)
            .await
            .map_err(|_| anyhow!("app {i} did not come up in time"))
            .and_then(|r| r.map_err(|_| anyhow!("app {i} thread exited during startup")))
            .and_then(|r| r.map_err(|e| anyhow!("app {i} failed to start: {e}")));
        if let Err(e) = ready {
            self.stop().await;
            return Err(e);
        }
        let port = self.config.port;
        let running = &self.running;
        let listening = wait_until(
            &format!("app {i} listening on {port}"),
            LISTEN_TIMEOUT,
            POLL,
            || async move {
                ensure!(
                    running.as_ref().is_some_and(|t| !t.is_finished()),
                    "the app thread stopped"
                );
                Ok(TcpStream::connect(("127.0.0.1", port)).await.ok().map(drop))
            },
        )
        .await;
        if let Err(e) = listening {
            self.stop().await;
            return Err(e);
        }
        tracing::info!(app = i, port, "app started");
        Ok(())
    }

    /// Stops the app completely (runtime shut down, listener and connections closed); a no-op
    /// when it is not running.
    pub(crate) async fn stop(&mut self) {
        if let Some(thread) = self.running.take() {
            let i = self.config.index;
            if let Err(e) = tokio::task::spawn_blocking(move || drop(thread)).await {
                eprintln!("app {i}: joining its thread failed: {e}");
            }
            tracing::info!(app = i, "app stopped");
        }
    }
}

/// A running app thread; dropping it stops the app and joins the thread.
#[derive(Debug)]
struct AppThread {
    /// Dropping (or sending on) it stops the app.
    stop: Option<oneshot::Sender<()>>,
    /// The thread, joined on drop.
    thread: Option<thread::JoinHandle<()>>,
}

impl AppThread {
    /// Whether the thread has exited (the server stopped on its own).
    fn is_finished(&self) -> bool {
        self.thread.as_ref().is_none_or(|t| t.is_finished())
    }
}

impl Drop for AppThread {
    /// Signals the stop and joins the thread (blocking).
    fn drop(&mut self) {
        drop(self.stop.take());
        if let Some(thread) = self.thread.take() &&
            thread.join().is_err()
        {
            eprintln!("an abci app thread panicked");
        }
    }
}

/// The app thread: builds a runtime, builds the app inside it (reporting on `ready`), serves it
/// until `stop` fires or the server stops, then shuts the runtime down.
fn run(
    config: AppConfig,
    halt: Arc<Mutex<Option<String>>>,
    ready: oneshot::Sender<Result<(), String>>,
    stop: oneshot::Receiver<()>,
) {
    let i = config.index;
    let runtime = match tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .thread_name(format!("abci-app-{i}-rt"))
        .enable_all()
        .build()
    {
        Ok(rt) => rt,
        Err(e) => {
            let _ = ready.send(Err(format!("building the runtime: {e}")));
            return;
        }
    };
    runtime.block_on(async move {
        let app = match build_app(&config).await {
            Ok(app) => app,
            Err(e) => {
                let _ = ready.send(Err(format!("{e:#}")));
                return;
            }
        };
        let _ = ready.send(Ok(()));
        let hook = move |reason: &str| {
            eprintln!("app {i} safety halt: {reason}");
            if let Ok(mut h) = halt.lock() {
                *h = Some(reason.to_string());
            }
        };
        let addr = format!("tcp://0.0.0.0:{}", config.port);
        tokio::select! {
            result = serve_with(app, &addr, hook) => {
                if let Err(e) = result {
                    eprintln!("app {i} server stopped: {e}");
                }
            }
            _ = stop => {}
        }
    });
    // Drops every task still alive (the tower-abci connections), closing their sockets.
    runtime.shutdown_timeout(SHUTDOWN_TIMEOUT);
}

/// Waits for the EL's Engine API and builds the app over its store.
async fn build_app(c: &AppConfig) -> Result<App<RpcL1Source, RpcEngine>> {
    let engine = RpcEngine::new(c.reth.http.clone(), c.reth.auth.clone(), &c.jwt)?;
    let engine_ref = &engine;
    wait_until(
        &format!("engine API of alethia-reth {}", c.index),
        RPC_TIMEOUT,
        POLL,
        || async move {
            engine_ref.check_capabilities().await?;
            Ok(Some(()))
        },
    )
    .await?;
    fs::create_dir_all(&c.store_dir)?;
    let l1 = RpcL1Source::new(connect_http_with_timeout(c.l1_http.clone()));
    let store = Store::new(c.store_dir.clone());
    Ok(App::new(l1, engine, c.params.clone(), store, AppOptions::default())?)
}

/// A free host port (bound on all interfaces, then released).
pub(crate) fn free_port() -> Result<u16> {
    Ok(std::net::TcpListener::bind("0.0.0.0:0")?.local_addr()?.port())
}
