//! Private local session control, independent of the sequential ABCI worker.
//!
//! The control socket lives inside the private app store directory, has mode 0600, and
//! never forwards reset operations through public ABCI Query. Checks only read a short mutex.
use std::{io, path::Path, time::Duration};

use serde::Deserialize;
use tokio::{
    io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader},
    net::{UnixListener, UnixStream},
    task::JoinSet,
};

use super::{ServerError, remove_stale_socket};
use crate::app::trust::{TrustHandle, TrustSnapshot};

/// Maximum complete JSON request line, including newline.
const MAX_LINE: u64 = 16 * 1024;
/// Bounds idle peers and response writes.
const IO_TIMEOUT: Duration = Duration::from_secs(2);
/// Maximum concurrently served local control connections.
const MAX_CONNECTIONS: usize = 32;

/// Strict versioned operations; unknown operations and extra fields fail closed.
#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case", deny_unknown_fields)]
enum Request {
    /// Reads current readiness without changing or authorizing a signer session.
    Observe {
        /// One for legacy generation zero; two for recovery-aware callers.
        schema_version: u32,
    },
    /// Allocates a fresh session and closes authorization before any L1 work.
    BeginSession {
        /// One for legacy generation zero; two for recovery-aware callers.
        schema_version: u32,
    },
    /// Reads authorization for one exact process/session incarnation.
    CheckSession {
        /// One for legacy generation zero; two for recovery-aware callers.
        schema_version: u32,
        /// Opaque string returned by BeginSession.
        session_id: String,
    },
}

/// Binds the private socket before the app starts serving consensus requests.
pub(super) async fn bind(path: &Path) -> Result<UnixListener, ServerError> {
    use std::os::unix::fs::{DirBuilderExt, PermissionsExt};
    let error = |source: io::Error| ServerError::Listen {
        addr: path.display().to_string(),
        source: source.into(),
    };
    let dir = path.parent().ok_or_else(|| ServerError::SocketPath {
        path: path.into(),
        reason: "control socket has no parent directory".into(),
    })?;
    std::fs::DirBuilder::new().recursive(true).mode(0o700).create(dir).map_err(error)?;
    if !std::fs::symlink_metadata(dir).map_err(error)?.file_type().is_dir() {
        return Err(ServerError::SocketPath {
            path: dir.into(),
            reason: "store directory must not be a symlink".into(),
        });
    }
    std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700)).map_err(error)?;
    remove_stale_socket(&path.display().to_string(), path).await?;
    let listener = UnixListener::bind(path).map_err(error)?;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).map_err(error)?;
    Ok(listener)
}

/// Accepts bounded independent peers. Dropping the task aborts every child connection.
pub(super) async fn run(listener: UnixListener, trust: TrustHandle) -> io::Result<()> {
    let mut connections = JoinSet::new();
    loop {
        tokio::select! {
            accepted = listener.accept(), if connections.len() < MAX_CONNECTIONS => {
                let (stream, _) = accepted?;
                let trust = trust.clone();
                connections.spawn(async move { let _ = connection(stream, trust).await; });
            }
            _ = connections.join_next(), if !connections.is_empty() => {}
        }
    }
}

