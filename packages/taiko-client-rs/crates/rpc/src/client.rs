//! JSON-RPC provider builders: timeout-bounded HTTP providers and the JWT-authenticated Engine
//! API provider.

use std::{fs, io, path::Path, time::Duration};

use alloy::rpc::client::RpcClient;
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::JwtSecret;
use alloy_transport_http::{AuthLayer, Http, HyperClient};
use http_body_util::Full;
use hyper::body::Bytes;
use hyper_util::{
    client::legacy::{Client as HyperService, connect::HttpConnector},
    rt::TokioExecutor,
};
use reqwest::{Client as ReqwestClient, Url};
use tower::{ServiceBuilder, timeout::TimeoutLayer};

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
    ProviderBuilder::default().connect_reqwest(reqwest_client_with_timeout(timeout), url)
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

    let layer_transport = HyperClient::<Full<Bytes>, _>::with_service(service);
    let http_hyper = Http::with_client(layer_transport, url);

    ProviderBuilder::default().connect_client(RpcClient::new(http_hyper, true))
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
    use std::path::PathBuf;

    use alloy_provider::Provider;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    use super::*;

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
