//! JSON-RPC server for driving preconfirmation injection.

use std::{
    future::Future,
    net::SocketAddr,
    pin::Pin,
    sync::Arc,
    task::{Context, Poll},
    time::Instant,
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_rpc_types_engine::{JwtError, JwtSecret};
use async_trait::async_trait;
use jsonrpsee::{
    RpcModule,
    server::{HttpBody, HttpRequest, HttpResponse, ServerBuilder, ServerHandle},
    types::{ErrorObjectOwned, Params},
};
use metrics::{counter, histogram};
use protocol::shasta::DriverRpcMethod;
use tower::{Service, ServiceBuilder};
use tracing::{debug, info, warn};

use crate::{
    error::{DriverError, Result as DriverResult},
    metrics::DriverMetrics,
};

/// Service implementation backing the driver JSON-RPC server.
#[async_trait]
pub trait DriverRpcApi: Send + Sync {
    /// Submit a fully built Taiko payload attributes struct for preconfirmation injection.
    async fn submit_execution_payload_v2(
        &self,
        payload: TaikoPayloadAttributes,
    ) -> Result<(), DriverError>;

    /// Return the highest canonical proposal id processed from L1 events.
    fn last_canonical_proposal_id(&self) -> u64;
}

/// Running driver JSON-RPC server.
#[derive(Debug)]
pub struct DriverRpcServer {
    /// Socket address the server is bound to.
    addr: SocketAddr,
    /// Handle used to stop and await server shutdown.
    handle: ServerHandle,
}

/// Context wrapper passed to JSON-RPC method handlers.
#[derive(Clone)]
struct DriverRpcContext {
    /// Service implementation backing the RPC methods.
    api: Arc<dyn DriverRpcApi>,
}

impl DriverRpcServer {
    /// Start a JWT-protected JSON-RPC server.
    pub async fn start(
        listen_addr: SocketAddr,
        jwt_secret: JwtSecret,
        api: Arc<dyn DriverRpcApi>,
    ) -> DriverResult<Self> {
        let http_middleware =
            ServiceBuilder::new().layer_fn(move |service| JwtAuthService { service, jwt_secret });

        let server =
            ServerBuilder::new().set_http_middleware(http_middleware).build(listen_addr).await?;
        let addr = server.local_addr()?;

        let handle = server.start(build_rpc_module(api));

        info!(addr = %addr, "started driver JSON-RPC server");
        Ok(Self { addr, handle })
    }

    /// Return the bound socket address.
    pub const fn local_addr(&self) -> SocketAddr {
        self.addr
    }

    /// Return the HTTP URL for this server.
    pub fn http_url(&self) -> String {
        format!("http://{}", self.addr)
    }

    /// Stop the server.
    pub async fn stop(self) {
        if let Err(err) = self.handle.stop() {
            warn!(error = %err, "driver JSON-RPC server already stopped");
        }
        let _ = self.handle.stopped().await;
    }
}

/// Build the JSON-RPC module with all driver endpoints registered.
fn build_rpc_module(api: Arc<dyn DriverRpcApi>) -> RpcModule<DriverRpcContext> {
    let mut module = RpcModule::new(DriverRpcContext { api });

    module
        .register_async_method(
            DriverRpcMethod::SubmitPreconfirmationPayload.as_str(),
            |params: Params<'static>, ctx: Arc<DriverRpcContext>, _| async move {
                let method = DriverRpcMethod::SubmitPreconfirmationPayload.as_str();
                let start = Instant::now();
                debug!(method, "received RPC request");

                let result = ctx.api.submit_execution_payload_v2(params.one()?).await;

                let duration_secs = start.elapsed().as_secs_f64();
                histogram!(DriverMetrics::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_DURATION_SECONDS)
                    .record(duration_secs);
                counter!(DriverMetrics::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_REQUESTS_TOTAL)
                    .increment(1);

                match &result {
                    Ok(()) => {
                        debug!(method, duration_secs, "RPC request succeeded");
                    }
                    Err(err) => {
                        counter!(DriverMetrics::RPC_SUBMIT_PRECONFIRMATION_PAYLOAD_ERRORS_TOTAL)
                            .increment(1);
                        warn!(method, ?err, duration_secs, "RPC request failed");
                    }
                }

                result.map(|()| true).map_err(driver_error_into_rpc)
            },
        )
        .expect("method registration should succeed");

    module
        .register_method(
            DriverRpcMethod::LastCanonicalProposalId.as_str(),
            |_, ctx: &DriverRpcContext, _| {
                let method = DriverRpcMethod::LastCanonicalProposalId.as_str();
                let start = Instant::now();
                debug!(method, "received RPC request");

                let result = ctx.api.last_canonical_proposal_id();

                let duration_secs = start.elapsed().as_secs_f64();
                histogram!(DriverMetrics::RPC_LAST_CANONICAL_PROPOSAL_ID_DURATION_SECONDS)
                    .record(duration_secs);
                counter!(DriverMetrics::RPC_LAST_CANONICAL_PROPOSAL_ID_REQUESTS_TOTAL).increment(1);
                debug!(method, result, duration_secs, "RPC request succeeded");

                result
            },
        )
        .expect("method registration should succeed");

    module
}

