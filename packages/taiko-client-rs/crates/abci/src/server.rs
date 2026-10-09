//! The ABCI socket server (spec §3.1, §8.1, §8.2).
//!
//! CometBFT opens four connections to the app's socket (consensus, mempool, info, snapshot).
//! [`serve`] answers them through tower-abci: [`split::service`] fans the four connections into
//! clones of one [`AppService`], and every clone forwards each request, in the order tower-abci
//! hands it over, into one unbounded channel (tower-abci keeps each connection's order and,
//! when several connections wait, favours consensus over mempool, snapshot and info requests).
//! A single dedicated task owns the [`App`] and answers that channel strictly sequentially, so
//! no two requests ever run concurrently and the app needs no locking.
//!
//! An [`AbciError::SafetyHalt`] is logged at ERROR and answered as an error; then the
//! [`HaltHook`] runs (in production [`ExitProcess`], which exits the process with
//! [`SAFETY_HALT_EXIT_CODE`]: no automatic restart into signing) and the worker stops. Any other
//! error is answered as an error too, on which tower-abci closes that connection and CometBFT
//! stops on its broken ABCI client.
//!
//! A `unix://` socket file outlives the process (exiting skips any cleanup), so [`serve_with`]
//! removes a stale socket at the path before it binds: one whose probe connection is refused.
//! Anything else there is refused.

use std::{
    future::Future,
    path::{Path, PathBuf},
    pin::Pin,
    task::{Context, Poll},
};

use tendermint::v0_38::abci::{Request, Response};
use tokio::{
    sync::{mpsc, oneshot},
    task::JoinHandle,
};
use tower::Service;
use tower_abci::{
    BoxError,
    v038::{Server, split},
};

use crate::{
    app::{AbciError, App},
    engine::Engine,
    l1::L1Source,
    metrics::AbciMetrics,
};

/// The process exit code after a safety halt.
pub const SAFETY_HALT_EXIT_CODE: i32 = 2;

/// The default ABCI listen address (CometBFT's default `proxy_app`).
pub const DEFAULT_ADDR: &str = "tcp://127.0.0.1:26658";

/// Queue bound of each tower-abci component service; [`AppService::call`] never waits, so one
/// slot suffices.
const SPLIT_BOUND: usize = 1;

/// How long [`remove_stale_socket`] waits for its probe connection to an existing socket file.
#[cfg(unix)]
const SOCKET_PROBE_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(1);

/// Errors of [`serve`]. The server only returns when it fails.
#[derive(Debug, thiserror::Error)]
pub enum ServerError {
    /// The listen address is neither `tcp://<host>:<port>` nor `unix://<path>`.
    #[error("invalid ABCI address {0:?}: expected tcp://<host>:<port> or unix://<path>")]
    InvalidAddr(String),
    /// The listener could not bind or stopped accepting connections.
    #[error("ABCI listener on {addr} failed: {source}")]
    Listen {
        /// The configured listen address.
        addr: String,
        /// The listener's error.
        source: BoxError,
    },
    /// The `unix://` socket path holds something the server must not replace: a file that is
    /// not a socket (never removed), a socket another process still listens on, or a socket
    /// whose probe connection failed other than by refusal (so it is not known to be stale).
    #[error("ABCI socket path {}: {reason}", path.display())]
    SocketPath {
        /// The configured socket path.
        path: PathBuf,
        /// Why the path cannot be used.
        reason: String,
    },
    /// The app worker stopped (a safety halt whose hook returned, or a panic); the value says
    /// why.
    #[error("ABCI app worker stopped: {0}")]
    WorkerStopped(String),
}

/// A parsed ABCI listen address.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ListenAddr {
    /// `tcp://<host>:<port>`; the value is `<host>:<port>`.
    Tcp(String),
    /// `unix://<path>`; the value is the socket path.
    Unix(PathBuf),
}

impl ListenAddr {
    /// Parses `tcp://<host>:<port>` (non-empty host, `u16` port) or `unix://<path>` (non-empty
    /// path, e.g. `unix:///run/abci.sock`).
    pub fn parse(addr: &str) -> Result<Self, ServerError> {
        let invalid = || ServerError::InvalidAddr(addr.to_string());
        if let Some(host_port) = addr.strip_prefix("tcp://") {
            match host_port.rsplit_once(':') {
                Some((host, port)) if !host.is_empty() && port.parse::<u16>().is_ok() => {
                    Ok(Self::Tcp(host_port.to_string()))
                }
                _ => Err(invalid()),
            }
        } else if let Some(path) = addr.strip_prefix("unix://") {
            if path.is_empty() { Err(invalid()) } else { Ok(Self::Unix(PathBuf::from(path))) }
        } else {
            Err(invalid())
        }
    }
}

/// What runs when a request ends in an [`AbciError::SafetyHalt`]: called once, after the
/// failing request was answered, with the halt's message. The worker stops when it returns.
pub trait HaltHook: Send + 'static {
    /// Reacts to the safety halt described by `reason`.
    fn halt(&self, reason: &str);
}