/// Serves one peer with strict framing, bounded reads and bounded writes. Parse failures close
/// the transport; no malformed request can produce an authorization response.
async fn connection(stream: UnixStream, trust: TrustHandle) -> io::Result<()> {
    let (read, mut write) = stream.into_split();
    let mut read = BufReader::new(read);
    loop {
        let mut line = Vec::new();
        let length = tokio::time::timeout(
            IO_TIMEOUT,
            (&mut read).take(MAX_LINE + 1).read_until(b'\n', &mut line),
        )
        .await??;
        if length == 0 {
            return Ok(())
        }
        if length as u64 > MAX_LINE || line.last() != Some(&b'\n') {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "oversized or incomplete control line",
            ));
        }
        let request: Request = serde_json::from_slice(&line)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        let schema_version = match &request {
            Request::Observe { schema_version } |
            Request::BeginSession { schema_version } |
            Request::CheckSession { schema_version, .. } => *schema_version,
        };
        if !matches!(schema_version, 1 | 2) ||
            (schema_version == 1 && trust.snapshot().generation.is_some_and(|g| g > 0))
        {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "unsupported control schema"));
        }
        let snapshot = match request {
            Request::Observe { .. } => trust.snapshot(),
            Request::BeginSession { .. } => trust.begin_session(),
            Request::CheckSession { session_id, .. } => trust.check_session(&session_id),
        };
        let mut bytes = response_bytes(snapshot, schema_version)?;
        bytes.push(b'\n');
        if bytes.len() as u64 > MAX_LINE {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "oversized control response"));
        }
        tokio::time::timeout(IO_TIMEOUT, write.write_all(&bytes)).await??;
    }
}

