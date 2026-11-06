//! Private IPC to one retained execution process. Authenticate the kernel peer on every new
//! connection before sending any public or Engine API request.
use alloy::{
    rpc::{
        client::RpcClient,
        json_rpc::{RequestPacket, ResponsePacket},
    },
    transports::{TransportError, TransportErrorKind, TransportFut},
};
use alloy_provider::{ProviderBuilder, RootProvider};
use std::{
    path::{Path, PathBuf},
    task::{Context, Poll},
    time::Duration,
};
use tokio::{
    io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader},
    net::UnixStream,
};
use tower::Service;

/// Capacity for a complete JSON-RPC reply, including hex-encoded Etna transaction data.
const MAX_REPLY: u64 = 128 << 20;
/// A freshly selected private Unix endpoint belonging to the controller's retained native child.
#[derive(Clone)]
struct OwnedIpc {
    /// Path in a private session directory, never reused by a later launch.
    socket: PathBuf,
    /// PID announced by the guardian through the inherited, anonymous parent-child pipe.
    pid: u32,
    /// Actual effective Unix user of the launched node.
    uid: u32,
    /// Bound on connecting, writing the request and reading its complete reply.
    timeout: Duration,
}
/// Build an Alloy provider over the pinned normal IPC or auth-IPC socket of this live child.
pub fn connect_owned_ipc(socket: &Path, pid: u32, uid: u32, timeout: Duration) -> RootProvider {
    ProviderBuilder::default().connect_client(RpcClient::new(
        OwnedIpc { socket: socket.to_owned(), pid, uid, timeout },
        true,
    ))
}
impl OwnedIpc {
    /// One request per authenticated connection. Closed or substituted endpoints cannot
    /// receive even a single request byte.
    async fn exchange(&self, request: RequestPacket) -> Result<ResponsePacket, TransportError> {
        let mut socket =
            UnixStream::connect(&self.socket).await.map_err(TransportErrorKind::custom)?;
        let cred = socket.peer_cred().map_err(TransportErrorKind::custom)?;
        if cred.pid().and_then(|p| u32::try_from(p).ok()) != Some(self.pid) ||
            cred.uid() != self.uid
        {
            return Err(TransportError::local_usage_str("execution IPC peer is not the owned child"))
        }
        let mut bytes = serde_json::to_vec(&request).map_err(TransportErrorKind::custom)?;
        bytes.push(b'\n');
        socket.write_all(&bytes).await.map_err(TransportErrorKind::custom)?;
        let mut reply = Vec::new();
        BufReader::new(socket)
            .take(MAX_REPLY + 1)
            .read_until(b'\n', &mut reply)
            .await
            .map_err(TransportErrorKind::custom)?;
        if reply.len() as u64 > MAX_REPLY || reply.last() != Some(&b'\n') {
            return Err(TransportError::local_usage_str(
                "truncated or oversized execution IPC reply",
            ))
        }
        serde_json::from_slice(&reply)
            .map_err(|e| TransportError::deser_err(e, "<owned IPC reply>"))
    }
}
impl Service<RequestPacket> for OwnedIpc {
    /// Parsed complete JSON-RPC reply.
    type Response = ResponsePacket;
    /// Local transport, peer authentication or response decoding failure.
    type Error = TransportError;
    /// A cancellation-safe, deadline-bounded call.
    type Future = TransportFut<'static>;
    /// Each request can open its own private connection immediately.
    fn poll_ready(&mut self, _: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }
    /// Connect, authenticate, exchange one framed packet and close the connection.
    fn call(&mut self, request: RequestPacket) -> Self::Future {
        let transport = self.clone();
        Box::pin(async move {
            tokio::time::timeout(transport.timeout, transport.exchange(request))
                .await
                .map_err(TransportErrorKind::custom)?
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_provider::Provider;
    #[tokio::test]
    async fn replacing_socket_names_with_a_foreign_process_denies_requests_before_sending() {
        let tmp = tempfile::tempdir_in("/tmp").unwrap();
        let path = tmp.path().join("rpc");
        let listener = tokio::net::UnixListener::bind(&path).unwrap();
        let pid = std::process::id();
        let rpc = connect_owned_ipc(
            &path,
            pid,
            std::fs::metadata(&path)
                .map(|m| {
                    use std::os::unix::fs::MetadataExt;
                    m.uid()
                })
                .unwrap(),
            Duration::from_secs(3),
        );
        let good = tokio::spawn(async move {
            let (socket, _) = listener.accept().await.unwrap();
            let mut reader = BufReader::new(socket);
            let mut request = Vec::new();
            reader.read_until(b'\n', &mut request).await.unwrap();
            let id = serde_json::from_slice::<serde_json::Value>(&request).unwrap()["id"].clone();
            let json = serde_json::json!({"jsonrpc":"2.0","id":id,"result":"0x1"});
            reader.into_inner().write_all(format!("{json}\n").as_bytes()).await.unwrap();
        });
        assert_eq!(rpc.get_chain_id().await.unwrap(), 1);
        good.await.unwrap();
        std::fs::remove_file(&path).unwrap();
        let ready = tmp.path().join("ready");
        let got = tmp.path().join("request-bytes");
        let script = "import socket,sys,pathlib\ns=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(1); pathlib.Path(sys.argv[2]).touch()\nc,_=s.accept(); pathlib.Path(sys.argv[3]).write_bytes(c.recv(1024))";
        let mut foreign = tokio::process::Command::new("python3")
            .arg("-c")
            .arg(script)
            .arg(&path)
            .arg(&ready)
            .arg(&got)
            .kill_on_drop(true)
            .spawn()
            .unwrap();
        tokio::time::timeout(Duration::from_secs(5), async {
            while !ready.exists() {
                tokio::task::yield_now().await;
            }
        })
        .await
        .unwrap();
        let err = rpc.get_chain_id().await.unwrap_err();
        assert!(err.to_string().contains("not the owned child"), "{err}");
        assert!(
            tokio::time::timeout(Duration::from_secs(5), foreign.wait())
                .await
                .unwrap()
                .unwrap()
                .success()
        );
        assert!(std::fs::read(got).unwrap().is_empty());
    }
}