/// The production [`HaltHook`]: exits the process with [`SAFETY_HALT_EXIT_CODE`].
#[derive(Clone, Copy, Debug, Default)]
pub struct ExitProcess;

impl HaltHook for ExitProcess {
    /// Exits the process with [`SAFETY_HALT_EXIT_CODE`] (the state is already durable: `Commit`
    /// persists before it answers).
    fn halt(&self, _reason: &str) {
        std::process::exit(SAFETY_HALT_EXIT_CODE)
    }
}

impl<F: Fn(&str) + Send + 'static> HaltHook for F {
    /// Calls the closure with `reason`.
    fn halt(&self, reason: &str) {
        self(reason)
    }
}

/// Something that answers ABCI requests one at a time: the [`App`], or a test double.
pub trait AbciHandler: Send + 'static {
    /// Answers `req`.
    fn handle_request(
        &mut self,
        req: Request,
    ) -> impl Future<Output = Result<Response, AbciError>> + Send;
}

impl<L: L1Source, E: Engine> AbciHandler for App<L, E> {
    /// Forwards to [`App::handle`].
    fn handle_request(
        &mut self,
        req: Request,
    ) -> impl Future<Output = Result<Response, AbciError>> + Send {
        self.handle(req)
    }
}

/// One queued request and where its answer goes.
type Job = (Request, oneshot::Sender<Result<Response, BoxError>>);

/// A cloneable [`Service`] that queues every request for the single app worker and resolves
/// with its answer; requests run in the order of the [`Service::call`]s.
#[derive(Clone, Debug)]
pub struct AppService {
    /// The worker's request queue.
    requests: mpsc::UnboundedSender<Job>,
}

impl AppService {
    /// Spawns the worker task owning `handler` and returns a service feeding it, plus the
    /// worker's handle, which resolves with why it stopped.
    pub fn spawn<H: AbciHandler, K: HaltHook>(handler: H, halt: K) -> (Self, JoinHandle<String>) {
        let (requests, queue) = mpsc::unbounded_channel();
        (Self { requests }, tokio::spawn(run_worker(handler, queue, halt)))
    }
}

/// The app worker is gone; requests can no longer be answered.
#[derive(Debug, thiserror::Error)]
#[error("the ABCI app worker has stopped")]
struct WorkerGone;

impl Service<Request> for AppService {
    /// The app's answer.
    type Response = Response;
    /// The app's error, or [`WorkerGone`].
    type Error = BoxError;
    /// Resolves when the worker answered.
    type Future = Pin<Box<dyn Future<Output = Result<Response, BoxError>> + Send>>;

    /// Ready while the worker runs.
    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), BoxError>> {
        Poll::Ready(if self.requests.is_closed() { Err(WorkerGone.into()) } else { Ok(()) })
    }

    /// Queues `req` at once (fixing its place in the order) and returns the answer's future.
    fn call(&mut self, req: Request) -> Self::Future {
        let (reply, answer) = oneshot::channel();
        let queued = self.requests.send((req, reply)).is_ok();
        Box::pin(async move {
            if !queued {
                return Err(WorkerGone.into());
            }
            answer.await.map_err(|_| BoxError::from(WorkerGone))?
        })
    }
}

/// Serves `app` on `addr` (`tcp://<host>:<port>` or `unix://<path>`) until the listener fails;
/// a safety halt exits the process (see the module docs).
pub async fn serve<L: L1Source, E: Engine>(app: App<L, E>, addr: &str) -> Result<(), ServerError> {
    serve_with(app, addr, ExitProcess).await
}

/// [`serve`] for any [`AbciHandler`], running `halt` on a safety halt. Returns when the listener
/// fails or the worker stops.
///
/// A `unix://` address first clears a stale socket file at its path ([`remove_stale_socket`]).
pub async fn serve_with<H: AbciHandler, K: HaltHook>(
    handler: H,
    addr: &str,
    halt: K,
) -> Result<(), ServerError> {
    let listen_addr = ListenAddr::parse(addr)?;
    if let ListenAddr::Unix(path) = &listen_addr {
        remove_stale_socket(addr, path).await?;
    }
    let (service, worker) = AppService::spawn(handler, halt);
    let (consensus, mempool, snapshot, info) = split::service(service, SPLIT_BOUND);
    let server = Server::builder()
        .consensus(consensus)
        .mempool(mempool)
        .info(info)
        .snapshot(snapshot)
        .finish()
        .expect("all four ABCI services are set");
    let listen = async move {
        match listen_addr {
            ListenAddr::Tcp(host_port) => server.listen_tcp(host_port).await,
            #[cfg(unix)]
            ListenAddr::Unix(path) => server.listen_unix(path).await,
            #[cfg(not(unix))]
            ListenAddr::Unix(_) => Err("unix sockets need a unix platform".into()),
        }
    };
    tokio::select! {
        result = listen => Err(ServerError::Listen {
            addr: addr.to_string(),
            source: result.err().unwrap_or_else(|| "the listener returned".into()),
        }),
        stopped = worker => Err(ServerError::WorkerStopped(
            stopped.unwrap_or_else(|e| format!("the worker task failed: {e}")),
        )),
    }
}

