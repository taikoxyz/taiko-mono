//! Shared request state used by REST and websocket handlers.

use std::sync::Arc;

use super::{WhitelistApi, auth::JwtAuth};

/// Shared state for REST/WS handlers.
#[derive(Clone)]
pub(super) struct AppState {
    /// Shared API implementation used by all request handlers.
    pub(super) api: Arc<dyn WhitelistApi>,
    /// Optional shared JWT validator; `None` disables auth checks.
    pub(super) jwt_auth: Option<Arc<JwtAuth>>,
}
