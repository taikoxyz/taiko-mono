//! JSON-RPC provider builders: timeout-bounded HTTP providers and the JWT-authenticated Engine
//! API provider.

use std::{
    fs, io,
    path::Path,
    task::{Context, Poll},
    time::Duration,
};

use alloy::{
    rpc::{
        client::RpcClient,
        json_rpc::{RequestPacket, ResponsePacket},
    },
    transports::{TransportError, TransportErrorKind, TransportFut, utils::guess_local_url},
};
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::AuthLayer;
use http_body_util::{BodyExt, Full};
use hyper::{
    Request, Response,
    body::{Bytes, Incoming},
};
use hyper_util::{
    client::legacy::{Client as HyperService, connect::HttpConnector},
    rt::TokioExecutor,
};
use reqwest::{Client as ReqwestClient, Url};
use tower::{Service, ServiceBuilder, timeout::TimeoutLayer};

/// A bounded HTTP response exceeded its allocation limit before JSON decoding.
#[derive(Debug, thiserror::Error)]
#[error("RPC response exceeds configured byte limit")]
pub struct ResponseTooLarge;

/// Preserve non-query HTTP failures when their bodies exceed the allocation cap.
/// Only success and explicit HTTP 413 expose the typed marker used for query narrowing.
fn response_limit_error(status: reqwest::StatusCode) -> TransportError {
    if status.is_success() || status == reqwest::StatusCode::PAYLOAD_TOO_LARGE {
        TransportError::local_usage(ResponseTooLarge)
    } else {
        TransportError::local_usage_str(&ResponseTooLarge.to_string())
    }
}

/// Default HTTP request timeout, for callers without a deadline of their own.
pub const DEFAULT_HTTP_TIMEOUT: Duration = Duration::from_secs(12);

/// The request timeout of an HTTP provider whose callers bound each call by `deadline`:
/// `deadline`, but never below [`DEFAULT_HTTP_TIMEOUT`], which also bounds the calls made
/// without a deadline of their own. The transport thus never cuts a call short of its caller's
/// deadline.
pub fn http_timeout_for(deadline: Duration) -> Duration {
    deadline.max(DEFAULT_HTTP_TIMEOUT)
}

/// Build a reqwest HTTP client whose requests time out after `timeout`.
fn reqwest_client_with_timeout(timeout: Duration) -> ReqwestClient {
    ReqwestClient::builder().timeout(timeout).build().expect("http client")
}

/// Build a [`RootProvider`] over HTTP(S) whose requests time out after `timeout`
/// ([`DEFAULT_HTTP_TIMEOUT`] for callers without a deadline of their own). A caller with a
/// longer deadline must pass at least that deadline, or the transport cuts its calls short.
pub fn connect_http_with_timeout(url: Url, timeout: Duration) -> RootProvider {
    let is_local = guess_local_url(url.as_str());
    let transport =
        PrivateHttp { client: reqwest_client_with_timeout(timeout), url, max_bytes: None };
    ProviderBuilder::default().connect_client(RpcClient::new(transport, is_local))
}

/// Build a credential-redacted provider with an HTTP response allocation cap, in bytes.
/// Declared and streaming bodies are bounded before JSON decoding; redirects are disabled.
/// Other constructors retain their existing response-size and redirect behavior.
pub fn connect_http_with_limits(url: Url, timeout: Duration, max_bytes: usize) -> RootProvider {
    let is_local = guess_local_url(url.as_str());
    let client = ReqwestClient::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("http client");
    let transport = PrivateHttp { client, url, max_bytes: Some(max_bytes) };
    ProviderBuilder::default().connect_client(RpcClient::new(transport, is_local))
}

/// Reqwest JSON-RPC transport that keeps endpoint credentials out of errors and tracing spans.
/// Alloy's standard reqwest transport includes the entire URL in its debug span and error chain.
#[derive(Clone)]
struct PrivateHttp {
    /// Timeout-bounded request client.
    client: ReqwestClient,
    /// Configured endpoint, used only to send requests.
    url: Url,
    /// Optional response allocation bound, checked before retaining each body chunk.
    max_bytes: Option<usize>,
}