/// Removes a stale unix socket left at `path` (the configured address `addr`) by an earlier
/// run, so binding does not fail with `AddrInUse`; a missing path is fine.
///
/// Only a socket whose probe connection is refused (`ECONNREFUSED`: nothing listens on it) is
/// stale and removed. Anything else is [`ServerError::SocketPath`] and left in place: a path that
/// is not a socket; a socket that accepts the probe or, with a full backlog, cannot take it yet
/// (`EAGAIN`: the probe never blocks); a probe failing otherwise (e.g. `EACCES`); or no answer
/// within [`SOCKET_PROBE_TIMEOUT`]. Failing to inspect or remove the path is
/// [`ServerError::Listen`]. (On macOS a full backlog also refuses connections, so a live
/// listener with a full backlog looks stale there.)
#[cfg(unix)]
async fn remove_stale_socket(addr: &str, path: &Path) -> Result<(), ServerError> {
    use std::{io::ErrorKind, os::unix::fs::FileTypeExt};

    let listen_error = |source: std::io::Error| ServerError::Listen {
        addr: addr.to_string(),
        source: source.into(),
    };
    let refuse = |reason: String| ServerError::SocketPath { path: path.to_path_buf(), reason };
    let meta = match std::fs::symlink_metadata(path) {
        Ok(meta) => meta,
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(()),
        Err(e) => return Err(listen_error(e)),
    };
    if !meta.file_type().is_socket() {
        return Err(refuse("the path exists and is not a socket".into()));
    }
    let live = "another process listens on the socket";
    match tokio::time::timeout(SOCKET_PROBE_TIMEOUT, tokio::net::UnixStream::connect(path)).await {
        Ok(Err(e)) if e.kind() == ErrorKind::ConnectionRefused => {}
        Ok(Ok(_)) => return Err(refuse(live.into())),
        Ok(Err(e)) if e.kind() == ErrorKind::WouldBlock => {
            return Err(refuse(format!("{live} (its backlog is full)")));
        }
        Ok(Err(e)) => {
            return Err(refuse(format!("probing the socket failed ({e}); it is left in place")));
        }
        Err(_) => {
            return Err(refuse(format!(
                "the socket did not answer a probe within {SOCKET_PROBE_TIMEOUT:?}; it is left in \
                 place"
            )));
        }
    }
    tracing::info!(path = %path.display(), "removing the stale ABCI socket");
    std::fs::remove_file(path).map_err(listen_error)
}

/// Without unix sockets nothing is ever left at a `unix://` path (serving one fails later).
#[cfg(not(unix))]
async fn remove_stale_socket(_addr: &str, _path: &Path) -> Result<(), ServerError> {
    Ok(())
}

/// The app worker: answers `queue` one request at a time with `handler`, in queue order.
///
/// Returns why it stopped: a safety halt (after answering it and running `halt`) or a closed
/// queue.
async fn run_worker<H: AbciHandler, K: HaltHook>(
    mut handler: H,
    mut queue: mpsc::UnboundedReceiver<Job>,
    halt: K,
) -> String {
    while let Some((req, reply)) = queue.recv().await {
        let method = method_name(&req);
        // A dropped `reply` means the connection is gone: there is nobody to answer.
        match handler.handle_request(req).await {
            Ok(response) => {
                let _ = reply.send(Ok(response));
            }
            Err(AbciError::SafetyHalt(reason)) => {
                tracing::error!(
                    method,
                    %reason,
                    "safety halt: stopping the node; an operator must investigate"
                );
                AbciMetrics::halted().set(1);
                let message = format!("safety halt in {method}: {reason}");
                let _ = reply.send(Err(message.clone().into()));
                halt.halt(&message);
                return message;
            }
            Err(error) => {
                tracing::error!(method, %error, "ABCI request failed");
                let _ = reply.send(Err(Box::new(error)));
            }
        }
    }
    "the request queue closed".to_string()
}

/// The ABCI method name of `req`, for logs.
const fn method_name(req: &Request) -> &'static str {
    match req {
        Request::Echo(_) => "Echo",
        Request::Flush => "Flush",
        Request::Info(_) => "Info",
        Request::InitChain(_) => "InitChain",
        Request::Query(_) => "Query",
        Request::CheckTx(_) => "CheckTx",
        Request::Commit => "Commit",
        Request::ListSnapshots => "ListSnapshots",
        Request::OfferSnapshot(_) => "OfferSnapshot",
        Request::LoadSnapshotChunk(_) => "LoadSnapshotChunk",
        Request::ApplySnapshotChunk(_) => "ApplySnapshotChunk",
        Request::PrepareProposal(_) => "PrepareProposal",
        Request::ProcessProposal(_) => "ProcessProposal",
        Request::ExtendVote(_) => "ExtendVote",
        Request::VerifyVoteExtension(_) => "VerifyVoteExtension",
        Request::FinalizeBlock(_) => "FinalizeBlock",
    }
}

#[cfg(test)]
mod tests;
