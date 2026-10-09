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

/// Default HTTP timeout for RPC and auxiliary HTTP clients.
pub const DEFAULT_HTTP_TIMEOUT: Duration = Duration::from_secs(12);

/// Build a reqwest HTTP client with a bounded timeout.
fn reqwest_client_with_timeout() -> ReqwestClient {
    ReqwestClient::builder().timeout(DEFAULT_HTTP_TIMEOUT).build().expect("http client")
}

/// Build a [`RootProvider`] backed by a reqwest client with a bounded timeout.
pub fn connect_http_with_timeout(url: Url) -> RootProvider {
    ProviderBuilder::default().connect_reqwest(reqwest_client_with_timeout(), url)
}

/// Builds a [`RootProvider`] backed by an HTTP transport that authenticates each request
/// using the Engine API JWT scheme.
pub fn build_jwt_http_provider(url: Url, secret: JwtSecret) -> RootProvider {
    let hyper_client: HyperService<HttpConnector, Full<Bytes>> =
        HyperService::builder(TokioExecutor::new()).build_http::<Full<Bytes>>();

    let auth_layer = AuthLayer::new(secret);
    let service = ServiceBuilder::new()
        .map_err(io::Error::other)
        .layer(TimeoutLayer::new(DEFAULT_HTTP_TIMEOUT))
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

    use super::*;

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
