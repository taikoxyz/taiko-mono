//! JSON-RPC server for driving preconfirmation injection.

use std::{
    future::Future,
    net::SocketAddr,
    pin::Pin,
    sync::Arc,
    task::{Context, Poll},
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_rpc_types_engine::{JwtError, JwtSecret};
use async_trait::async_trait;
use jsonrpsee::{
    RpcModule,
    server::{HttpBody, HttpRequest, HttpResponse, ServerBuilder, ServerHandle},
    types::{ErrorObjectOwned, Params},
};
use tower::{Service, ServiceBuilder};
use tracing::info;

use crate::error::{DriverError, Result as DriverResult};

/// Driver JSON-RPC method names.
#[derive(Debug, Clone, Copy)]
pub enum DriverRpcMethod {
    /// Submit a preconfirmation payload built by the client.
    SubmitPreconfirmationPayload,
    /// Return the last processed canonical proposal id.
    LastCanonicalProposalId,
}

impl DriverRpcMethod {
    /// Return the JSON-RPC method name.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::SubmitPreconfirmationPayload => "preconf_submitPreconfirmationPayload",
            Self::LastCanonicalProposalId => "preconf_lastCanonicalProposalId",
        }
    }
}

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
    pub async fn stop(self) -> DriverResult<()> {
        let stop_result = self.handle.stop().map_err(DriverError::from);
        let _ = self.handle.stopped().await;
        stop_result
    }
}

/// Build the JSON-RPC module with all driver endpoints registered.
fn build_rpc_module(api: Arc<dyn DriverRpcApi>) -> RpcModule<DriverRpcContext> {
    let mut module = RpcModule::new(DriverRpcContext { api });

    module
        .register_async_method(
            DriverRpcMethod::SubmitPreconfirmationPayload.as_str(),
            |params: Params<'static>, ctx: Arc<DriverRpcContext>, _| async move {
                ctx.api
                    .submit_execution_payload_v2(params.one()?)
                    .await
                    .map(|()| true)
                    .map_err(driver_error_into_rpc)
            },
        )
        .expect("method registration should succeed");

    module
        .register_method(
            DriverRpcMethod::LastCanonicalProposalId.as_str(),
            |_, ctx: &DriverRpcContext, _| ctx.api.last_canonical_proposal_id(),
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
        let is_valid = validate_jwt_header(&request, &self.jwt_secret).is_ok();
        let mut inner = self.service.clone();

        Box::pin(async move {
            if !is_valid {
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
    async fn stop_returns_error_when_already_stopped() {
        let addr: SocketAddr = "127.0.0.1:0".parse().expect("valid addr");
        let (stop_handle, handle) = stop_channel();
        drop(stop_handle);

        let server = DriverRpcServer { addr, handle };

        let join = spawn(async move { server.stop().await });
        let result = join.await.expect("stop task panicked");
        assert!(matches!(result, Err(DriverError::DriverRpcAlreadyStopped(_))));
    }
}