impl Service<RequestPacket> for PrivateHttp {
    /// Parsed JSON-RPC response packet.
    type Response = ResponsePacket;
    /// Alloy-compatible HTTP, transport, and JSON decoding error.
    type Error = TransportError;
    /// Owned request future, safe to move between runtime threads.
    type Future = TransportFut<'static>;

    /// Reqwest clients can accept a request immediately.
    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }

    /// Preserve Alloy's request and response semantics while removing reqwest's attached URL
    /// before an error is boxed, so every consumer's complete source chain remains safe to print.
    fn call(&mut self, request: RequestPacket) -> Self::Future {
        let transport = self.clone();
        Box::pin(async move {
            let mut response = transport
                .client
                .post(transport.url)
                .json(&request)
                .headers(request.headers())
                .send()
                .await
                .map_err(|error| TransportErrorKind::custom(error.without_url()))?;
            let status = response.status();
            let body = if let Some(limit) = transport.max_bytes {
                if response.content_length().is_some_and(|n| n > limit as u64) {
                    return Err(response_limit_error(status));
                }
                let mut body = Vec::new();
                while let Some(chunk) = response
                    .chunk()
                    .await
                    .map_err(|error| TransportErrorKind::custom(error.without_url()))?
                {
                    if chunk.len() > limit.saturating_sub(body.len()) {
                        return Err(response_limit_error(status));
                    }
                    body.extend_from_slice(&chunk);
                }
                Bytes::from(body)
            } else {
                response
                    .bytes()
                    .await
                    .map_err(|error| TransportErrorKind::custom(error.without_url()))?
            };
            if !status.is_success() {
                return Err(TransportErrorKind::http_error(
                    status.as_u16(),
                    String::from_utf8_lossy(&body).into_owned(),
                ));
            }
            serde_json::from_slice(&body)
                .map_err(|error| TransportError::deser_err(error, String::from_utf8_lossy(&body)))
        })
    }
}

/// Builds a [`RootProvider`] backed by a plain-HTTP transport that authenticates each request
/// using the Engine API JWT scheme and times it out after `timeout`.
///
/// The connector speaks plain HTTP only: an `https` URL fails on every request.
pub fn build_jwt_http_provider(url: Url, secret: JwtSecret, timeout: Duration) -> RootProvider {
    let hyper_client: HyperService<HttpConnector, Full<Bytes>> =
        HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new()
        .map_err(io::Error::other)
        .layer(TimeoutLayer::new(timeout))
        .layer(auth_layer)
        .service(hyper_client);

    let transport = PrivateHyper { service, url };
    ProviderBuilder::default().connect_client(RpcClient::new(transport, true))
}

/// JWT HTTP transport using the same timeout and AuthLayer as Alloy, without its full-URL span.
#[derive(Clone)]
struct PrivateHyper<S> {
    /// Authenticated, timeout-bounded Hyper service.
    service: S,
    /// Configured endpoint, used only to send requests.
    url: Url,
}

impl<S> Service<RequestPacket> for PrivateHyper<S>
where
    S: Service<Request<Full<Bytes>>, Response = Response<Incoming>> + Clone + Send + Sync + 'static,
    S::Error: std::error::Error + Send + Sync + 'static,
    S::Future: Send,
{
    /// Parsed JSON-RPC response packet.
    type Response = ResponsePacket;
    /// Alloy-compatible request, transport, and JSON decoding error.
    type Error = TransportError;
    /// Owned request future, safe to move between runtime threads.
    type Future = TransportFut<'static>;

    /// The underlying Hyper client accepts requests immediately.
    fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        Poll::Ready(Ok(()))
    }

    /// Preserve Alloy's request serialization, headers, per-request JWT, and response mapping.
    fn call(&mut self, packet: RequestPacket) -> Self::Future {
        let mut transport = self.clone();
        Box::pin(async move {
            let mut builder = Request::builder()
                .method(hyper::Method::POST)
                .uri(transport.url.as_str())
                .header(hyper::header::CONTENT_TYPE, "application/json");
            for (name, value) in packet.headers().iter() {
                builder = builder.header(name, value);
            }
            let serialized = packet.serialize().map_err(TransportError::ser_err)?;
            let request = builder
                .body(Full::new(Bytes::copy_from_slice(serialized.get().as_bytes())))
                .map_err(TransportErrorKind::custom)?;
            let response =
                transport.service.call(request).await.map_err(TransportErrorKind::custom)?;
            let status = response.status();
            let body = response
                .into_body()
                .collect()
                .await
                .map_err(TransportErrorKind::custom)?
                .to_bytes();
            if !status.is_success() {
                return Err(TransportErrorKind::http_error(
                    status.as_u16(),
                    String::from_utf8_lossy(&body).into_owned(),
                ));
            }
            serde_json::from_slice(&body)
                .map_err(|error| TransportError::deser_err(error, String::from_utf8_lossy(&body)))
        })
    }
}

