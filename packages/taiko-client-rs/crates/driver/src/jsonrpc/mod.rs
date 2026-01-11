//! JSON-RPC server for driving preconfirmation injection.

use std::{net::SocketAddr, sync::Arc};

use alloy_rpc_types_engine::{ExecutionPayloadInputV2, JwtError, JwtSecret};
use async_trait::async_trait;
use jsonrpsee::{
    RpcModule,
    server::{ServerBuilder, ServerHandle},
    types::{ErrorObjectOwned, Params},
};
use tower::ServiceBuilder;
use tracing::info;

use crate::error::DriverError;

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
    /// Submit a fully built execution payload for preconfirmation injection.
    async fn submit_execution_payload_v2(
        &self,
        payload: ExecutionPayloadInputV2,
    ) -> std::result::Result<(), DriverError>;

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
    ) -> crate::error::Result<Self> {
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
        self.handle.stop().expect("server should stop");
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
                let payload: ExecutionPayloadInputV2 = params.one()?;
                ctx.api
                    .submit_execution_payload_v2(payload)
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

impl<S> tower::Service<jsonrpsee::server::HttpRequest> for JwtAuthService<S>
where
    S: tower::Service<jsonrpsee::server::HttpRequest, Response = jsonrpsee::server::HttpResponse>
        + Clone
        + Send
        + 'static,
    S::Error: Send,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future = std::pin::Pin<
        Box<
            dyn std::future::Future<Output = std::result::Result<Self::Response, Self::Error>>
                + Send,
        >,
    >;

    /// Check whether the inner service is ready to accept a request.
    fn poll_ready(
        &mut self,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<std::result::Result<(), Self::Error>> {
        self.service.poll_ready(cx)
    }

    /// Validate JWT header before forwarding the request to the inner service.
    fn call(&mut self, request: jsonrpsee::server::HttpRequest) -> Self::Future {
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
fn validate_jwt_header(
    request: &jsonrpsee::server::HttpRequest,
    jwt_secret: &JwtSecret,
) -> std::result::Result<(), JwtError> {
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
fn unauthorized_response() -> jsonrpsee::server::HttpResponse {
    jsonrpsee::server::HttpResponse::builder()
        .status(401)
        .header("content-type", "text/plain")
        .body(jsonrpsee::server::HttpBody::from("Unauthorized"))
        .expect("unauthorized response")
}