/// Encodes the requested version, refusing downgrade even if initialization raced the request.
fn response_bytes(mut snapshot: TrustSnapshot, schema_version: u32) -> io::Result<Vec<u8>> {
    // Recheck the returned snapshot too: initialization can race the preflight above.
    if schema_version == 1 && snapshot.generation.is_some_and(|g| g > 0) {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "recovery requires schema two"));
    }
    snapshot.schema_version = schema_version;
    let mut value = serde_json::to_value(&snapshot).map_err(io::Error::other)?;
    if schema_version == 1 {
        value.as_object_mut().expect("snapshot is an object").remove("recovery_origin");
    }
    serde_json::to_vec(&value).map_err(io::Error::other)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{app::trust::TrustSnapshot, test_utils::Fixture};
    use std::os::unix::fs::PermissionsExt;

    async fn exchange(path: &Path, request: &[u8]) -> io::Result<TrustSnapshot> {
        let mut stream = UnixStream::connect(path).await?;
        stream.write_all(request).await?;
        let mut response = Vec::new();
        BufReader::new(stream).read_until(b'\n', &mut response).await?;
        serde_json::from_slice(&response).map_err(io::Error::other)
    }

    #[tokio::test]
    async fn private_socket_rejects_malformed_oversized_and_stale_sessions() {
        let dir = tempfile::Builder::new().prefix("etna-t-").tempdir_in("/tmp").unwrap();
        let app = Fixture::genesis(1).app(dir.path());
        let trust = app.trust_handle();
        let path = app.trust_control_path();
        let listener = bind(&path).await.unwrap();
        assert_eq!(std::fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o600);
        assert_eq!(std::fs::metadata(dir.path()).unwrap().permissions().mode() & 0o777, 0o700);
        let task = tokio::spawn(run(listener, trust.clone()));
        let first =
            exchange(&path, b"{\"schema_version\":1,\"op\":\"begin_session\"}\n").await.unwrap();
        let second =
            exchange(&path, b"{\"schema_version\":1,\"op\":\"begin_session\"}\n").await.unwrap();
        assert_ne!(first.session_id, second.session_id);
        assert!(second.syncing && !second.trust_ready);
        let request = format!(
            "{{\"schema_version\":1,\"op\":\"check_session\",\"session_id\":\"{}\"}}\n",
            first.session_id
        );
        let stale = exchange(&path, request.as_bytes()).await.unwrap();
        assert_eq!(stale.session_id, second.session_id);
        assert!(!stale.trust_ready);
        for invalid in [
            b"{\"schema_version\":3,\"op\":\"begin_session\"}\n".as_slice(),
            b"{\"schema_version\":1,\"op\":\"begin_session\",\"extra\":true}\n",
            b"{\"schema_version\":1,\"op\":\"reset\"}\n",
            b"{\"schema_version\":1,\"op\":\"check_session\",\"session_id\":1}\n",
        ] {
            assert!(exchange(&path, invalid).await.is_err());
        }
        let oversized = vec![b'x'; MAX_LINE as usize + 1];
        assert!(exchange(&path, &oversized).await.is_err());
        assert_eq!(trust.snapshot().session_id, second.session_id);
        task.abort();
    }

    #[tokio::test]
    async fn schema_two_supports_closed_handshake_and_schema_one_stays_legacy() {
        let dir = tempfile::Builder::new().prefix("etna-t-").tempdir_in("/tmp").unwrap();
        let app = Fixture::genesis(1).app(dir.path());
        let trust = app.trust_handle();
        let path = app.trust_control_path();
        let listener = bind(&path).await.unwrap();
        let task = tokio::spawn(run(listener, trust));
        let snapshot =
            exchange(&path, b"{\"schema_version\":2,\"op\":\"begin_session\"}\n").await.unwrap();
        assert_eq!(snapshot.schema_version, 2);
        assert!(!snapshot.trust_ready && snapshot.syncing);
        let legacy = exchange(&path, b"{\"schema_version\":1,\"op\":\"observe\"}\n").await.unwrap();
        assert_eq!(legacy.schema_version, 1);
        task.abort();
    }

    #[test]
    fn recovered_snapshot_never_downgrades_to_schema_one() {
        let dir = tempfile::tempdir().unwrap();
        let app = Fixture::genesis(1).app(dir.path());
        let mut snapshot = app.trust_handle().snapshot();
        snapshot.generation = Some(1);
        assert!(response_bytes(snapshot.clone(), 1).is_err());
        let wire: serde_json::Value =
            serde_json::from_slice(&response_bytes(snapshot, 2).unwrap()).unwrap();
        assert_eq!(wire["schema_version"], 2);
        assert!(wire.as_object().unwrap().contains_key("recovery_origin"));
    }

    #[tokio::test]
    async fn observation_never_rearms_or_authorizes_a_session() {
        let dir = tempfile::Builder::new().prefix("etna-t-").tempdir_in("/tmp").unwrap();
        let app = Fixture::genesis(1).app(dir.path());
        let trust = app.trust_handle();
        let path = app.trust_control_path();
        let listener = bind(&path).await.unwrap();
        let task = tokio::spawn(run(listener, trust.clone()));
        let before = trust.snapshot();
        let observed = exchange(&path, b"{\"schema_version\":1,\"op\":\"observe\"}\n")
            .await
            .expect("private observation must be available without a signing session");
        assert_eq!(observed, before);
        assert_eq!(trust.snapshot(), before);
        task.abort();
    }

    #[tokio::test]
    async fn begin_and_check_answer_while_app_waits_on_l1_and_shutdown_revokes() {
        let dir = tempfile::Builder::new().prefix("etna-t-").tempdir_in("/tmp").unwrap();
        let fx = Fixture::genesis(1);
        let app = fx.app(dir.path());
        app.l1().state().delay = Some(Duration::from_secs(10));
        let path = app.trust_control_path();
        let trust = app.trust_handle();
        let task = tokio::spawn(crate::server::serve_with(app, "tcp://127.0.0.1:0", |_: &str| {}));
        tokio::time::timeout(Duration::from_secs(2), async {
            while !path.exists() {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
        })
        .await
        .unwrap();
        let response = tokio::time::timeout(
            Duration::from_millis(200),
            exchange(&path, b"{\"schema_version\":1,\"op\":\"begin_session\"}\n"),
        )
        .await
        .unwrap()
        .unwrap();
        let request = format!(
            "{{\"schema_version\":1,\"op\":\"check_session\",\"session_id\":\"{}\"}}\n",
            response.session_id
        );
        let checked =
            tokio::time::timeout(Duration::from_millis(200), exchange(&path, request.as_bytes()))
                .await
                .unwrap()
                .unwrap();
        assert!(!checked.trust_ready && checked.syncing);
        task.abort();
        let _ = task.await;
        assert_eq!(trust.snapshot().phase, crate::app::trust::TrustPhase::Halted);
    }
}