/// Returns the JWT secret for the engine API
/// using the provided path. If the file is not found, it will return [None].
pub fn read_jwt_secret(path: &Path) -> Option<JwtSecret> {
    if let Ok(secret) = fs::read_to_string(path) {
        return JwtSecret::from_hex(secret).ok();
    };

    None
}

#[cfg(test)]
mod tests {
    use std::{
        io::Write,
        path::PathBuf,
        sync::{Arc, Mutex},
    };

    use alloy_provider::Provider;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tracing::instrument::WithSubscriber;

    use super::*;

    #[derive(Clone)]
    struct LogBuffer(Arc<Mutex<Vec<u8>>>);

    impl Write for LogBuffer {
        fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
            self.0.lock().unwrap().extend_from_slice(bytes);
            Ok(bytes.len())
        }

        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    async fn assert_endpoint_credentials_are_hidden(provider: RootProvider) {
        let logs = LogBuffer(Arc::default());
        let writer = logs.clone();
        let subscriber = tracing_subscriber::fmt()
            .with_max_level(tracing::Level::DEBUG)
            .without_time()
            .with_ansi(false)
            .with_writer(move || writer.clone())
            .finish();
        let error = provider.get_chain_id().with_subscriber(subscriber).await.unwrap_err();
        let mut rendered = format!("{error}\n{error:?}");
        let mut source = std::error::Error::source(&error);
        while let Some(cause) = source {
            rendered.push_str(&format!("\n{cause}\n{cause:?}"));
            source = cause.source();
        }
        rendered.push_str(&String::from_utf8(logs.0.lock().unwrap().clone()).unwrap());
        for credential in ["user-secret", "pass-secret", "path-secret", "query-secret"] {
            assert!(
                !rendered.contains(credential),
                "RPC errors or debug logs exposed {credential}"
            );
        }
    }

    fn credential_path(mut url: Url) -> Url {
        url.set_path("/path-secret");
        url.set_query(Some("key=query-secret"));
        url
    }

    fn credential_url(url: Url) -> Url {
        let mut url = credential_path(url);
        url.set_username("user-secret").unwrap();
        url.set_password(Some("pass-secret")).unwrap();
        url
    }

