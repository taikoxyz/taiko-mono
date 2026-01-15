//! Minimal beacon API stub for driver tests.

use std::sync::Arc;

use anyhow::Result;
use http_body_util::Full;
use hyper::{
    Method, StatusCode,
    body::Bytes as HyperBytes,
    header::CONTENT_TYPE,
    server::conn::http1::Builder as Http1Builder,
    service::service_fn,
};
use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};
use url::Url;

/// Minimal beacon API stub for driver startup (genesis/spec/block endpoints).
pub struct BeaconStubServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
}

impl BeaconStubServer {
    pub async fn start() -> Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let endpoint = Url::parse(&format!("http://{addr}"))?;

        let shutdown = Arc::new(Notify::new());
        let cancel = shutdown.clone();

        let handle = spawn(async move {
            loop {
                select! {
                    _ = cancel.notified() => break,
                    accept_result = listener.accept() => {
                        let Ok((stream, _)) = accept_result else { continue };
                        spawn(async move {
                            let io = hyper_util::rt::TokioIo::new(stream);
                            let service = service_fn(|req| async move {
                                Ok::<_, hyper::Error>(handle_beacon_request(req))
                            });
                            let _ = Http1Builder::new().serve_connection(io, service).await;
                        });
                    }
                }
            }
        });

        Ok(Self { endpoint, shutdown, handle })
    }

    pub fn endpoint(&self) -> &Url {
        &self.endpoint
    }

    pub async fn shutdown(self) -> Result<()> {
        self.shutdown.notify_waiters();
        self.handle.await?;
        Ok(())
    }
}

fn handle_beacon_request(
    req: hyper::Request<hyper::body::Incoming>,
) -> hyper::Response<Full<HyperBytes>> {
    let empty_response = |status| {
        hyper::Response::builder().status(status).body(Full::new(HyperBytes::new())).unwrap()
    };

    if req.method() != Method::GET {
        return empty_response(StatusCode::METHOD_NOT_ALLOWED);
    }

    let path = req.uri().path();
    let json = match path {
        "/eth/v1/beacon/genesis" => r#"{"data":{"genesis_time":"0"}}"#,
        "/eth/v1/config/spec" => r#"{"data":{"SECONDS_PER_SLOT":"12"}}"#,
        _ if path.starts_with("/eth/v2/beacon/blocks/") => {
            r#"{"data":{"message":{"body":{"execution_payload":{"block_number":"0"}}}}}"#
        }
        _ => return empty_response(StatusCode::NOT_FOUND),
    };

    hyper::Response::builder()
        .status(StatusCode::OK)
        .header(CONTENT_TYPE, "application/json")
        .body(Full::new(HyperBytes::from(json)))
        .unwrap()
}