/// Map driver errors into JSON-RPC error objects.
fn driver_error_into_rpc(err: DriverError) -> ErrorObjectOwned {
    ErrorObjectOwned::owned(-32000, err.to_string(), None::<()>)
}

/// HTTP middleware that enforces JWT authentication.
#[derive(Clone)]
struct JwtAuthService<S> {
    /// Inner HTTP service.
    service: S,
    /// JWT secret used for request validation.
    jwt_secret: JwtSecret,
}

impl<S> Service<HttpRequest> for JwtAuthService<S>
where
    S: Service<HttpRequest, Response = HttpResponse> + Clone + Send + 'static,
    S::Error: Send,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    /// Check whether the inner service is ready to accept a request.
    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.service.poll_ready(cx)
    }

    /// Validate JWT header before forwarding the request to the inner service.
    fn call(&mut self, request: HttpRequest) -> Self::Future {
        let validation_result = validate_jwt_header(&request, &self.jwt_secret);
        let mut inner = self.service.clone();

        Box::pin(async move {
            if let Err(err) = validation_result {
                counter!(DriverMetrics::RPC_UNAUTHORIZED_TOTAL).increment(1);
                warn!(?err, "RPC request rejected: unauthorized");
                return Ok(unauthorized_response());
            }
            inner.call(request).await
        })
    }
}

/// Validate the HTTP authorization header against the engine JWT secret.
fn validate_jwt_header(request: &HttpRequest, jwt_secret: &JwtSecret) -> Result<(), JwtError> {
    let Some(value) = request.headers().get("authorization") else {
        return Err(JwtError::MissingOrInvalidAuthorizationHeader);
    };
    let header = value.to_str().map_err(|_| JwtError::MissingOrInvalidAuthorizationHeader)?;
    let Some(token) = header.strip_prefix("Bearer ") else {
        return Err(JwtError::MissingOrInvalidAuthorizationHeader);
    };

    jwt_secret.validate(token)
}

/// Build a 401 Unauthorized response for failed JWT validation.
fn unauthorized_response() -> HttpResponse {
    HttpResponse::builder()
        .status(401)
        .header("content-type", "text/plain")
        .body(HttpBody::from("Unauthorized"))
        .expect("unauthorized response")
}

#[cfg(test)]
mod tests {
    use super::*;
    use jsonrpsee::server::stop_channel;
    use tokio::spawn;

    #[tokio::test]
    async fn stop_is_idempotent() {
        let addr: SocketAddr = "127.0.0.1:0".parse().expect("valid addr");
        let (stop_handle, handle) = stop_channel();
        drop(stop_handle);

        let server = DriverRpcServer { addr, handle };

        let join = spawn(async move { server.stop().await });
        join.await.expect("stop task panicked");
    }
}