    #[tokio::test]
    async fn connection_errors_and_debug_logs_hide_endpoint_credentials() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        drop(listener);
        assert_endpoint_credentials_are_hidden(connect_http_with_timeout(
            credential_url(url),
            Duration::from_secs(1),
        ))
        .await;
    }

    #[tokio::test]
    async fn timeout_errors_and_debug_logs_hide_endpoint_credentials() {
        let url = slow_rpc(Duration::from_secs(1)).await;
        assert_endpoint_credentials_are_hidden(connect_http_with_timeout(
            credential_url(url),
            Duration::from_millis(50),
        ))
        .await;
    }

    #[tokio::test]
    async fn jwt_connection_errors_and_debug_logs_hide_endpoint_credentials() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        drop(listener);
        assert_endpoint_credentials_are_hidden(build_jwt_http_provider(
            credential_path(url),
            secret(),
            Duration::from_secs(1),
        ))
        .await;
    }

    #[tokio::test]
    async fn jwt_timeout_errors_and_debug_logs_hide_endpoint_credentials() {
        let url = slow_rpc(Duration::from_secs(1)).await;
        assert_endpoint_credentials_are_hidden(build_jwt_http_provider(
            credential_path(url),
            secret(),
            Duration::from_millis(50),
        ))
        .await;
    }

    async fn rpc_response(status: u16, body: &'static str) -> Url {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        tokio::spawn(async move {
            let (mut socket, _) = listener.accept().await.unwrap();
            let mut request = Vec::new();
            let mut buffer = [0u8; 4096];
            while !request.ends_with(b"}") {
                let length = socket.read(&mut buffer).await.unwrap();
                assert!(length > 0);
                request.extend_from_slice(&buffer[..length]);
            }
            let response = format!(
                "HTTP/1.1 {status} Test\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                body.len()
            );
            socket.write_all(response.as_bytes()).await.unwrap();
        });
        url
    }

    #[tokio::test]
    async fn bounded_provider_rejects_declared_and_chunked_oversize_without_body_or_credentials() {
        for framing in 0..3 {
            let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
            let url = format!("http://{}/", listener.local_addr().unwrap()).parse().unwrap();
            tokio::spawn(async move {
                let (mut socket, _) = listener.accept().await.unwrap();
                let mut request = [0; 4096];
                let read = socket.read(&mut request).await.unwrap();
                assert!(read > 0);
                let response = if framing == 1 {
                    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n11\r\nsecret-body-token\r\n0\r\n\r\n"
                } else if framing == 2 {
                    "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\nsecret-body-token"
                } else {
                    "HTTP/1.1 200 OK\r\nContent-Length: 10000000\r\nConnection: close\r\n\r\nsecret-body-token"
                };
                let _ = socket.write_all(response.as_bytes()).await;
            });
            let error = connect_http_with_limits(credential_url(url), Duration::from_secs(1), 8)
                .get_chain_id()
                .await
                .unwrap_err();
            assert!(
                matches!(&error, TransportError::LocalUsageError(inner) if inner.is::<ResponseTooLarge>())
            );
            assert_eq!(
                error.to_string(),
                "local usage error: RPC response exceeds configured byte limit"
            );
            assert!(!format!("{error:?}").contains("secret"));
        }
    }

    #[tokio::test]
    async fn http_transport_preserves_status_and_error_body() {
        let url = rpc_response(429, "quota exhausted").await;
        let error =
            connect_http_with_timeout(url, DEFAULT_HTTP_TIMEOUT).get_chain_id().await.unwrap_err();
        let TransportError::Transport(TransportErrorKind::HttpError(error)) = error else {
            panic!("expected HTTP transport error");
        };
        assert_eq!(error.status, 429);
        assert_eq!(error.body, "quota exhausted");
    }

    #[tokio::test]
    async fn http_transport_preserves_rpc_errors_and_invalid_response_text() {
        let url = rpc_response(
            200,
            r#"{"jsonrpc":"2.0","id":0,"error":{"code":-32000,"message":"unavailable"}}"#,
        )
        .await;
        let error =
            connect_http_with_timeout(url, DEFAULT_HTTP_TIMEOUT).get_chain_id().await.unwrap_err();
        let TransportError::ErrorResp(error) = error else {
            panic!("expected JSON-RPC error");
        };
        assert_eq!(error.code, -32000);
        assert_eq!(error.message, "unavailable");
        let url = rpc_response(200, "invalid response").await;
        let error =
            connect_http_with_timeout(url, DEFAULT_HTTP_TIMEOUT).get_chain_id().await.unwrap_err();
        let TransportError::DeserError { text, .. } = error else {
            panic!("expected JSON decoding error");
        };
        assert_eq!(text, "invalid response");
    }

    #[tokio::test]
    async fn jwt_transport_preserves_request_target_and_refreshes_valid_authentication() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url =
            Url::parse(&format!("http://{}/rpc/path?key=test-key", listener.local_addr().unwrap()))
                .unwrap();
        let server = tokio::spawn(async move {
            let mut tokens = Vec::new();
            for _ in 0..2 {
                let (mut socket, _) = listener.accept().await.unwrap();
                let mut request = Vec::new();
                let mut buffer = [0u8; 4096];
                while !request.ends_with(b"}") {
                    let length = socket.read(&mut buffer).await.unwrap();
                    assert!(length > 0);
                    request.extend_from_slice(&buffer[..length]);
                }
                let request = String::from_utf8(request).unwrap();
                assert!(request.starts_with("POST /rpc/path?key=test-key HTTP/1.1\r\n"));
                let token = request
                    .lines()
                    .find_map(|line| {
                        let (name, value) = line.split_once(':')?;
                        name.eq_ignore_ascii_case("authorization")
                            .then(|| value.trim().strip_prefix("Bearer ").unwrap().to_owned())
                    })
                    .expect("JWT authorization header");
                secret().validate(&token).expect("fresh JWT signed by configured secret");
                tokens.push(token);
                let body = r#"{"jsonrpc":"2.0","id":0,"result":"0x7"}"#;
                let response = format!(
                    "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                    body.len()
                );
                socket.write_all(response.as_bytes()).await.unwrap();
            }
            assert_ne!(tokens[0], tokens[1], "JWT claims should refresh between requests");
        });
        let provider = build_jwt_http_provider(url, secret(), DEFAULT_HTTP_TIMEOUT);
        assert_eq!(provider.get_chain_id().await.unwrap(), 7);
        tokio::time::sleep(Duration::from_millis(1100)).await;
        assert_eq!(provider.get_chain_id().await.unwrap(), 7);
        server.await.unwrap();
    }

    /// Answers every HTTP request on a local port with an `eth_chainId` result of 7 after
    /// `delay`; returns the endpoint.
    async fn slow_rpc(delay: Duration) -> Url {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        tokio::spawn(async move {
            while let Ok((mut socket, _)) = listener.accept().await {
                tokio::spawn(async move {
                    let (mut request, mut chunk) = (Vec::new(), [0u8; 4096]);
                    // Read up to the end of the JSON body (the request is one small object).
                    while !request.ends_with(b"}") {
                        match socket.read(&mut chunk).await {
                            Ok(0) | Err(_) => return,
                            Ok(n) => request.extend_from_slice(&chunk[..n]),
                        }
                    }
                    tokio::time::sleep(delay).await;
                    let body = r#"{"jsonrpc":"2.0","id":0,"result":"0x7"}"#;
                    let response = format!(
                        "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n\
                         content-length: {}\r\nconnection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(response.as_bytes()).await;
                });
            }
        });
        url
    }

    /// The test JWT secret.
    fn secret() -> JwtSecret {
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex");
        read_jwt_secret(Path::new(path)).expect("the test JWT secret")
    }

    #[test]
    fn http_timeout_covers_the_caller_deadline() {
        assert_eq!(http_timeout_for(Duration::from_secs(5)), DEFAULT_HTTP_TIMEOUT);
        assert_eq!(http_timeout_for(DEFAULT_HTTP_TIMEOUT), DEFAULT_HTTP_TIMEOUT);
        assert_eq!(http_timeout_for(Duration::from_secs(60)), Duration::from_secs(60));
    }

    /// Both providers honour the timeout they are built with, in either direction: a reply
    /// slower than the timeout fails, one within it arrives.
    #[tokio::test]
    async fn providers_time_out_after_the_given_timeout() {
        let url = slow_rpc(Duration::from_millis(400)).await;
        let short = Duration::from_millis(100);
        let long = Duration::from_secs(5);

        assert!(connect_http_with_timeout(url.clone(), short).get_chain_id().await.is_err());
        assert_eq!(connect_http_with_timeout(url.clone(), long).get_chain_id().await.unwrap(), 7);
        let jwt = |timeout| build_jwt_http_provider(url.clone(), secret(), timeout);
        assert!(jwt(short).get_chain_id().await.is_err());
        assert_eq!(jwt(long).get_chain_id().await.unwrap(), 7);
    }

    #[test]
    fn test_read_jwt_secret() {
        let jwt_path =
            PathBuf::from(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));

        // Should successfully read the JWT secret
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_some());

        // Verify the secret is a valid 32-byte key
        let secret = secret.unwrap();
        assert_eq!(secret.as_bytes().len(), 32);
    }

    #[test]
    fn test_read_jwt_secret_nonexistent() {
        let jwt_path = PathBuf::from("/nonexistent/path/jwt.hex");

        // Should return None for non-existent file
        let secret = read_jwt_secret(jwt_path.as_path());
        assert!(secret.is_none());
    }
}
