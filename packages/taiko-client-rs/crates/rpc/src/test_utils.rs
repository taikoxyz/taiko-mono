//! HTTP stub servers shared by this crate's unit tests.

use std::{
    sync::{Arc, Mutex, mpsc},
    time::Duration,
};

use http_body_util::Full;
use hyper::{
    StatusCode, Uri, body::Bytes as HyperBytes, header::CONTENT_TYPE,
    server::conn::http1::Builder as Http1Builder, service::service_fn,
};
use tokio::{
    net::TcpListener,
    runtime::{Builder, Runtime},
    select, spawn,
    sync::Notify,
    task::{JoinHandle, spawn_blocking},
    time::timeout,
};
use url::Url;

/// Local HTTP server that answers each request with the status and JSON body its handler returns
/// for the request URI, and records the URIs it receives.
pub(crate) struct TestServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
    requests: Arc<Mutex<Vec<Uri>>>,
}

impl TestServer {
    pub(crate) async fn start(
        handler: impl Fn(&Uri) -> (StatusCode, String) + Send + Sync + 'static,
    ) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .expect("test server should bind an ephemeral port");
        let addr = listener.local_addr().expect("listener address should be available");
        let endpoint =
            Url::parse(&format!("http://{addr}")).expect("test endpoint URL should parse");

        let shutdown = Arc::new(Notify::new());
        let cancel = shutdown.clone();
        let handler = Arc::new(handler);
        let requests = Arc::new(Mutex::new(Vec::new()));
        let recorded = requests.clone();

        let handle = spawn(async move {
            loop {
                select! {
                    _ = cancel.notified() => break,
                    accept_result = listener.accept() => {
                        let Ok((stream, _)) = accept_result else { continue };
                        let handler = handler.clone();
                        let recorded = recorded.clone();
                        spawn(async move {
                            let io = hyper_util::rt::TokioIo::new(stream);
                            let service = service_fn(move |request: hyper::Request<_>| {
                                recorded.lock().unwrap().push(request.uri().clone());
                                let (status, body) = handler(request.uri());
                                async move {
                                    Ok::<_, hyper::Error>(
                                        hyper::Response::builder()
                                            .status(status)
                                            .header(CONTENT_TYPE, "application/json")
                                            .body(Full::new(HyperBytes::from(body)))
                                            .expect("test response should build"),
                                    )
                                }
                            });
                            let _ = Http1Builder::new().serve_connection(io, service).await;
                        });
                    }
                }
            }
        });

        Self { endpoint, shutdown, handle, requests }
    }

    pub(crate) fn endpoint(&self) -> Url {
        self.endpoint.clone()
    }

    /// URIs of the requests received so far whose path starts with `prefix`, in order.
    pub(crate) fn requests_with_prefix(&self, prefix: &str) -> Vec<Uri> {
        self.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|uri| uri.path().starts_with(prefix))
            .cloned()
            .collect()
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        self.shutdown.notify_waiters();
        self.handle.abort();
    }
}

/// A current-thread runtime whose blocking pool has a single thread, for
/// [`assert_waits_for_blocking_pool`].
pub(crate) fn single_blocking_thread_runtime() -> Runtime {
    Builder::new_current_thread()
        .enable_all()
        .max_blocking_threads(1)
        .build()
        .expect("test runtime should build")
}

/// Asserts that `fut`, polled on a [`single_blocking_thread_runtime`], cannot finish while the only
/// thread of the blocking pool is busy: its work runs on the blocking pool, not on the async
/// runtime.
pub(crate) async fn assert_waits_for_blocking_pool(fut: impl Future) {
    let (release, busy) = mpsc::channel::<()>();
    let occupied = spawn_blocking(move || busy.recv());
    let finished = timeout(Duration::from_millis(250), fut).await.is_ok();
    release.send(()).expect("the blocking pool thread should be waiting");
    occupied
        .await
        .expect("the blocking pool thread should not panic")
        .expect("the blocking pool thread should be released");
    assert!(!finished, "the future finished while the blocking pool was busy");
}

/// Starts a beacon node stub, with genesis at 0 and 12-second slots, that answers every request
/// other than the genesis and spec ones through `handler`.
pub(crate) async fn start_beacon(
    handler: impl Fn(&Uri) -> (StatusCode, String) + Send + Sync + 'static,
) -> TestServer {
    TestServer::start(move |uri| match uri.path() {
        "/eth/v1/beacon/genesis" => (StatusCode::OK, r#"{"data":{"genesis_time":"0"}}"#.to_owned()),
        "/eth/v1/config/spec" => (
            StatusCode::OK,
            r#"{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}"#.to_owned(),
        ),
        _ => handler(uri),
    })
    .await
}
