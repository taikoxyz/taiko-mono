//! Real ABCI CLI termination with live socket-protocol connections.
#![cfg(unix)]

use std::{io::ErrorKind, process::Stdio, time::Duration};

use anyhow::{Context, Result, ensure};
use axum::{Json, Router, routing::post};
use prost::Message;
use serde_json::{Value, json};
use tendermint_proto::v0_38::abci as pb;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpListener, TcpStream},
    process::Command,
};

async fn rpc(Json(request): Json<Value>) -> Json<Value> {
    let result = match request["method"].as_str() {
        Some("eth_chainId") => json!(format!("{:#x}", 167001)),
        Some("eth_getBlockByNumber") => Value::Null,
        Some("engine_exchangeCapabilities") => json!(rpc::auth::REQUIRED_ENGINE_METHODS),
        other => panic!("unexpected startup RPC: {other:?}"),
    };
    Json(json!({"jsonrpc":"2.0", "id":request["id"], "result":result}))
}

async fn response(stream: &mut TcpStream) -> Result<pb::Response> {
    let mut prefix = Vec::new();
    let length = loop {
        prefix.push(stream.read_u8().await?);
        if let Ok(length) = prost::encoding::decode_varint(&mut prefix.as_slice()) {
            break usize::try_from(length)?;
        }
        ensure!(prefix.len() < 10, "invalid ABCI length prefix");
    };
    ensure!(length <= 65536, "unexpectedly large ABCI response");
    let mut body = vec![0; length];
    stream.read_exact(&mut body).await?;
    Ok(pb::Response::decode(body.as_slice())?)
}

/// Open connections and a partial frame must not retain the CLI after SIGTERM.
#[tokio::test]
#[ignore = "integration"]
async fn abci_sigterm_closes_live_connections_and_exits() -> Result<()> {
    let rpc_listener = TcpListener::bind("127.0.0.1:0").await?;
    let endpoint = format!("http://{}", rpc_listener.local_addr()?);
    let router = Router::new().route("/", post(rpc));
    let rpc_task = tokio::spawn(async move { axum::serve(rpc_listener, router).await });
    let reservation = TcpListener::bind("127.0.0.1:0").await?;
    let address = reservation.local_addr()?;
    drop(reservation);
    let dir = tempfile::tempdir()?;
    let jwt = dir.path().join("jwt.hex");
    std::fs::write(&jwt, "11".repeat(32))?;
    let log = dir.path().join("abci.log");
    let output = std::fs::File::create(&log)?;
    let mut child = Command::new(env!("CARGO_BIN_EXE_taiko-client"))
        .args([
            "abci",
            "--fee-recipient",
            "0x7777777777777777777777777777777777777777",
            "--l1.http",
            &endpoint,
            "--l2.http",
            &endpoint,
            "--l2.auth",
            &endpoint,
            "--jwt.secret",
            &jwt.display().to_string(),
            "--abci.addr",
            &format!("tcp://{address}"),
            "--data-dir",
            &dir.path().join("state").display().to_string(),
        ])
        .env_remove("METRICS_ENABLED")
        .env_remove("METRICS_ADDR")
        .env_remove("METRICS_PORT")
        .env("RUST_LOG", "info")
        .env("RUST_LOG_STYLE", "never")
        .stdout(Stdio::from(output.try_clone()?))
        .stderr(Stdio::from(output))
        .kill_on_drop(true)
        .spawn()?;
    let mut first = tokio::time::timeout(Duration::from_secs(10), async {
        loop {
            ensure!(
                child.try_wait()?.is_none(),
                "ABCI exited before listening: {}",
                std::fs::read_to_string(&log)?
            );
            if let Ok(stream) = TcpStream::connect(address).await {
                return anyhow::Ok(stream);
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    })
    .await
    .context("ABCI CLI did not listen")??;
    let info = pb::Request {
        value: Some(pb::request::Value::Info(pb::RequestInfo {
            version: "0.40.0".into(),
            block_version: 11,
            p2p_version: 9,
            abci_version: "2.2.0".into(),
        })),
    };
    let flush = pb::Request { value: Some(pb::request::Value::Flush(pb::RequestFlush {})) };
    first
        .write_all(
            &[info.encode_length_delimited_to_vec(), flush.encode_length_delimited_to_vec()]
                .concat(),
        )
        .await?;
    tokio::time::timeout(Duration::from_secs(5), async {
        ensure!(
            matches!(response(&mut first).await?.value, Some(pb::response::Value::Info(_))),
            "real ABCI Info must complete before shutdown"
        );
        ensure!(
            matches!(response(&mut first).await?.value, Some(pb::response::Value::Flush(_))),
            "ABCI Flush must complete"
        );
        anyhow::Ok(())
    })
    .await
    .context("ABCI handshake did not finish")??;
    let mut streams = vec![first];
    for _ in 0..3 {
        streams.push(TcpStream::connect(address).await?);
    }
    // Keep a decoder waiting in an incomplete frame, as well as idle connections.
    streams[3].write_all(&[0x80]).await?;
    let pid = child.id().context("live ABCI child")?.to_string();
    ensure!(Command::new("kill").args(["-TERM", &pid]).status().await?.success(), "send SIGTERM");
    let status = tokio::time::timeout(Duration::from_secs(15), child.wait()).await.with_context(
        || {
            format!(
                "Rust ABCI shutdown hung: {}",
                std::fs::read_to_string(&log).unwrap_or_default()
            )
        },
    )??;
    ensure!(status.success(), "ABCI shutdown failed: {}", std::fs::read_to_string(&log)?);
    for mut stream in streams {
        let read = tokio::time::timeout(Duration::from_secs(2), stream.read(&mut [0u8; 1])).await?;
        ensure!(
            matches!(read, Ok(0)) ||
                matches!(read, Err(ref error) if matches!(error.kind(), ErrorKind::ConnectionReset | ErrorKind::ConnectionAborted)),
            "ABCI socket remained open after process exit: {read:?}"
        );
    }
    ensure!(TcpStream::connect(address).await.is_err(), "ABCI listener remained live");
    rpc_task.abort();
    Ok(())
}
